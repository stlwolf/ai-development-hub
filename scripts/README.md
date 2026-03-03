# Scripts

リポジトリ運用のユーティリティスクリプト。

## ディレクトリ構成

```
scripts/
├── arena-compare.sh   -> ../projects/arena-compare/arena-compare.sh
├── so-compare.sh
└── sync/
    ├── sync-cursor-agents.sh
    ├── sync-cursor-commands.sh
    ├── sync-cursor-mcp.sh
    └── sync-cursor-skills.sh
```

## sync/

Cursor 設定ファイルをホームディレクトリにシンボリックリンクとして配置するスクリプト群。

| スクリプト | ソース | 配置先 |
|---|---|---|
| `sync-cursor-commands.sh` | `cursor/command/**/*.md` | `~/.cursor/commands/` |
| `sync-cursor-agents.sh` | `cursor/agents/*.md` | `~/.cursor/agents/` |
| `sync-cursor-skills.sh` | `cursor/skill/*/` | `~/.cursor/skills/` |
| `sync-cursor-mcp.sh` | `cursor/mcp.json` | `~/.cursor/mcp.json` |

```bash
./scripts/sync/sync-cursor-commands.sh
./scripts/sync/sync-cursor-agents.sh
./scripts/sync/sync-cursor-skills.sh
./scripts/sync/sync-cursor-mcp.sh
```

## ユーティリティ

### `so-compare.sh`

セカンドオピニオン比較実行スクリプト。同一プロンプトを Codex CLI / Claude Code に投げて結果をファイルに保存する。

```bash
# 推奨: -w でワークスペースパスを渡す
so-compare.sh -w "$(pwd)" "プロンプトテキスト"

# プロンプトファイルから
so-compare.sh -f prompt.txt -w "$(pwd)"

# イテレーション（前回の回答を踏まえて再質問）
so-compare.sh --prev tmp/so-YYYYMMDD-HHMMSS -w "$(pwd)" "再評価してください"

# Codex のみ / Claude のみ
so-compare.sh -w "$(pwd)" "プロンプト" --codex-only
so-compare.sh -w "$(pwd)" "プロンプト" --claude-only
```

主要オプション:

| オプション | 説明 |
|-----------|------|
| `-w PATH` | ワークスペースパス（推奨。codex に `-C`、claude に `--add-dir` として渡される） |
| `-c FILE...` | コンテキストファイル添付（非推奨。プロンプト肥大化の原因） |
| `-f FILE` | プロンプトをファイルから読み込み |
| `-o DIR` | 出力ディレクトリ指定 |
| `--prev DIR` | 前回出力を追記（イテレーション用） |

環境変数: `SO_TIMEOUT`（デフォルト: 240秒）、`PREV_MAX_BYTES`（デフォルト: 4000）

関連スキル: `cursor/skill/so-compare/SKILL.md`

### `arena-compare.sh`

複数AIモデルへの並列投入と回答比較スクリプト。`projects/arena-compare/arena-compare.sh` へのシンボリックリンク。

詳細は [projects/arena-compare/README.md](../projects/arena-compare/README.md) を参照。
