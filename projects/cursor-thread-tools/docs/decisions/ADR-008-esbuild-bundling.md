---
title: "ADR-008: esbuild バンドル設定"
date: 2026-02-21
type: decision
related:
  - type: implements
    ref: ../plans/2026-02-21-plan-phase4-packaging.md
    reason: "Phase 4 Step 1 の実装判断"
  - type: depends_on
    ref: ADR-001-sqlite-library.md
    reason: "better-sqlite3 がネイティブモジュールのため external 指定が必要"
tags: [esbuild, bundling, build, phase4]
---

# ADR-008: esbuild バンドル設定

## ステータス

Accepted

## コンテキスト

Phase 1-3 では `tsc` でトランスパイルのみ行い、`out/` に複数ファイルを出力していた。配布時のファイル数削減と将来のバンドルサイズ最適化のため、esbuild への移行を検討。

## 決定

- **esbuild** を採用し、拡張（`extension.ts`）と CLI（`cli.ts`）をそれぞれ単一ファイルにバンドルする
- `better-sqlite3` と `vscode` は `external` 指定で除外（ネイティブモジュールは esbuild でバンドル不可）
- 出力形式: `format: 'cjs'`、`platform: 'node'`、`sourcemap: true`
- CLI エントリには `banner: { js: '#!/usr/bin/env node' }` で shebang を付与（ソースファイル側の shebang は削除）
- `tsc` は `--noEmit` で型チェック専用に変更

## 根拠

- esbuild は VS Code 公式ドキュメントで推奨されるバンドラー（[Bundling Extensions](https://code.visualstudio.com/api/working-with-extensions/bundling-extension)）
- ネイティブモジュールは esbuild でバンドルすると `__dirname` 解決が壊れる（esbuild issue #2830, #4154）
- CJS 出力は VS Code Extension Host との互換性を維持
- shebang の重複問題: esbuild は TypeScript の hashbang comment を保持するため、banner と二重になる。ソース側を削除して banner のみで管理

## 結果

- `out/extension.js`: 22kb（6ファイル → 1ファイル）
- `out/cli.js`: 19kb（6ファイル → 1ファイル）
- 型チェック: `npm run compile`（`tsc -p ./ --noEmit`）
- ビルド: `npm run build`（`node esbuild.mjs`）
