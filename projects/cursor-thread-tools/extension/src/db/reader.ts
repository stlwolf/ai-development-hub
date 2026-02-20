import Database from 'better-sqlite3';
import { existsSync, copyFileSync, unlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { homedir } from 'os';
import * as vscode from 'vscode';

const tmpDbPaths: string[] = [];

function getStateDbPath(): string {
  const home = homedir();
  const appName = vscode.env.appName?.includes('Cursor') ? 'Cursor' : 'Code';
  return join(home, 'Library', 'Application Support', appName, 'User', 'globalStorage', 'state.vscdb');
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

export function openDatabase(): Database.Database {
  const dbPath = getStateDbPath();

  if (!existsSync(dbPath)) {
    throw new Error(`state.vscdb not found at ${dbPath}`);
  }

  try {
    const db = new Database(dbPath, { readonly: true, fileMustExist: true });
    db.pragma('busy_timeout = 3000');
    const journalMode = db.pragma('journal_mode', { simple: true });
    console.log(`[cursor-thread-tools] journal_mode: ${journalMode}`);
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
