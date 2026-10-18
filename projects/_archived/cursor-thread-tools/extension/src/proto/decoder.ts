/**
 * Minimal protobuf wire-format decoder for agent.v1 messages.
 *
 * Zero external dependencies — parses raw protobuf bytes using only
 * wire-type 0 (varint) and wire-type 2 (length-delimited).
 *
 * Message schema recovered from Cursor's workbench.desktop.main.js:
 *
 *   ConversationTurnStructure (agentKv:blob)
 *     1: agent_conversation_turn  (message, oneof turn)
 *     2: shell_conversation_turn  (message, oneof turn)
 *
 *   AgentConversationTurnStructure
 *     1: user_message  (bytes = blob ID)
 *     2: steps         (repeated bytes = blob IDs)
 *     3: request_id    (string, optional)
 *
 *   UserMessage
 *     1: text        (string)
 *     2: message_id  (string)
 *
 *   ConversationStep
 *     1: assistant_message  (message, oneof)
 *     2: tool_call          (message, oneof)
 *     3: thinking_message   (message, oneof)
 *
 *   AssistantMessage
 *     1: text  (string)
 *
 *   ThinkingMessage
 *     1: text         (string)
 *     2: duration_ms  (uint32)
 *
 *   ConversationStateStructure
 *     2: turns_old                  (repeated bytes)
 *     8: turns                      (repeated bytes)
 *     1: root_prompt_messages_json  (repeated bytes)
 */

export interface ProtobufField {
  fieldNum: number;
  wireType: number;
  data: Buffer;   // wire-type 2: raw bytes
  varint?: number; // wire-type 0: decoded value
}

function readVarint(buf: Buffer, pos: number): [number, number] {
  let val = 0;
  let shift = 0;
  while (pos < buf.length && buf[pos] & 0x80) {
    val |= (buf[pos] & 0x7f) << shift;
    shift += 7;
    pos++;
  }
  if (pos < buf.length) {
    val |= (buf[pos] & 0x7f) << shift;
    pos++;
  }
  return [val, pos];
}

export function parseProtobufFields(buf: Buffer): ProtobufField[] {
  const fields: ProtobufField[] = [];
  let pos = 0;
  while (pos < buf.length) {
    const tag = buf[pos];
    pos++;
    const fieldNum = tag >> 3;
    const wireType = tag & 0x07;

    if (wireType === 0) {
      const [val, newPos] = readVarint(buf, pos);
      pos = newPos;
      fields.push({ fieldNum, wireType, data: Buffer.alloc(0), varint: val });
    } else if (wireType === 2) {
      const [len, newPos] = readVarint(buf, pos);
      pos = newPos;
      if (pos + len > buf.length) break;
      const data = buf.slice(pos, pos + len);
      pos += len;
      fields.push({ fieldNum, wireType, data });
    } else if (wireType === 5) {
      pos += 4;
    } else if (wireType === 1) {
      pos += 8;
    } else {
      break;
    }
  }
  return fields;
}

function getField(fields: ProtobufField[], num: number): ProtobufField | undefined {
  return fields.find(f => f.fieldNum === num);
}

function getAllFields(fields: ProtobufField[], num: number): ProtobufField[] {
  return fields.filter(f => f.fieldNum === num);
}

// --- High-level decoders ---

export interface DecodedUserMessage {
  text: string;
  messageId: string;
}

export interface DecodedStep {
  type: 'assistant' | 'tool_call' | 'thinking' | 'unknown';
  text: string;
  durationMs?: number;
}

export interface DecodedTurn {
  userMessage: DecodedUserMessage | null;
  steps: DecodedStep[];
}

export interface DecodedConversationState {
  turnBlobIds: Buffer[];
}

export function decodeConversationState(buf: Buffer): DecodedConversationState {
  const fields = parseProtobufFields(buf);
  let turnBlobIds = getAllFields(fields, 8).map(f => f.data);
  if (turnBlobIds.length === 0) {
    turnBlobIds = getAllFields(fields, 2).map(f => f.data);
  }
  return { turnBlobIds };
}

export function decodeTurnStructure(buf: Buffer): DecodedTurn | null {
  const fields = parseProtobufFields(buf);
  const agentTurnField = getField(fields, 1);
  if (!agentTurnField) return null;

  const innerFields = parseProtobufFields(agentTurnField.data);
  const userMsgBlobId = getField(innerFields, 1)?.data ?? null;
  const stepBlobIds = getAllFields(innerFields, 2).map(f => f.data);

  return {
    userMessage: null, // populated later after blob lookup
    steps: [],         // populated later after blob lookup
    _userMsgBlobId: userMsgBlobId,
    _stepBlobIds: stepBlobIds,
  } as DecodedTurn & { _userMsgBlobId: Buffer | null; _stepBlobIds: Buffer[] };
}

export function decodeUserMessage(buf: Buffer): DecodedUserMessage | null {
  const fields = parseProtobufFields(buf);
  const textField = getField(fields, 1);
  const msgIdField = getField(fields, 2);
  if (!textField) return null;
  return {
    text: textField.data.toString('utf8'),
    messageId: msgIdField?.data.toString('utf8') ?? '',
  };
}

export function decodeStep(buf: Buffer): DecodedStep {
  const fields = parseProtobufFields(buf);

  // field 1 = assistant_message
  const assistantField = getField(fields, 1);
  if (assistantField) {
    const inner = parseProtobufFields(assistantField.data);
    const text = getField(inner, 1)?.data.toString('utf8') ?? '';
    return { type: 'assistant', text };
  }

  // field 3 = thinking_message
  const thinkingField = getField(fields, 3);
  if (thinkingField) {
    const inner = parseProtobufFields(thinkingField.data);
    const text = getField(inner, 1)?.data.toString('utf8') ?? '';
    const durationMs = getField(inner, 2)?.varint;
    return { type: 'thinking', text, durationMs };
  }

  // field 2 = tool_call (extract minimal info)
  const toolCallField = getField(fields, 2);
  if (toolCallField) {
    return { type: 'tool_call', text: '' };
  }

  return { type: 'unknown', text: '' };
}

/**
 * Decode a conversationState string (from composerData or bubbleId JSON).
 * "~" prefix → base64, otherwise hex.
 */
export function decodeConversationStateString(csString: string): DecodedConversationState {
  const buf = csString.startsWith('~')
    ? Buffer.from(csString.slice(1), 'base64')
    : Buffer.from(csString, 'hex');
  return decodeConversationState(buf);
}
