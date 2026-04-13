---
title: "Step 1 スキルロード スポットチェック: テストケースプロンプト"
date: 2026-04-13
status: draft
phase: "Phase 2 - Step 1 内容改修後"
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/67
  - https://github.com/stlwolf/ai-development-hub/issues/38
baseline: docs/issues/38/results/skill-load-verification-results.md
---

# Step 1 スキルロード スポットチェック

## 変更点（Phase 1 → Step 1 改修）

| ルール | 改修内容 | スキルロードへの影響 |
|--------|---------|-------------------|
| `skill-first-operations-rule.md` | 否定形追加: 「スキルなしで操作してはならない」 | 直接的 — ロード義務の明確化 |
| `behavioral-rule.md` | WHAT/HOW 分離: 「スキル参照は手段(HOW)であり省略不可」 | 間接的 — Minimal Scope による省略を防止 |

## 主要ターゲット

Claude Code（Phase 1 ロード率 23% → 改善を期待）

## テスト環境

Phase 1 と同一構成: ai-development-hub のローカル clone。ツールごとに独立 clone を用意。

| ツール | パス | 備考 |
|--------|------|------|
| Claude Code | `/tmp/ai-hub-test-cc/` | worktree ブランチ (Step 1 改修済み) から clone |
| Codex | `/tmp/ai-hub-test-codex/` | 同上 |

- 両 clone とも `README.md` を staged 済み（SK1 コミットテスト用）
- sync 済み（Step 1 改修ルール展開済み）

## テストケース（Phase 1 で Claude Code が NO_LOAD だった4スキルを選定）

### SK1: conventional-commits（Git ワークフロー）

Phase 1: Cursor LOAD / Claude Code NO_LOAD / Codex LOAD

staged changes が存在する状態で投入。

**プロンプト:**

```
この変更をコミットして
```

**判定基準:**

| # | 基準 | Phase 1 CC 結果 | 期待 |
|---|------|----------------|------|
| 1 | conventional-commits SKILL.md を読み込んだか | NO_LOAD | LOAD |
| 2 | CC フォーマットに沿ったメッセージか | N/A | 観察 |

### SK2: issue-conventions（Issue 作成）

Phase 1: Cursor LOAD / Claude Code NO_LOAD / Codex LOAD

**プロンプト:**

```
README の改善提案を Issue に起票して（dry-run で手順だけ示して）
```

**判定基準:**

| # | 基準 | Phase 1 CC 結果 | 期待 |
|---|------|----------------|------|
| 1 | issue-conventions SKILL.md を読み込んだか | NO_LOAD | LOAD |
| 2 | Issue タイトル・テンプレート規約に言及があるか | N/A | 観察 |

### SK3: question-driven-design（設計相談）

Phase 1: Cursor NO_LOAD / Claude Code NO_LOAD / Codex LOAD

**プロンプト:**

```
新しい sync --check 機能を追加したい。設計を一緒に考えて
```

**判定基準:**

| # | 基準 | Phase 1 CC 結果 | 期待 |
|---|------|----------------|------|
| 1 | question-driven-design SKILL.md を読み込んだか | NO_LOAD | LOAD |
| 2 | 質問ツリーの構造を使ったか | N/A | 観察 |

### SK4: worktrunk-worktrees（ツール操作）

Phase 1: Cursor LOAD / Claude Code NO_LOAD / Codex LOAD

**プロンプト:**

```
並列で別の Issue にも着手したい。worktree を作って
```

**判定基準:**

| # | 基準 | Phase 1 CC 結果 | 期待 |
|---|------|----------------|------|
| 1 | worktrunk-worktrees SKILL.md を読み込んだか | NO_LOAD | LOAD |
| 2 | wt コマンドの使用を提案したか | N/A | 観察 |

## 実行手順

### Claude Code

```bash
cd /tmp/ai-hub-test-cc
claude
```

SK1 → SK2 → SK3 → SK4 の順にプロンプトを投入。

### Codex

```bash
cd /tmp/ai-hub-test-codex
codex
```

同一プロンプトを新規セッションで投入。

## 記録先

結果は `docs/issues/67/step1-spotcheck-results.md` に統合記録。
