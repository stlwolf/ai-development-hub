import Database from 'better-sqlite3';
import { existsSync, copyFileSync, unlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { homedir } from 'os';

const tmpDbPaths: string[] = [];

export interface DbPathOptions {
  appName?: string;
}

export function getStateDbPath(options?: DbPathOptions): string {
  const appName = options?.appName ?? 'Cursor';
  return join(homedir(), 'Library', 'Application Support', appName, 'User', 'globalStorage', 'state.vscdb');
}

function isBusyOrLocked(err: unknown): boolean {
  if (err instanceof Error) {
    return err.message.includes('SQLITE_BUSY') || err.message.includes('SQLITE_LOCKED');
  }
  return false;
}

function openWithCopyFallback(dbPath: string): Database.Database {
  const uniqueId = Date.now().toString(36);
  const tmpPath = join(tmpdir(), `cursor-thread-tools-${uniqueId}.vscdb`);
  tmpDbPaths.push(tmpPath);
  copyFileSync(dbPath, tmpPath);

  const walPath = dbPath + '-wal';
  const shmPath = dbPath + '-shm';
  if (existsSync(walPath)) copyFileSync(walPath, tmpPath + '-wal');
  if (existsSync(shmPath)) copyFileSync(shmPath, tmpPath + '-shm');

  return new Database(tmpPath, { readonly: true, fileMustExist: true });
}

export function openDatabase(options?: DbPathOptions): Database.Database {
  const dbPath = getStateDbPath(options);

  if (!existsSync(dbPath)) {
    throw new Error(`state.vscdb not found at ${dbPath}`);
  }

  try {
    const db = new Database(dbPath, { readonly: true, fileMustExist: true });
    db.pragma('busy_timeout = 3000');
    const journalMode = db.pragma('journal_mode', { simple: true });
    console.error(`[cursor-thread-tools] journal_mode: ${journalMode}`);
    db.prepare('SELECT 1 FROM cursorDiskKV LIMIT 1').get();
    return db;
  } catch (err: unknown) {
    if (!isBusyOrLocked(err)) {
      throw err;
    }
    console.warn('[cursor-thread-tools] DB busy/locked, falling back to copy');
    return openWithCopyFallback(dbPath);
  }
}

export function cleanupTmpDb(): void {
  for (const base of tmpDbPaths) {
    for (const suffix of ['', '-wal', '-shm']) {
      const p = base + suffix;
      if (existsSync(p)) {
        try { unlinkSync(p); } catch { /* best effort */ }
      }
    }
  }
  tmpDbPaths.length = 0;
}

export interface ComposerDataRow {
  key: string;
  value: string;
}

export function getComposerDataEntries(db: Database.Database): ComposerDataRow[] {
  const stmt = db.prepare(
    "SELECT key, value FROM cursorDiskKV WHERE key LIKE 'composerData:%'"
  );
  return stmt.all() as ComposerDataRow[];
}

export function getBlobByHex(db: Database.Database, hexId: string): Buffer | null {
  const key = `agentKv:blob:${hexId}`;
  const row = db.prepare(
    'SELECT value FROM cursorDiskKV WHERE key = ?'
  ).get(key) as { value: Buffer } | undefined;
  return row ? Buffer.from(row.value) : null;
}

export function getBlobByBytes(db: Database.Database, blobId: Buffer): Buffer | null {
  return getBlobByHex(db, blobId.toString('hex'));
}

export interface BubbleIdRow {
  key: string;
  value: string;
}

export function getBubbleIdEntry(
  db: Database.Database,
  composerId: string,
  bubbleId: string,
): BubbleIdRow | null {
  const key = `bubbleId:${composerId}:${bubbleId}`;
  const row = db.prepare(
    'SELECT key, value FROM cursorDiskKV WHERE key = ?'
  ).get(key) as BubbleIdRow | undefined;
  return row ?? null;
}

function extractCsString(raw: unknown): string | null {
  if (!raw) return null;

  // Some older threads store as object { "0": "a", "1": "b", ... }
  if (typeof raw === 'object' && !Array.isArray(raw)) {
    const obj = raw as Record<string, string>;
    const keys = Object.keys(obj);
    if (keys.length < 10) return null;
    const joined = keys
      .sort((a, b) => Number(a) - Number(b))
      .map((k: string) => obj[k])
      .join('');
    return joined.length > 10 ? joined : null;
  }

  if (typeof raw === 'string' && raw.length > 10) {
    return raw;
  }

  return null;
}

/**
 * Find the most recent conversationState string for a thread.
 * Checks composerData first (most complete), then falls back to
 * walking bubbleId entries from newest to oldest.
 */
export function findConversationState(
  db: Database.Database,
  composerId: string,
  headers: Array<{ bubbleId: string; type: number }>,
  composerDataJson?: string,
): string | null {
  // 1. Try composerData-level conversationState (most up-to-date)
  if (composerDataJson) {
    try {
      const cd = JSON.parse(composerDataJson);
      const cs = extractCsString(cd.conversationState);
      if (cs) return cs;
    } catch { /* fall through */ }
  }

  // 2. Walk bubbleId entries from newest to oldest
  for (let i = headers.length - 1; i >= 0; i--) {
    const row = getBubbleIdEntry(db, composerId, headers[i].bubbleId);
    if (!row) continue;
    try {
      const parsed = JSON.parse(row.value);
      const cs = extractCsString(parsed.conversationState);
      if (cs) return cs;
    } catch {
      continue;
    }
  }
  return null;
}
