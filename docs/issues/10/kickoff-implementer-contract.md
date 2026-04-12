---
title: "サブエージェント Implementer 契約の定義（A-5）"
date: 2026-03-29
type: kickoff
source: "Epic #10 — OSSツールキットパターンの選択的採用"
scope: canonical
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/12"
    reason: "本キックオフの対象 Issue"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/10"
    reason: "Epic #10 Tier 1"
  - type: source_material
    ref: "https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/implementer-prompt.md"
    reason: "出典: Implementer Subagent Prompt Template"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/harness-engineering-mapping.md"
    reason: "「ミスしたら環境改善」パターン — BLOCKED 処理の位置づけ"
  - type: integration_target
    ref: "canonical/rules/subagent-strategy-rule.md"
    reason: "既存のサブエージェント戦略ルールから参照"
  - type: sibling
    ref: "https://github.com/stlwolf/ai-development-hub/issues/11"
    reason: "#11 Adversarial Review の Compliance Review が本契約の報告を検証する側"
tags: [implementer-contract, skill, canonical, tier-1, epic-10, subagent]
---

# サブエージェント Implementer 契約の定義（A-5）

## 背景

### 問題

サブエージェント（Task tool）に実装タスクを委譲する際、現状では:

- 報告フォーマットが統一されていない（何を報告すべきかが委譲者の記述に依存）
- 完了ステータスが曖昧（「できました」と「懸念ありだが一応完了」の区別がない）
- self-review の仕組みがなく、実装者が自分の出力を検証しないまま報告する
- 「わからない」「詰まった」のエスカレーション手段が定義されていない

`subagent-strategy-rule.md` にはサブエージェントの起動戦略（カスタムエージェント優先、1タスク1サブエージェント）があるが、**返却契約**（何をどう報告するか）が欠けている。

### 出典

[superpowers](https://github.com/obra/superpowers)（MIT License）の Implementer Subagent Prompt Template が、以下を構造化した形で定義している:

- **ステータス enum**: `DONE` / `DONE_WITH_CONCERNS` / `BLOCKED` / `NEEDS_CONTEXT`
- **Before You Begin**: 着手前に不明点を質問する（推測で進めない）
- **When You're in Over Your Head**: エスカレーション条件の明示
- **Self-Review**: Completeness / Quality / Discipline / Testing の4軸チェック
- **Report Format**: ステータス + 実装内容 + テスト結果 + 変更ファイル + 懸念事項

### ハーネスエンジニアリングとの対応

`harness-engineering-mapping.md` より:

> 「ミスしたら環境を改善する」パターン = Negative Knowledge 昇格 + Implementer 契約の BLOCKED 処理

BLOCKED / NEEDS_CONTEXT でのエスカレーションは、問題を握りつぶさず環境改善に変えるためのチャネル。

## 成果物

**`canonical/skills/implementer-contract/SKILL.md`** — 1ファイル

内容:
- ステータス enum の定義と使い分け基準
- 報告フォーマットテンプレート
- self-review チェックリスト
- エスカレーション条件と手順
- Task tool でそのまま貼れるプロンプトテンプレート

## 実装計画

### Step 0: 前提確認（概算: 15分）

- [ ] superpowers リポジトリのライセンスが MIT であることを確認（#11 と共通、実施済みなら省略）
- [ ] 出典の Implementer Prompt Template を読み込み
- [ ] 現在のサブエージェント委譲パターンを確認（`peer-ai-review.md` の Step 3、`subagent-strategy-rule.md`）
- [ ] 既存スキルのフォーマット確認（`so-compare/SKILL.md` 等）

### Step 1: SKILL.md 作成（概算: 1時間）

`canonical/skills/implementer-contract/SKILL.md` を作成する。

#### 1.1 YAML frontmatter

```yaml
---
name: implementer-contract
description: >
  サブエージェントへの実装委譲時の返却契約。ステータスenum、報告フォーマット、
  self-reviewチェックリスト、エスカレーション条件を定義する。
---
```

#### 1.2 「いつ使うか」セクション

- Task tool でサブエージェントに実装タスクを委譲するとき
- サブエージェントのプロンプトに注入するテンプレートとして使用

#### 1.3 ステータス enum

superpowers の4値を踏襲し、独自の使い分け基準を定義する:

| ステータス | 意味 | 使用条件 |
|-----------|------|---------|
| `DONE` | タスク完了。self-review 通過、懸念なし | 要件を全て実装し、self-review で問題なし |
| `DONE_WITH_CONCERNS` | タスク完了だが懸念あり | 実装は完了したが、正確性に疑い、スコープ逸脱の可能性、想定外の副作用等 |
| `NEEDS_CONTEXT` | 情報不足で判断できない。**追加情報があれば再開可能** | 要件が曖昧、必要なコードが見つからない、依存関係が不明 |
| `BLOCKED` | 続行不可能。**情報追加だけでは解消せず、方針変更・タスク分割・上位判断が必要** | アーキテクチャ判断が必要、自分の能力を超えている、前提が崩れている |

**重要**: `DONE_WITH_CONCERNS` を使うことは弱さではない。不確実な成果物を `DONE` と報告するほうが有害。

#### 1.4 報告フォーマット

```markdown
## Implementation Report

**Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED

**What I implemented:**
- [実装内容の箇条書き]

**Files changed:**
- [変更ファイル一覧]

**What I tested:**
- [テスト内容と結果]

**Self-review findings:**
- [self-review で発見した事項。なければ「Issues: None」]

**Concerns (DONE_WITH_CONCERNS の場合):**
- [具体的な懸念事項]

**Blocked on (BLOCKED / NEEDS_CONTEXT の場合):**
- [何に詰まっているか]
- [試したこと]
- [必要な情報・判断]
```

#### 1.5 Self-review チェックリスト

superpowers の4軸を踏襲し、自リポの文脈に調整:

**Completeness（完全性）**:
- 仕様の全要件を実装したか
- 見落とした要件はないか
- 未処理のエッジケースはないか

**Quality（品質）**:
- 命名は明確で正確か（実装方法ではなく、何をするかを表現しているか）
- コードは読みやすく保守しやすいか
- 既存パターンに従っているか

**Discipline（規律）**:
- YAGNI: 依頼されていないものを作っていないか
- 依頼範囲のみ対応しているか（「ついで」の変更をしていないか）
- ファイルが計画以上に肥大化していないか

**Testing（検証）**:
- テストが実際の振る舞いを検証しているか（モックの振る舞いではなく）
- テストは包括的か

self-review で問題を発見したら、**報告前に修正する**。修正不能な場合は `DONE_WITH_CONCERNS` で報告。

#### 1.6 エスカレーション条件

superpowers の「When You're in Over Your Head」を独自表現に再構成:

以下のいずれかに該当する場合、推測で進めずに **BLOCKED** または **NEEDS_CONTEXT** で報告する:

- 複数の妥当なアプローチがあり、アーキテクチャ判断が必要
- 提供されたコンテキスト外のコード理解が必要で、自分で見つけられない
- 自分のアプローチが正しいか確信が持てない
- 計画が想定していないコード再構成が必要
- ファイルを次々に読んでいるが、理解が進んでいない

**「悪い成果物は、成果物なしよりも有害」**。エスカレーションにペナルティはない。

#### 1.7 着手前の確認

superpowers の「Before You Begin」パターン:

実装に着手する前に、以下が不明な場合は **先に質問する**:
- 要件やアクセプタンス基準
- アプローチや実装戦略
- 依存関係や前提条件

**実装中も同様**: 予想外の状況や不明点に遭遇したら、推測せず質問する。

#### 1.8 プロンプトテンプレート

Task tool でサブエージェントに注入するプロンプトの完成形テンプレートを記載する。上記の全要素（ステータス enum、self-review、エスカレーション条件、報告フォーマット）を含む。

テンプレートは `[タスク説明]` `[コンテキスト]` `[作業ディレクトリ]` のプレースホルダを持ち、委譲者が埋める形式。

!! GATE: Step 1 完了レビュー

- SKILL.md が既存パターンに従っているか
- superpowers の表現をそのままコピペしていないか（独自表現への落とし込み）
- ステータス enum の使い分け基準が明確か
- self-review チェックリストが自リポのルール（Minimal Scope, Follow Existing Patterns 等）と整合しているか

### Step 2: subagent-strategy-rule.md からの参照（概算: 15分）

`canonical/rules/subagent-strategy-rule.md` に、implementer-contract スキルへの参照を最小限（1-2行）追加する。

追加位置の候補: 「基本方針」セクションの「1サブエージェント1タスクで集中させる」の後に、実装委譲時の返却契約への参照。

既存ルールの構造を壊さない。

!! GATE: Step 2 完了レビュー

- ルールファイルの構造・分量が大きく変わっていないか
- 参照先パスが正しいか

### Step 3: sync 対応確認（概算: 10分）

全ターゲット（cursor / claude / codex）で `canonical/skills/implementer-contract/` が正しく同期されるか確認する。

- [ ] `./scripts/sync.sh --list` で対象確認
- [ ] `./scripts/sync.sh` 実行後、`~/.cursor/skills/implementer-contract/`、`~/.claude/skills/implementer-contract/`、`~/.codex/skills/implementer-contract/` に配置されるか確認
- [ ] 必要に応じて各 sync スクリプトに追記（canonical/skills/ をワイルドカードで拾っているなら追記不要の可能性）

### Step 4: 試用（概算: 30分）

本リポまたはサービス開発リポで1回以上試用する。

- Task tool でサブエージェントを起動する際にプロンプトテンプレートを注入
- サブエージェントが報告フォーマットに従って報告するか確認
- ステータス enum が適切に使い分けられるか確認
- self-review が機能しているか確認

試用ログは手元メモまたは `tmp/` 配下で十分。

!! GATE: Step 4 完了 — 試用結果の判定

- 報告フォーマットに過不足がないか
- self-review チェックリストの粒度は適切か（多すぎてノイズ化していないか）
- エスカレーション条件は実用的か

### Step 5: 成果物の AI レビュー（概算: 15分）

完成した SKILL.md に対して `so-compare` でセカンドオピニオンを取得する。プランどおりに作っても、意図した品質・網羅性になっているかは別問題。

- [ ] `so-compare -w "$(pwd)" "canonical/skills/implementer-contract/SKILL.md のレビュー。ステータス enum の使い分け基準、報告フォーマットの実用性、self-review チェックリストの粒度、エスカレーション条件の妥当性を検証してください"` を実行
- [ ] 重大な指摘があれば修正。軽微な指摘は試用（Step 4）の結果と合わせて判断

!! GATE: Step 5 — AI レビュー結果の判定

- 重大な構造的欠陥の指摘がないか
- 指摘への対処判断（修正 / 受容 / 保留）を記録

## #11 Adversarial Review との接続

- #11 の **Compliance Review（B）** は、本契約の報告を受けて「実装者の報告を信用するな。実コードを読んで検証しろ」を実行する側
- 本契約が報告フォーマットを定義し、Compliance Review がそのフォーマットを入力として検証する
- 両方が揃うことで「実装 → 自己レビュー → 独立レビュー」のパイプラインが成立

## ライセンス

- superpowers リポジトリは MIT License
- プロンプトテンプレートは独自表現への落とし込み
- SKILL.md に出典帰属を1行記載: 「superpowers (obra/superpowers, MIT) の Implementer Subagent Prompt Template を参考に独自構成」

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| self-review チェックリストが重すぎてサブエージェントが冗長になる | タスク完了が遅延、コンテキスト消費増 | 項目数を絞る。Completeness / Discipline の2軸が最小セット |
| BLOCKED / NEEDS_CONTEXT の乱用 | エスカレーションが増えて親エージェントの負担増 | 「最低限自分で試すべきこと」をエスカレーション条件に含める |
| 報告フォーマットをサブエージェントが無視する | 契約が機能しない | プロンプト末尾に報告フォーマットを再掲。将来的にはフック（subagentStop）で構造化検証 |

## 完了条件

- [ ] `canonical/skills/implementer-contract/SKILL.md` が存在する
- [ ] ステータス enum（DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED）が定義されている
- [ ] 報告フォーマットが定義されている
- [ ] self-review チェックリストが定義されている
- [ ] エスカレーション条件が定義されている
- [ ] Task tool 注入用プロンプトテンプレートがそのまま使える
- [ ] `subagent-strategy-rule.md` から参照導線がある
- [ ] sync で全ターゲット（cursor / claude / codex）に配置される
- [ ] 1回以上試用し、結果に基づく調整が完了している
- [ ] 出典への帰属が記載されている

## スコープ外

- オーケストレーション protocol（B-9）→ 本契約の定着後に検討
- フック（`subagentStop`）による報告フォーマットの機械的検証 → #17
- Negative Knowledge 昇格の仕組み → Tier 3

## Appendix: SO レビュー指摘事項（実装時に検討）

キックオフ文書に対する SO レビュー（2026-03-29、出力: `tmp/so-20260329-231404/`）で指摘された事項のうち、キックオフ修正ではなく **実装時に対応** するもの。

### A-1. #11 との受け渡しマッピング（Codex, Medium）

報告フォーマットの `What I implemented` に「要件→実装箇所」の最小マッピングがないと、Compliance Review の照合コストが高い。Step 1.4 で報告フォーマットを定義する際に検討する。

### A-2. superpowers 取り込み漏れ（Codex, Medium）

- 「勝手なファイル分割・再構成をしない」（Code Organization 抑制）
- 「TDD required の場合は順守したか」の self-review 項目

Step 1.5 (self-review) と Step 1.6 (エスカレーション) で明示する。

### A-3. リスク追加（Codex, Low）

- 「ステータス過少申告（本来 DONE_WITH_CONCERNS なのに DONE）」
- 「テスト未実行環境での見かけ上完了」

リスク表に追加するか、self-review チェックリストで吸収するか Step 1 で判断。

## 参照

- [Issue #12](https://github.com/stlwolf/ai-development-hub/issues/12) — 本キックオフの対象
- [Epic #10](https://github.com/stlwolf/ai-development-hub/issues/10) — 親 Epic
- [Epic #10 補足コメント](https://github.com/stlwolf/ai-development-hub/issues/10#issuecomment-4150201176) — Tier 1 運用ルール
- [superpowers](https://github.com/obra/superpowers) — 出典リポジトリ（MIT）
- `projects/orchestration-research/synthesis/harness-engineering-mapping.md` — ハーネス対応
- [Issue #11](https://github.com/stlwolf/ai-development-hub/issues/11) — Adversarial Review（Compliance Review が本契約の報告を検証する）
