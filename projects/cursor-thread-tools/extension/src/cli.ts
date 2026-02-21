#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { platform } from 'os';
import { join, resolve } from 'path';
import { mkdirSync, writeFileSync } from 'fs';
import { openDatabase, cleanupTmpDb } from './db/reader';
import {
  listAllThreads,
  extractThreadContent,
  resolveFileName,
  formatDate,
  DEFAULT_EXPORT_CONFIG,
  type ComposerMeta,
  type ExportConfig,
} from './core/threads';
import { generateMarkdown } from './export/markdown';

process.on('exit', cleanupTmpDb);
process.on('SIGINT', () => { cleanupTmpDb(); process.exit(130); });
process.on('SIGTERM', () => { cleanupTmpDb(); process.exit(143); });

function usage(exitCode = 1): never {
  const out = exitCode === 0 ? console.log : console.error;
  out(`Usage:
  node cli.js list [--json] [--app-name <name>]
  node cli.js export <composerId> [options]
  node cli.js export --all [options]

Options:
  --app-name <name>    App name: 'Cursor' | 'Code' (default: 'Cursor')
  --no-thinking        Exclude thinking blocks
  --output-dir <path>  Output directory (default: '.thread-exports')
  --format <pattern>   File name format (default: '{name}_{date}')
  --json               Output list as JSON
  --all                Export all threads
  --since <duration>   Only threads created within duration (e.g. '24h', '7d')
`);
  process.exit(exitCode);
}

function parseSinceDuration(since: string): number {
  const match = since.match(/^(\d+)(h|d|m)$/);
  if (!match) {
    console.error(`Invalid --since format: ${since}. Use e.g. '24h', '7d', '30m'`);
    process.exit(1);
  }
  const value = parseInt(match[1], 10);
  const unit = match[2];
  const ms = unit === 'h' ? value * 3600000
           : unit === 'd' ? value * 86400000
           : value * 60000;
  return Date.now() - ms;
}

function main(): void {
  if (platform() !== 'darwin') {
    console.error('Error: cursor-thread-tools CLI currently supports macOS only.');
    process.exit(1);
  }

  const { values, positionals } = parseArgs({
    args: process.argv.slice(2),
    options: {
      all:            { type: 'boolean', default: false },
      'no-thinking':  { type: 'boolean', default: false },
      'output-dir':   { type: 'string' },
      format:         { type: 'string' },
      'app-name':     { type: 'string' },
      json:           { type: 'boolean', default: false },
      since:          { type: 'string' },
      help:           { type: 'boolean', default: false },
    },
    allowPositionals: true,
  });

  if (values.help) {
    usage(0);
  }
  if (positionals.length === 0) {
    usage(1);
  }

  const [subcommand, ...rest] = positionals;
  const appName = values['app-name'] as string | undefined;

  if (subcommand === 'list') {
    runList({ appName, json: !!values.json });
  } else if (subcommand === 'export') {
    const config: ExportConfig = {
      includeThinking: !values['no-thinking'],
      outputDir: (values['output-dir'] as string) ?? DEFAULT_EXPORT_CONFIG.outputDir,
      fileNameFormat: (values.format as string) ?? DEFAULT_EXPORT_CONFIG.fileNameFormat,
    };
    const sinceMs = values.since ? parseSinceDuration(values.since as string) : undefined;

    if (sinceMs && !values.all) {
      console.error('Warning: --since is only effective with --all. Ignoring.');
    }

    if (values.all) {
      runExportAll({ appName, config, sinceMs });
    } else if (rest.length > 0) {
      runExportSingle(rest[0], { appName, config });
    } else {
      console.error('Error: provide a composerId or use --all');
      process.exit(1);
    }
  } else {
    console.error(`Unknown command: ${subcommand}`);
    usage();
  }
}

function runList(opts: { appName?: string; json: boolean }): void {
  const db = openDatabase({ appName: opts.appName });
  try {
    const threads = listAllThreads(db);
    if (opts.json) {
      const output = threads.map(t => ({
        composerId: t.composerId,
        name: t.name ?? null,
        createdAt: t.createdAt ?? null,
        isAgentic: t.isAgentic ?? false,
        bubbleCount: t.bubbleCount,
      }));
      console.log(JSON.stringify(output, null, 2));
    } else {
      if (threads.length === 0) {
        console.log('No threads found.');
        return;
      }
      for (const t of threads) {
        const label = t.name || t.composerId.slice(0, 12) + '...';
        const mode = t.isAgentic ? 'Agent' : 'Chat';
        console.log(`${label}  [${mode}]  ${t.bubbleCount} msgs  ${formatDate(t.createdAt)}  ${t.composerId}`);
      }
      console.error(`\n${threads.length} threads total`);
    }
  } finally {
    db.close();
  }
}

function runExportSingle(
  composerId: string,
  opts: { appName?: string; config: ExportConfig },
): void {
  const db = openDatabase({ appName: opts.appName });
  try {
    const threads = listAllThreads(db);
    const meta = threads.find(t => t.composerId === composerId);
    if (!meta) {
      console.error(`Thread not found: ${composerId}`);
      process.exit(1);
    }
    const exported = exportOne(db, meta, opts.config);
    if (exported) {
      console.log(exported);
    }
  } finally {
    db.close();
  }
}

function runExportAll(
  opts: { appName?: string; config: ExportConfig; sinceMs?: number },
): void {
  const db = openDatabase({ appName: opts.appName });
  try {
    let threads = listAllThreads(db);
    if (opts.sinceMs) {
      threads = threads.filter(t => (t.createdAt ?? 0) >= opts.sinceMs!);
    }

    let success = 0;
    let failed = 0;
    for (const meta of threads) {
      try {
        const result = exportOne(db, meta, opts.config);
        if (result) {
          success++;
        } else {
          failed++;
        }
      } catch (err) {
        console.error(`Failed: ${meta.name || meta.composerId}`, err instanceof Error ? err.message : err);
        failed++;
      }
    }
    console.error(`Exported ${success} threads (${failed} failed, ${threads.length} total)`);
  } finally {
    db.close();
  }
}

function exportOne(
  db: ReturnType<typeof openDatabase>,
  meta: ComposerMeta,
  config: ExportConfig,
): string | null {
  const result = extractThreadContent(db, meta);
  if (!result || result.turns.length === 0) {
    console.error(`Skipped: ${meta.name || meta.composerId} (no content)`);
    return null;
  }

  const threadName = meta.name || meta.composerId.slice(0, 12) + '...';
  const markdown = generateMarkdown(threadName, result.turns, {
    includeThinking: config.includeThinking,
  });

  const outputDir = resolve(config.outputDir);
  mkdirSync(outputDir, { recursive: true });

  const fileName = resolveFileName(config.fileNameFormat, meta);
  const filePath = join(outputDir, fileName);
  writeFileSync(filePath, markdown, 'utf8');

  console.error(`Exported: ${threadName} → ${filePath}`);
  return filePath;
}

try {
  main();
} catch (err) {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
}
