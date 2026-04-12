---
title: "Issue #64: スキル/コマンド ロード検証 — 静的分析結果"
date: 2026-04-12
status: completed
tags: [canonical, skills, commands, cross-agent, phase1, static-analysis]
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/64
  - https://github.com/stlwolf/ai-development-hub/issues/38
---

# Issue #64: スキル/コマンド ロード検証 — 静的分析結果

## 1. 配置状況

全ツールへの sync 済み。配置に問題なし。

| 対象 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| スキル (19) | `~/.cursor/skills/` 19件 ✅ | `~/.claude/skills/` 19件 ✅ | `~/.codex/skills/` 19件 ✅ |
| コマンド (7) | `~/.cursor/commands/` 7件 ✅ | `~/.claude/commands/` 7件 ✅ | `commands-registry` 5/7件 ⚠️ |

**Codex commands-registry の欠落**: `pr-review-checklist` と `research-intake` が `registry.md` に未登録。ファイル自体は `canonical/commands/` に存在するが、Codex の疑似コマンド導線に含まれていない。

## 2. description の定量分析

### 2.1 Claude Code 250 文字制限

全19スキルの description が 250 文字以内。切り詰めによる情報損失は発生しない。

| スキル | 文字数 | 250文字判定 |
|--------|--------|------------|
| kickoff-to-plan | 159 | OK |
| playwright-browser | 141 | OK |
| spec-card | 136 | OK |
| question-driven-design | 127 | OK |
| plan-to-kickoff | 121 | OK |
| persistent-exploration | 121 | OK |
| adversarial-review | 116 | OK |
| worktrunk-worktrees | 115 | OK |
| so-compare | 114 | OK |
| arena-compare | 113 | OK |
| implementer-contract | 112 | OK |
| branch-naming | 110 | OK |
| sentry-investigation | 109 | OK |
| conventional-commits | 103 | OK |
| pr-conventions | 101 | OK |
| issue-conventions | 98 | OK |
| markdown-conventions | 89 | OK |
| oss-research-session | ~101 | OK |
| branch-finish | 64 | OK |

### 2.2 Codex agents/openai.yaml

全19スキルに `agents/openai.yaml` が存在しない。Codex の暗黙起動制御（`policy.allow_implicit_invocation` 等）が未設定。Codex のスキル発見は Progressive disclosure のデフォルト挙動に完全に依存している。

### 2.3 oss-research-session の YAML multiline

`oss-research-session` の description は YAML multiline (`>`) 構文を使用。パース結果は正しいが、ツールによっては改行位置の扱いが異なる可能性がある。

## 3. description の質的評価

### 評価基準

- **トリガーワードの明確さ**: ユーザーが自然に使う語句を description が含むか
- **ツール非依存性**: Cursor/Claude Code/Codex 固有の語句が残っていないか
- **タスク紐づけの具体性**: 適用場面が具体的に記述されているか

### 評価結果

#### Grade A（強いトリガー + ツール非依存）— 7 スキル

| スキル | 主なトリガーワード | 備考 |
|--------|-------------------|------|
| conventional-commits | コミット、git commit、メッセージ | 規約名（Conventional Commits）は業界標準で中立 |
| branch-naming | ブランチ、命名、作成、Issue番号 | git コマンド名は中立 |
| pr-conventions | PR、プルリクエスト、作成、テンプレート | `gh pr create` は GitHub CLI で中立 |
| issue-conventions | Issue、作成、タイトル、テンプレート | `gh issue create` は GitHub CLI で中立 |
| markdown-conventions | Markdown、PR本文、Issue本文、README | 広いドキュメントタスクに紐づく |
| branch-finish | ブランチ、マージ、PR、クリーンアップ | 短く高密度、ツール非依存 |
| sentry-investigation | Sentry、エラー、スタックトレース、調査 | ドメイン明確 |

#### Grade B（適切だが改善余地あり）— 5 スキル

| スキル | 主なトリガーワード | 問題点 |
|--------|-------------------|--------|
| adversarial-review | レビュー、品質、仕様照合 | 別スキル名 `kickoff-to-plan` への参照が description に含まれる |
| arena-compare | 複数モデル、比較、並列 | スクリプト名 `arena-compare.sh` が先頭に来る |
| persistent-exploration | 調査、再現、バグ、不可能 | 「prompt注入」「サブエージェント」がエージェント実装寄り |
| so-compare | セカンドオピニオン、ピアレビュー | スクリプト名 `so-compare.sh` 先頭 + 3ツール名列挙（Codex/Claude/Cursor） |
| worktrunk-worktrees | worktree、並列作業、ブランチ | `wt` サブコマンドが狭い。「エージェント開始前」はエージェント依存 |

#### Grade C（弱いトリガーまたはツール依存）— 7 スキル

| スキル | ツール固有語 | 問題点 |
|--------|------------|--------|
| kickoff-to-plan | `Cursor Plan Mode`、`Claude Code Tasks/TodoWrite` | **2つのツール名**が description に直接含まれる |
| plan-to-kickoff | `Cursor Plan` | Cursor 固有の概念名 |
| question-driven-design | `Plan mode`、`implementation-gate-rule` | ツール固有モード名 + 内部ルールスラッグ |
| playwright-browser | `user-playwright-mcp`、`built-inブラウザ` | Cursor MCP サーバー ID |
| implementer-contract | `TaskCreate`、`Agentツール` | Cursor 固有のツール名 |
| oss-research-session | `oss-researcher`（エージェント名） | 内部エージェント名が主なフック。ユーザータスク語が弱い |
| spec-card | `蒸留パイプライン`、`Episode→Decision` | リポジトリ固有のドメイン語。一般ユーザーが使わない語彙 |

## 4. Codex 固有の発見性問題

### 4.1 AGENTS.md のファイル数不整合

`canonical/codex/AGENTS.md` L6:

> 正本は `canonical/rules/*.md`（8ファイル）。

実際は 11 ファイル。更新が必要。

### 4.2 Context Strategy の誘導力

Context Strategy セクション（L38-45）は以下を参照:

- `canonical/skills/`（重い手順・専門ワークフロー）
- `canonical/commands/`（タスク実行手順）
- `canonical/codex/commands-registry/registry.md`（疑似コマンド対応）

**問題**: 参照はカテゴリレベルのみで、個別スキル名と適用場面の紐づけがない。Codex がタスクを受けたとき「どのスキルが関連するか」を判断する手がかりが弱い。唯一名前で言及されるスキルは `implementer-contract`（L36）のみ。

### 4.3 agents/openai.yaml の全面不在

Phase 0 調査で確認された Codex のスキル発見メカニズム:

1. Progressive disclosure: メタデータ（name, description）のみ → 使用決定時にフルロード
2. `agents/openai.yaml` で暗黙起動ポリシーを制御可能

19スキル全てに `agents/openai.yaml` が不在のため、(2) は未活用。Codex の暗黙スキル発見は (1) の Progressive disclosure のデフォルト挙動に完全に依存している。

## 5. サマリ

### 即時修正候補（description 改善 PR に含める）

| 修正 | 対象 | 内容 |
|------|------|------|
| ツール固有語の除去 | kickoff-to-plan, plan-to-kickoff, question-driven-design, playwright-browser, implementer-contract | description からツール固有名を除去し、ツール非依存の表現に置換 |
| ファイル数不整合 | canonical/codex/AGENTS.md | 「8ファイル」→「11ファイル」 |
| commands-registry 補完 | canonical/codex/commands-registry/registry.md | `pr-review-checklist`, `research-intake` を追加 |

### Phase 2 / Agent Adapter への申し送り候補

| 論点 | 理由 |
|------|------|
| Codex `agents/openai.yaml` の導入 | 全19スキルで不在。暗黙起動制御が未活用 |
| Codex AGENTS.md の Context Strategy 強化 | 個別スキル名と適用場面の紐づけが不在 |
| Grade B スキルのスクリプト名先頭問題 | `so-compare.sh`、`arena-compare.sh` がスクリプトファーストで、ユーザータスク語が後ろに回っている |
| oss-research-session の description 再設計 | エージェント実装語が主で、ユーザーが起動できるトリガーが弱い |
