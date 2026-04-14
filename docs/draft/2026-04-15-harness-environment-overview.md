---
title: AI開発ハーネス環境の紹介
date: 2026-04-15
context: devチームオフライン会 共有資料
status: draft
---

# AI開発ハーネス環境の紹介

> 「出力の品質を決めるのはモデルではなくハーネス」— LangChain チーム（ハーネス改善だけで SWE-bench Top 30 → Top 5）

## この資料について

個人で構築・運用している AI 開発ハーネスの構成と設計思想の共有資料。
[`ai-development-hub`](https://github.com/stlwolf/ai-development-hub) リポジトリで管理しており、Bash スクリプトと Markdown のみで構成されている（ビルドシステムなし）。

---

## 1. ハーネスとは何か

AI コーディングエージェントの動作を制御・最適化するための仕組み全体。

```
┌─────────────────────────────────────────────────────────┐
│  ハーネス = ルール + スキル + エージェント + コマンド + フック  │
│            + MCP + ツールキット + sync                    │
└─────────────────────────────────────────────────────────┘
         ↓                   ↓                   ↓
     Cursor             Claude Code            Codex
```

モデルへの指示（プロンプト）を構造化・再利用可能にし、ガードレールで安全性を担保し、複数ツール間で統一的に運用する。

---

## 2. 全体アーキテクチャ

```
ai-development-hub/
├── canonical/           ← ツール非依存の正本（ここが Single Source of Truth）
│   ├── rules/           ← 行動規範（11個）
│   ├── skills/          ← 操作スキル（19個）
│   ├── agents/          ← エージェント定義（3個）
│   ├── commands/        ← コマンド定義（7個）
│   ├── hooks/           ← ガードレール・フック（4個）
│   ├── mcp/             ← MCP サーバー設定
│   ├── cursor/          ← Cursor 固有拡張
│   └── codex/           ← Codex 固有拡張
├── projects/            ← 独立ツールキット群
├── scripts/sync/        ← 各ツールへの配信スクリプト
└── docs/                ← ドキュメント・調査・意思決定
```

全リソースの索引: [`canonical/CATALOG.md`](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/CATALOG.md)

### 配信の仕組み（sync）

```bash
./scripts/sync.sh          # 全ツールに一括配信
./scripts/sync.sh cursor   # Cursor のみ
```

canonical の正本をシンボリックリンクで各ツールのホームディレクトリに配置する。
どちら側から編集しても同じファイルが変更され、リポジトリでバージョン管理できる。

| sync ターゲット | 配置先 | 内容 |
|---|---|---|
| cursor | `~/.cursor/` | skills, commands, agents, hooks, MCP |
| claude | `~/.claude/` | rules, skills, commands, agents, hooks, MCP |
| codex | `~/.codex/` | skills, commands-registry, agents, hooks |
| bin | `~/bin/` | so-compare, arena-compare |

sync スクリプト: [`scripts/sync/`](https://github.com/stlwolf/ai-development-hub/tree/master/scripts/sync)

---

## 3. 構成要素の詳細

### 3-1. ルール（11個） — エージェントの行動規範

ツール横断で適用される基本原則。Cursor では User Rules、Claude Code では `~/.claude/rules/` に配置。

| ルール | 一言 |
|---|---|
| [behavioral-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/behavioral-rule.md) | Evidence First / CLI Native / Safe Operations / Minimal Scope / Incremental Steps |
| [careful-operations-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/careful-operations-rule.md) | 破壊的コマンドの3段階分類（Blocked / 要確認 / 例外） |
| [implementation-gate-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/implementation-gate-rule.md) | コード変更前に計画フェーズを必須化 |
| [execution-policy-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/execution-policy-rule.md) | 読み取り→変更の順序、ゲート/チェックポイントを TODO 化 |
| [decision-pacing-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/decision-pacing-rule.md) | 「何もしない」を選択肢に含める |
| [subagent-strategy-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/subagent-strategy-rule.md) | カスタムエージェント優先、1タスク1サブエージェント |
| [skill-first-operations-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/skill-first-operations-rule.md) | 該当スキルがあれば必ずロードする |
| [output-format-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/output-format-rule.md) | 結論→根拠→手順→リスク→リンクの構造化出力 |
| [input-style-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/input-style-rule.md) | 音声入力のタイポ・断片を許容 |
| [workflow-awareness-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/workflow-awareness-rule.md) | GitHub Flow 前提、Issue 起点でブランチ自動作成 |
| [implementation-principles-rule](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/rules/implementation-principles-rule.md) | ハック禁止、既存動作を壊さない確認 |

### 3-2. スキル（19個） — 具体的な操作手順書

特定の操作を行うときにエージェントが参照する手順書。SKILL.md 形式。

主なスキル:

| カテゴリ | スキル | 概要 |
|---|---|---|
| **Git フロー** | [branch-naming](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/branch-naming/SKILL.md) | ブランチ命名規則（prefix/issue-number/slug） |
| | [conventional-commits](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/conventional-commits/SKILL.md) | CC 形式のコミットメッセージ生成 |
| | [pr-conventions](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/pr-conventions/SKILL.md) | PR タイトル正規化・テンプレート適用 |
| | [issue-conventions](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/issue-conventions/SKILL.md) | Issue 作成規約 |
| | [worktrunk-worktrees](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/worktrunk-worktrees/SKILL.md) | worktree ベースの並列作業 |
| | [branch-finish](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/branch-finish/SKILL.md) | 完了判定→4択（マージ/PR/保留/破棄） |
| **品質** | [adversarial-review](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/adversarial-review/SKILL.md) | Plan Review + Compliance Review |
| | [implementer-contract](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/implementer-contract/SKILL.md) | サブエージェントへの返却契約（ステータス enum） |
| | [persistent-exploration](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/persistent-exploration/SKILL.md) | 「諦めない」深掘り行動原則 |
| **認知協調** | [so-compare](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/so-compare/SKILL.md) | セカンドオピニオン取得（Codex + Claude） |
| | [arena-compare](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/arena-compare/SKILL.md) | マルチモデル並列比較（Cursor CLI） |
| **設計** | [question-driven-design](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/question-driven-design/SKILL.md) | 質問ツリーで暗黙の前提を明示化 |
| | [kickoff-to-plan](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/kickoff-to-plan/SKILL.md) | Kickoff Document → 実行プランに忠実変換 |
| | [plan-to-kickoff](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/plan-to-kickoff/SKILL.md) | プラン → Kickoff Document 形式に変換 |
| **運用** | [sentry-investigation](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/sentry-investigation/SKILL.md) | Sentry API パターン集 |
| | [playwright-browser](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/playwright-browser/SKILL.md) | Playwright MCP でブラウザ操作 |
| | [oss-research-session](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/oss-research-session/SKILL.md) | OSS 調査の起動・成果保存標準化 |
| | [spec-card](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/spec-card/SKILL.md) | ドキュメントフォーマット適用（frontmatter・ULID） |
| | [markdown-conventions](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/markdown-conventions/SKILL.md) | Markdown 記法規約 |

### 3-3. コマンド（7個） — 複合ワークフロー

複数スキルを組み合わせた高レベル操作。

| コマンド | 概要 |
|---|---|
| [peer-ai-review](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/verification/peer-ai-review.md) | Codex + Claude にピアレビュー依頼、3者合意まで繰り返し |
| [arena-perspectives](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/verification/arena-perspectives.md) | 複数モデルに同一プロンプト並列投入・比較表示 |
| [issue-debug](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/investigation/issue-debug.md) | Sentry/Issue 起点の調査→分析→修正 |
| [research-intake](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/investigation/research-intake.md) | URL 起点の本質抽出→資産マッピング→Issue化 |
| [pr-review](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/review/pr-review.md) | 指定 PR のレビュー |
| [pr-review-checklist](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/review/pr-review-checklist.md) | diff をチェック項目に照らして検証 |
| [copilot-review-response](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/review/copilot-review-response.md) | Copilot レビューコメントへの対応 |

### 3-4. エージェント（3個） — 専門調査役

| エージェント | 役割 |
|---|---|
| [oss-researcher](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/agents/oss-researcher.md) | OSS の深層調査（ソースコード直接解析・設計パターン抽出） |
| [playwright-agent](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/agents/playwright-agent.md) | ブラウザ操作実行・結果報告 |
| [vendor-inspector](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/agents/vendor-inspector.md) | vendor/node_modules の深層読解 |

### 3-5. フック（4個） — 機械的ガードレール

ルール（テキスト指示）ではなくスクリプトで強制するガードレール。

| フック | 動作 | 対象ツール |
|---|---|---|
| [block-destructive](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/hooks/scripts/block-destructive.sh) | `rm -rf /`, `DROP TABLE` 等をブロック | Cursor / Claude / Codex |
| [block-force-push](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/hooks/scripts/block-force-push.sh) | `git push --force` をブロック（`--force-with-lease` は許可） | Cursor / Claude / Codex |
| [cc-lint](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/hooks/scripts/cc-lint.sh) | `git commit -m` の CC 形式を検証 | Cursor / Claude / Codex |
| [commit-gate](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/hooks/scripts/commit-gate.sh) | タスク完了時に未コミット変更を通知（advisory） | Claude のみ |

フック設定: [Cursor](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/hooks/cursor.hooks.json) / [Claude](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/hooks/claude.hooks.json) / [Codex](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/hooks/codex.hooks.json)

**設計ポイント**: ルールは「お願い」、フックは「強制」。安全系はフックで機械的に担保する。

### 3-6. MCP（Model Context Protocol） — 外部サービス接続

AI エージェントがブラウザ操作や外部サービスと連携するためのプロトコル設定。ツールごとに JSON 形式が異なるため、canonical に正本を置き sync で配信。

| MCP サーバー | 用途 | 配信方式 |
|---|---|---|
| **Playwright MCP** | ブラウザ操作・スクリーンショット・DOM 調査・E2E 検証 | Cursor: mcp.json symlink / Claude: ~/.claude.json にマージ |
| **Notion** | ページ検索・作成・更新・コメント | 同上 |
| **Notion-Personal** | 個人ワークスペース用（分離管理） | 同上 |

MCP 設定ファイル: [cursor.json](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/mcp/cursor.json) / [claude.json](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/mcp/claude.json)

Playwright MCP は [playwright-browser スキル](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/playwright-browser/SKILL.md) と [playwright-agent](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/agents/playwright-agent.md) から利用され、ブラウザベースの UI 検証やデバッグをエージェントに委任できる。Notion MCP はこの資料自体の Notion ページ作成にも使われている。

---

## 4. 認知協調 — 独自の強み

業界記事にない、このハーネス独自のレイヤー。

```
  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
  │ arena-compare │     │  so-compare  │     │peer-ai-review│
  │  （発散）      │     │  （収束）      │     │ （合意形成）   │
  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
         │                     │                     │
    複数モデル             Codex + Claude        3者合意ループ
    並列比較               セカンドオピニオン       イテレーション
```

- **arena-compare**: Cursor CLI で複数モデルに同一プロンプトを並列投入。多角的視点の取得 → [スキル](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/arena-compare/SKILL.md) / [プロジェクト](https://github.com/stlwolf/ai-development-hub/tree/master/projects/arena-compare)
- **so-compare**: Codex CLI + Claude Code に同じ質問。セカンドオピニオンとして活用 → [スキル](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/skills/so-compare/SKILL.md) / [スクリプト](https://github.com/stlwolf/ai-development-hub/blob/master/scripts/so-compare.sh)
- **peer-ai-review**: 修正や設計判断に対して複数 AI にレビュー依頼、合意に至るまで繰り返す → [コマンド](https://github.com/stlwolf/ai-development-hub/blob/master/canonical/commands/verification/peer-ai-review.md)

---

## 5. ツール間統一と差異

3つの AI コーディングツールを並行利用。canonical で共通化しつつ、各ツールの差異を吸収。

| 項目 | Cursor | Claude Code | Codex |
|---|---|---|---|
| ルール配置 | User Rules（手動） | `~/.claude/rules/`（sync） | 未対応 |
| スキル | `~/.cursor/skills/` | `~/.claude/skills/` | `~/.codex/skills/` |
| フック | `hooks.json` + scripts | `settings.json` merge | `hooks.json` + scripts |
| MCP | `mcp.json` symlink | `~/.claude.json` merge | — |
| コンテキスト | 大（制限緩い） | コンパクト後に再注入 | 32KiB 制限 |

詳細: [3ツール比較調査](https://github.com/stlwolf/ai-development-hub/blob/master/docs/research/2026-04-12-cross-agent-rules-skills-config-survey.md)

### dotfiles 側の対応

`.bashrc` にAI IDE 検出関数があり、統合ターミナル環境を最適化:

```bash
is_ai_ide() {
    [[ "$TERM_PROGRAM" == "vscode" ]] && return 0  # VSCode/Cursor
    [[ -n "$CURSOR_PID" ]] && return 0              # Cursor
    [[ -n "$CLAUDE_CODE" ]] && return 0             # Claude Code
    return 1
}
```

AI IDE 検出時: tmux 自動起動・starship・bash-completion をスキップ（軽量化）。
Worktrunk（`wt`）のシェル連携は AI IDE でも読み込み（worktree 操作のため）。

---

## 6. 現在地とギャップ — 何ができていて何が足りないか

### リサーチ基盤

ハーネスエンジニアリングに関する外部記事・論文・実証事例を体系的に収集・分析し、自設計との対応を評価している。

- **英語一次情報 7本**: OpenAI（100万行プロダクト構築）、Martin Fowler（批評的考察）、Anthropic×2（Generator+Evaluator / コンテキスト管理）、Mitchell Hashimoto（ミスしたら仕組みで防ぐ）、Charlie Guo（Playbook 俯瞰）、LangChain（ハーネス改善だけで Top 5）
- **英語補足 12本**: Bouchard, HumanLayer, Schmid, Willison, Fowler 続編 等
- **NLAH 論文**: 清華大・ハルビン工大。ハーネスの制御ロジックを自然言語で統一記述し、OSWorld +16.8pt を達成。canonical の Markdown 駆動と方向性が一致
- **富士通 SWE-bench**: 27B モデルをハーネス設計のみで SLM SOTA（74.8%）。フェーズ×ワークフロー二段制御、ファイルシステム共有領域の具体実装
- **CADDi**: 完璧なルールより空の枠組みを先に作る「Framework-first」。canonical のディレクトリ構造自体がこのパターンの実践

これらの記事群から抽出したハーネス構成要素に対し、canonical 資産の充足度を評価したのが以下の整理。

### 充足している領域（約6割）

| 構成要素 | 説明 |
|---|---|
| Progressive Disclosure | rules → skills → commands の階層構造。必要に応じて段階的に情報を開示し、コンテキスト予算を節約 |
| Self-verification loop | adversarial-review（品質チェック）+ so-compare（セカンドオピニオン）+ peer-ai-review（3者合意）の多段検証 |
| サブエージェント契約 | implementer-contract でステータス enum（DONE / BLOCKED / NEEDS_CONTEXT 等）を定義し、サブエージェントの自己申告を構造化 |
| 機械的ガードレール | hooks による強制ブロック。散文ルールの「お願い」を exit code で 100% 担保に昇格 |
| 認知協調 | arena-compare（発散・多角視点）+ so-compare（収束・検証）。業界記事に登場しない独自レイヤー |
| 枠組みファースト | canonical のディレクトリ構造（`rules/` `skills/` `hooks/` 等）自体が「ここに追加すればいい」という道標として機能 |

### 最大のギャップ — 制御ループの不在

```
現状:  人間 → エージェント → 結果 → 人間が確認 → 次の指示
                                    ↑ ここが手動

目標:  人間 → エージェント → 検証ゲート → 自動再投入 → 合格 → 人間に報告
                              ↑ ループが自動化
```

検証の仕組み（adversarial-review, so-compare）は存在するが、自動ループしない。
Issue [#19](https://github.com/stlwolf/ai-development-hub/issues/19)（オーケストレーション MVP）で追跡中。

### 他の未着手ギャップ

| ギャップ | 意味 |
|---|---|
| Negative Knowledge ledger | 失敗の構造化蓄積・次サイクルへの自動注入 |
| State Semantics | スキル/コマンドの入出力・永続化の宣言 |
| Failure Taxonomy | リカバリパス付きの失敗分類 |
| Time budgeting | サブエージェントへの時間意識注入 |
| Orchestra | 1ターン内の探索役/整形役の分離 |

### リサーチ・調査資料

充足/ギャップ評価の根拠は、リポジトリ内にすべて蓄積している。

- **現状評価・ギャップ分析**: [current-state-assessment.md](https://github.com/stlwolf/ai-development-hub/blob/master/docs/research/harness-engineering/current-state-assessment.md) — 記事群から抽出したハーネス構成要素と canonical 資産の充足度を3段階評価し、Issue カバレッジマップで追跡する living doc（last reviewed: 2026-04-12）
- **3ツール比較調査**: [cross-agent-rules-skills-config-survey.md](https://github.com/stlwolf/ai-development-hub/blob/master/docs/research/2026-04-12-cross-agent-rules-skills-config-survey.md) — Cursor / Claude Code / Codex のルール・スキル・フックの差異を横断比較
- **フック仕様調査**: [ai-tool-hooks-specification-survey.md](https://github.com/stlwolf/ai-development-hub/blob/master/docs/research/2026-03-30-ai-tool-hooks-specification-survey.md) — 3ツールのフック仕様（イベント名、JSON スキーマ、配信方式）

### 制御ループの実装に向けて

最大のギャップである「制御ループの不在」を埋めるために、自作オーケストレーション実装（[#19](https://github.com/stlwolf/ai-development-hub/issues/19): MVP）を計画している。その設計入力として、OSS オーケストレーションツール 25+ 本の調査と概念整理を [`orchestration-research`](https://github.com/stlwolf/ai-development-hub/tree/master/projects/orchestration-research) に集約済み。

設計思想は「deterministic orchestrator が non-deterministic agent を呼ぶ」構造（[設計スケッチ](https://github.com/stlwolf/ai-development-hub/blob/master/projects/orchestration-research/synthesis/architecture-sketch.md)）。Bash + jq で薄く始め、エンベロープ（タスク定義）→ ディスパッチャ（エージェント振り分け）→ 検証ゲート → 条件判定で再投入 or 完了、の1サイクル完走が MVP のゴール。ただし状態管理やエラーリカバリの複雑さから、段階的に Python/TS へ移行する可能性も視野に入れている。

---

## 7. ここまでやってきて見えてきたこと

ハーネスの整備と実案件での運用を並行して進める中で、いくつかの本質的な気づきが積み上がってきた。

### ハーネス = 自分自身の外在化

canonical に書いているルールやスキルは、AI のために新しく考えたものではなく、自分が開発するときに無意識にやっている判断の言語化。「Evidence First」も「Minimal Scope」も「implementation-gate」も、全部自分の開発スタイルそのもの。それをエージェントに読ませることで「自分と同じ判断ができるもう一人」を作っている。

### 「強制できるもの」と「確率的に従わせるもの」の分離

ハーネスの設計で最も重要な判断軸の一つ。

```
hooks（フック）  → 機械的に強制。exit code で 100% ブロック
rules（ルール）  → 散文による指示。読まれないリスク、解釈ブレあり
skills（スキル） → 手順書。ロード信頼性はツールにより異なる
```

安全系（破壊的コマンドのブロック等）は hooks で担保し、判断の文脈依存性が高いものは rules/skills で「確率的にブレを減らす」。この二層の見極めが、ハーネスの実効性を左右する。

### ルールの書き方一つで出力が変わる

同じルールでも、否定形か肯定形か、例外を先に書くか後に書くか、description を英語で書くか日本語で書くかで、モデルの遵守率が変わる。ツールごと（Cursor / Claude Code / Codex）でスキルロードのタイミングやトークン予算が違うので、同じ canonical でも効き方が異なる。

インタラクティブモードでエージェントの思考過程をリアルタイムで見ていると、ルールを調整した効果が最終出力の前にわかる。思考経路が自分の判断パターンと重なっているかどうかを感覚的に検知している。定量的な eval がなくても、自分自身が eval 関数として機能する。ただしそれはエンジニアとしての経験があるからこそ。

### 銀の弾丸はない — だから自分で育てる

ツールもフレームワークも、そのまま使えるものは存在しない。結局、自分の経験知と開発スタイルに合わせてブラッシュアップし続ける必要がある。canonical を実案件に sync して使い、そこで得たフィードバックでルールを磨き、またエージェントの思考を見て調整する。このループそのものがハーネスの品質を上げる。

### 個人ハーネスとチームハーネス

| 層 | 個人 | チーム |
|---|---|---|
| ハーネスの目指すもの | 「自分の分身」となるAI | 「チームの古参メンバー」となるAI |
| 共有できる層 | — | hooks（機械的強制）、安全ルール |
| 合意が必要な層 | — | ワークフロー定義（命名規約、CC、PR規約） |
| 個人に残る層 | 閾値、探索行動、チューニング | 各自が自分で育てる |

個人のハーネスこそが差別化要因になる可能性がある。canonical の「コード」は公開できても、ハーネスの「チューニング」は個人の経験知に紐づいている。AI 開発時代に差がつくのは、モデルの性能でもツールの選択でもなく、そのチューニングの精度。

チーム展開は、共有できる層（hooks・安全ルール・ワークフロー定義）を先に整備し、個人の層は各自が自分で育てるものとして扱う方が設計として健全。ただしこの「チームでのハーネス共有」の具体的方法論は、業界全体でもまだ誰も確立していない領域。

---

## 8. 目指しているところ

### 短期 — 部品の品質向上と制御ループの1サイクル実証

今ある canonical の部品（rules, skills, hooks）を実案件のフィードバックで磨きつつ、フックの拡充（[#24](https://github.com/stlwolf/ai-development-hub/issues/24)）で機械的に担保できる領域を広げる。並行して、オーケストレーション MVP（[#19](https://github.com/stlwolf/ai-development-hub/issues/19)）の1サイクル完走を目指す。「人間がループを回す」形でも構わないので、まず制御ループが一周する状態を作る。

### 中期 — 制御ループの自動化と検証の機械化

人間が手動で回しているループを段階的に自動化する。検証ゲートの実行証跡、ループ終了条件の宣言的定義、失敗蓄積（Negative Knowledge）の自動注入。ここが動くと、ハーネスが「部品の倉庫」から「自律的に品質を維持する装置」に変わる。

### 本質的なゴール — 自分の判断基準で動くもう一人のエンジニア

ハーネスの究極のゴールは「自分と同じ判断ができるエージェント」を作ること。ルールで行動規範を与え、スキルで手順を教え、フックで安全を担保し、制御ループで品質を維持する。そのすべてが、自分の経験知と開発スタイルの言語化。

これは個人に閉じない。チームにとっては「サービスの歴史的経緯や暗黙知を知っている古参メンバー」をハーネスとして外在化することで、属人化を解消し、誰でもアクセスできる集合知にする可能性がある。

ただし、今の業界にはチームハーネスの方法論は存在しない。個人のハーネスを実践し、そこで得た知見を元にチームへの展開パスを自分たちで作り出す必要がある。

---

## 9. チームでハーネスを育てるための設計哲学

チームハーネスの確立された方法論はまだ存在しない。ただし、個人での実践を通じて見えてきた原則がいくつかある。

### 枠組みが先、ルールは後

完璧なルールを書いてから配るのではなく、空の枠組み（ディレクトリ構造 + テンプレート）を先にチームに共有する。canonical の `rules/` `skills/` `hooks/` という構造自体が「ここに追加すればいい」という道標になる。中身は日常の開発でつまずいたとき、レビューで繰り返し指摘したとき、インシデントが起きたときに、その場で一つずつ埋めていく。

### 強制層から共有を始める

チームで最初に共有すべきは hooks（機械的ガードレール）。`rm -rf` のブロックや `--force-with-lease` の強制は、解釈の余地がなく、合意コストが低く、効果が確実。ルール（散文）は人によって読み方が違い、モデルによって遵守率が変わる。安全に関わるものから機械化し、判断が必要なものは後から段階的に足す。

```
導入順:  hooks（安全）→ ワークフロー定義（CC, PR規約）→ ルール（行動規範）→ スキル（手順書）
         確実 ─────────────────────────────────────────────→ 合意コスト高
```

### 個人の層を奪わない

ハーネスには「OS 部分」と「ユーザー設定」がある。

| 層 | 性質 | チームでの扱い |
|---|---|---|
| hooks + 安全ルール | 機械的・二値判定 | チーム共有（全員同じ） |
| ワークフロー定義 | 合意ベース | チーム共有（PR・コミット規約等） |
| 行動規範ルール | 文脈依存 | チーム推奨 + 個人カスタマイズ |
| 探索行動・閾値・input-style | 個人の癖 | 各自が自分で育てる |

チューニング（どこまで深掘りするか、どの閾値で人間に聞くか、音声入力のタイポをどう扱うか）は個人の開発スタイルそのもの。これを標準化しようとすると、ハーネスの最大の価値 —「自分と同じ判断ができるもう一人」— が失われる。

### 暗黙知の言語化装置として使う

チームにとってのハーネスの最大の価値は、暗黙知の外在化。

- 「このAPIは歴史的経緯でこうなっている」→ ルールに書く
- 「この操作は本番で事故ったことがある」→ フックでブロック + 理由をエラーメッセージに埋め込む
- 「レビューでいつも同じことを指摘している」→ スキルにする

これが蓄積されると、ハーネスは「チームの古参メンバー」として機能し始める。新しいメンバーが入っても、ハーネスがプロジェクトの文脈を伝える。属人化の解消とバスファクターの低減が、副次効果ではなく主要な効果になる。

### 正解はまだない — だから実践から作る

業界でチームハーネスの成功事例はほぼ報告されていない。OpenAI も LangChain も、公開しているのは個人またはチーム内の暗黙的な実践であって、再現可能な方法論ではない。

だからこそ、個人のハーネスで得た知見を元に、自分たちのチームに合った形を試行錯誤で作る価値がある。canonical という枠組みは、その実験の土台として設計されている。

---

## 10. 外部参考情報

### 論文・実証

- [NLAH 論文](https://arxiv.org/abs/2603.25723) — 自然言語ハーネスで OSWorld +16.8pt（清華大・ハルビン工大, 2026-03）
- [富士通 SWE-bench](https://blog.fltech.dev/entry/2026/04/07/swebench) — 27B モデルでハーネス設計のみで SOTA

### 主要記事

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/) — 最重要記事。100万行のプロダクトを人間がコードを書かずに構築
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) — 批評的考察
- [Anthropic: Harness Design](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Generator + Evaluator のマルチエージェント構造
- [Mitchell Hashimoto](https://mitchellh.com/writing/my-ai-adoption-journey) — 「ミスしたら二度と繰り返さない仕組みを作る」
- [LangChain](https://blog.langchain.com/improving-deep-agents-with-harness-engineering/) — ハーネス改善だけで Top 30 → Top 5
- [CADDi](https://caddi.tech/start-harness-engineering-with-framework) — 枠組みファーストのアプローチ
