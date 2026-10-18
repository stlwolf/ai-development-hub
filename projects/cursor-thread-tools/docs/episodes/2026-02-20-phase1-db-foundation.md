---
title: "Phase 1 DB読み取り基盤: agentKv:blob マッピング解明と拡張スキャフォールド"
date: 2026-02-20
type: episode
related:
  - type: implements
    ref: ../plans/2026-02-20-kickoff-phase1-db-foundation.md
    reason: "Phase 1 キックオフの実装"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-1-1〜A-1-5 の検証結果"
  - type: evidence_for
    ref: ../decisions/ADR-001-sqlite-library.md
    reason: "SQLiteライブラリ選定の実証"
tags: [phase1, sqlite, state-vscdb, agentKv, better-sqlite3, vscode-extension]
---

# Phase 1 DB読み取り基盤: 作業記録

## 概要

`state.vscdb` からスレッド会話データを読み取る VS Code 拡張の基盤を構築した。`threadTools.list` コマンドが Node.js レベルで動作確認済み。

## Step 0: rg 局所抽出によるマッピング解明

`workbench.desktop.main.js`（51MB）から rg でキーワードを局所抽出し、以下のデータモデルを解明した:

### agentKv:blob のキー生成パターン

```
agentKv:blob:${hex(SHA-256(content))}
```

- `ComposerBlobStore.keyFor(n)` → `"agentKv:blob:" + YY(n)`
- `YY(n)` = `Buffer.from(n).toString("hex")` — Uint8Array の hex エンコード
- `zAe(n)` = `crypto.subtle.digest("SHA-256", n)` — SHA-256 ハッシュ
- `ohe(n)` = hex → Uint8Array のデコード（逆関数）

### データ格納方式

- **格納**: `cursorDiskKVSetBinary(key, value)` — BLOB 型
- **取得**: `cursorDiskKVGetBinary(key)` — Uint8Array
- **フォーマット**: JSON と protobuf が混在
  - 先頭バイト `7B` (`{`) → JSON（`{"role":"system"...}` 形式）
  - 先頭バイト `0A` → protobuf（`SJm.fromBinary()` でデシリアライズ）
- **暗号化**: `EncryptedBlobStore` (AES-GCM, IV 12byte) レイヤーが存在。有効な場合は復号が必要

### 会話 turns の構造

```
composerData → fullConversationHeadersOnly → [{bubbleId, type}]
  ↓
各 turn は blob ID (SHA-256 hash) として保持
  ↓
agentKv:blob:<hex> → protobuf binary → SJm.fromBinary() でデシリアライズ
  ↓
turn.case === "agentConversationTurn" → userMessage, steps
```

### composer.content.* の役割

- ファイルコンテンツの content-addressed storage
- キー = `composer.content.${hex(SHA-256(serialize(content)))}`
- 会話テキストのマッピングとは無関係（ファイル差分用）

## Step 1: DB構造の実データ確認

### テーブル構造

| テーブル | 用途 |
|---------|------|
| `cursorDiskKV` | メインKVストア。`key` (TEXT), `value` (TEXT or BLOB) |
| `ItemTable` | VS Code レガシーKV |

### キープレフィックス分布

| プレフィックス | 件数 | 型 | 内容 |
|--------------|------|-----|------|
| `agentKv:` | 29,096 | blob | blob/checkpoint/bubbleCheckpoint |
| `bubbleId:` | 15,531 | text | メッセージメタデータ JSON |
| `checkpointId:` | 1,121 | - | チェックポイント |
| `composerData:` | 206 | text | スレッドメタデータ JSON |
| `composer.content.*` | - | text | ファイルコンテンツ |

### composerData の構造

```json
{
  "_v": 13,
  "composerId": "uuid",
  "name": "Thread name (optional)",
  "createdAt": 1771589637472,
  "isAgentic": true,
  "fullConversationHeadersOnly": [
    {"bubbleId": "uuid", "type": 2, "serverBubbleId": "uuid"}
  ]
}
```

- `createdAt`: Unix timestamp (ms)
- `name`: 自動生成名（一部のスレッドは空）
- `type`: 1=HUMAN, 2=ASSISTANT

### journal_mode

WAL モード確認済み。read-only 同時アクセスが可能。

### globalStorage vs workspaceStorage

- globalStorage: 1つ（メインの `state.vscdb`、全スレッドデータ）
- workspaceStorage: ワークスペースごとに存在（32個確認）

## Step 2-4: 拡張実装

### ファイル構成

```
extension/
├── package.json       # better-sqlite3 in dependencies
├── tsconfig.json      # strict, ES2020, tsc only
├── .vscodeignore
├── .gitignore
├── .vscode/launch.json
└── src/
    ├── extension.ts   # activate/deactivate
    ├── db/reader.ts   # openDatabase, cleanupTmpDb
    └── commands/list.ts # threadTools.list (QuickPick)
```

### DB同時アクセス戦略

1. `readonly: true, fileMustExist: true` でオープン
2. `busy_timeout = 3000` 設定
3. `SQLITE_BUSY`/`SQLITE_LOCKED` のみ catch → WAL 3ファイルコピーフォールバック
4. ユニークファイル名で衝突回避
5. `deactivate()` で一時ファイルクリーンアップ

### 動作確認

Node.js テストで `state.vscdb` の read-only 読み取りに成功:

```
composerData count: 206
Latest threads:
  Gemini CLI feasibility and validation | 48 msgs | 2026/2/20 21:13:57
  Phase 1 planning and documentation | 122 msgs | 2026/2/20 21:03:08
  ...
```

## 事後 peer-ai-review（Step 0/3/5 完了時点）

プラン記載の3つの peer-ai-review 実施ポイントを事後に一括レビュー。
レビューログ: `tmp/peer-review-20260220-214639/review-log.md`
SO 出力: `tmp/so-phase1-post-review/`

### 3者合意で即修正した4点

1. `list.ts` の未使用 import `cleanupTmpDb` を削除
2. `tmpDbPath` 単一変数を配列化（複数フォールバック時のリーク防止）
3. QuickPickItem に `composerId` を保持（Phase 2 で選択スレッド特定用）
4. `parseComposerData` に型ガード追加（value が string でない場合を防御）

### SOが発見し自分が見落としていたこと

- `tmpDbPath` 単一変数リーク — Codex/Claude 共に指摘
- 未使用 import — Codex
- QuickPickItem に composerId 欠落 — Claude
- `parseComposerData` の文字列前提 — Codex
- `YY(n)` は digest bytes を取る点の明示（Phase 2 で double-hex 回避に重要）— Codex

## Phase 2 への引き継ぎ

### 解決済み

- [x] SQLiteライブラリ: `better-sqlite3` で動作確認
- [x] DB同時アクセス: readonly + busy_timeout + コピーフォールバック
- [x] composerData メタデータ取得
- [x] agentKv:blob マッピング解明
- [x] peer-ai-review 事後レビューで4点修正済み

### Phase 2 で対応が必要

- [ ] `agentKv:blob` からのテキスト抽出（protobuf デシリアライズ + 暗号化復号）
- [ ] Markdown エクスポート（ユーザー発言 + アシスタント応答の結合）
- [ ] Extension Development Host での実機テスト（N-API ABI ではなくロードパス確認が目的）
- [ ] 大規模スレッド（400+ bubbles）での性能確認
- [ ] EncryptedBlobStore 鍵管理の調査（暗号化有効時の復号方法）
- [ ] クロスプラットフォームパス解決（macOS 以外）
- [ ] WAL コピーの一貫性強化（非アトミックコピーの改善）

---

## スレッド作業フィードバック

### 経過および結果

- プラン作成 → peer-ai-review（プラン版）→ プラン確定 → 実装（Step 0〜5）→ 成果物記録 → peer-ai-review（事後3ポイント）→ 修正4件 → ユーザールール追加
- **成果物**: VS Code 拡張スキャフォールド（`extension/` 以下7ファイル）、ADR-001、エピソード、検証マトリクス更新、実装プランログ
- **技術的成果**: `agentKv:blob` のキー生成パターンを完全解明（SHA-256 content-addressed, protobuf/JSON 混在, AES-GCM 暗号化レイヤー）。`better-sqlite3` で Cursor 起動中の `state.vscdb` read-only アクセスに成功（206 スレッド確認）
- **Node.js テスト成功**。Extension Development Host での実機テストは未実施（Phase 2 の最初の作業として実施予定）

### 想定外の点

- `agentKv:blob` のデータが **JSON と protobuf の混在**だった。キックオフ時の想定では JSON 前提だったが、実データでは先頭バイト `7B` = JSON, `0A` = protobuf が混在。Phase 2 のコンテンツ抽出に影響する
- `EncryptedBlobStore`（AES-GCM）の存在。暗号化レイヤーがあること自体が想定外。有効な場合、復号キーの取得方法が Phase 2 の追加課題になる
- `composer.content.*` はファイル差分用で、会話テキストのマッピングとは**無関係**だった。キックオフ時の仮説（「仲介者の可能性」）を棄却

### プラン実行時に調整した点

- **Step 1b/1c をスキップ**: Step 0 の rg 局所抽出で agentKv:blob マッピングが十分に解明されたため、diff 実験（1b）と exportChatAsMd 突合（1c）は不要と判断。プランの条件分岐（「解明できれば 1b はスキップ可能」）に沿った判断
- **Step 3 と Step 4 を実質統合**: reader.ts にDB同時アクセス戦略を最初から組み込んだため、Step 3（ライブラリ検証）と Step 4（同時アクセス実装）は1つの作業として進行
- **Step 1 のクエリを強化**: プランのクエリに `typeof(value)` と `hex(substr(value, 1, 16))` を追加（peer-review 反映済みだがプラン記載通り以上に拡張）。`json_extract` で composerData のフィールド構造を直接確認するクエリも追加

### プラン改善点

- **peer-ai-review 実施ポイントが TODO から脱落した**: プラン本文の「peer-ai-review 実施ポイント」セクションに3箇所の review gate が記載されていたが、TODO リストに独立項目として含まれていなかったため、実装の勢いで全て飛ばされた。**対策**: ユーザールール（Execution Policy）に「プラン内の gate/checkpoint/review 指示は TODO 項目として登録すること」を追加済み
- **Step 間の依存関係がプランに明記されているのに、TODO は並列リストだった**: フローチャート（mermaid）はあったが、TODO リストはフラットで、Step 間の前後関係や条件分岐が反映されていなかった。TODO にも依存関係を持たせるか、少なくとも gate を挟む構造が必要
- **「テストファースト」の定義が曖昧だった**: Step 3 で「テストファースト」と書いてあったが、Node.js テスト成功 = 検証完了なのか、Extension Development Host テストまで含むのかが不明確。合格基準を明記すべきだった

### 提案

- **Phase 2 キックオフの最初のアクションとして Extension Development Host テストを実施すべき**。better-sqlite3 の N-API ABI は概ね安定しているが、Cursor の Electron 内での require() パス解決は未検証。ここが壊れると Phase 2 全体が止まる
- **peer-ai-review コマンド自体に「review ポイントは TODO に含めること」の注意書きを追加する価値がある**。ユーザールールで一般原則は追加したが、コマンド固有の多重防御としても有効
- **今回のスレッドは「ゼロベースプロジェクトの Phase 1 実装」の実例として、B-2-1（キックオフで立ち上がりが速まるか）の検証データになる**。次スレッド（Phase 2）の開始時に「このエピソード + キックオフだけで文脈が復元できるか」を意識的に評価すべき

## 生ログ

- 本スレッド（SpecStory）: `raw-logs/2026-02-20_12-03Z-phase-1-planning-and-documentation.md`
- 本スレッド（Cursor transcript）: `raw-logs/cursor_phase_1_planning_and_documentati_b554d627-3e8c-40ab-bcaf-5cffb869c8d0.md`
