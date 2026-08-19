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

## 情報収集（intake）ストリーム

進行状態・未処理の在庫・Feedly の再取得手順は [`docs/research/2026-08-20-intake-handoff.md`](research/2026-08-20-intake-handoff.md) に集約している。会話スレッドを参照できなくなっても、そこから再開できる。

- [ ] **束 B の 4 件をノート化するか判断する** — 読了済み・要点は継続資料に記録済み。Goodpatch の 2 点（ループ 4 分類、`AGENTS.md` の肥大化対策）は [#307](https://github.com/stlwolf/ai-development-hub/issues/307) に効く
- [ ] **6 月保存の未読 5 件を処理するか判断する** — うち alibaba/open-code-review は `oss-research-session` の案件として起票する候補
- [ ] **2026 年 1〜5 月の未取り込み分（約 66 件）を層で切って一括処理する** — 1 件ずつ精査する方法はコストが高いと分かっている
- [ ] **Feedly の developer token を更新する（2026-08-27 失効）** — refresh token で更新が回るかは未検証

## Issue 化済み

- [x] 会話ログ保存の仕組み構築 → [#2](https://github.com/stlwolf/ai-development-hub/issues/2)
