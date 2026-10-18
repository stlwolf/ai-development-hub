---
title: "ADR-005: CLI パッケージング方法 — Node.js スクリプト + util.parseArgs()"
date: 2026-02-21
type: decision
status: accepted
related:
  - type: derived_from
    ref: ../plans/2026-02-21-plan-phase3-auto-save-cli.md
    reason: "Phase 3 Step 0-b の決定事項"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-3-2 CLI 検証の基盤"
tags: [cli, packaging, util-parseArgs, node-script]
---

# ADR-005: CLI パッケージング方法 — Node.js スクリプト + util.parseArgs()

## 状態

Accepted

## コンテキスト

Phase 3 で CLI エントリポイントを追加するにあたり、配布形式と引数パース方法を選定する必要があった。

## 決定

**Node.js スクリプト（`node out/cli.js`）として配布し、引数パースは Node.js ビルトインの `util.parseArgs()` を使用する。**

## 根拠

| 候補 | 棄却理由 |
|------|---------|
| `process.argv` 手動パース | 当初プラン案。peer-ai-review で Claude が `util.parseArgs()` を推奨。`--no-thinking` の negation 処理、`--output-dir=./foo` と `--output-dir ./foo` の両形式対応など、エッジケースが多く保守困難 |
| 外部ライブラリ（commander, yargs） | ゼロ外部依存方針に反する。引数の規模に対して過剰 |
| standalone バイナリ（pkg, nexe） | better-sqlite3 がネイティブモジュールのため pkg 化が複雑。Phase 4 のパッケージング・配布で検討 |

`util.parseArgs()` の利点:
- Node.js 18.3+ で stable（Cursor 内蔵 Node.js v25.6.1 で問題なし）
- 外部依存ゼロ（Node.js 標準ライブラリ）
- `--no-*` negation を自動処理
- `allowPositionals` でサブコマンドパターンに対応

## 影響

- `extension/src/cli.ts` に `import { parseArgs } from 'node:util'` を使用
- `package.json` への依存追加なし
- CLI 使用時は `npm rebuild better-sqlite3` でシステム Node.js 向けリビルドが必要（Electron 向けビルドとは互換性なし）
