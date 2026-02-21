import * as esbuild from 'esbuild';

const isWatch = process.argv.includes('--watch');

/** @type {import('esbuild').BuildOptions} */
const sharedOptions = {
  bundle: true,
  platform: 'node',
  format: 'cjs',
  sourcemap: true,
  minify: false,
  target: 'node20',
};

const extensionConfig = {
  ...sharedOptions,
  entryPoints: ['src/extension.ts'],
  outfile: 'out/extension.js',
  external: ['vscode', 'better-sqlite3'],
};

const cliConfig = {
  ...sharedOptions,
  entryPoints: ['src/cli.ts'],
  outfile: 'out/cli.js',
  external: ['better-sqlite3'],
  banner: { js: '#!/usr/bin/env node' },
};

if (isWatch) {
  const extCtx = await esbuild.context(extensionConfig);
  const cliCtx = await esbuild.context(cliConfig);
  await Promise.all([extCtx.watch(), cliCtx.watch()]);
  console.log('[esbuild] watching...');
} else {
  await esbuild.build(extensionConfig);
  await esbuild.build(cliConfig);
  console.log('[esbuild] build complete');
}
