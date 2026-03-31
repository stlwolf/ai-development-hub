# wezterm-ai-mode

WezTerm の **Human Mode（tmux 維持）** と **AI Mode（`wezterm cli` 上乗せ）** を両立する `wez` CLI ツールキット。技術検証は [`projects/poc/wezterm-ai-mode/`](../poc/wezterm-ai-mode/) に凍結されたまま残す。

## ステータス

**準備スケルトン** — ディレクトリ・ドキュメント規約・検証マトリクス骨格のみ。`wez` 実装は [Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 1 で進める。

## 開発方式（検証ケース）

[cursor-thread-tools](../cursor-thread-tools/) と同型の **Stage 1（Agent: プラン + peer-ai-review）→ Stage 2（Plan mode: 実装）→ Stage 3（記録）** を本リポジトリで2例目として検証する。手順の正本は [CONVENTIONS.md](CONVENTIONS.md)。

## ドキュメント

- [CONVENTIONS.md](CONVENTIONS.md) — 命名・frontmatter・plan/episode 分離・gate
- [docs/VERIFICATION_MATRIX.md](docs/VERIFICATION_MATRIX.md) — A: ツール / B: プロセス
- [docs/raw-logs/README.md](docs/raw-logs/README.md) — 層3の一時ログ置き場

## 今後の配置（予定）

- `bin/wez`（または `bin/` + ライブラリスクリプト）を本ディレクトリ配下に置き、[scripts/sync/sync-bin.sh](../../scripts/sync/sync-bin.sh) 経由で `~/bin/` に同期する想定（未実施）。
