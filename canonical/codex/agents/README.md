# Codex Agent Definitions

このディレクトリはCodex向けsubagent定義の拡張レイヤー。

- 正本は`canonical/agents/*.md`
- 共通行動原則の正本は`canonical/codex/AGENTS.md`（この配下には書かない）
- `sync-codex.sh`実行時に`canonical/agents`から`~/.codex/agents/*.toml`を生成する
- このディレクトリには将来、Codex専用の上書き定義や補助ドキュメントを追加できる
