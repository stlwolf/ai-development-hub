---
title: "arena-compare.sh プロトタイプ検証: Cursor CLI でマルチモデル並列比較"
date: 2026-02-22
type: episode
related:
  - type: derived_from
    ref: ../../scripts/so-compare.sh
    reason: "インターフェース設計と並列実行パターンのベース"
  - type: evidence_for
    ref: ../../ideas/20260222/orchestration-tool-building-approach.md
    reason: "自前オーケストレーションツールのプロトタイプ実験"
tags: [arena-mode, cursor-cli, multi-model, agent-cli, verification]
---

# arena-compare.sh プロトタイプ検証

## 背景

Windsurf の Arena Mode（同一プロンプトを複数モデルに並列投入して比較する機能）を、Cursor のサブスク内モデルで再現できるか検証。外部 API（Claude API / OpenAI API）の制限・コストを回避し、Cursor サブスクの枠内で完結させることが制約。

## 発見: Cursor CLI `agent` コマンド

```bash
agent -p -f --model "モデルID" --output-format text "プロンプト"
```

- `-p`: 非インタラクティブ（print mode）
- `-f`: Workspace Trust スキップ（ヘッドレス時に必須）
- `--model`: 38+ モデルから指定可能
- `--output-format`: text / json / stream-json
- `--resume`: セッション維持
- `--workspace`: ワークスペース指定

`agent models` で利用可能モデル一覧を取得可能（opus-4.6, sonnet-4.6, gpt-5.2, gemini-3-flash, grok, kimi-k2.5 等）。

## 検証結果

### run-01: 単体動作（gemini-3-flash）

- **結果**: 成功
- **応答時間**: 7秒
- **方式**: `nohup agent -p -f --model gemini-3-flash --mode ask`

### run-02: 3モデル並列（スタガーなし）

- **結果**: 2/3 成功、GPT-5.2 が失敗
- **失敗原因**: `cli-config.json` のレースコンディション

```
Error: ENOENT: no such file or directory, rename
'/Users/eddy/.cursor/cli-config.json.tmp' -> '/Users/eddy/.cursor/cli-config.json'
```

複数の `agent` プロセスが同時に設定ファイルをリネームしようとして衝突。

### run-03: GPT-5.2 単体

- **結果**: 成功（5秒）
- **確認**: レースコンディションが並列起因であることを確定

### run-04: 3モデル並列（2秒スタガー）

- **結果**: 3/3 全成功
- **応答時間**: gemini-3-flash 24秒 / sonnet-4.6 11秒 / gpt-5.2 11秒
- **出力品質**: 3モデルとも同じ質問に対して構造化された回答を返した

| モデル | 時間 | 出力行数 | 出力バイト数 | 状態 |
|--------|------|---------|------------|------|
| gemini-3-flash | 24秒 | 34行 | 1474 bytes | 成功 |
| sonnet-4.6 | 11秒 | 33行 | 855 bytes | 成功 |
| gpt-5.2 | 11秒 | 30行 | 1189 bytes | 成功 |

## 知見

### 1. レースコンディション対策が必須

`agent` CLI は起動時に `~/.cursor/cli-config.json` を書き換える。同時起動するとファイルのリネームが衝突する。**2秒のスタガー（ずらし起動）で解決**。

### 2. `nohup` + `-f` の組み合わせが必要

Cursor 統合ターミナルから実行する場合:
- `nohup`: TTY 分離（`claude-safe` と同じ課題）
- `-f` (`--force`): Workspace Trust の確認プロンプトを回避

### 3. `--mode ask` がデフォルトで安全

- `ask` モード: read-only、コード変更なし → 比較用途に最適
- `agent` モード: コード変更可能 → worktree 隔離と組み合わせれば Arena Mode 完全再現

### 4. so-compare.sh との関係

| | so-compare.sh | arena-compare.sh |
|---|---|---|
| バックエンド | codex CLI + claude-safe | Cursor `agent` CLI |
| コスト | 各 CLI の API 制限に依存 | Cursor サブスク内 |
| モデル数 | 2 | 38+ |
| 並列実行 | 即時 | 2秒スタガー必要 |
| セッション維持 | なし | `--resume` で可能 |

## 成果物

- `arena-compare.sh`: プロトタイプスクリプト
- `run-01-single/`: 単体動作検証の出力
- `run-02-parallel/`: 並列（スタガーなし）検証の出力
- `run-03-gpt-solo/`: GPT-5.2 単体確認の出力
- `run-04-stagger/`: 並列（スタガー付き）検証の出力

## 追加検証: セッション維持（resume）

### チャットデータの永続化先

```
~/.cursor/chats/{workspace-hash}/{chat-uuid}/store.db  (SQLite 3.x)
├── meta テーブル: hex エンコード JSON（agentId, name, createdAt, latestRootBlobId, mode）
└── blobs テーブル: バイナリ形式の会話状態（直読み不可）
```

### resume フロー検証

```bash
# 1. チャット作成
CHAT_ID=$(agent create-chat)
# → 932e64ce-21c4-40ec-92e2-bd66c8d0c865

# 2. 1発目
agent -p -f --resume="$CHAT_ID" --model "gemini-3-flash" "Pythonのソートについて"
# → "list.sort() と sorted(list) の2つ"

# 3. 2発目（コンテキスト保持確認）
agent -p -f --resume="$CHAT_ID" "先ほどの2つの使い分け基準を"
# → 前回の回答を踏まえた回答（成功）
```

### 制約

- `agent ls`（チャット一覧）: Ink UI 必須のため非インタラクティブでは使えない
- blobs データ: バイナリシリアライズされておりテキストでは読めない
- 回避策: `~/.cursor/chats/*/store.db` の meta テーブルを SQLite で走査すればチャットIDと名前は取得可能

## 次のステップ

- [x] `scripts/` に昇格して `so-compare.sh` と並列管理 → `scripts/arena-compare.sh` がシンボリックリンクとして配置済み
- [x] Cursor コマンドを作成してメインスレッドから呼べるようにする → `cursor/command/verification/arena-perspectives.md` として作成・sync済み
- [x] `--resume` によるセッション維持の検証 → 動作確認済み
- [x] arena-compare.sh に resume サポートを組み込む → `--resume-from DIR` 実装済み（2026-02-23）
- [ ] 回答品質を比較する自動サマリ機能（diff / テーブル出力）
- [ ] `--mode agent` + worktree 隔離でのコード変更比較
