---
title: "Issue #64: スキル/コマンド ロード検証 — テスト実行手順書"
date: 2026-04-12
status: ready-to-execute
tags: [canonical, skills, commands, cross-agent, phase1, runbook]
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/64
---

# スキル/コマンド ロード検証 — テスト実行手順書

> この手順書を上から順に実行する。各ツールの検証は独立しており、順不同で実行可。

---

## 0. 事前準備（全ツール共通・実施済み）

```bash
# sync 実行
cd ~/work/repos/github.com/stlwolf/ai-development-hub
./scripts/sync.sh

# 配置確認（全て 19 であること）
ls ~/.cursor/skills/ | grep -v '.system' | wc -l
ls ~/.claude/skills/ | wc -l
ls ~/.codex/skills/ | grep -v '.system' | wc -l

# ローカル clone（作成済み）
# /tmp/ai-hub-test/
```

---

## 1. Cursor での検証

### 1-A. 暗黙起動テスト

**手順**: `/tmp/ai-hub-test/` を Cursor で開き、各グループごとに**新しいチャットセッション**を作成してプロンプトを投入する。1プロンプトにつき最低 2 回（別セッション or 同一セッションで2回目を再投入）。

**記録方法**: セッション完了後にスレッドエクスポートし、スキルの SKILL.md への Read が発生したかを確認。

#### Session Group A: Git ワークフロー系

> セッション開始前に clone 内でダミーファイルを変更しておく:
> ```bash
> cd /tmp/ai-hub-test && echo "test" >> README.md
> git add README.md
> ```

**A1 — branch-naming**

```
Issue #64 用のブランチを作って
```

- 期待スキル: `branch-naming`
- LOAD 判定: スレッドエクスポートに `branch-naming/SKILL.md` の Read が含まれる

**A2 — conventional-commits**

```
この変更をコミットして
```

- 期待スキル: `conventional-commits`
- LOAD 判定: スレッドエクスポートに `conventional-commits/SKILL.md` の Read が含まれる

**A3 — pr-conventions**

```
この変更の PR を作成して（dry-run で手順だけ示して、実際には作成しないで）
```

- 期待スキル: `pr-conventions`
- LOAD 判定: スレッドエクスポートに `pr-conventions/SKILL.md` の Read が含まれる

**A4 — branch-finish**

```
このブランチの作業は完了した。次のステップを提案して
```

- 期待スキル: `branch-finish`
- LOAD 判定: スレッドエクスポートに `branch-finish/SKILL.md` の Read が含まれる

#### Session Group B: Issue・ドキュメント系

**B1 — issue-conventions**

```
README の改善提案を Issue に起票して（dry-run で手順だけ示して、実際には作成しないで）
```

- 期待スキル: `issue-conventions`
- LOAD 判定: `issue-conventions/SKILL.md` の Read

**B2 — markdown-conventions**

```
README.md に「Contributing」セクションを追加して
```

- 期待スキル: `markdown-conventions`
- LOAD 判定: `markdown-conventions/SKILL.md` の Read

**B3 — spec-card**

```
この議論の結論を Decision ドキュメントとして記録して
```

- 期待スキル: `spec-card`
- LOAD 判定: `spec-card/SKILL.md` の Read

#### Session Group C: プラン・設計系

**C1 — kickoff-to-plan**

```
docs/plans/epic#38/2026-04-12-kickoff-phase1-core-canonical-diagnosis.md をプランに変換して
```

- 期待スキル: `kickoff-to-plan`
- LOAD 判定: `kickoff-to-plan/SKILL.md` の Read

**C2 — question-driven-design**

```
新しい sync --check 機能を追加したい。設計を一緒に考えて
```

- 期待スキル: `question-driven-design`
- LOAD 判定: `question-driven-design/SKILL.md` の Read

**C3 — adversarial-review**

```
docs/plans/epic#38/2026-04-12-kickoff-phase2-canonical-cross-agent-proposals.md のプランに問題がないかレビューして
```

- 期待スキル: `adversarial-review`
- LOAD 判定: `adversarial-review/SKILL.md` の Read

#### Session Group D: ツール・調査系

**D1 — worktrunk-worktrees**

```
並列で別の Issue にも着手したい。worktree を作って
```

- 期待スキル: `worktrunk-worktrees`
- LOAD 判定: `worktrunk-worktrees/SKILL.md` の Read

**D2 — implementer-contract**

```
canonical/codex/commands-registry/registry.md に不足しているコマンド2件（pr-review-checklist, research-intake）を追加する作業を、サブエージェントに委譲して実装させて
```

- 期待スキル: `implementer-contract`
- LOAD 判定: `implementer-contract/SKILL.md` の Read
- 文脈: 具体的な実装タスク（ファイル名・内容が明確）をサブエージェントに渡す場面

**D3 — persistent-exploration**

```
scripts/sync/sync-codex.sh で skills の symlink が作られるはずなのに、特定の環境で ~/.codex/skills/ が空になる問題を調査している。strace もログも確認したが原因が掴めない。他に試せるアプローチはあるか
```

- 期待スキル: `persistent-exploration`
- LOAD 判定: `persistent-exploration/SKILL.md` の Read
- 文脈: 具体的な調査対象があり、既に複数手段を試して行き詰まっている状況

### 1-B. 明示起動テスト

**手順**: 1つのチャットセッションで、`/` メニューからスキル名を検索し選択する。各スキルについて「一覧に表示されるか」「選択後にロードされるか」を確認。

**19スキル — 以下を順に `/` で検索:**

```
/adversarial-review
/arena-compare
/branch-finish
/branch-naming
/conventional-commits
/implementer-contract
/issue-conventions
/kickoff-to-plan
/markdown-conventions
/oss-research-session
/persistent-exploration
/plan-to-kickoff
/playwright-browser
/pr-conventions
/question-driven-design
/sentry-investigation
/so-compare
/spec-card
/worktrunk-worktrees
```

**7コマンド — 以下を順に `/` で検索:**

```
/issue-debug
/research-intake
/pr-review
/pr-review-checklist
/copilot-review-response
/peer-ai-review
/arena-perspectives
```

---

## 2. Claude Code での検証

### 2-A. 暗黙起動テスト

**手順**: `/tmp/ai-hub-test/` で `claude` を起動。各グループごとに新しいセッション（`/clear` or 再起動）。

> セッション開始前の準備（Group A 用）:
> ```bash
> cd /tmp/ai-hub-test && echo "test-claude" >> README.md && git add README.md
> ```

#### Session Group A: Git ワークフロー系

**A1 — branch-naming**

```
Issue #64 用のブランチを作って
```

**A2 — conventional-commits**

```
この変更をコミットして
```

**A3 — pr-conventions**

```
この変更の PR を作成して（dry-run で手順だけ示して、実際には作成しないで）
```

**A4 — branch-finish**

```
このブランチの作業は完了した。次のステップを提案して
```

**セッション終了前に確認プロンプト:**

```
今のセッションでロードしたスキルを全て教えて
```

#### Session Group B: Issue・ドキュメント系

**B1 — issue-conventions**

```
README の改善提案を Issue に起票して（dry-run で手順だけ示して、実際には作成しないで）
```

**B2 — markdown-conventions**

```
README.md に「Contributing」セクションを追加して
```

**B3 — spec-card**

```
この議論の結論を Decision ドキュメントとして記録して
```

**セッション終了前に確認プロンプト:**

```
今のセッションでロードしたスキルを全て教えて
```

#### Session Group C: プラン・設計系

**C1 — kickoff-to-plan**

```
docs/plans/epic#38/2026-04-12-kickoff-phase1-core-canonical-diagnosis.md をプランに変換して
```

**C2 — question-driven-design**

```
新しい sync --check 機能を追加したい。設計を一緒に考えて
```

**C3 — adversarial-review**

```
docs/plans/epic#38/2026-04-12-kickoff-phase2-canonical-cross-agent-proposals.md のプランに問題がないかレビューして
```

**セッション終了前に確認プロンプト:**

```
今のセッションでロードしたスキルを全て教えて
```

#### Session Group D: ツール・調査系

**D1 — worktrunk-worktrees**

```
並列で別の Issue にも着手したい。worktree を作って
```

**D2 — implementer-contract**

```
canonical/codex/commands-registry/registry.md に不足しているコマンド2件（pr-review-checklist, research-intake）を追加する作業を、サブエージェントに委譲して実装させて
```

**D3 — persistent-exploration**

```
scripts/sync/sync-codex.sh で skills の symlink が作られるはずなのに、特定の環境で ~/.codex/skills/ が空になる問題を調査している。strace もログも確認したが原因が掴めない。他に試せるアプローチはあるか
```

**セッション終了前に確認プロンプト:**

```
今のセッションでロードしたスキルを全て教えて
```

### 2-B. 明示起動テスト

**手順**: 1つのセッション内で、以下のスラッシュコマンドを順に入力。認識されるか・ロードされるかを確認。

**19スキル:**

```
/adversarial-review
/arena-compare
/branch-finish
/branch-naming
/conventional-commits
/implementer-contract
/issue-conventions
/kickoff-to-plan
/markdown-conventions
/oss-research-session
/persistent-exploration
/plan-to-kickoff
/playwright-browser
/pr-conventions
/question-driven-design
/sentry-investigation
/so-compare
/spec-card
/worktrunk-worktrees
```

**7コマンド:**

```
/issue-debug
/research-intake
/pr-review
/pr-review-checklist
/copilot-review-response
/peer-ai-review
/arena-perspectives
```

### 2-C. 記録

各セッション完了後:

```bash
# Claude Code のセッションエクスポート
# 方法: /export コマンド or セッション自動保存ファイルを確認
```

---

## 3. Codex での検証

### 3-A. 暗黙起動テスト

**手順**: `/tmp/ai-hub-test/` で `codex` を起動。各グループごとに新しいセッション。

> セッション開始前の準備（Group A 用）:
> ```bash
> cd /tmp/ai-hub-test && echo "test-codex" >> README.md && git add README.md
> ```

> **重要**: Codex は Default mode で即実行する傾向がある。dry-run 指示を強調すること。

#### Session Group A: Git ワークフロー系

**A1 — branch-naming**

```
Issue #64 用のブランチを作って
```

**A2 — conventional-commits**

```
この変更をコミットして
```

**A3 — pr-conventions**

```
この変更の PR を作成して（dry-run で手順だけ示して、実際には作成しないで）
```

**A4 — branch-finish**

```
このブランチの作業は完了した。次のステップを提案して
```

#### Session Group B: Issue・ドキュメント系

**B1 — issue-conventions**

```
README の改善提案を Issue に起票して（dry-run で手順だけ示して、実際には作成しないで）
```

**B2 — markdown-conventions**

```
README.md に「Contributing」セクションを追加して
```

**B3 — spec-card**

```
この議論の結論を Decision ドキュメントとして記録して
```

#### Session Group C: プラン・設計系

**C1 — kickoff-to-plan**

```
docs/plans/epic#38/2026-04-12-kickoff-phase1-core-canonical-diagnosis.md をプランに変換して
```

**C2 — question-driven-design**

```
新しい sync --check 機能を追加したい。設計を一緒に考えて
```

**C3 — adversarial-review**

```
docs/plans/epic#38/2026-04-12-kickoff-phase2-canonical-cross-agent-proposals.md のプランに問題がないかレビューして
```

#### Session Group D: ツール・調査系

**D1 — worktrunk-worktrees**

```
並列で別の Issue にも着手したい。worktree を作って
```

**D2 — implementer-contract**

```
canonical/codex/commands-registry/registry.md に不足しているコマンド2件（pr-review-checklist, research-intake）を追加する作業を、サブエージェントに委譲して実装させて
```

**D3 — persistent-exploration**

```
scripts/sync/sync-codex.sh で skills の symlink が作られるはずなのに、特定の環境で ~/.codex/skills/ が空になる問題を調査している。strace もログも確認したが原因が掴めない。他に試せるアプローチはあるか
```

### 3-B. 明示起動テスト

**手順**: 1つのセッション内で以下を実行。

まずスキル一覧を確認:

```
/skills
```

次に各スキルを個別に呼び出し:

```
$adversarial-review を使って
$arena-compare を使って
$branch-finish を使って
$branch-naming を使って
$conventional-commits を使って
$implementer-contract を使って
$issue-conventions を使って
$kickoff-to-plan を使って
$markdown-conventions を使って
$oss-research-session を使って
$persistent-exploration を使って
$plan-to-kickoff を使って
$playwright-browser を使って
$pr-conventions を使って
$question-driven-design を使って
$sentry-investigation を使って
$so-compare を使って
$spec-card を使って
$worktrunk-worktrees を使って
```

コマンド（registry 経由）:

```
/issue-debug を実行して
/pr-review を実行して
/copilot-review-response を実行して
/peer-ai-review を実行して
/arena-perspectives を実行して
/research-intake を実行して（※ registry 未登録）
/pr-review-checklist を実行して（※ registry 未登録）
```

### 3-C. 記録

各セッション完了後:

```bash
# Codex セッションエクスポート（JSONL）
# 場所: ~/.codex/sessions/ 配下の最新ファイル
ls -lt ~/.codex/sessions/2026/04/ | head -5
```

---

## 4. 結果記録テンプレート

### 4-1. 暗黙起動テスト結果

以下の表を各ツールの検証完了後に埋める。

```markdown
| # | スキル | プロンプト | Cursor 1回目 | Cursor 2回目 | Claude 1回目 | Claude 2回目 | Codex 1回目 | Codex 2回目 |
|---|--------|-----------|-------------|-------------|-------------|-------------|------------|------------|
| A1 | branch-naming | Issue #64 用のブランチを作って | | | | | | |
| A2 | conventional-commits | この変更をコミットして | | | | | | |
| A3 | pr-conventions | PR を作成して（dry-run） | | | | | | |
| A4 | branch-finish | ブランチ完了、次のステップを | | | | | | |
| B1 | issue-conventions | Issue に起票して（dry-run） | | | | | | |
| B2 | markdown-conventions | README に Contributing 追加 | | | | | | |
| B3 | spec-card | Decision ドキュメントを記録 | | | | | | |
| C1 | kickoff-to-plan | キックオフをプランに変換 | | | | | | |
| C2 | question-driven-design | sync --check 設計相談 | | | | | | |
| C3 | adversarial-review | プランレビュー | | | | | | |
| D1 | worktrunk-worktrees | worktree を作って | | | | | | |
| D2 | implementer-contract | サブエージェントに委譲 | | | | | | |
| D3 | persistent-exploration | 原因特定できない、別アプローチ | | | | | | |
```

各セルに `LOAD` / `NO_LOAD` を記入。補足があれば括弧で追記。

### 4-2. 明示起動テスト結果

```markdown
| # | スキル/コマンド | 種別 | Cursor | Claude Code | Codex |
|---|---------------|------|--------|-------------|-------|
| 1 | adversarial-review | skill | | | |
| 2 | arena-compare | skill | | | |
| 3 | branch-finish | skill | | | |
| 4 | branch-naming | skill | | | |
| 5 | conventional-commits | skill | | | |
| 6 | implementer-contract | skill | | | |
| 7 | issue-conventions | skill | | | |
| 8 | kickoff-to-plan | skill | | | |
| 9 | markdown-conventions | skill | | | |
| 10 | oss-research-session | skill | | | |
| 11 | persistent-exploration | skill | | | |
| 12 | plan-to-kickoff | skill | | | |
| 13 | playwright-browser | skill | | | |
| 14 | pr-conventions | skill | | | |
| 15 | question-driven-design | skill | | | |
| 16 | sentry-investigation | skill | | | |
| 17 | so-compare | skill | | | |
| 18 | spec-card | skill | | | |
| 19 | worktrunk-worktrees | skill | | | |
| 20 | issue-debug | cmd | | | |
| 21 | research-intake | cmd | | | |
| 22 | pr-review | cmd | | | |
| 23 | pr-review-checklist | cmd | | | |
| 24 | copilot-review-response | cmd | | | |
| 25 | peer-ai-review | cmd | | | |
| 26 | arena-perspectives | cmd | | | |
```

各セルに `LOAD` / `NO_LOAD` / `NOT_FOUND`（一覧に表示されない場合）を記入。

### 4-3. 備考記録（Phase 2 入力用）

検証中に気づいた行動観察（ロード後の遵守度等）をフリーテキストで記録:

```markdown
## 行動観察メモ（Phase 2 入力）

### Cursor
- 

### Claude Code
- 

### Codex
- 
```

---

## 5. 検証完了後の次ステップ

結果記録テンプレートが埋まったら、Cursor セッションで以下を依頼:

```
Issue #64 のスキルロード検証結果が揃った。
結果は docs/plans/epic#38/2026-04-12-skill-load-test-runbook.md の
セクション4のテンプレートに記入済み。
Stage 4（ロード率マトリクス作成・原因分析・PR・申し送り）を実行して。
```
