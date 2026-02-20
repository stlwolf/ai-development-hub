import * as vscode from 'vscode';
import { listThreads } from './commands/list';
import { cleanupTmpDb } from './db/reader';

export function activate(context: vscode.ExtensionContext): void {
  console.log('[cursor-thread-tools] activate', process.versions);

  const listCmd = vscode.commands.registerCommand('threadTools.list', () =>
    listThreads()
  );
  context.subscriptions.push(listCmd);
}

export function deactivate(): void {
  cleanupTmpDb();
}
