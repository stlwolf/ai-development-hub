# arena-compare

Cursor CLI（`agent` コマンド）を使って、同一プロンプトを複数モデルに並列投入し結果を比較するスクリプト。

Cursor サブスクのモデルを使うので、外部 API のキーやレート制限を別に持たなくてよい。既定は `composer-2.5` の1本で、ほかのモデルは `--list-models` で確かめて `-m` で渡す。

## 使い方

```bash
# 既定のモデル（composer-2.5）で実行
./arena-compare.sh "プロンプト"

# モデル指定（モデル名は --list-models で確かめる）
./arena-compare.sh -m "<モデル>,<モデル>" "プロンプト"

# コンテキストファイル付き
./arena-compare.sh -c src/file.ts "このコードをレビューして"

# プロンプトをファイルから読み込み
./arena-compare.sh -f prompt.txt

# 利用可能モデル一覧
./arena-compare.sh --list-models
```

### セッション継続（resume）

```bash
# 初回実行（チャットIDが自動保存される）
./arena-compare.sh -m "<モデル>,<モデル>" -o tmp/session1 "最初の質問"

# 2回目（前回のコンテキストを保持して追加質問）
./arena-compare.sh --resume-from tmp/session1 -m "<モデル>,<モデル>" -o tmp/session1-r2 "前の回答を踏まえて深掘り"

# 3回目（さらに連鎖）
./arena-compare.sh --resume-from tmp/session1-r2 -m "<モデル>,<モデル>" -o tmp/session1-r3 "さらに追加の質問"
```

## 前提条件

```bash
# Cursor CLI (agent) がインストール・認証済みであること
agent status
```

## オプション

| オプション | 説明 | デフォルト |
|-----------|------|----------|
| `-m MODELS` | 比較モデル（カンマ区切り） | `composer-2.5` |
| `-f FILE` | プロンプトをファイルから読み込み | - |
| `-c FILE...` | コンテキストファイルを添付 | - |
| `-o DIR` | 出力ディレクトリ指定 | `tmp/arena-YYYYMMDD-HHMMSS` |
| `-w PATH` | ワークスペースパス | カレントディレクトリ |
| `--mode MODE` | agent モード（agent/plan/ask） | `ask` |
| `--resume-from DIR` | 前回の出力ディレクトリからセッション再開 | - |
| `--list-models` | 使えるモデルの一覧を表示（`agent models`） | - |
| `--dry-run` | 実行せずコマンド表示 | - |

## 環境変数

| 変数 | 説明 | デフォルト |
|------|------|----------|
| `ARENA_MODELS` | デフォルトモデル（カンマ区切り。`-m` が優先） | `composer-2.5` |
| `ARENA_TIMEOUT` | タイムアウト秒数 | `240` |

## デフォルトモデル

既定はモードによらず `composer-2.5` の1本である。セカンドオピニオン（so-compare）の Cursor のレーンの既定とそろえている。

複数のモデルで比べたいときは、`--list-models` でアカウントで使えるモデル名を確かめ、`-m` か `ARENA_MODELS` で渡す。モデル名は Cursor の側で変わるので、この README には具体的な名前を並べない。

## 出力構造

```
tmp/arena-YYYYMMDD-HHMMSS/
├── prompt.txt              # 投入プロンプト
├── summary.md              # 回答サマリ（メタデータ + 各モデル回答全文）
├── {model}-chat-id.txt     # チャットID（resume 用）
├── {model}-stdout.txt      # 各モデルの応答
├── {model}-stderr.txt      # エラー出力
└── {model}-meta.txt        # メタデータ（実行時間、行数、バイト数、チャットID）
```

## 既知の制約

- **シーケンシャル実行**: `agent` CLI が `~/.cursor/cli-config.json` を書き換えるため、並列起動するとレースコンディションでハングする。各モデルをシーケンシャルに実行して回避
- **`nohup` + `-f` が必須**: Cursor 統合ターミナルから実行する場合、TTY 分離と Workspace Trust スキップが必要
- **`agent ls` は非インタラクティブでは使えない**: チャット一覧は `~/.cursor/chats/` の SQLite を直接走査する必要がある
- **`--resume` と `--mode` の併用不可**: `--resume` 使用時に `--mode ask` を指定するとハングする。初回のみ `--mode` が適用され、resume 時は自動的に省略される

## 関連

- `canonical/skills/arena-compare/SKILL.md` — Arena スキル（呼び出し方法、モデル選択基準、resume 手順のリファレンス）
- `canonical/commands/verification/arena-perspectives.md` — Arena を使うコマンド（サブエージェント委譲対応済み）
- `scripts/so-compare.sh` — Codex CLI / Claude CLI バックエンドの比較スクリプト（本スクリプトの原型）
- `canonical/commands/verification/peer-ai-review.md` — SO比較を組み込んだピアレビューコマンド
- `ideas/20260222/orchestration-tool-building-approach.md` — オーケストレーションツール構築の構想
