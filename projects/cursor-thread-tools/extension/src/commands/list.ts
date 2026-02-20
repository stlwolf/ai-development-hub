import * as vscode from 'vscode';
import { openDatabase, getComposerDataEntries } from '../db/reader';

interface ComposerMeta {
  composerId: string;
  name?: string;
  createdAt?: number;
  isAgentic?: boolean;
  bubbleCount: number;
}

function parseComposerData(key: string, value: unknown): ComposerMeta | null {
  if (typeof value !== 'string') return null;
  try {
    const data = JSON.parse(value);
    const headers: unknown[] = data.fullConversationHeadersOnly ?? [];
    return {
      composerId: data.composerId ?? key.replace('composerData:', ''),
      name: data.name || undefined,
      createdAt: data.createdAt,
      isAgentic: data.isAgentic,
      bubbleCount: headers.length,
    };
  } catch {
    return null;
  }
}

function formatDate(ms: number | undefined): string {
  if (!ms) return 'unknown';
  return new Date(ms).toLocaleString();
}

export async function listThreads(): Promise<void> {
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
    }

    const items: ThreadQuickPickItem[] = threads.map(t => ({
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
