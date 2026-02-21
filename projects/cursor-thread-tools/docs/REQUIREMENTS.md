---
title: "cursor-thread-tools 機能要件・非機能要件"
date: 2026-02-21
type: plan
related:
  - type: derived_from
    ref: plans/2026-02-20-kickoff-cursor-thread-tools.md
    reason: "プロジェクトキックオフのスコープ定義"
  - type: derived_from
    ref: decisions/ADR-004-scope-refocus.md
    reason: "スコープ変更（thread-done を外し、A+B 層に集中）"
tags: [requirements, scope, functional, non-functional]
use_when:
  - "新しいフェーズの計画時にスコープを確認したいとき"
  - "機能追加の判断時にスコープ内かどうかを判定したいとき"
---

# 機能要件・非機能要件

## プロダクト定義

Cursor の Composer スレッド会話データを **GUIトリガーなしで** 抽出・エクスポートする VS Code 拡張 + CLI ツール。

Cursor 内部データ（`state.vscdb`）への read-only アクセスを核とし、会話ログの保存・変換・自動化をワークフローに組み込むことを目的とする。

---

## 機能要件

### FR-1: スレッド一覧表示（Phase 1 完了）

| 項目 | 内容 |
|------|------|
| コマンド | `threadTools.list` |
| トリガー | コマンドパレット |
| 入力 | なし |
| 出力 | QuickPick UI（スレッド名、メッセージ数、作成日時、Agent/Chat 区別） |
| データソース | `composerData:*` from `state.vscdb` |

### FR-2: Markdown エクスポート（Phase 2 完了）

| 項目 | 内容 |
|------|------|
| コマンド | `threadTools.export` |
| トリガー | コマンドパレット（QuickPick でスレッド選択） |
| 入力 | スレッド選択（composerId） |
| 出力 | `.thread-exports/{name}_{id}.md` をワークスペースに保存 → エディタで開く |
| 出力内容 | ユーザー発言 + アシスタント応答テキスト。thinking は `<details>` 折りたたみ（デフォルト ON）。tool_call はテキスト抽出なし |
| データソース | `composerData` → `conversationState`（base64/hex protobuf）→ `agentKv:blob` → turn/message protobuf |

### FR-3: 自動保存（Phase 3 予定）

| 項目 | 内容 |
|------|------|
| トリガー | バックグラウンド定期実行（設定可能なインターバル） |
| 入力 | なし（全スレッドまたは設定で指定） |
| 出力 | 指定ディレクトリに Markdown ファイルを自動保存 |
| 差分検知 | 前回エクスポート以降に更新されたスレッドのみ対象 |
| 備考 | SpecStory の代替・補完として位置づけ |

### FR-4: CLI エントリポイント（Phase 3 予定）

| 項目 | 内容 |
|------|------|
| 実行方法 | `node cli.js list` / `node cli.js export <composerId>` |
| 入力 | コマンドライン引数 |
| 出力 | stdout（list）/ ファイル（export） |
| コア共有 | VS Code 拡張と同じ db/reader, proto/decoder, export/markdown を使用 |
| 備考 | VS Code 非依存で動作。CI/スクリプトからの利用を想定 |

### FR-5: エクスポートカスタマイズ（Phase 3 予定）

| 項目 | 内容 |
|------|------|
| thinking の出力制御 | 含む / 含まない / `<details>` 折りたたみ |
| tool_call の出力制御 | 含まない（現状）/ ツール名のみ / 詳細 |
| 出力先の指定 | ワークスペース内 / 任意パス |
| ファイル名フォーマット | カスタマイズ可能（日付、スレッド名等のテンプレート） |
| 設定方法 | VS Code settings（拡張）/ コマンドライン引数（CLI） |

---

## 明示的にスコープ外

| 機能 | 理由 | 代替手段 |
|------|------|---------|
| `threadTools.done`（完了報告 + Issue 投稿） | git/gh CLI 連携はコアと独立した関心（ADR-004） | Cursor コマンド or 独立 CLI として別途実装 |
| クラウド同期 | ローカル完結の方針 | git push で代替 |
| チャット UI 改造 | Cursor の非公開 API に依存しない | - |
| リアルタイム会話キャプチャ | DB の定期読み取りで十分 | 自動保存（FR-3）で代替 |

---

## 将来検討（スコープ外だが記録）

| 機能 | 概要 |
|------|------|
| `threadTools.start` | スレッド開始時の Issue 紐付け・プラン宣言 |
| `threadTools.progress` | 途中経過報告 |
| `threadTools.done` | 完了報告（別ツールとして、本拡張の export 結果を入力に使用） |
| MCP サーバー化 | エージェントが自分のスレッド履歴を自己参照 |
| マーケットプレイス公開 | `.vsix` ビルド → 公開 |

---

## 非機能要件

### NFR-1: 対応環境

| 項目 | 現状 | 目標 |
|------|------|------|
| OS | macOS のみ | macOS / Windows / Linux（Phase 4 以降） |
| エディタ | Cursor（Electron 39） | Cursor + VS Code |
| Node.js | v25.6.1（Cursor 内蔵） | Cursor/VS Code 内蔵バージョンに追従 |

### NFR-2: DB アクセス

| 項目 | 仕様 |
|------|------|
| アクセス方式 | read-only（`state.vscdb` を書き換えない） |
| ロック対策 | `readonly: true` + `busy_timeout = 3000` + WAL 3ファイルコピーフォールバック |
| 暗号化対応 | 現環境で非適用を確認。暗号化有効時はスコープ縮小（明示エラー） |

### NFR-3: 性能

| 項目 | 実測値 | 目標 |
|------|--------|------|
| turn デコード速度 | 25,000 turns/sec（75 turns / 3ms） | 5秒以内で任意サイズのスレッドをエクスポート |
| Markdown 生成含め | 4ms（75 turns） | - |

### NFR-4: 外部依存

| 項目 | 仕様 |
|------|------|
| ランタイム依存 | `better-sqlite3@12.6.2` のみ |
| protobuf パーサー | 外部依存ゼロ（自前 198 行） |
| ビルド依存 | `@electron/rebuild`（Cursor の Electron バージョン向けリビルド） |

### NFR-5: Cursor アップデート耐性

| 項目 | 仕様 |
|------|------|
| 方針 | 薄く作って壊れたら直す |
| スキーマ変更検知 | protobuf デコード失敗時に安全にスキップ（unknown field） |
| Electron バージョン変更 | `@electron/rebuild` で再ビルド。better-sqlite3 のメジャーバージョン対応が必要な場合あり |

### NFR-6: 配布

| 項目 | 現状 | 目標 |
|------|------|------|
| 方式 | ローカルインストール（`npm install` + `@electron/rebuild`） | `.vsix` ビルド → ローカルインストール → マーケットプレイス（将来） |
| リポジトリ | ai-development-hub 内 | 独立リポジトリに分離（分離条件: 安定動作 + 汎用 README + ドメイン固有情報なし） |

---

## 既知の制約・技術的負債

| 項目 | 詳細 | 対応予定 |
|------|------|---------|
| 新フォーマットスレッド | `conversationState: "~"` のスレッドはテキスト抽出不可 | Phase 3 で調査・対応 |
| `readVarint` 32bit 制限 | JavaScript bitwise OR は 32bit。大きな varint でオーバーフローの可能性 | 実用範囲では問題なし |
| macOS 専用パス | `getStateDbPath()` が `~/Library/...` にハードコード | Phase 4 でクロスプラットフォーム対応 |
| `@electron/rebuild` 手動実行 | `npm install` 後に手動リビルド必要 | `postinstall` スクリプト化を検討 |
