import * as vscode from 'vscode';
import { listThreads } from './commands/list';
import { exportThread } from './commands/export';
import { openDatabase, cleanupTmpDb } from './db/reader';
import {
  listAllThreads,
  extractThreadContent,
  resolveFileName,
  DEFAULT_EXPORT_CONFIG,
} from './core/threads';
import { generateMarkdown } from './export/markdown';
import { join } from 'path';
import { mkdirSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';

let autoSaveHandle: ReturnType<typeof setInterval> | null = null;
let autoSaveRunning = false;

function setupAutoSave(context: vscode.ExtensionContext): void {
  if (autoSaveHandle) {
    clearInterval(autoSaveHandle);
    autoSaveHandle = null;
  }

  const config = vscode.workspace.getConfiguration('cursorThreadTools');
  const interval = config.get<number>('autoSave.intervalMinutes', 0);
  if (interval <= 0) return;

  console.log(`[cursor-thread-tools] auto-save enabled: every ${interval} minutes`);

  autoSaveHandle = setInterval(async () => {
    if (autoSaveRunning) return;
    autoSaveRunning = true;
    try {
      await autoSaveNewThreads(context);
    } catch (err) {
      console.error('[cursor-thread-tools] auto-save error:', err);
    } finally {
      autoSaveRunning = false;
    }
  }, interval * 60 * 1000);
}

async function autoSaveNewThreads(context: vscode.ExtensionContext): Promise<void> {
  const prevCounts = context.globalState.get<Record<string, number>>('autoSaveBubbleCounts', {});
  const cfg = vscode.workspace.getConfiguration('cursorThreadTools');
  const includeThinking = cfg.get<boolean>('export.includeThinking', DEFAULT_EXPORT_CONFIG.includeThinking);
  const outputDirSetting = cfg.get<string>('export.outputDir', DEFAULT_EXPORT_CONFIG.outputDir);
  const fileNameFormat = cfg.get<string>('export.fileNameFormat', DEFAULT_EXPORT_CONFIG.fileNameFormat);

  let db;
  try {
    db = openDatabase();
    const threads = listAllThreads(db);

    const updated = threads.filter(t => (prevCounts[t.composerId] ?? 0) < t.bubbleCount);
    if (updated.length === 0) return;

    const workspaceFolders = vscode.workspace.workspaceFolders;
    let outputDir: string;
    if (workspaceFolders && workspaceFolders.length > 0) {
      outputDir = join(workspaceFolders[0].uri.fsPath, outputDirSetting);
    } else {
      outputDir = join(tmpdir(), 'thread-exports');
    }
    mkdirSync(outputDir, { recursive: true });

    const newCounts: Record<string, number> = {};
    for (const t of threads) {
      newCounts[t.composerId] = prevCounts[t.composerId] ?? 0;
    }

    let saved = 0;
    for (const meta of updated) {
      const result = extractThreadContent(db!, meta);
      if (!result || result.turns.length === 0) continue;

      const threadName = meta.name || meta.composerId.slice(0, 12) + '...';
      const markdown = generateMarkdown(threadName, result.turns, { includeThinking });

      const fileName = resolveFileName(fileNameFormat, meta);
      const filePath = join(outputDir, fileName);
      writeFileSync(filePath, markdown, 'utf8');

      newCounts[meta.composerId] = meta.bubbleCount;
      saved++;
    }

    if (saved > 0) {
      await context.globalState.update('autoSaveBubbleCounts', newCounts);
      console.log(`[cursor-thread-tools] auto-saved ${saved} threads`);
    }
  } finally {
    db?.close();
  }
}

export function activate(context: vscode.ExtensionContext): void {
  console.log('[cursor-thread-tools] activate', process.versions);

  context.subscriptions.push(
    vscode.commands.registerCommand('threadTools.list', () => listThreads()),
    vscode.commands.registerCommand('threadTools.export', () => exportThread()),
  );

  context.subscriptions.push({
    dispose: () => {
      if (autoSaveHandle) {
        clearInterval(autoSaveHandle);
        autoSaveHandle = null;
      }
    },
  });

  setupAutoSave(context);

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration(e => {
      if (e.affectsConfiguration('cursorThreadTools.autoSave')) {
        setupAutoSave(context);
      }
    }),
  );
}

export function deactivate(): void {
  cleanupTmpDb();
}
