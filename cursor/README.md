# Cursor

Cursor AI エディタ向けのコマンド、ルール集。

## ディレクトリ構成

```
cursor/
├── agents/               # サブエージェント定義 (.md, YAML frontmatter)
├── command/              # 実行可能なコマンドテンプレート
│   ├── review/           # PRレビュー関連
│   └── verification/     # マルチエージェント検証
├── project-rules/        # プロジェクト固有ルール (.mdc, alwaysApply)
└── user-rules/           # ユーザー共通ルール (.md)
```

## コマンド

| コマンド | 配置先 | 責務 |
|---|---|---|
| `/peer-ai-review` | `verification/` | Codex/Claude にピアレビュー依頼（3者合意ループ） |
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
./scripts/sync-cursor-commands.sh

# cursor/agents/ 配下を ~/.cursor/agents/ にシンボリックリンク
./scripts/sync-cursor-agents.sh
```

## ルール

- **`project-rules/`**: `.mdc` 形式。プロジェクトの `.cursor/rules/` にコピーして使用
- **`user-rules/`**: `.md` 形式。Cursor の User Rules に設定して使用
