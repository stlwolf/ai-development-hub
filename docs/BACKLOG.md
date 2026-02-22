# バックログ

Issue化するまでもないが忘れたくない検討・調査タスク。優先度が上がったら GitHub Issue に昇格する。

---

## 調査・キャッチアップ

- [ ] **サブエージェント/スキル機能のキャッチアップ + ルール分割検証**
  - Cursor: Task tool（サブエージェント）、スキル機能
  - Claude Code: `/task` によるサブタスク分割
  - Codex CLI: skills システム（`~/.codex/skills/`）
  - 目的: これらをイテレーションに組み込めるか検討。並行して集権的ルール（CONVENTIONS.md）のサブエージェント向け分割を検証
  - 検証プロジェクト: `projects/agent-rule-decomposition/`
  - 参照: `projects/second-opinion-verification/docs/episodes/2026-02-15-session-synthesis-codex-verification-to-autonomous-flow.md` セクション5
  - 参照: `ideas/20260221/document-format-design-principles.md`（ルール配布時の「何を渡すか」判断基準）

## Issue 化済み

- [x] 会話ログ保存の仕組み構築 → [#2](https://github.com/stlwolf/ai-development-hub/issues/2)
