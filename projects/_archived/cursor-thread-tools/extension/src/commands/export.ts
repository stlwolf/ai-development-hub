import * as vscode from 'vscode';
import { openDatabase } from '../db/reader';
import {
  listAllThreads,
  extractThreadContent,
  resolveFileName,
  formatDate,
  DEFAULT_EXPORT_CONFIG,
  type ComposerMeta,
  type ExportConfig,
} from '../core/threads';
import { generateMarkdown } from '../export/markdown';
import { join } from 'path';
import { mkdirSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';

function readExportConfig(): ExportConfig {
  const cfg = vscode.workspace.getConfiguration('cursorThreadTools');
  return {
    includeThinking: cfg.get<boolean>('export.includeThinking', DEFAULT_EXPORT_CONFIG.includeThinking),
    outputDir: cfg.get<string>('export.outputDir', DEFAULT_EXPORT_CONFIG.outputDir),
    fileNameFormat: cfg.get<string>('export.fileNameFormat', DEFAULT_EXPORT_CONFIG.fileNameFormat),
  };
}

export async function exportThread(): Promise<void> {
  let db;
  try {
    db = openDatabase();
    const threads = listAllThreads(db);

    if (threads.length === 0) {
      vscode.window.showInformationMessage('No threads found.');
      return;
    }

    interface ThreadQuickPickItem extends vscode.QuickPickItem {
      composerId: string;
      meta: ComposerMeta;
    }

    const items: ThreadQuickPickItem[] = threads.map((t: ComposerMeta) => ({
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

    const config = readExportConfig();

    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: `Exporting: ${selected.label}`,
        cancellable: false,
      },
      async progress => {
        progress.report({ message: 'Extracting thread content...' });

        const result = extractThreadContent(db!, selected.meta);

        if (!result) {
          vscode.window.showWarningMessage(
            'Could not find conversation state for this thread. ' +
              'The thread may use a newer data format not yet supported.',
          );
          return;
        }

        if (result.turns.length === 0) {
          vscode.window.showWarningMessage(
            `Could not extract any text from ${result.totalTurnBlobIds} turns (${result.skipped} skipped).`,
          );
          return;
        }

        progress.report({ message: 'Generating Markdown...' });

        const markdown = generateMarkdown(
          selected.label,
          result.turns,
          { includeThinking: config.includeThinking },
        );

        const workspaceFolders = vscode.workspace.workspaceFolders;
        let outputDir: string;

        if (workspaceFolders && workspaceFolders.length > 0) {
          outputDir = join(workspaceFolders[0].uri.fsPath, config.outputDir);
        } else {
          outputDir = join(tmpdir(), 'thread-exports');
        }

        mkdirSync(outputDir, { recursive: true });

        const fileName = resolveFileName(config.fileNameFormat, selected.meta);
        const filePath = join(outputDir, fileName);

        writeFileSync(filePath, markdown, 'utf8');

        const doc = await vscode.workspace.openTextDocument(filePath);
        await vscode.window.showTextDocument(doc, { preview: false });

        try {
          await vscode.commands.executeCommand(
            'composer.addfilestocomposer',
            vscode.Uri.file(filePath),
          );
        } catch {
          // Cursor 非公開 API — 失敗してもエクスポート自体は正常完了
        }

        vscode.window.showInformationMessage(
          `Exported ${result.turns.length} turns (${result.decoded} decoded, ${result.skipped} skipped) → ${fileName}`,
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
