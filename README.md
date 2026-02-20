# AI Development Hub

AI駆動開発のための統合リポジトリ。Cursor AI向けルール・コマンド、マルチエージェント検証フレームワーク、アイデアメモを集約管理。

## リポジトリ構成

```
ai-development-hub/
├── cursor/                 # Cursor AI エディタ関連
│   ├── command/
│   │   ├── review/         # PRレビュー・Copilotレビュー対応
│   │   └── verification/   # マルチエージェント検証コマンド
│   ├── project-rules/      # プロジェクト固有ルール (.mdc)
│   └── user-rules/         # ユーザー共通ルール
├── docs/
│   ├── draft/              # ドラフトドキュメント
│   └── BACKLOG.md          # 軽量バックログ
├── ideas/                  # アイデア（YYYYMMDD形式、凍結スナップショット）
├── projects/
│   ├── agent-verification-flow/   # マルチエージェント検証フレームワーク（メイン）
│   ├── claude-safe/               # Claude CLI ラッパー
│   └── second-opinion-verification/  # セカンドオピニオン検証（完了・アーカイブ）
└── scripts/                # ユーティリティスクリプト
```

## 主要コンポーネント

### Cursor コマンド（`cursor/command/`）

| コマンド | 責務 |
|---|---|
| `/peer-ai-review` | Codex/Claude にピアレビュー依頼。3者合意ループ + レビューログ |
| `/pr-review` | GitHub PR のレビュー（gh CLI） |
| `/copilot-review-response` | Copilot レビューへの対応 |
| `/sentry-cli` | Sentry エラーの取得・分析・修正（※ `~/.cursor/commands/` に直接配置） |

### マルチエージェント検証（`projects/agent-verification-flow/`）

AI駆動のAPI検証・マルチエージェント協調のフレームワーク。

- **スクリプト**: JWT/Session認証、API呼び出し、Sentry連携
- **テンプレート**: 検証レポート、検証ケース、facts.md（事実/解釈分離）
- **設計パターン**: ロール設計（案A: 並行比較、案B: 逐次専門化）、計画/実行分離
- **エピソード**: 実践から得た知見の記録

確立済みの知見:
- SO（セカンドオピニオン）の効果分析と限界（ハルシネーションリスク含む）
- GitHub Issue を「契約書」とした計画/実行分離パターン
- 3者合意ループによるレビュー品質の標準化

### ツール（`scripts/`）

| スクリプト | 内容 |
|---|---|
| `so-compare.sh` | Claude Code / Codex CLI を並行実行し結果をファイルに保存 |
| `sync-cursor-commands.sh` | `cursor/command/` を `~/.cursor/commands/` にシンボリックリンク配置 |

### アイデア（`ideas/`）

日付ディレクトリ（`YYYYMMDD/`）で管理。追加後は凍結（frozen snapshot）。成功したアイデアは `projects/` に昇格。

### タスク管理

| 粒度 | 置き場 |
|---|---|
| 明確なスコープのタスク | GitHub Issue |
| 忘れたくない検討事項 | [`docs/BACKLOG.md`](docs/BACKLOG.md) |
| 概念・構想の凍結スナップショット | `ideas/YYYYMMDD/` |

## セットアップ

### Cursor コマンドの同期

```bash
./scripts/sync-cursor-commands.sh
```

`cursor/command/` 配下のコマンドを `~/.cursor/commands/` にシンボリックリンクとして配置。

### Cursor AI ルールの適用

1. **プロジェクトルール**: `cursor/project-rules/*.mdc` をプロジェクトの `.cursor/rules/` にコピー
2. **ユーザールール**: `cursor/user-rules/*.md` を参照し、Cursor の User Rules に設定

## 関連リソース

- [Cursor Documentation](https://docs.cursor.com/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [GitHub CLI](https://cli.github.com/)
