# wezterm-ai-mode

WezTerm の **Human Mode（tmux 維持）** と **AI Mode（`wezterm cli` 上乗せ）** を両立する `wez` CLI ツールキット。技術検証は [`projects/poc/wezterm-ai-mode/`](../poc/wezterm-ai-mode/) に凍結されたまま残す。

## ステータス

**Phase 1 実装中** — `wez discover` が動作する状態。[Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20) で `pane`・`notify` 等を追加予定。

## クイックスタート

```bash
# ソケット自動検出 + 接続確認
./projects/wezterm-ai-mode/bin/wez discover

# JSON 出力（スクリプト連携用）
./projects/wezterm-ai-mode/bin/wez discover --json

# 他スクリプトからソケットパスを取得
WEZTERM_UNIX_SOCKET=$(./projects/wezterm-ai-mode/bin/wez discover --quiet)
```

## CLI リファレンス

### `wez discover`

WezTerm の UNIX ソケットを自動検出し、`wezterm cli list` で接続を確認する。

```
Usage: wez discover [options]

Options:
  --json           JSON 出力（stderr 抑制）
  --quiet          stderr のステータスメッセージを抑制
  --verbose        --json 使用時にも stderr を有効化
  --socket <path>  ソケットパスを明示指定（自動検出をスキップ）
```

**ソケット解決の優先順位**:

1. `--socket <path>` フラグ
2. `WEZTERM_UNIX_SOCKET` 環境変数
3. `~/.local/share/wezterm/gui-sock-*` からの自動検出

明示指定（1, 2）が失敗した場合はフォールバックせず即エラー。自動検出（3）では複数ソケットがある場合に mtime 降順 + 接続確認のハイブリッド方式で最適なものを選択する。

**Exit codes**:

| コード | 意味 |
|--------|------|
| 0 | 成功 |
| 1 | ソケット未検出 |
| 2 | 接続失敗 |
| 64 | 使用法エラー（不正なオプション、引数不足） |
| 127 | wezterm 未インストール |

**JSON 出力スキーマ** (`--json`):

```json
{
  "socket": "/Users/you/.local/share/wezterm/gui-sock-12345",
  "pane_count": 3
}
```

### `wez help`

サブコマンド一覧を表示。

### `wez version` / `wez --version`

バージョン情報を表示。

## ファイル構成

```
projects/wezterm-ai-mode/
├── bin/wez              # エントリポイント（subcommand dispatcher）
├── lib/
│   ├── common.sh        # 共通: カラー、ログ関数、exit code 定数
│   └── discover.sh      # wez discover の実装
├── docs/
│   ├── VERIFICATION_MATRIX.md
│   ├── decisions/       # ADR（設計判断記録）
│   ├── episodes/        # 作業記録
│   └── plans/           # キックオフ・実装プラン
├── CONVENTIONS.md        # ドキュメント規約
└── README.md             # ← このファイル
```

## 前提条件

- **Bash** 3.2+
- **wezterm** CLI（`brew install --cask wezterm`）
- **jq**（推奨。不在時は `grep -c` フォールバックで動作）

## 開発方式（検証ケース）

[cursor-thread-tools](../cursor-thread-tools/) と同型の **Stage 1（Agent: プラン + peer-ai-review）→ Stage 2（Plan mode: 実装）→ Stage 3（記録）** を本リポジトリで2例目として検証する。手順の正本は [CONVENTIONS.md](CONVENTIONS.md)。

## ドキュメント

- [CONVENTIONS.md](CONVENTIONS.md) — 命名・frontmatter・plan/episode 分離・gate
- [docs/plans/](docs/plans/) — キックオフ・実装プラン
- [docs/VERIFICATION_MATRIX.md](docs/VERIFICATION_MATRIX.md) — A: ツール / B: プロセス
- [docs/decisions/](docs/decisions/) — ADR（設計判断記録）
- [docs/episodes/](docs/episodes/) — 実装エピソード
- [docs/raw-logs/README.md](docs/raw-logs/README.md) — 層3の一時ログ置き場

## sync-bin.sh 統合（未実施）

`bin/wez` を [scripts/sync/sync-bin.sh](../../scripts/sync/sync-bin.sh) 経由で `~/bin/` にシンボリックリンクし、パスなしで `wez discover` を実行可能にする予定（Phase 1 ステップ 1-5）。
