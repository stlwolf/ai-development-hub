# AI Development Hub

AI駆動開発のための統合リポジトリ。再利用可能なプロンプト、ルール、ドキュメント、アイデアを集約管理します。

## リポジトリ構成

```
ai-development-hub/
├── canonical/              # ツール非依存の正本 + ツール固有拡張
│   ├── rules/              # ユーザー共通ルール（行動規範・入力・出力等）
│   ├── skills/             # スキル定義（各ディレクトリに SKILL.md）
│   ├── agents/             # エージェント定義
│   ├── commands/           # コマンド（review/, investigation/, verification/）
│   ├── mcp/                # MCP設定（cursor.json 等）
│   ├── cursor/             # Cursor 固有ファイル（archive-title 等）
│   └── codex/              # Codex 固有ファイル（AGENTS.md, commands-registry 等）
├── docs/                   # ドキュメント
│   ├── draft/              # ドラフト・作成中のドキュメント
│   ├── knowledge/          # ナレッジドキュメント（セットアップガイド等）
│   └── BACKLOG.md          # 軽量バックログ（Issue化前の検討事項）
├── ideas/                  # アイデア・ブレストメモ
├── projects/               # 独立したプロジェクト・ツールキット
└── scripts/                # ユーティリティスクリプト
    └── sync/               # 各ツール設定の同期スクリプト
```

## 各ディレクトリの役割

### `canonical/`
ツール非依存の共通リソース（rules, skills, agents, commands）と、ツール固有の拡張レイヤー（cursor/, codex/, mcp/）を集約管理。

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

### 設定の同期（推奨）

`canonical/` の共通リソースを各AIツールの設定ディレクトリにシンボリックリンクとして配置できます。

```bash
./scripts/sync.sh              # 全ツール一括（Cursor, Claude Code, Codex, bin）
./scripts/sync.sh cursor       # Cursor のみ
./scripts/sync.sh claude       # Claude Code のみ
./scripts/sync.sh --list       # 利用可能ターゲット一覧
```

- シンボリックリンクなので、どちら側から編集しても同じファイルが変更される
- リポジトリ側でバージョン管理が可能

### ルールの適用

1. **プロジェクトルール**: `cursor/project-rules/*.mdc` をプロジェクトの `.cursor/rules/` にコピー
2. **共通ルール**: `canonical/rules/*.md` を各ツールのルール設定として使用
   - **Claude Code**: `./scripts/sync.sh claude` で `~/.claude/rules/` にシンボリックリンクを自動配置
   - **Cursor**: User Rules として手動で登録（`sync-cursor.sh` は rules を配置しない）
   - **Codex**: 現時点では rules 未対応（設定体系の拡張待ち、`sync-codex.sh` は skills のみ配置）

## タスク管理

| 粒度 | 置き場 |
|---|---|
| 明確なスコープのタスク | [GitHub Issues](https://github.com/stlwolf/ai-development-hub/issues) |
| 忘れたくない検討事項 | [`docs/BACKLOG.md`](docs/BACKLOG.md) |
| 概念・構想の凍結スナップショット | `ideas/YYYYMMDD/` |

## コンテンツ追加ガイドライン

- **新しいルール**: 共通ルールは `canonical/rules/` に追加。Cursor 固有ルールは各プロジェクトの `.cursor/rules/` に配置
- **コマンド**: `canonical/commands/` 配下に機能別ディレクトリを作成
- **ドキュメント**: `docs/draft/` で作成し、成熟したら適切な場所に移動
- **アイデア**: `ideas/YYYYMMDD/` に凍結スナップショットとして追加

## 関連リソース

- [Cursor Documentation](https://docs.cursor.com/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [GitHub CLI](https://cli.github.com/)

## ライセンス

このリポジトリは個人・チーム内での利用を想定しています。
