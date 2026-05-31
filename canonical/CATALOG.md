# Canonical Resource Catalog

`canonical/` 配下の全リソース一覧。AI がコンテキスト読み込みの起点に使うためのエントリポイント。

## Language Convention

- **Rules**: English — ルール/原則はモデルの学習分布（CS 概念体系が英語ベース）と一致させるため英語で記述。断定的・厳格・端的な表現を使う
- **Skills**: Japanese — スキルはドメイン知識・コンテキストを含むため、ユーザーの思考言語（日本語）で記述。description（frontmatter）も日本語

## Skills (19)

| 名前 | 説明 | パス | depends |
|------|------|------|---------|
| adversarial-review | Plan/Specの品質チェック（Plan Review）と、実装完了後の仕様照合（Compliance Review）を行う | `skills/adversarial-review/SKILL.md` | — |
| arena-compare | arena-compare.shで複数モデルに同一プロンプトを並列投入し、回答を比較する | `skills/arena-compare/SKILL.md` | cli: arena-compare |
| branch-finish | ブランチ完了判定フロー（検証→4択→実行→クリーンアップ） | `skills/branch-finish/SKILL.md` | skill: worktrunk-worktrees, skill: pr-conventions, skill: conventional-commits |
| branch-naming | ブランチ命名規則を適用する | `skills/branch-naming/SKILL.md` | — |
| conventional-commits | コミットメッセージをConventional Commits規約に従って生成する | `skills/conventional-commits/SKILL.md` | — |
| implementer-contract | サブエージェントへの実装委譲時の返却契約（ステータスenum・報告フォーマット・スコープ外報告） | `skills/implementer-contract/SKILL.md` | — |
| issue-conventions | Issue作成の規約を適用する | `skills/issue-conventions/SKILL.md` | — |
| kickoff-to-plan | Kickoff Documentを実行可能なプランに忠実変換する | `skills/kickoff-to-plan/SKILL.md` | skill: adversarial-review |
| markdown-conventions | Markdown記法の規約を適用する | `skills/markdown-conventions/SKILL.md` | — |
| oss-research-session | oss-researcher 調査セッションの起動・成果保存の標準化（パス規約・注入テンプレ・チェックリスト） | `skills/oss-research-session/SKILL.md` | — |
| persistent-exploration | 原因探索の「諦めない」深掘り行動原則 | `skills/persistent-exploration/SKILL.md` | — |
| plan-to-kickoff | Cursor Plan / プランMDをKickoff Document形式に変換する | `skills/plan-to-kickoff/SKILL.md` | skill: so-compare, skill: kickoff-to-plan, command: peer-ai-review |
| playwright-browser | Playwright MCPでブラウザ操作・DOM調査・UI検証を行う | `skills/playwright-browser/SKILL.md` | — |
| pr-conventions | PR作成の規約を適用する | `skills/pr-conventions/SKILL.md` | — |
| question-driven-design | 実装前に設計ツリーを質問で網羅的に掘り下げ、暗黙の前提を明示化する | `skills/question-driven-design/SKILL.md` | — |
| sentry-investigation | Sentry APIからエラー情報・スタックトレースを取得するパターン集 | `skills/sentry-investigation/SKILL.md` | — |
| so-compare | so-compare.shでセカンドオピニオン（Codex/Claude）を取得し、結果を比較する | `skills/so-compare/SKILL.md` | cli: so-compare |
| spec-card | 蒸留パイプラインのドキュメントフォーマット適用ガイド（frontmatter・ULID・status） | `skills/spec-card/SKILL.md` | — |
| worktrunk-worktrees | Worktrunk (wt) ベースの worktree 運用 | `skills/worktrunk-worktrees/SKILL.md` | skill: branch-naming, cli: wt |

## Workflow Chains

Skills テーブルの `depends` は技術的参照（このスキルが使用するスキル）を宣言する。
以下はワークフロー上の順序であり、`depends` の方向とは異なる。

| チェーン | フロー | 備考 |
|---------|--------|------|
| Issue → Branch → Worktree → Finish | `issue-conventions` → `branch-naming` → `worktrunk-worktrees` → `branch-finish` | タスク開始〜完了の全フロー |

## Commands (7)

| 名前 | 説明 | パス | depends |
|------|------|------|---------|
| peer-ai-review | 修正タスクや設計判断に対して、Codex CLIとClaude Codeにピアレビューを依頼し、3者合意に至るまでイテレーションを繰り返す | `commands/verification/peer-ai-review.md` | skill: so-compare, skill: persistent-exploration, skill: adversarial-review, skill: implementer-contract, cli: so-compare, command: pr-review-checklist |
| arena-perspectives | 同一プロンプトを複数モデルに並列投入し、モデルごとの回答を並べて表示する | `commands/verification/arena-perspectives.md` | skill: arena-compare, skill: persistent-exploration, cli: arena-compare |
| issue-debug | Issue / Sentryエラーの調査・分析・修正を行う | `commands/investigation/issue-debug.md` | skill: sentry-investigation, skill: persistent-exploration, skill: branch-naming, skill: conventional-commits, skill: pr-conventions, command: arena-perspectives, command: peer-ai-review |
| research-intake | 外部記事/論文のURL起点で、本質抽出→既存資産マッピング→統合判断→Issue化/ドキュメント化を行う | `commands/investigation/research-intake.md` | skill: oss-research-session, skill: issue-conventions, skill: markdown-conventions |
| pr-review | 指定したPR（またはレビュー依頼が来ているPR）を一緒にレビューする | `commands/review/pr-review.md` | command: pr-review-checklist |
| pr-review-checklist | レビュー対象のdiffをチェック項目に照らして検証し、問題があれば修正を提案する | `commands/review/pr-review-checklist.md` | — |
| copilot-review-response | 未返信の Copilot レビューコメントのみ対象に、対応可否・修正・対応した／しないの返信まで行う | `commands/review/copilot-review-response.md` | — |

## Agents (3)

| 名前 | 説明 | パス |
|------|------|------|
| oss-researcher | OSS・ライブラリの深層調査エージェント。GitHubリポジトリのソースコード直接解析、設計パターン抽出、実装詳細の調査を行う | `agents/oss-researcher.md` |
| playwright-agent | Playwright MCPでブラウザ操作を実行し、結果を要約して報告するエージェント | `agents/playwright-agent.md` |
| vendor-inspector | Dependency and vendor code deep-reading agent. Investigates local vendor/, node_modules/, and external repository code | `agents/vendor-inspector.md` |

## Rules (11)

| Name | Description | Path |
|------|-------------|------|
| behavioral-rule | Core principles: Evidence First, CLI Native, Safe Operations, Minimal Scope (WHAT/HOW separation), Incremental Steps, Follow Existing Patterns | `rules/behavioral-rule.md` |
| careful-operations-rule | Destructive command guardrails — three-tier pattern table (blocked / requires confirmation / exceptions) | `rules/careful-operations-rule.md` |
| decision-pacing-rule | Separate problem reporting from action proposals; include "do nothing / defer" as an option | `rules/decision-pacing-rule.md` |
| execution-policy-rule | Read-only before mutations; gates/checkpoints as TODO items; execution obligations | `rules/execution-policy-rule.md` |
| implementation-gate-rule | Propose a planning phase before any code change; agent MUST NOT self-apply exceptions | `rules/implementation-gate-rule.md` |
| implementation-principles-rule | Address root causes over hacky fixes; verify no existing behavior is broken | `rules/implementation-principles-rule.md` |
| input-style-rule | Handle voice-input typos and fragments; prioritize intent over polish | `rules/input-style-rule.md` |
| output-format-rule | Conclusion → evidence → steps → risks → links output structure | `rules/output-format-rule.md` |
| skill-first-operations-rule | Load and follow skills for routine dev operations; do NOT skip skill loading | `rules/skill-first-operations-rule.md` |
| subagent-strategy-rule | Subagent delegation: custom agents first, one task per subagent, implementer-contract; routing gate (new thread escalation signal, PR-unit) | `rules/subagent-strategy-rule.md` |
| workflow-awareness-rule | GitHub Flow; autonomously start branching for issue-driven work | `rules/workflow-awareness-rule.md` |

## Hooks

フック名・目的の一行サマリ。詳細は [`hooks/README.md`](hooks/README.md) を参照。

| フック | スクリプト | 目的 |
|--------|-----------|------|
| 破壊コマンドブロック | `hooks/scripts/block-destructive.sh` | `rm -rf /`, `DROP TABLE` 等の破壊的コマンドをブロック |
| force push ブロック | `hooks/scripts/block-force-push.sh` | `git push --force` をブロック（`--force-with-lease` は許可） |
| CC 形式チェック | `hooks/scripts/cc-lint.sh` | `git commit -m` の Conventional Commits 形式を検証（3ツール共通） |
| コミットゲート | `hooks/scripts/commit-gate.sh` | タスク完了時に未コミット変更があれば通知（Claude Code のみ） |

## ツール固有拡張

canonical/ 内のツール固有レイヤー。各ディレクトリの README を参照。

| ディレクトリ | 対象ツール | 内容 |
|-------------|-----------|------|
| `cursor/` | Cursor | Cursor 固有コマンド (`command/`)、User Rule (`rules/cursor-first-turn.mdc`)、Agent Skill (`skills/cursor-kickoff/`) |
| `codex/` | Codex | Codex 固有 AGENTS.md、commands-registry |
| `mcp/` | Cursor, Claude Code | MCP サーバー設定（`cursor.json`, `claude.json`） |
