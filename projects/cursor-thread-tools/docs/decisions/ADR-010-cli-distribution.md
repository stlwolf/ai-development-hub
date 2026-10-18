---
title: "ADR-010: CLI 配布方式"
date: 2026-02-21
type: decision
related:
  - type: implements
    ref: ../plans/2026-02-21-plan-phase4-packaging.md
    reason: "Phase 4 Step 3b の実装判断"
  - type: depends_on
    ref: ADR-005-cli-packaging.md
    reason: "CLI エントリポイントの前提"
  - type: depends_on
    ref: ADR-009-native-module-distribution.md
    reason: "ネイティブモジュールのビルドターゲット問題"
tags: [cli, npm-link, bin, distribution, phase4]
---

# ADR-010: CLI 配布方式

## ステータス

Accepted

## コンテキスト

CLI (`cursor-thread-tools list` / `export`) を利用者が手軽に実行できる方法を選定する必要がある。候補: npm link + bin フィールド、npx、standalone binary（pkg 等）。

## 決定

- `package.json` の `bin` フィールドで `cursor-thread-tools` コマンドを登録
- `npm link` でグローバルにシンボリックリンクを作成して利用
- npx や standalone binary は採用しない

## 根拠

- npm link + bin は Node.js エコシステムの標準的な開発者向け配布方法
- npx はネイティブモジュールとの相性が悪い（毎回 install が走る可能性）
- standalone binary（pkg, nexe 等）はネイティブアドオンのバンドルに非対応
- 現在のスコープ（開発者向け、ソース同梱前提）では npm link で十分

## CLI/Extension リビルドターゲット衝突

| 用途 | 必要なビルド | コマンド |
|------|-------------|---------|
| Extension（Cursor） | Electron 向け | `npx @electron/rebuild -v 39.4.0` |
| CLI（ターミナル） | Node.js 向け | `npm rebuild better-sqlite3` |

同一ディレクトリで Extension と CLI の両方を使う場合、ビルドターゲットの切り替えが必要。INSTALL.md に手順を明記。
