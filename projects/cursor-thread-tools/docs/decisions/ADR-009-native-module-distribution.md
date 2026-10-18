---
title: "ADR-009: ネイティブモジュール（better-sqlite3）の配布方式"
date: 2026-02-21
type: decision
related:
  - type: implements
    ref: ../plans/2026-02-21-plan-phase4-packaging.md
    reason: "Phase 4 Step 3a の実装判断"
  - type: depends_on
    ref: ADR-001-sqlite-library.md
    reason: "better-sqlite3 採用の前提"
  - type: depends_on
    ref: ADR-003-better-sqlite3-v12-upgrade.md
    reason: "Electron 39 向けリビルドの前提"
tags: [native-module, better-sqlite3, electron-rebuild, distribution, phase4]
---

# ADR-009: ネイティブモジュール（better-sqlite3）の配布方式

## ステータス

Accepted

## コンテキスト

better-sqlite3 はネイティブアドオン（`.node` バイナリ）を含む。Extension（Cursor/Electron）と CLI（Node.js）で異なる ABI ターゲットが必要。利用者が簡単にセットアップできる方法が求められる。

## 決定

- `scripts/install.sh` で `npm install` + `@electron/rebuild` を一括実行
- Electron バージョンは `ELECTRON_VERSION` 環境変数 > スクリプト引数 > デフォルト値（`39.4.0`）の優先順で検出
- Cursor の `package.json` には `electronVersion` フィールドがないため、自動検出は断念（事実検証済み）
- `.vsix` には macOS ビルドの `.node` バイナリを含める（プラットフォーム固有）
- 他プラットフォームの利用者はソースからビルドが必要

## 根拠

- Cursor の Electron バージョンを外部から自動検出する信頼できる方法がない
- `postinstall` スクリプトで自動リビルドは、`npm install` のたびに実行されるため重すぎる
- 明示的な `install.sh` の方がトラブルシューティングが容易

## 制約

- Extension と CLI で同一の `node_modules/better-sqlite3/` を共有できない（Electron ABI vs Node.js ABI）
- Extension 用にリビルド後、CLI を使うには `npm rebuild better-sqlite3` が必要
