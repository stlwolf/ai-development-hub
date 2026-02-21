---
title: "ADR-003: better-sqlite3 v11 → v12.6.2 アップグレード"
date: 2026-02-21
type: decision
status: accepted
related:
  - type: supersedes
    ref: ADR-001-sqlite-library.md
    reason: "ADR-001 で採用した better-sqlite3 のバージョンを更新"
  - type: derived_from
    ref: ../episodes/2026-02-21-phase2-markdown-export.md
    reason: "Phase 2 Extension Development Host テストで発見"
tags: [better-sqlite3, electron, native-module, v8-api]
---

# ADR-003: better-sqlite3 v11 → v12.6.2 アップグレード

## 状態

Accepted（ADR-001 のバージョン部分を更新）

## コンテキスト

Phase 2 の Extension Development Host テスト（F5 実機テスト）で、`better-sqlite3@11` が Cursor の Electron 39 環境でロード失敗した。

## 決定

**`better-sqlite3` を `^12.6.2` にアップグレードし、`@electron/rebuild --version 39.4.0` でリビルドする。**

## 根拠

- Electron 39 の V8 API 変更で `GetIsolate()` が削除された
- `better-sqlite3@11` はこの API に依存しており、Electron 39 で `Symbol not found` エラー
- `better-sqlite3@12.6.2` は V8 API 変更に対応済み
- `@electron/rebuild` で Cursor の Electron バージョン向けにリビルドが必要

## 影響

- `extension/package.json`: `"better-sqlite3": "^12.6.2"`
- ビルド手順: `npm install` 後に `npx @electron/rebuild --version 39.4.0` が必要
- `postinstall` スクリプトへの組み込みは将来検討（Electron バージョン自動取得の仕組みが必要）
