# Cursor

Cursor AI エディタ向けのコマンド、ルール集。

## ディレクトリ構成

```
cursor/
├── agents/               # サブエージェント定義 (.md, YAML frontmatter)
├── command/              # 実行可能なコマンドテンプレート
│   ├── review/           # PRレビュー関連
│   └── verification/     # マルチエージェント検証
├── knowledge/            # 知識ベース（セットアップガイド等）
├── mcp.json              # MCP サーバー設定
├── project-rules/        # プロジェクト固有ルール (.mdc, alwaysApply)
├── skill/                # スキル定義（命名規則、コミット規約等）
└── user-rules/           # ユーザー共通ルール (.md)
```

## コマンド

| コマンド | 配置先 | 責務 |
|---|---|---|
| `/peer-ai-review` | `verification/` | Codex/Claude にピアレビュー依頼（3者合意ループ） |
| `/arena-perspectives` | `verification/` | 複数モデルへの並列投入と回答比較 |
| `/pr-review` | `review/` | GitHub PR のレビュー（gh CLI） |
| `/copilot-review-response` | `review/` | Copilot レビューへの対応 |

`~/.cursor/commands/` に直接配置されたコマンド（`/sentry-cli`, `/gh-cli` 等）はこのリポジトリには含まれない。

## サブエージェント

| エージェント | 用途 |
|---|---|
| `oss-researcher` | OSS・ライブラリの深層調査。設計思想、機能発見、エコシステム調査、横断比較 |
| `vendor-inspector` | 依存コードの深掘り。vendor/node_modules内の関数読解、アップデート影響分析、デバッグ |

## デプロイ

```bash
# cursor/command/ 配下を ~/.cursor/commands/ にシンボリックリンク
./scripts/sync/sync-cursor-commands.sh

# cursor/agents/ 配下を ~/.cursor/agents/ にシンボリックリンク
./scripts/sync/sync-cursor-agents.sh

# cursor/skill/ 配下を ~/.cursor/skills/ にシンボリックリンク
./scripts/sync/sync-cursor-skills.sh

# cursor/mcp.json を ~/.cursor/mcp.json にシンボリックリンク
./scripts/sync/sync-cursor-mcp.sh

# cursor/user-rules/*.md を ~/.claude/rules/ にシンボリックリンク（Claude Code 向け）
./scripts/sync/sync-claude-rules.sh
```

## ルール

- **`project-rules/`**: `.mdc` 形式。プロジェクトの `.cursor/rules/` にコピーして使用
- **`user-rules/`**: `.md` 形式。Cursor の User Rules および Claude Code のユーザールール（`~/.claude/rules/`）として使用
