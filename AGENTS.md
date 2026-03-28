# Repository Agent Contract

このファイルは、リポジトリ全体で共通に守る最小運用ルールを定義する。
詳細な手順・長い説明は各正本ドキュメントを参照し、このファイルには展開しない。

## Source of Truth

- リポジトリ構成・運用概要: `README.md`
- sync 実行方法: `scripts/README.md`
- ツール非依存の正本: `canonical/`（`rules/`, `skills/`, `agents/`, `commands/`）
- Codex専用ガードレール: `canonical/codex/AGENTS.md`

## Scope and Ownership

- `canonical/agents/` はサブエージェント役割定義のみを保持する。
- ツール固有ポリシーは各ツール用パスで管理し、ルートに混在させない。
- `~/.codex/agents/*.toml` は生成物として扱い、手動編集しない。
- `~/.codex/agents/*.toml` の変更は `canonical/agents/` と `scripts/sync/sync-codex.sh` で行う。

## Operating Rules

- 依頼範囲外の変更をしない。
- 既存差分がある場合は、タスク関連ファイルのみをステージ・コミットする。
- Bash/Markdown の既存規約（命名・記法・構成）を踏襲する。
- スクリプト変更時は、対象スクリプトの実行確認と `shellcheck` を優先する。

## Contribution Baseline

- コミットは Conventional Commits（`feat:`, `fix:`, `docs:`, `chore:`）を使用。
- 1コミット1論理変更を原則とする。
- PRには目的、影響範囲、実行した検証コマンドを明記する。
