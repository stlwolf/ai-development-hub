---
title: "cursor-thread-tools キックオフ"
date: 2026-02-20
type: plan
participants:
  - Eddy
  - Cursor Agent (Claude 4.6 Opus, Primary)
related:
  - type: derived_from
    ref: ../../../ideas/20260220/context-persistence-4layer-model.md
    reason: "層3（生ログ）の抽出パイプラインとして本プロジェクトが位置づけられる"
  - type: derived_from
    ref: ../../../ideas/20260208/hypothesis-intentional-compression-and-promotion-flow.md
    reason: "Episode→Decision昇格フローの入力源としてスレッドログを活用"
  - type: depends_on
    ref: ../../second-opinion-verification/docs/DOCUMENT_CONVENTION.md
    reason: "エピソード記録・ドキュメント規約を踏襲"
  - type: depends_on
    ref: ../../agent-verification-flow/docs/DESIGN_PRINCIPLES.md
    reason: "設計原則（Evidence First等）を踏襲"
tags: [cursor, vscode-extension, transcript, thread-lifecycle, sqlite]
keywords: [state.vscdb, cursorDiskKV, composerData, bubbleId, agentKv, composer.exportChatAsMd]
use_when:
  - "Cursorスレッドの会話ログを自動保存・活用したいとき"
  - "スレッド完了時にIssueへ定型報告を投稿したいとき"
  - "AI開発の判断経緯を構造化して保存したいとき"
---

# cursor-thread-tools キックオフ

## 1. 目的

### 直接の目的

Cursorのスレッド（Composer）会話を**GUIトリガーなしで**Markdownにエクスポートし、スレッドのライフサイクル管理（開始宣言・完了報告）をコマンドパレットから実行できるVS Code拡張を開発する。

### 裏テーマ（検証）

- **4層モデルの層3パイプライン実装**: 生ログ（会話トランスクリプト）から構造化ナレッジへの抽出パイプラインを実現する
- **意図的圧縮と昇格フローの自動化起点**: Episode記録の入力源としてスレッドログを活用し、Decision/Context層への昇格フローの入口を作る
- **自己参照的ツール開発**: 本ツール自体の開発過程をツールで記録・検証する再帰構造

---

## 2. 背景（確立済みの知見）

### 2-1. Cursor内部データ構造（実証済み）

Cursorは `state.vscdb`（SQLite）に会話データを格納。テーブル構造:

| テーブル | 用途 | 件数（Eddy環境） |
|---------|------|-----------------|
| `ItemTable` | VS Code由来のレガシーKV | - |
| `cursorDiskKV` | Cursor独自KV（主要データ） | - |

`cursorDiskKV` の主要キープレフィックス:

| プレフィックス | 件数 | 内容 |
|--------------|------|------|
| `agentKv:blob:` | 26,671 | アシスタント応答のコンテンツ本体（content-addressed） |
| `bubbleId:` | 14,461 | 個別メッセージメタデータ |
| `composerData:` | 193 | スレッドメタデータ（名前、bubbleIdリスト、タイムスタンプ） |
| `checkpointId:` | 1,014 | チェックポイント |
| `composer.content.*` | 667 | コンテンツハッシュ |

**DB場所**: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`

### 2-2. データ取得フロー（逆アセンブルで確認済み）

Cursorの `composer.exportChatAsMd` コマンドの実装を逆アセンブルして確認:

1. `composerData:<id>` から `fullConversationHeadersOnly`（bubbleIdリスト）を取得
2. 最初のbubbleIdを起点に `getConversationFromBubble()` でフル会話をロード
3. 各メッセージの `type`（1=HUMAN, 2=ASSISTANT）と `text` + `codeBlocks` をMarkdown整形
4. `~/Downloads/cursor_{name}.md` にファイル保存ダイアログ経由で出力

**技術課題**: アシスタント応答のテキストが `bubbleId` エントリ自体には格納されず、`agentKv:blob:<hash>` にcontent-addressed形式で分離されている。このマッピングの解明が主要な実装課題。

### 2-3. 全コマンドID一覧（発見済み）

`workbench.desktop.main.js` から抽出した主要コマンド:

| コマンドID | ラベル |
|-----------|--------|
| `composer.exportChatAsMd` | Export Transcript |
| `composer.shareChat` | Share Transcript |
| `composer.copyRequestId` | Copy Request ID |
| `composer.openChatAsEditor` | Open Tab as Editor |
| `composer.showComposerHistory` | 履歴表示 |

### 2-4. SpecStory検証結果

SpecStory拡張をインストールして出力を確認済み:

- `.specstory/history/` にMarkdownを自動出力（GUIトリガー不要）
- 出力にはthinkingブロック、ツールコール詳細、モデル名が含まれる
- Cursorの Export Transcript より詳細だが、冗長（1スレッドで1.3MB超のケースあり）
- Issue投稿・git diff統合機能はなし

---

## 3. スコープ

### 作るもの

1. **`threadTools.export`** — 現在（or 指定）のスレッドをMarkdown出力
   - `state.vscdb` をread-onlyで読み取り
   - ユーザー発言 + アシスタント回答テキストのみ（ツールコール詳細・thinking省略）
   - 出力先: ワークスペース内 `.thread-exports/` or 指定パス

2. **`threadTools.done`** — スレッド完了報告の生成・投稿
   - `git diff` + `git log` で変更内容を要約
   - エクスポートしたトランスクリプトから判断経緯を抽出（オプション）
   - 定型フォーマットで `gh issue comment` に投稿

3. **`threadTools.list`** — スレッド一覧表示
   - 名前、bubbleCount、createdAt、isAgentic

### 作らないもの

- 自動保存（バックグラウンド定期実行）→ SpecStoryで足りる
- クラウド同期 → ローカル完結
- チャットUI改造 → Cursorの非公開APIに依存しない
- thinking/ツールコール詳細の出力 → ノイズ、容量問題

### 将来検討（スコープ外だが記録）

- `threadTools.start` — スレッド開始時のIssue紐付け・プラン宣言
- `threadTools.progress` — 途中経過報告
- MCP サーバー化（エージェントが自分のスレッド履歴を自己参照）
- 正準エージェント定義フォーマット（ideas/20260212）との統合

---

## 4. 4層モデルにおける位置づけ

`ideas/20260220/context-persistence-4layer-model.md` で定義された4層との対応:

```
層1: GitHub Issue ←── threadTools.done が投稿（完了報告）
層2: 構造化ナレッジ ←── トランスクリプトから昇格したエピソード/ADR
層3: 生ログ ←── threadTools.export が出力（★本プロジェクトの主要成果物）
層4: コード + コミット ←── threadTools.done が git diff で参照
```

**本プロジェクトは「層3の抽出パイプライン」の最初の実装**。4層モデルの「現時点の制約: 層3の抽出パイプラインは未実装」を解消する。

---

## 5. 技術設計（概要）

### 拡張構成

```
extension/
├── package.json          # コマンド定義、activationEvents
├── tsconfig.json
└── src/
    ├── extension.ts      # エントリポイント（activate/deactivate）
    ├── db/
    │   └── reader.ts     # state.vscdb 読み取り（SQLite, read-only）
    ├── export/
    │   └── markdown.ts   # Markdown生成
    └── commands/
        ├── export.ts     # threadTools.export
        ├── done.ts       # threadTools.done（git diff + gh issue comment）
        └── list.ts       # threadTools.list
```

### 依存

- `better-sqlite3` — SQLite読み取り
- VS Code Extension API — コマンド登録、ファイル操作
- `child_process` — `git`, `gh` コマンド実行

### DB同時アクセス対策

Cursor起動中はDBがロックされる可能性がある。read-onlyモードで開く:

```typescript
const db = new Database(dbPath, { readonly: true, fileMustExist: true });
```

---

## 6. 検証計画

### Phase 1: DB読み取りの基盤検証

- [ ] `better-sqlite3` で `state.vscdb` をread-only読み取りできるか
- [ ] Cursor起動中の同時アクセスで問題が起きないか
- [ ] `composerData` → `bubbleId` → テキスト抽出のフルパスが機能するか
- [ ] `agentKv:blob` とbubbleIdのマッピングを解明できるか

### Phase 2: Markdownエクスポート

- [ ] ユーザー発言 + アシスタント回答のMarkdown出力
- [ ] SpecStoryの出力と比較して情報の過不足を確認
- [ ] 大規模スレッド（411 bubbles等）での性能確認

### Phase 3: thread-done 統合

- [ ] `git diff` + `git log` による変更要約の生成
- [ ] `gh issue comment` による定型報告投稿
- [ ] トランスクリプトからの判断経緯抽出（オプション機能）

### Phase 4: パッケージング

- [ ] `.vsix` ビルドとCursorへのローカルインストール
- [ ] `scripts/install.sh` の作成

### 成功基準

- コマンドパレットからワンアクションでスレッドをMarkdownエクスポートできる
- `threadTools.done` でIssueに定型報告が投稿できる
- SpecStoryなしで層3のログ保存が機能する
- 本プロジェクト自体の開発エピソードが `docs/episodes/` に記録される

---

## 7. 既存資産との接続

| 既存資産 | 本プロジェクトとの関係 |
|---------|---------------------|
| `DOCUMENT_CONVENTION.md` | `docs/episodes/` の記録規約として踏襲 |
| `peer-ai-review` コマンド | 設計判断のレビューに使用（開発プロセスの検証） |
| `so-compare.sh` | セカンドオピニオン取得に使用 |
| `agent_handover.md` | スレッド間コンテキスト引き継ぎの参考 |
| `4層モデル` | 層3パイプラインの位置づけ |
| `意図的圧縮と昇格フロー` | Episode→Decision昇格の入力源 |
| `BACKLOG.md` #2 | 「会話ログ保存の仕組み構築」Issue との対応 |

---

## 8. リポジトリ分離計画

### 現フェーズ（ai-development-hub内）

```
projects/cursor-thread-tools/
├── extension/     # VS Code拡張コード
├── docs/          # 設計判断・検証記録（DOCUMENT_CONVENTION準拠）
└── scripts/       # ユーティリティ
```

### 公開フェーズ（条件を満たしたら）

- 拡張コードを独立リポジトリ `github.com/stlwolf/cursor-thread-tools` に移行
- `extension/` のコード + 汎用README + LICENSE のみ移行
- `docs/episodes/` 等の検証記録はai-development-hub側に残す
- ai-development-hub側は凍結スナップショットとして保持し、READMEに移行先を記載

### 分離条件

- Phase 2 が完了し、エクスポート機能が安定動作すること
- 他者が利用可能な汎用READMEが書けること
- ドメイン固有情報（プロダクト固有等）が拡張コードに含まれていないこと

---

## 9. リスクと注意点

| リスク | 影響 | 対処 |
|-------|------|------|
| Cursorアップデートでスキーマ変更 | DB読み取りが壊れる | 薄く作って壊れたら直す。SpecStoryのソースも参考に |
| `agentKv:blob` マッピング解明の困難 | アシスタント応答が取得不能 | フォールバック: `composer.exportChatAsMd` をキーバインド経由で呼ぶ |
| 構造維持が目的化 | 本来の開発が停滞 | 最小機能（export）を先に動かし、doneは後回し可 |
| better-sqlite3のネイティブモジュール問題 | Cursor内で動かない | sql.js（WASMベース）にフォールバック |
