---
name: arena-compare
description: arena-compare.shで複数モデルに同一プロンプトを並列投入し、回答を比較する。多角的視点の取得、モデル間の回答差異分析、設計判断の補助に使用する。モデル選択基準、resume手順、summary読み込み手順を含む。
---

# Arena Compare — マルチモデル並列比較

## スクリプトの場所

```
projects/arena-compare/arena-compare.sh
```

## 呼び出し方法

Shell ツールで実行する:

```bash
./projects/arena-compare/arena-compare.sh [OPTIONS] "プロンプト"
```

### オプション一覧

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `-w PATH` | ワークスペースパス（推奨） | カレントディレクトリ |
| `-f FILE` | プロンプトをファイルから読み込み | - |
| `-m MODELS` | 比較モデル（カンマ区切り） | モード別デフォルト |
| `-c FILE...` | コンテキストファイル添付（**非推奨**。`-w` を使うこと） | - |
| `-o DIR` | 出力ディレクトリ指定 | `tmp/arena-YYYYMMDD-HHMMSS` |
| `--mode MODE` | agent モード: `agent` / `plan` / `ask` | `ask` |
| `--resume-from DIR` | 前回出力からセッション再開 | なし |
| `--list-models` | 利用可能モデル一覧を表示 | - |
| `--dry-run` | 実行せずコマンド表示のみ | - |

### 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `ARENA_TIMEOUT` | 各モデルのタイムアウト秒数 | `240` |
| `ARENA_MODELS` | デフォルトモデル（カンマ区切り） | モード別デフォルト |

### 基本パターン

```bash
# 推奨: -w でワークスペースを渡す
./projects/arena-compare/arena-compare.sh -w "$(pwd)" "この設計の問題点を指摘して"

# モデル明示指定
./projects/arena-compare/arena-compare.sh -m "sonnet-4.6,gpt-5.2,gemini-3.1-pro" -w "$(pwd)" "プロンプト"

# セッション継続（前回の回答を踏まえて追加質問）
./projects/arena-compare/arena-compare.sh --resume-from tmp/arena-20260304-001234 -w "$(pwd)" "追加の質問"
```

## モデル選択の基準

### モード別デフォルトモデル

| モード | デフォルトモデル | 理由 |
|--------|----------------|------|
| `ask` / `plan` | `gpt-5.2,gemini-3.1-pro,opus-4.6-thinking` | 異なるファミリー3つで多様性を確保 |
| `agent` | `gpt-5.3-codex-high,gemini-3.1-pro,composer-1.5` | コード生成に強いモデルを選択 |

### 選択の指針

- **ファミリー多様性**: 同じファミリー（例: Claude系×2）を避け、異なるモデルファミリーを混ぜる
- **メインスレッドとの差異**: メインスレッドが Claude 系のため、デフォルトから Claude を外して視点の多様性を確保
- **think モデルの混在**: 深い推論が必要な場合は think モデル（`opus-4.6-thinking`, `sonnet-4.6-thinking`）を含める

### よく使う組み合わせ

```bash
# 思考モデルを含める
-m "opus-4.6-thinking,sonnet-4.6-thinking,gpt-5.2"

# 軽量モデルで素早く比較
-m "gemini-3-flash,sonnet-4.6,gpt-5.2"

# 5モデル比較（時間がかかる）
-m "opus-4.6,sonnet-4.6,gpt-5.2,gemini-3.1-pro,grok"
```

## `--resume-from` によるセッション継続

各モデルがチャットIDを保持しており、前回のコンテキストを引き継いで追加質問できる。

```bash
# 初回実行
./projects/arena-compare/arena-compare.sh -w "$(pwd)" "この設計の問題点を指摘して"
# → 出力: tmp/arena-20260304-001234/

# 気になった回答を深掘り
./projects/arena-compare/arena-compare.sh --resume-from tmp/arena-20260304-001234 -w "$(pwd)" "GPT の指摘について、具体的な対策案を提示して"
```

resume 時はモデル指定（`-m`）を省略すると、前回と同じモデルが使われる。

## 出力ディレクトリ構成

```
tmp/arena-YYYYMMDD-HHMMSS/
├── prompt.txt              # 最終プロンプト全文
├── summary.md              # 全モデルの回答をまとめたMarkdown
├── {model}-stdout.txt      # 各モデルの回答
├── {model}-stderr.txt      # 各モデルの stderr
├── {model}-meta.txt        # メタデータ（model, chat_id, exit_code, elapsed_seconds, ...）
└── {model}-chat-id.txt     # チャットID（resume 用）
```

## summary.md の読み込みと要約手順

1. 実行完了後、`summary.md` を Read ツールで読み込む
2. summary.md の構成:
   - メタデータテーブル（モデル名・実行時間・出力サイズ・exit code）
   - 各モデルの回答全文
3. 要約する場合は、各モデルの回答から差分ポイント（一致点・相違点）を抽出する

```bash
cat tmp/arena-YYYYMMDD-HHMMSS/summary.md
```

## 注意事項

- 実行には `agent` CLI（Cursor CLI）が PATH 上に必要
- 並列実行時、agent CLI の cli-config.json レースコンディションを避けるため2秒ずつスタガー起動する
- `ARENA_TIMEOUT` のデフォルトは180秒。全モデルタイムアウト時はガイダンスメッセージが表示される
- 出力は `tmp/` 配下で gitignore 対象
- `-c` はプロンプト肥大化の原因になるため `-w` の使用を推奨
