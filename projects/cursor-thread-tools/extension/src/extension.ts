import * as vscode from 'vscode';
import { listThreads } from './commands/list';
import { exportThread } from './commands/export';
import { cleanupTmpDb } from './db/reader';

export function activate(context: vscode.ExtensionContext): void {
  console.log('[cursor-thread-tools] activate', process.versions);

  context.subscriptions.push(
    vscode.commands.registerCommand('threadTools.list', () => listThreads()),
    vscode.commands.registerCommand('threadTools.export', () => exportThread()),
  );
}

export function deactivate(): void {
  cleanupTmpDb();
}
