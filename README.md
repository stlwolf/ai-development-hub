# AI Development Hub

AI駆動開発のための統合リポジトリ。複数AIツール（Cursor / Claude Code / Codex）向けのルール・スキル・エージェント・コマンド・フックと、各ツール連携プロジェクトを集約管理します。主に Bash スクリプトと Markdown で構成されています。

## リポジトリ構成

```
ai-development-hub/
├── AGENTS.md               # 全ツール共通のリポジトリ契約（最小ルール）
├── CLAUDE.md               # Claude Code 向けの詳細ガイド（コマンド・アーキテクチャ）
├── canonical/              # ツール非依存の正本 + ツール固有拡張
│   ├── CATALOG.md          # skills / commands / agents / rules / hooks の一覧・依存
│   ├── rules/              # ユーザー共通ルール（行動規範・入力・出力等）
│   ├── skills/             # スキル定義（各ディレクトリに SKILL.md）
│   ├── agents/             # エージェント定義
│   ├── commands/           # コマンド（review/, investigation/, verification/）
│   ├── hooks/              # フック定義（ツール別設定 + 共通スクリプト → sync で配布）
│   ├── mcp/                # MCP設定（cursor.json → ~/.cursor/mcp.json にリンク）
│   ├── cursor/             # Cursor 固有（コマンド定義等）
│   └── codex/              # Codex 固有（AGENTS.md, commands-registry, agents 等）
├── docs/                   # ドキュメント
│   ├── draft/              # ドラフト・作成中のドキュメント
│   ├── knowledge/          # ナレッジ（セットアップガイド等）
│   ├── decisions/          # 意思決定記録（Decision）
│   ├── plans/              # Issue 連携キックオフ・プラン類
│   ├── research/           # 調査メモ・OSSセッション・ハーネス調査等
│   ├── specs/              # 仕様・ドキュメントフォーマット（例: document-format）
│   └── BACKLOG.md          # 軽量バックログ（Issue化前の検討事項）
├── ideas/                  # アイデア（YYYYMMDD/、凍結スナップショット）
├── projects/               # 独立したツールキット（_archived/ にアーカイブ含む）
└── scripts/                # ユーティリティ
    ├── sync.sh             # 統合 sync ランナー（cursor / claude / codex / bin）
    ├── sync/               # 各ツール向け同期スクリプト
    ├── check-codex-guardrails.sh  # Codex ガードレール整合チェック
    ├── so-compare.sh       # セカンドオピニオン用（~/bin へ sync-bin で配置）
    └── arena-compare.sh    # arena-compare へのラッパー（同上）
```

## 各ディレクトリの役割

### `canonical/`
ツール非依存の共通リソース（`rules/`, `skills/`, `agents/`, `commands/`）と、フック（`hooks/`）、MCP・Cursor・Codex 向け拡張を集約管理。全リソースの索引は [`canonical/CATALOG.md`](canonical/CATALOG.md)。

### `docs/`
開発フロー、調査、仕様、意思決定のドキュメント。

- **`draft/`**: 作成中・検証中のドキュメント
- **`knowledge/`**: セットアップ等のナレッジ
- **`decisions/`**: 採用・方針の Decision 記録
- **`plans/`**: Issue 連携のキックオフ・プラン
- **`research/`**: 調査メモ、OSS セッション、テーマ別調査（例: harness-engineering）
- **`specs/`**: ドキュメント形式などの仕様定義
- **`BACKLOG.md`**: Issue化するまでもない検討・調査タスクの管理

### `ideas/`
アイデア、ブレスト、素案の保管場所。日付ディレクトリ（`YYYYMMDD/`）ごとに整理。追加後は凍結（frozen snapshot）。
詳細は [ideas/README.md](ideas/README.md) を参照。

### `projects/`
独立したツールキット（検証フロー、CLI ラッパー、拡張、調査プロジェクト等）。アーカイブは `projects/_archived/`。
詳細は [projects/README.md](projects/README.md) を参照。

### `scripts/`
`sync.sh` による一括同期、`sync/` 配下のツール別同期、その他検証・ラッパースクリプト。
詳細は [scripts/README.md](scripts/README.md) を参照。

## 使い方

### 設定の同期（推奨）

`canonical/` の共通リソースを各AIツールの設定ディレクトリにシンボリックリンクとして配置できます。

```bash
./scripts/sync.sh                    # 全ターゲット（cursor, claude, codex, bin）
./scripts/sync.sh cursor             # Cursor のみ
./scripts/sync.sh claude codex       # 複数指定可
./scripts/sync.sh --list             # 利用可能ターゲット一覧
```

`bin` は CLI スクリプトを `~/bin/` に配置します。対象は `so-compare` / `arena-compare` / `wez` / `wt-pane-issue` / `oe-tree` / `oe-hookfire` / `validate-knowledge` / `knowledge-list` の8件で、リンク名と実体の対応は `scripts/sync/sync-bin.sh` の配列が正本です。

- シンボリックリンクなので、どちら側から編集しても同じファイルが変更される
- リポジトリ側でバージョン管理が可能

### ルールの適用

1. **プロジェクトルール**: 作業対象リポジトリの `.cursor/rules/` にプロジェクト用 `.mdc` を配置
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
