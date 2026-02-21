export interface ExportedTurn {
  type: 'human' | 'assistant';
  text: string;
  thinkingText?: string;
  toolName?: string;
}

export interface MarkdownOptions {
  includeThinking?: boolean;
  includeToolCalls?: boolean;
  fileNameFormat?: string;
}

export function generateMarkdown(
  threadName: string,
  turns: ExportedTurn[],
  options: MarkdownOptions = {},
): string {
  const date = new Date().toISOString().split('T')[0];
  const lines: string[] = [
    `# ${threadName}`,
    `_Exported on ${date} from Cursor Thread Tools_`,
    '',
    '---',
    '',
  ];

  for (const turn of turns) {
    if (turn.type === 'human') {
      lines.push('**User**', '', turn.text, '', '---', '');
    } else {
      lines.push('**Assistant**', '');

      if (options.includeThinking && turn.thinkingText) {
        lines.push(
          '<details>',
          '<summary>Thinking</summary>',
          '',
          turn.thinkingText,
          '',
          '</details>',
          '',
        );
      }

      if (options.includeToolCalls && turn.toolName) {
        lines.push(`> Tool: ${turn.toolName}`, '');
      }

      lines.push(turn.text, '', '---', '');
    }
  }

  return lines.join('\n');
}
