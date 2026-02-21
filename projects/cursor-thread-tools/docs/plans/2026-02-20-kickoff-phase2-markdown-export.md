---
title: "Phase 2 キックオフ: Markdownエクスポート"
date: 2026-02-20
type: plan
participants:
  - Eddy
  - Cursor Agent (Primary)
related:
  - type: derived_from
    ref: ../episodes/2026-02-20-phase1-db-foundation.md
    reason: "Phase 1 エピソードの「Phase 2 への引き継ぎ」セクションが入力"
  - type: derived_from
    ref: ../plans/2026-02-20-kickoff-cursor-thread-tools.md
    reason: "プロジェクトキックオフの Phase 2 検証計画"
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント命名規則・フォルダ構成はこの規約に従う"
  - type: depends_on
    ref: ../VERIFICATION_MATRIX.md
    reason: "検証項目 A-2-1 〜 A-2-4 に対応"
  - type: depends_on
    ref: ../decisions/ADR-001-sqlite-library.md
    reason: "SQLiteライブラリは better-sqlite3 で確定済み"
tags: [phase2, markdown-export, protobuf, agentKv, vscode-extension, threadTools]
keywords: [agentKv:blob, protobuf, SJm, AES-GCM, EncryptedBlobStore, composerData, bubbleId, exportChatAsMd]
use_when:
  - "Phase 2 子スレッドを開始するとき（このファイルが最初のプロンプト）"
  - "Markdownエクスポート機能の設計判断を確認したいとき"
---

# Phase 2 キックオフ: Markdownエクスポート

## 規約

本プロジェクトのドキュメント規約は `CONVENTIONS.md`（プロジェクトルート）に定義されている。ファイル命名・frontmatter・フォルダ構成はそれに従うこと。

## 1. 目的

`state.vscdb` からスレッドの会話データを抽出し、ユーザー発言 + アシスタント応答を Markdown にエクスポートする `threadTools.export` コマンドを実装する。

### Phase 2 の成功基準

- [ ] コマンドパレットから `threadTools.export` を実行し、選択スレッドの Markdown ファイルが生成される
- [ ] ユーザー発言とアシスタント応答のテキストが正しく結合されている
- [ ] Extension Development Host で拡張が正常にロードされる（better-sqlite3 の require() パス解決を含む）
- [ ] 大規模スレッド（400+ bubbles）で性能に問題がない
- [ ] SpecStory 出力との比較で、会話内容の欠損がない

---

## 2. Phase 1 からの引き継ぎ

### 解決済み（Phase 1 で確認済み）

- better-sqlite3 で `state.vscdb` の read-only アクセス成功（ADR-001）
- DB 同時アクセス: `readonly + busy_timeout + WAL 3ファイルコピーフォールバック`
- `composerData` メタデータ取得（206 スレッド確認）
- `agentKv:blob` マッピング解明（SHA-256 content-addressed）
- `threadTools.list` コマンドが Node.js テストで動作

### Phase 2 の主要課題

1. **Extension Development Host テスト**（Phase 1 未実施の最重要確認）
2. **agentKv:blob からのテキスト抽出**（protobuf デシリアライズ + 暗号化復号）
3. **Markdown エクスポート**（ユーザー発言 + アシスタント応答の結合出力）

### Phase 1 で発見された想定外の事実

- `agentKv:blob` のデータは **JSON と protobuf の混在**。先頭バイト `7B` (`{`) = JSON、`0A` = protobuf
- `EncryptedBlobStore`（AES-GCM, IV 12byte）の暗号化レイヤーが存在する
- 会話 turns の構造:

```
composerData → fullConversationHeadersOnly → [{bubbleId, type}]
  ↓
各 turn は blob ID (SHA-256 hash) として保持
  ↓
agentKv:blob:<hex> → protobuf binary → SJm.fromBinary() でデシリアライズ
  ↓
turn.case === "agentConversationTurn" → userMessage, steps
```

---

## 3. 実施計画

### Step 0: Extension Development Host テスト（最優先ブロッカー）

**目的**: better-sqlite3 が Cursor の Electron 環境で正常にロードされるか確認。ここが壊れると Phase 2 全体が止まる。

1. `extension/` で `npm run compile`
2. F5 で Extension Development Host を起動
3. `threadTools.list` をコマンドパレットから実行
4. `process.versions` のログ出力を確認（Electron / Node バージョン）

**判断分岐**:
- 成功 → Step 1 に進む
- `better-sqlite3` のロード失敗 → `vscode-node-sqlite3`（Microsoft fork）に切り替え。ADR-001 を supersedes で更新

### Step 1: agentKv:blob からのテキスト抽出

**目的**: protobuf バイナリと JSON の混在データからテキストを抽出するモジュールを実装する。

#### 1-a. データフォーマット判定

```typescript
function detectFormat(data: Buffer): 'json' | 'protobuf' | 'encrypted' | 'unknown' {
  if (data[0] === 0x7B) return 'json';    // { = JSON
  if (data[0] === 0x0A) return 'protobuf'; // protobuf varint tag
  // AES-GCM encrypted: 要調査（先頭バイトパターン）
  return 'unknown';
}
```

#### 1-b. JSON パス

JSON 形式のデータ（`{"role":"system"...}` 等）はそのまま `JSON.parse()` でテキスト抽出。

#### 1-c. Protobuf パス

Phase 1 の rg 局所抽出で判明した情報:

- `SJm.fromBinary()` でデシリアライズ
- `turn.case === "agentConversationTurn"` でアシスタントの応答を取得
- `userMessage`, `steps` フィールドにテキストが格納

**アプローチ選択肢**:

| 方法 | メリット | デメリット |
|------|---------|----------|
| `.proto` 定義を逆エンジニアリングして `protobufjs` で正式デシリアライズ | 型安全、正確 | `.proto` 抽出が困難 |
| バイナリから直接テキストフィールドを抽出（wire type 2 = length-delimited） | 実装が単純 | protobuf の構造変更に弱い |
| Cursor の minified JS から `SJm` クラス相当のデコーダを移植 | 最も正確 | 複雑、メンテ困難 |

Phase 1 の rg 局所抽出結果をさらに深掘りし、フィールド番号とメッセージ構造を特定してからアプローチを決定する。

#### 1-d. EncryptedBlobStore（AES-GCM）

暗号化が有効な場合の対応。

- 鍵の保管場所を調査（`workbench.desktop.main.js` の `EncryptedBlobStore` 周辺）
- 鍵が取得可能なら AES-GCM 復号を実装
- 鍵が取得不能なら、暗号化されていないデータのみを対象とする（スコープ縮小）

### Step 2: Markdown 生成

`composerData` → `bubbleId` リスト → 各 turn のテキスト取得 → Markdown 整形。

```markdown
# {thread_name}
_Exported on {date} from Cursor Thread Tools_

---

**User**

{user_message}

---

**Assistant**

{assistant_response}

---
```

- Cursor の `composer.exportChatAsMd` の出力フォーマットに近い形式を目指す
- codeBlocks は fenced code block として出力

### Step 3: threadTools.export コマンド実装

1. `threadTools.list` の QuickPick で選択（`composerId` を取得）
2. 選択スレッドの全 turn を読み取り
3. Markdown 生成
4. ワークスペース内 `.thread-exports/` にファイル保存（or ユーザー指定パス）
5. 保存したファイルをエディタで開く

### Step 4: 検証

- SpecStory 出力と突合し、テキストの欠損・差異を確認
- 大規模スレッド（400+ bubbles）での処理時間を計測
- `threadTools.list` → 選択 → export の end-to-end テスト

---

## 4. 検証マトリクス対応

| 検証項目 | ID | 本 Phase での検証内容 |
|---------|----|--------------------|
| ユーザー発言 + アシスタント回答の結合出力 | A-2-1 | Step 2 + Step 3 |
| SpecStory 出力との情報過不足比較 | A-2-2 | Step 4 |
| 大規模スレッド（400+ bubbles）での性能 | A-2-3 | Step 4 |
| コマンドパレットからの実行 | A-2-4 | Step 0 + Step 3 |

---

## 5. リスクと対処

| リスク | 影響 | 対処 |
|-------|------|------|
| better-sqlite3 が Cursor Electron でロード失敗 | Phase 2 全体ブロック | Step 0 で最優先確認。失敗時は vscode-node-sqlite3 に切り替え |
| protobuf 構造が複雑で .proto 定義の逆エンジニアリングが困難 | テキスト抽出不能 | バイナリ直接抽出にフォールバック。最悪 exportChatAsMd 出力をゴールデンにして手動比較 |
| EncryptedBlobStore の鍵が取得不能 | 暗号化データが読めない | 暗号化無効なデータのみ対象。Cursor の暗号化設定を確認し、無効化可能か調査 |
| Cursor アップデートで protobuf スキーマ変更 | デシリアライズ破損 | フォーマット検出を先頭バイトで行い、unknown は安全にスキップ |

---

## 6. peer-ai-review 実施ポイント

Phase 2 実装中に以下のタイミングで `/peer-ai-review` を実施する。**これらは実装プラン作成時に TODO 項目として独立登録すること**（Phase 1 の教訓）。

1. **Step 0 完了時**: Extension Development Host テスト結果の確認（問題が出た場合のみ）
2. **Step 1 完了時**: protobuf デシリアライズのアプローチ確定
3. **Step 3 完了時**: 拡張全体のコードレビュー（Phase 3 キックオフ前）

---

## 7. 完了条件

Phase 2 完了時に統合ハブスレッドに持ち帰るもの:

- [ ] `threadTools.export` が動作する拡張コード
- [ ] protobuf デシリアライズの実装（episodes/ に記録）
- [ ] EncryptedBlobStore の調査結果（対応可否の判断）
- [ ] VERIFICATION_MATRIX の A-2-1〜A-2-4 更新
- [ ] Phase 3 キックオフに必要な情報の整理

---

## 8. B-2-1 検証: キックオフで立ち上がりが速まるか

本キックオフは Phase 1 エピソード + CONVENTIONS.md から生成された。Phase 2 子スレッド開始時に、**このキックオフだけで文脈が復元できるか**を意識的に評価し、エピソードに記録すること。
