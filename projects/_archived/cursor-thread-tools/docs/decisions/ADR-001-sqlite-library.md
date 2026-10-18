---
title: "ADR-001: SQLiteライブラリ選定"
date: 2026-02-20
type: decision
status: accepted
related:
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-1-1 の検証結果"
  - type: derived_from
    ref: ../plans/2026-02-20-kickoff-phase1-db-foundation.md
    reason: "Phase 1 Step 3 の検証結果"
tags: [sqlite, better-sqlite3, vscode-extension, native-module]
---

# ADR-001: SQLiteライブラリ選定

## 状態

Accepted

## コンテキスト

Cursor の `state.vscdb`（SQLite）を VS Code 拡張から read-only で読み取る必要がある。候補は以下の3つ:

1. `better-sqlite3` — ネイティブ N-API、同期API、高速
2. `vscode-node-sqlite3` — Microsoft fork、Node-API prebuilt
3. `sql.js` — WASM、メモリ全量ロード

## 決定

**`better-sqlite3` を採用する。**

## 根拠

### 検証結果

- `npm install better-sqlite3` で `node-gyp` ビルドが成功（macOS arm64）
- Cursor 起動中に `state.vscdb` を `readonly: true` + `busy_timeout = 3000` で開き、206 スレッドのメタデータ読み取りに成功
- N-API（Node-API）により ABI 安定。Cursor の Electron バージョンに依存しない
- 同期 API のため、VS Code 拡張のコマンドハンドラ内で自然に使える

### peer-ai-review 3者合意

- `sql.js` は本番経路に置かない（全量メモリロードで大規模 DB がクラッシュするリスク — SQLite Forum + Codex/Claude 指摘）
- `vscode-node-sqlite3` はフォールバック候補として残す（`better-sqlite3` の N-API prebuild が Cursor Electron で動かない場合のみ使用）

### パッケージング

- `better-sqlite3` は `dependencies`（`devDependencies` ではない）に配置
- `vsce package` は `dependencies` のみを VSIX に含める（VS Code 公式ドキュメントで確認済み）
- Phase 1 は `tsc` のみ（バンドリングなし）。Phase 4 で esbuild 導入時に `external` 指定

## 代替案

| 候補 | 棄却理由 |
|------|---------|
| `sql.js` (WASM) | DB 全体を ArrayBuffer にロード → 大規模 DB でクラッシュリスク |
| `vscode-node-sqlite3` | フォールバックとして保留。`better-sqlite3` が動作したため不要 |
| SQLite CLI subprocess | パース・エラーハンドリングが複雑。ネイティブモジュールの方が堅牢 |

## 影響

- `extension/package.json` の `dependencies` に `better-sqlite3: ^11.0.0` を追加
- ネイティブモジュールのため、クロスプラットフォーム配布時は各 OS 向けの prebuild が必要（Phase 4 課題）
- macOS 以外の環境では動作未検証（Phase 1 スコープ外）
