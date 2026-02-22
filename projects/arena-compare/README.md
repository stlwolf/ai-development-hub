# arena-compare

Cursor CLI（`agent` コマンド）を使って、同一プロンプトを複数モデルに並列投入し結果を比較するスクリプト。

Cursor サブスク内の全モデル（38+）を使えるため、外部 API のコスト・レート制限を回避できる。

## 使い方

```bash
# 3モデルで比較（デフォルト: opus-4.6, gpt-5.2, gemini-3-flash）
./arena-compare.sh "プロンプト"

# モデル指定
./arena-compare.sh -m "sonnet-4.6,gpt-5.2,gemini-3.1-pro" "プロンプト"

# コンテキストファイル付き
./arena-compare.sh -m "opus-4.6,sonnet-4.6" -c src/file.ts "このコードをレビューして"

# プロンプトをファイルから読み込み
./arena-compare.sh -f prompt.txt

# 利用可能モデル一覧
./arena-compare.sh --list-models
```

## 前提条件

```bash
# Cursor CLI (agent) がインストール・認証済みであること
agent status
```

## オプション

| オプション | 説明 | デフォルト |
|-----------|------|----------|
| `-m MODELS` | 比較モデル（カンマ区切り） | `opus-4.6,gpt-5.2,gemini-3-flash` |
| `-f FILE` | プロンプトをファイルから読み込み | - |
| `-c FILE...` | コンテキストファイルを添付 | - |
| `-o DIR` | 出力ディレクトリ指定 | `tmp/arena-YYYYMMDD-HHMMSS` |
| `-w PATH` | ワークスペースパス | カレントディレクトリ |
| `--mode MODE` | agent モード（agent/plan/ask） | `ask` |
| `--list-models` | モデル一覧表示 | - |
| `--dry-run` | 実行せずコマンド表示 | - |

## 環境変数

| 変数 | 説明 | デフォルト |
|------|------|----------|
| `ARENA_MODELS` | デフォルトモデル | `opus-4.6,gpt-5.2,gemini-3-flash` |
| `ARENA_TIMEOUT` | タイムアウト秒数 | `300` |

## 出力構造

```
tmp/arena-YYYYMMDD-HHMMSS/
├── prompt.txt              # 投入プロンプト
├── {model}-stdout.txt      # 各モデルの応答
├── {model}-stderr.txt      # エラー出力
└── {model}-meta.txt        # メタデータ（実行時間、行数、バイト数）
```

## 既知の制約

- **並列起動にスタガー（2秒間隔）が必要**: `agent` CLI が `~/.cursor/cli-config.json` を書き換えるため、同時起動するとレースコンディションが発生する
- **`nohup` + `-f` が必須**: Cursor 統合ターミナルから実行する場合、TTY 分離と Workspace Trust スキップが必要
- **`agent ls` は非インタラクティブでは使えない**: チャット一覧は `~/.cursor/chats/` の SQLite を直接走査する必要がある

## セッション維持（resume）

```bash
# チャット作成
CHAT_ID=$(agent create-chat)

# 1発目
agent -p -f --resume="$CHAT_ID" --model "opus-4.6" "最初の質問"

# 2発目（コンテキスト保持）
agent -p -f --resume="$CHAT_ID" "前の回答を踏まえて深掘り"
```

## 関連

- `scripts/so-compare.sh` — Codex CLI / Claude CLI バックエンドの比較スクリプト（本スクリプトの原型）
- `cursor/command/verification/peer-ai-review.md` — SO比較を組み込んだピアレビューコマンド
- `ideas/20260222/orchestration-tool-building-approach.md` — オーケストレーションツール構築の構想
