import * as vscode from 'vscode';
import {
  openDatabase,
  getComposerDataEntries,
  getBlobByBytes,
  findConversationState,
} from '../db/reader';
import {
  decodeConversationStateString,
  decodeTurnStructure,
  decodeUserMessage,
  decodeStep,
  type DecodedStep,
} from '../proto/decoder';
import { generateMarkdown, type ExportedTurn } from '../export/markdown';
import { join } from 'path';
import { mkdirSync, writeFileSync } from 'fs';

interface ComposerMeta {
  composerId: string;
  name?: string;
  createdAt?: number;
  isAgentic?: boolean;
  bubbleCount: number;
  headers: Array<{ bubbleId: string; type: number }>;
  rawJson: string;
}

function parseComposerData(key: string, value: unknown): ComposerMeta | null {
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

function formatDate(ms: number | undefined): string {
  if (!ms) return 'unknown';
  return new Date(ms).toLocaleString();
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

export async function exportThread(): Promise<void> {
  let db;
  try {
    db = openDatabase();
    const rows = getComposerDataEntries(db);

    const threads: ComposerMeta[] = [];
    for (const row of rows) {
      const meta = parseComposerData(row.key, row.value);
      if (meta && meta.bubbleCount > 0) {
        threads.push(meta);
      }
    }

    threads.sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));

    if (threads.length === 0) {
      vscode.window.showInformationMessage('No threads found.');
      return;
    }

    interface ThreadQuickPickItem extends vscode.QuickPickItem {
      composerId: string;
      meta: ComposerMeta;
    }

    const items: ThreadQuickPickItem[] = threads.map(t => ({
      label: t.name || t.composerId.slice(0, 12) + '...',
      description: t.isAgentic ? 'Agent' : 'Chat',
      detail: `${t.bubbleCount} messages | ${formatDate(t.createdAt)}`,
      composerId: t.composerId,
      meta: t,
    }));

    const selected = await vscode.window.showQuickPick(items, {
      placeHolder: `Select a thread to export (${threads.length} available)`,
      matchOnDetail: true,
    });

    if (!selected) return;

    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: `Exporting: ${selected.label}`,
        cancellable: false,
      },
      async progress => {
        progress.report({ message: 'Finding conversation state...' });

        const csString = findConversationState(
          db!,
          selected.composerId,
          selected.meta.headers,
          selected.meta.rawJson,
        );

        if (!csString) {
          vscode.window.showWarningMessage(
            'Could not find conversation state for this thread. ' +
              'The thread may use a newer data format not yet supported.',
          );
          return;
        }

        const cs = decodeConversationStateString(csString);
        if (cs.turnBlobIds.length === 0) {
          vscode.window.showWarningMessage(
            'No turn data found in conversation state.',
          );
          return;
        }

        progress.report({
          message: `Decoding ${cs.turnBlobIds.length} turns...`,
        });

        const exportedTurns: ExportedTurn[] = [];
        let decoded = 0;
        let skipped = 0;

        for (const turnBlobId of cs.turnBlobIds) {
          const turnBlob = getBlobByBytes(db!, turnBlobId);
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

          // Decode user message
          if (turnWithIds._userMsgBlobId) {
            const umBlob = getBlobByBytes(db!, turnWithIds._userMsgBlobId);
            if (umBlob) {
              const userMsg = decodeUserMessage(umBlob);
              if (userMsg && userMsg.text) {
                exportedTurns.push({
                  type: 'human',
                  text: userMsg.text,
                });
              }
            }
          }

          // Decode steps (assistant responses)
          const steps: DecodedStep[] = [];
          for (const stepBlobId of turnWithIds._stepBlobIds) {
            const stepBlob = getBlobByBytes(db!, stepBlobId);
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

        if (exportedTurns.length === 0) {
          vscode.window.showWarningMessage(
            `Could not extract any text from ${cs.turnBlobIds.length} turns (${skipped} skipped).`,
          );
          return;
        }

        progress.report({ message: 'Generating Markdown...' });

        const markdown = generateMarkdown(
          selected.label,
          exportedTurns,
          { includeThinking: true },
        );

        // Save to workspace or temp directory
        const workspaceFolders = vscode.workspace.workspaceFolders;
        let outputDir: string;

        if (workspaceFolders && workspaceFolders.length > 0) {
          outputDir = join(
            workspaceFolders[0].uri.fsPath,
            '.thread-exports',
          );
        } else {
          const { tmpdir } = await import('os');
          outputDir = join(tmpdir(), 'thread-exports');
        }

        mkdirSync(outputDir, { recursive: true });

        const safeName = (selected.label || selected.composerId)
          .replace(/[^a-zA-Z0-9\u3000-\u9fff\u4e00-\u9fff_-]/g, '_')
          .slice(0, 60);
        const fileName = `${safeName}_${Date.now().toString(36)}.md`;
        const filePath = join(outputDir, fileName);

        writeFileSync(filePath, markdown, 'utf8');

        const doc = await vscode.workspace.openTextDocument(filePath);
        await vscode.window.showTextDocument(doc, { preview: false });

        vscode.window.showInformationMessage(
          `Exported ${exportedTurns.length} turns (${decoded} decoded, ${skipped} skipped) → ${fileName}`,
        );
      },
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    vscode.window.showErrorMessage(`Thread Tools Export: ${msg}`);
  } finally {
    db?.close();
  }
}
