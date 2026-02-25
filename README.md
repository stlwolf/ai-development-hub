# AI Development Hub

AI駆動開発のための統合リポジトリ。再利用可能なプロンプト、ルール、ドキュメント、アイデアを集約管理します。

## リポジトリ構成

```
ai-development-hub/
├── cursor/                 # Cursor AI エディタ関連
│   ├── agents/             # サブエージェント定義
│   ├── command/            # 実行可能なコマンド集
│   │   ├── review/         # PRレビュー関連コマンド
│   │   └── verification/   # マルチエージェント検証コマンド
│   ├── knowledge/          # ナレッジドキュメント
│   ├── mcp.json            # MCP設定（~/.cursor/mcp.json にリンク）
│   ├── project-rules/      # プロジェクト固有のルール (.mdc)
│   ├── skill/              # スキル定義（~/.cursor/skills/ にリンク）
│   └── user-rules/         # ユーザー共通ルール (.md)
├── docs/                   # ドキュメント
│   ├── draft/              # ドラフト・作成中のドキュメント
│   └── BACKLOG.md          # 軽量バックログ（Issue化前の検討事項）
├── ideas/                  # アイデア・ブレストメモ
├── projects/               # 独立したプロジェクト・ツールキット
└── scripts/                # ユーティリティスクリプト
    └── sync/               # Cursor設定の同期スクリプト
```

## 各ディレクトリの役割

### `cursor/`
Cursor AIエディタで使用するルールとコマンド集。
詳細は [cursor/README.md](cursor/README.md) を参照。

### `docs/`
開発フローやベストプラクティスのドキュメント。

- **`draft/`**: 作成中・検証中のドキュメント
- **`BACKLOG.md`**: Issue化するまでもない検討・調査タスクの管理

### `ideas/`
アイデア、ブレスト、素案の保管場所。日付ディレクトリ（`YYYYMMDD/`）ごとに整理。追加後は凍結（frozen snapshot）。
詳細は [ideas/README.md](ideas/README.md) を参照。

### `projects/`
独立した研究開発成果物・ツールキット。
詳細は [projects/README.md](projects/README.md) を参照。

### `scripts/`
リポジトリ運用のユーティリティスクリプト。
詳細は [scripts/README.md](scripts/README.md) を参照。

## 使い方

### Cursor 設定の同期（推奨）

`cursor/` 配下の設定を `~/.cursor/` にシンボリックリンクとして配置できます。

```bash
./scripts/sync/sync-cursor-commands.sh  # コマンド → ~/.cursor/commands/
./scripts/sync/sync-cursor-agents.sh    # エージェント → ~/.cursor/agents/
./scripts/sync/sync-cursor-skills.sh    # スキル → ~/.cursor/skills/
./scripts/sync/sync-cursor-mcp.sh       # MCP設定 → ~/.cursor/mcp.json
```

- シンボリックリンクなので、どちら側から編集しても同じファイルが変更される
- リポジトリ側でバージョン管理が可能

### Cursor AI ルールの適用

1. **プロジェクトルール**: `cursor/project-rules/*.mdc` をプロジェクトの `.cursor/rules/` にコピー
2. **ユーザールール**: `cursor/user-rules/*.md` を参照し、Cursor の User Rules に設定

## タスク管理

| 粒度 | 置き場 |
|---|---|
| 明確なスコープのタスク | [GitHub Issues](https://github.com/stlwolf/ai-development-hub/issues) |
| 忘れたくない検討事項 | [`docs/BACKLOG.md`](docs/BACKLOG.md) |
| 概念・構想の凍結スナップショット | `ideas/YYYYMMDD/` |

## コンテンツ追加ガイドライン

- **新しいルール**: 用途に応じて `cursor/project-rules/` または `cursor/user-rules/` に追加
- **コマンド**: `cursor/command/` 配下に機能別ディレクトリを作成
- **ドキュメント**: `docs/draft/` で作成し、成熟したら適切な場所に移動
- **アイデア**: `ideas/YYYYMMDD/` に凍結スナップショットとして追加

## 関連リソース

- [Cursor Documentation](https://docs.cursor.com/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [GitHub CLI](https://cli.github.com/)

## ライセンス

このリポジトリは個人・チーム内での利用を想定しています。
