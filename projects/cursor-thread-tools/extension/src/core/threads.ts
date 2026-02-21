import Database from 'better-sqlite3';
import {
  getComposerDataEntries,
  getBlobByBytes,
  findConversationState,
  type DbPathOptions,
} from '../db/reader';
import {
  decodeConversationStateString,
  decodeTurnStructure,
  decodeUserMessage,
  decodeStep,
  type DecodedStep,
} from '../proto/decoder';
import { type ExportedTurn } from '../export/markdown';

export { type DbPathOptions } from '../db/reader';

export interface ComposerMeta {
  composerId: string;
  name?: string;
  createdAt?: number;
  isAgentic?: boolean;
  bubbleCount: number;
  headers: Array<{ bubbleId: string; type: number }>;
  rawJson: string;
}

export interface ExportConfig {
  includeThinking: boolean;
  outputDir: string;
  fileNameFormat: string;
}

export const DEFAULT_EXPORT_CONFIG: ExportConfig = {
  includeThinking: true,
  outputDir: '.thread-exports',
  fileNameFormat: '{name}_{date}',
};

export function parseComposerData(key: string, value: unknown): ComposerMeta | null {
  if (typeof value !== 'string') return null;
  try {
    const data = JSON.parse(value as string);
    const headers: Array<{ bubbleId: string; type: number }> =
      data.fullConversationHeadersOnly ?? [];
    return {
      composerId: data.composerId ?? key.replace('composerData:', ''),
      name: data.name || undefined,
      createdAt: data.createdAt,
      isAgentic: data.isAgentic,
      bubbleCount: headers.length,
      headers,
      rawJson: value as string,
    };
  } catch {
    return null;
  }
}

export function formatDate(ms: number | undefined): string {
  if (!ms) return 'unknown';
  return new Date(ms).toLocaleString();
}

export function listAllThreads(db: Database.Database): ComposerMeta[] {
  const rows = getComposerDataEntries(db);
  const threads: ComposerMeta[] = [];
  for (const row of rows) {
    const meta = parseComposerData(row.key, row.value);
    if (meta && meta.bubbleCount > 0) {
      threads.push(meta);
    }
  }
  threads.sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));
  return threads;
}

function collectAssistantText(steps: DecodedStep[]): {
  text: string;
  thinkingText: string;
} {
  const textParts: string[] = [];
  const thinkingParts: string[] = [];

  for (const step of steps) {
    if (step.type === 'assistant' && step.text) {
      textParts.push(step.text);
    } else if (step.type === 'thinking' && step.text) {
      thinkingParts.push(step.text);
    }
  }

  return {
    text: textParts.join(''),
    thinkingText: thinkingParts.join('\n\n'),
  };
}

export interface ExtractResult {
  turns: ExportedTurn[];
  decoded: number;
  skipped: number;
  totalTurnBlobIds: number;
}

export function extractThreadContent(
  db: Database.Database,
  meta: ComposerMeta,
): ExtractResult | null {
  const csString = findConversationState(
    db,
    meta.composerId,
    meta.headers,
    meta.rawJson,
  );

  if (!csString) return null;

  const cs = decodeConversationStateString(csString);
  if (cs.turnBlobIds.length === 0) {
    return { turns: [], decoded: 0, skipped: 0, totalTurnBlobIds: 0 };
  }

  const exportedTurns: ExportedTurn[] = [];
  let decoded = 0;
  let skipped = 0;

  for (const turnBlobId of cs.turnBlobIds) {
    const turnBlob = getBlobByBytes(db, turnBlobId);
    if (!turnBlob) {
      skipped++;
      continue;
    }

    const turn = decodeTurnStructure(turnBlob);
    if (!turn) {
      skipped++;
      continue;
    }

    const turnWithIds = turn as typeof turn & {
      _userMsgBlobId: Buffer | null;
      _stepBlobIds: Buffer[];
    };

    if (turnWithIds._userMsgBlobId) {
      const umBlob = getBlobByBytes(db, turnWithIds._userMsgBlobId);
      if (umBlob) {
        const userMsg = decodeUserMessage(umBlob);
        if (userMsg && userMsg.text) {
          exportedTurns.push({ type: 'human', text: userMsg.text });
        }
      }
    }

    const steps: DecodedStep[] = [];
    for (const stepBlobId of turnWithIds._stepBlobIds) {
      const stepBlob = getBlobByBytes(db, stepBlobId);
      if (stepBlob) {
        steps.push(decodeStep(stepBlob));
      }
    }

    if (steps.length > 0) {
      const { text, thinkingText } = collectAssistantText(steps);
      if (text) {
        exportedTurns.push({
          type: 'assistant',
          text,
          thinkingText: thinkingText || undefined,
        });
      }
    }

    decoded++;
  }

  return {
    turns: exportedTurns,
    decoded,
    skipped,
    totalTurnBlobIds: cs.turnBlobIds.length,
  };
}

export function resolveFileName(
  format: string,
  meta: ComposerMeta,
): string {
  const date = new Date().toISOString().split('T')[0];
  const safeName = (meta.name || meta.composerId)
    .replace(/[^a-zA-Z0-9\u3000-\u9fff\u4e00-\u9fff_-]/g, '_')
    .slice(0, 60);
  const shortId = Date.now().toString(36);

  return format
    .replace('{name}', safeName)
    .replace('{date}', date)
    .replace('{id}', shortId) + '.md';
}
