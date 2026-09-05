# Canonical Resource Catalog

`canonical/` 配下の全リソース一覧。AI がコンテキスト読み込みの起点に使うためのエントリポイント。

## Language Convention

- **Rules**: English — ルール/原則はモデルの学習分布（CS 概念体系が英語ベース）と一致させるため英語で記述。断定的・厳格・端的な表現を使う
- **Skills**: Japanese — スキルはドメイン知識・コンテキストを含むため、ユーザーの思考言語（日本語）で記述。description（frontmatter）も日本語

## Skills (28)

| 名前 | 説明 | パス | depends |
|------|------|------|---------|
| adversarial-review | Plan/Specの品質チェック（Plan Review）と、実装完了後の仕様照合（Compliance Review）を行う | `skills/adversarial-review/SKILL.md` | — |
| arena-compare | arena-compare.shで複数モデルに同一プロンプトを並列投入し、回答を比較する | `skills/arena-compare/SKILL.md` | cli: arena-compare |
| branch-finish | ブランチ完了判定フロー（検証→4択→実行→クリーンアップ） | `skills/branch-finish/SKILL.md` | skill: worktrunk-worktrees, skill: pr-conventions, skill: conventional-commits |
| branch-naming | ブランチ命名規則を適用する | `skills/branch-naming/SKILL.md` | — |
| c4-architecture | 構造化データからC4アーキテクチャ図（Mermaid）を生成する記述スキル（4レベル視点・graph TD/classDef・AS-IS/TO-BE・サニタイズ指針） | `skills/c4-architecture/SKILL.md` | — |
| code-path-exhaustion | バグ調査で入力→出力のコードパスに未読がある限り外部要因の仮説に進まない。仮説を tmp/hypothesis-NNN.md に外部化し read-state を可視化（exhaustion-before-conclusion のバグ調査ドメイン層2・#77 の姉妹）。hypothesis-gate フックが N=3 で advisory 誘導 | `skills/code-path-exhaustion/SKILL.md` | skill: persistent-exploration, skill: episode-retrospective |
| conventional-commits | コミットメッセージをConventional Commits規約に従って生成する | `skills/conventional-commits/SKILL.md` | — |
| delegate-task | 親子 Claude Code セッション間の委譲操作（delegate / send / list / report）を自然言語から判断して実行する。tmux 環境前提 | `skills/delegate-task/SKILL.md` | — |
| diff-audit | PR diff全体を原則ベースでレビューする。4つの問いを軸に、チェックリスト外の問題も含めて拾う。既知パターンは各問いのヒントとして残す | `skills/diff-audit/SKILL.md` | — |
| doc-flow-guardrail | ドキュメントフロー全体の地図・委譲固定節テンプレ・cold-start を注入する薄い枠（DJ-11 二層＝大原則1行 + routing 表のみ・中身は個別スキルへ routing） | `skills/doc-flow-guardrail/SKILL.md` | skill: spec-card, skill: delegate-task, skill: episode-retrospective, skill: predecision-exploration |
| episode-retrospective | Episode closure 時の構造化振り返り（closure gate checklist・出力型×消費チャネル〔構造化 FB セクション向け〕・tier 判定・本文と closure の read/write 契約＝pointer 許容で二重執筆を止める） | `skills/episode-retrospective/SKILL.md` | skill: spec-card, skill: so-compare |
| implementer-contract | サブエージェントへの実装委譲時の返却契約（ステータスenum・報告フォーマット・スコープ外報告） | `skills/implementer-contract/SKILL.md` | — |
| issue-conventions | Issue作成の規約を適用する | `skills/issue-conventions/SKILL.md` | — |
| kickoff-to-plan | Kickoff Documentを実行可能なプランに忠実変換する | `skills/kickoff-to-plan/SKILL.md` | skill: adversarial-review |
| markdown-conventions | Markdown記法の規約を適用する | `skills/markdown-conventions/SKILL.md` | — |
| orchestration-toolkit | oe-* オーケストレーションツール群（engine/委譲/SOゲート/選択・観測）と駆動層規律の統合概観。repo 走査でなく一貫理解する loadable パッケージ。詳細は bin/README へ routing | `skills/orchestration-toolkit/SKILL.md` | skill: delegate-task, skill: so-compare, skill: predecision-exploration, skill: episode-retrospective, skill: code-path-exhaustion |
| oss-research-session | oss-researcher 調査セッションの起動・成果保存の標準化（パス規約・注入テンプレ・チェックリスト） | `skills/oss-research-session/SKILL.md` | — |
| persistent-exploration | 原因探索の「諦めない」深掘り行動原則 | `skills/persistent-exploration/SKILL.md` | — |
| plan-to-kickoff | Cursor Plan / プランMDをKickoff Document形式に変換する | `skills/plan-to-kickoff/SKILL.md` | skill: so-compare, skill: kickoff-to-plan, command: peer-ai-review |
| playwright-browser | Playwright MCPでブラウザ操作・DOM調査・UI検証を行う | `skills/playwright-browser/SKILL.md` | — |
| pr-conventions | PR作成の規約を適用する | `skills/pr-conventions/SKILL.md` | — |
| predecision-exploration | 設計判断を確定する前にゼロベースで代替案を最低1回引き出し、探索木を確定前 artifact に残してから確定する（so-compare 選択肢拡張・確定前証跡・暫定停止条件）。exhaustion-before-conclusion-rule の設計ドメイン層2（soft forcing。hard 版は defer） | `skills/predecision-exploration/SKILL.md` | skill: so-compare, skill: kickoff-to-plan, skill: episode-retrospective, command: peer-ai-review |
| question-driven-design | 実装前に設計ツリーを質問で網羅的に掘り下げ、暗黙の前提を明示化する | `skills/question-driven-design/SKILL.md` | — |
| sentry-investigation | Sentry APIからエラー情報・スタックトレースを取得するパターン集 | `skills/sentry-investigation/SKILL.md` | — |
| so-compare | so-compare.shでセカンドオピニオン（Codex/Claude/Cursor）を取得し比較する。**弱 SO**（1周可・partial=disclose・0はなし）。強 SO は `peer-ai-review` | `skills/so-compare/SKILL.md` | cli: so-compare |
| spec-card | 蒸留パイプラインのドキュメントフォーマット適用ガイド（frontmatter・ULID・status） | `skills/spec-card/SKILL.md` | — |
| unmet-gate-check | 委譲を完了扱いにする前に未達のゲートと step を経緯抜きで照合する検出層。plan + 委譲時の書面 + ゲート表 + 観測可能な状態のみを path で渡し、会話履歴・完了報告・ACK の散文を遮断（境界は書面から導出し申告で受けない）。判定は5値（fulfilled/unmet/unknown/not-yet-due/not-applicable）で `unknown` を `fulfilled` に、`not-yet-due` を `not-applicable` に畳まない（baseline 不一致時は `invalid-baseline` のみ返し判定に入らない）。**起動は保証しない**（強制層は #291） | `skills/unmet-gate-check/SKILL.md` | skill: doc-flow-guardrail, skill: delegate-task, skill: implementer-contract |
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
| peer-ai-review | 修正タスクや設計判断に対して、Codex CLIとClaude Codeにピアレビューを依頼し、3者合意に至るまでイテレーションを繰り返す。**強 SO**（全レーン合意まで iterate・0=不可） | `commands/verification/peer-ai-review.md` | skill: so-compare, skill: persistent-exploration, skill: adversarial-review, skill: implementer-contract, cli: so-compare, command: pr-review-checklist |
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

## Rules (12)

| Name | Description | Path |
|------|-------------|------|
| behavioral-rule | Core principles: Evidence First, CLI Native, Safe Operations, Minimal Scope (WHAT/HOW separation), Incremental Steps, Follow Existing Patterns, Root Cause (address root causes; report which existing behavior you touched and how you checked it) | `rules/behavioral-rule.md` |
| careful-operations-rule | Destructive command guardrails — three-tier pattern table (blocked / requires confirmation / exceptions) | `rules/careful-operations-rule.md` |
| decision-pacing-rule | Reporting a problem is not a decision to fix it; separate analysis from action proposals | `rules/decision-pacing-rule.md` |
| evidence-verification-rule | Concretizes Evidence First into a checkable protocol: claim-level verification status (verified/unverified-summary/speculation) + source, and risk-proportional consumer spot-check | `rules/evidence-verification-rule.md` |
| execution-policy-rule | Read-only before mutations; gates/checkpoints as TODO items; execution obligations | `rules/execution-policy-rule.md` |
| exhaustion-before-conclusion-rule | Complements Evidence First with exploration breadth: do not conclude while reachable paths or options remain unexamined. Illustrated by design (option) / bug-investigation (code-path) cases; design-domain soft layer landed as predecision-exploration (#77) + soft floor reframe-on-stall-rule (#161); deterministic hard gates (#77/#78) deferred; includes a minimal high-stakes discipline | `rules/exhaustion-before-conclusion-rule.md` |
| implementation-gate-rule | Propose a planning phase before any code change; agent MUST NOT self-apply exceptions | `rules/implementation-gate-rule.md` |
| input-style-rule | Handle voice-input typos and fragments; prioritize intent over polish | `rules/input-style-rule.md` |
| output-format-rule | Conclusion → evidence → steps → risks → links output structure; related links required when the turn created or updated an Issue / PR / in-repo doc (§5: heading pinned by the report's language, comments optional, bare `#N` insufficient, no padding, read-only turns exempt; operator-facing section, distinct from a subagent's `Links` field); URL form by destination (§6: bare URL to the terminal, `[label](url)` to Markdown renderers); plain-Japanese wording (§8: no decorative English, keep work-object names); operator-facing plain prose (§9: no telegram compression; chat + human-gate; reasoning / agent-channels / board exempt) | `rules/output-format-rule.md` |
| reframe-on-stall-rule | Always-on soft floor under exhaustion-before-conclusion: when exploration stalls (no material new information, lateral repetition), consider a zero-base rebuild before continuing. Qualitative trigger via observable signs (not a count); reconcile against discarded premises; low-risk carve-out; model-dependent (hard gate #77 backs high-stakes once it lands) | `rules/reframe-on-stall-rule.md` |
| subagent-strategy-rule | Subagent delegation: custom agents first, one task per subagent, implementer-contract; concurrency / nesting limits belong to the harness, not to the rule; routing gate (new thread escalation signal, PR-unit) | `rules/subagent-strategy-rule.md` |
| workflow-awareness-rule | GitHub Flow; autonomously start branching for issue-driven work | `rules/workflow-awareness-rule.md` |

## Hooks

フック名・目的の一行サマリ。詳細は [`hooks/README.md`](hooks/README.md) を参照。

| フック | スクリプト | 目的 |
|--------|-----------|------|
| 破壊コマンドブロック | `hooks/scripts/block-destructive.sh` | `rm -rf /`, `DROP TABLE` 等の破壊的コマンドをブロック |
| force push ブロック | `hooks/scripts/block-force-push.sh` | `git push --force` をブロック（`--force-with-lease` は許可） |
| CC 形式チェック | `hooks/scripts/cc-lint.sh` | `git commit -m` の Conventional Commits 形式を検証（3ツール共通） |
| コミットゲート | `hooks/scripts/commit-gate.sh` | タスク完了時に未コミット変更があれば通知（Claude Code のみ） |
| 仮説ゲート | `hooks/scripts/hypothesis-gate.sh` | バグ調査で `tmp/hypothesis-*.md` が N=3 に達したら外部要因の結論前にコードパス未読確認を advisory 通知（Claude Code PostToolUse・ブロックしない・#78 code-path-exhaustion） |
| 取り込み印 | `hooks/scripts/oe-prompt-receipt.sh` | 注入された 1 行を受け手セッションが取り込んだ瞬間に、ペインに束縛された受領印（`prompt_received`）を活動ログへ追記（Claude Code UserPromptSubmit・stdout を汚さない・#299 P1） |
| 通知 | `hooks/scripts/notify.sh` | エージェントの完了・入力待ちを macOS 通知（advisory、並走時のポーリング解消）。loc にセッション名を表示 |
| セッション命名 | `hooks/scripts/session-name.sh` | セッション名を自動設定（Claude Code のみ・UserPromptSubmit）。worktree は `#<issue> <slug>`（`scripts/wt/wt-pane-issue.sh`＝worktrunk post-switch と連携）、非 wt は現在 git ブランチ名（issue規約→`#<issue> <slug>` / デフォルト・非git→リポ名）でブランチ変化に追従。並列セッション識別用 |

## ツール固有拡張

canonical/ 内のツール固有レイヤー。各ディレクトリの README を参照。

| ディレクトリ | 対象ツール | 内容 |
|-------------|-----------|------|
| `cursor/` | Cursor | Cursor 固有コマンド (`command/`)、User Rule (`rules/cursor-first-turn.mdc`)、Agent Skill (`skills/cursor-kickoff/`) |
| `codex/` | Codex | Codex 固有 AGENTS.md、commands-registry |
| `mcp/` | Cursor, Claude Code | MCP サーバー設定（`cursor.json`, `claude.json`） |
