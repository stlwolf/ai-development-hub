import * as vscode from 'vscode';
import { openDatabase } from '../db/reader';
import { listAllThreads, formatDate, type ComposerMeta } from '../core/threads';

export async function listThreads(): Promise<void> {
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
    }

    const items: ThreadQuickPickItem[] = threads.map((t: ComposerMeta) => ({
      label: t.name || t.composerId.slice(0, 12) + '...',
      description: t.isAgentic ? 'Agent' : 'Chat',
      detail: `${t.bubbleCount} messages | ${formatDate(t.createdAt)}`,
      composerId: t.composerId,
    }));

    const selected = await vscode.window.showQuickPick(items, {
      placeHolder: `${threads.length} threads found`,
      matchOnDetail: true,
    });

    if (selected) {
      vscode.window.showInformationMessage(`Selected: ${selected.label} (${selected.composerId})`);
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    vscode.window.showErrorMessage(`Thread Tools: ${msg}`);
  } finally {
    db?.close();
  }
}
