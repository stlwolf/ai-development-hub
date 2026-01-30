# AI Development Hub

AI駆動開発のための統合リポジトリ。再利用可能なプロンプト、ルール、ドキュメント、アイデアを集約管理します。

## 📁 リポジトリ構成

```
ai-development-hub/
├── cursor/                 # Cursor AI エディタ関連
│   ├── command/            # 実行可能なコマンド集
│   │   └── review/         # PRレビュー関連コマンド
│   ├── project-rules/      # プロジェクト固有のルール (.mdc)
│   └── user-rules/         # ユーザー共通ルール (.md)
├── docs/                   # ドキュメント
│   ├── draft/              # ドラフト・作成中のドキュメント
│   └── project-rules/      # プロジェクトルール（ドキュメント版）
├── ideas/                  # アイデア・ブレストメモ
└── scripts/                # ユーティリティスクリプト
```

## 🎯 各ディレクトリの役割

### `cursor/`
Cursor AIエディタで使用するルールとコマンド集

- **`command/`**: 実行可能なコマンドテンプレート
  - `review/pr-review.md`: GitHub PR レビューフロー
  - `review/copilot-review-response.md`: レビュー対応フロー

- **`project-rules/`**: プロジェクト全体に適用されるルール（`.mdc`形式）
  - `behavioral-execution-output-rule.mdc`: 行動・実行・出力形式の基本ルール

- **`user-rules/`**: ユーザーレベルで適用される共通ルール
  - `behavioral-execution-output-rule.md`: 行動規範
  - `input-style-rule.md`: 入力スタイル規約
  - `markdown-rule.md`: Markdown記法ルール

### `docs/`
開発フローやベストプラクティスのドキュメント

- **`draft/`**: 作成中・検証中のドキュメント
  - `AI_DRIVEN_DEVELOPMENT.md`: AI駆動開発フローの実践ガイド

### `ideas/`
アイデア、ブレスト、素案の保管場所。日付ディレクトリ（YYYYMMDD）ごとに整理。
詳細は [ideas/README.md](ideas/README.md) を参照。

## 🚀 使い方

### Cursor コマンドの同期（推奨）

`cursor/command/` 配下のコマンドを `~/.cursor/commands/` にシンボリックリンクとして配置できます。

```bash
# 初回セットアップ
./scripts/sync-cursor-commands.sh

# リポジトリにコマンドを追加した後も同じコマンドを実行
./scripts/sync-cursor-commands.sh
```

**メリット**:
- シンボリックリンクなので、どちら側から編集しても同じファイルが変更される
- リポジトリ側でバージョン管理が可能
- プロジェクト固有のコマンドは `~/.cursor/commands/` に直接配置可能（スクリプトはスキップ）

### Cursor AI ルールの適用

1. **プロジェクトルール**: `cursor/project-rules/*.mdc` をプロジェクトの `.cursor/rules/` にコピー
2. **ユーザールール**: `cursor/user-rules/*.md` を参照し、Cursor の User Rules に設定

### コマンドの実行（手動の場合）

`cursor/command/` 配下のマークダウンファイルを参照し、記載されたフローに従って実行

例：PRレビュー
```bash
# cursor/command/review/pr-review.md を参照
gh pr view <PR番号>
gh pr diff <PR番号>
```

## 📝 コンテンツ追加ガイドライン

- **新しいルール**: 用途に応じて `cursor/project-rules/` または `cursor/user-rules/` に追加
- **コマンド**: `cursor/command/` 配下に機能別ディレクトリを作成
- **ドキュメント**: `docs/draft/` で作成し、成熟したら適切な場所に移動
- **アイデア**: `ideas/` に自由形式で追加

## 🔗 関連リソース

- [Cursor Documentation](https://docs.cursor.com/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [GitHub CLI](https://cli.github.com/)

## 📄 ライセンス

このリポジトリは個人・チーム内での利用を想定しています。
