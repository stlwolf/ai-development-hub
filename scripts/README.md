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
so-compare.sh "プロンプトテキスト"
so-compare.sh -f prompt.txt
echo "プロンプト" | so-compare.sh -
```

### `arena-compare.sh`

複数AIモデルへの並列投入と回答比較スクリプト。`projects/arena-compare/arena-compare.sh` へのシンボリックリンク。

詳細は [projects/arena-compare/README.md](../projects/arena-compare/README.md) を参照。
