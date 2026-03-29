---
title: "Adversarial Spec Review スキル整備（A-2）"
date: 2026-03-29
type: kickoff
source: "Epic #10 — OSSツールキットパターンの選択的採用"
scope: canonical
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/11"
    reason: "本キックオフの対象 Issue"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/10"
    reason: "Epic #10 Tier 1"
  - type: source_material
    ref: "https://github.com/obra/superpowers/blob/main/skills/brainstorming/spec-document-reviewer-prompt.md"
    reason: "出典 A: Spec Document Reviewer（Plan 品質チェック）"
  - type: source_material
    ref: "https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/spec-reviewer-prompt.md"
    reason: "出典 B: Spec Compliance Reviewer（実装照合）"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "§3 adversarial review の優先度定義（B > A > C）"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/harness-engineering-mapping.md"
    reason: "Self-verification loop の位置づけ"
  - type: integration_target
    ref: "canonical/skills/kickoff-to-plan/SKILL.md"
    reason: "Plan 変換後に A を参照する導線"
  - type: integration_target
    ref: "canonical/commands/verification/peer-ai-review.md"
    reason: "Step 2.5 の計画レビュータイプから参照"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/17"
    reason: "Tier 1.5 でフックトリガーを追加（stop / subagentStop → followup_message）"
tags: [adversarial-review, skill, canonical, tier-1, epic-10]
---

# Adversarial Spec Review スキル整備（A-2）

## 背景

### 問題

現在の開発フローには「Plan/仕様の品質チェック」と「実装完了後の独立検証」の構造化されたプロセスがない。

- Plan 完了後: `kickoff-to-plan` で変換はするが、Plan 自体の漏れ・矛盾・曖昧さを機械的にチェックする仕組みがない
- タスク完了後: 実装者（エージェント含む）の完了報告を鵜呑みにし、実コードと仕様を照合する独立レビューがない
- `architecture-sketch.md` §3 で「親エージェントが fix-loop の結果に十分に懐疑的でない。人間が最終段階で抜けに気づいて戻すパターン」が課題として記録されている

### 出典

[superpowers](https://github.com/obra/superpowers)（MIT License）の2つのプロンプトテンプレートが、このギャップに直接対応する:

- **Spec Document Reviewer**: Plan/Spec 完成後に Completeness / Consistency / Clarity / Scope / YAGNI をチェック
- **Spec Compliance Reviewer**: 実装完了後に「実装者の報告を信用するな。実コードを読んで仕様と line-by-line で照合しろ」

これらを独自表現に落とし込み、自リポの既存ワークフローに統合する。

### ハーネスエンジニアリングとの対応

`harness-engineering-mapping.md` より:

> Self-verification loop = Adversarial Spec Review（Epic #10 A-2）+ pre-completion check（フック候補）

業界的には「ルールで祈るのではなく、検証ループで強制する」方向に収束。本スキルは検証ループの **プロンプト実体**。トリガーの自動化（フック）は #17 で対応。

## 成果物

**`canonical/skills/adversarial-review/SKILL.md`** — 1ファイル

タイミング別に2つのレビューモードを持つ単一スキル:

| モード | タイミング | 目的 | 起動元 |
|--------|-----------|------|--------|
| **Plan Review（A）** | Plan/Spec/Kickoff 完成後、実装着手前 | Plan 自体の品質チェック（漏れ・矛盾・曖昧さ・スコープ肥大・YAGNI） | 手動、または `kickoff-to-plan` 変換後 |
| **Compliance Review（B）** | タスク/サブエージェント完了後 | 実装が仕様と合致しているか独立検証。報告を信用せず実コードを読む | 手動、将来は `stop` / `subagentStop` フック |

## 実装計画

### Step 0: 前提確認（概算: 15分）

- [ ] superpowers リポジトリのライセンスが MIT であることを確認
- [ ] 出典2ファイルの内容を読み込み、自リポの既存ワークフローとの差分を特定
- [ ] `canonical/skills/` 配下の既存スキル（`so-compare/SKILL.md`, `kickoff-to-plan/SKILL.md`）のフォーマットを確認

### Step 1: SKILL.md 作成（概算: 1時間）

`canonical/skills/adversarial-review/SKILL.md` を作成する。

#### 1.1 YAML frontmatter

既存スキルのパターンに従う:

```yaml
---
name: adversarial-review
description: >
  Plan/Specの品質チェック（Plan Review）と、実装完了後の仕様照合（Compliance Review）を行う。
  サブエージェント注入用プロンプトテンプレートを含む。
---
```

#### 1.2 「いつ使うか」セクション

スキルの起動条件を明確に定義する。2モードそれぞれの起動条件:

- **Plan Review**: `kickoff-to-plan` 変換完了後、Plan を Agent mode で実行する前
- **Compliance Review**: サブエージェントがタスク完了報告をした後、結果をマージ/承認する前

#### 1.3 Plan Review プロンプトテンプレート

superpowers の Spec Document Reviewer を基に独自表現に再構成する。

入力: レビュー対象の Plan/Spec/Kickoff ファイルパス

チェック観点（superpowers の5カテゴリを踏襲しつつ自リポ向けに調整）:

| カテゴリ | チェック内容 |
|---------|------------|
| Completeness | TODO・プレースホルダ・TBD・未完成セクションがないか |
| Consistency | 内部矛盾・競合する要件がないか |
| Clarity | 実装時に誤解を生むほど曖昧な要件がないか |
| Scope | 1つの Plan で完結するか。独立したサブシステムが混在していないか |
| YAGNI | 依頼されていない機能・過剰設計がないか |

キャリブレーション（superpowers の設計思想を踏襲）:

> **実装計画に影響を与える本当の問題だけ指摘しろ。** 欠落セクション、矛盾、2通りに解釈できる要件 — それらは問題。文言の改善提案、スタイルの好み、「他のセクションより詳細が薄い」は問題ではない。深刻なギャップがない限り承認せよ。

出力形式:

```
## Plan Review

**Status:** Approved | Issues Found

**Issues (if any):**
- [セクション X]: [具体的な問題] - [なぜ実装計画に影響するか]

**Recommendations (advisory, do not block approval):**
- [改善提案]
```

#### 1.4 Compliance Review プロンプトテンプレート

superpowers の Spec Compliance Reviewer を基に独自表現に再構成する。

入力: (1) タスク要件の全文、(2) 実装者の完了報告

コア指示（superpowers の「報告を信用するな」を踏襲）:

> **実装者の報告を信用するな。** レポートは不完全・不正確・楽観的かもしれない。実コードを読んで検証せよ。

検証観点:

- **Missing requirements**: 要件を全て実装したか。スキップ・漏れはないか。実装したと主張しているが実際にはしていないものはないか
- **Extra/unneeded work**: 依頼されていないものを作っていないか。過剰設計・不要な機能追加はないか
- **Misunderstandings**: 要件を意図と異なる解釈をしていないか。正しい機能を間違った方法で実装していないか

出力形式:

```
## Compliance Review

**Status:** ✅ Spec Compliant | ❌ Issues Found

**Issues (if any):**
- [Missing/Extra/Misunderstanding]: [具体的な問題] - [file:line 参照]
```

#### 1.5 サブエージェント注入パターン

Task tool でサブエージェントとして起動する際のプロンプト組み立て方を記載する。

```
Task tool (explore or generalPurpose):
  description: "Review [plan/implementation]"
  prompt: |
    [SKILL.md の該当セクションから適切なテンプレートを選択]
    [レビュー対象のパスまたは内容を埋め込み]
```

#### 1.6 フック統合の設計メモ

Tier 1.5（#17）でフック化する際の想定を記載する（本 Step では実装しない）:

- `stop` フック → `followup_message` で Compliance Review の起動を自動注入
- `subagentStop` フック → サブエージェント完了時に同様の起動
- スキル本体はフックの有無に依存しない設計にする（手動起動でも機能する）

!! GATE: Step 1 完了レビュー

- SKILL.md が `canonical/skills/` の既存パターン（frontmatter + 「いつ使うか」+ 本文）に従っているか
- superpowers の表現をそのままコピペしていないか（独自表現への落とし込み）
- Plan Review / Compliance Review の起動条件が明確に分離されているか

### Step 2: 既存成果物との接続（概算: 30分）

#### 2.1 kickoff-to-plan からの参照導線

`canonical/skills/kickoff-to-plan/SKILL.md` のどこかに、Plan 変換完了後に adversarial-review の Plan Review を実行できる旨の導線を追加する。

追加は最小限（1-2行のリンク/参照）。kickoff-to-plan の構造を壊さない。

#### 2.2 peer-ai-review からの参照導線

`canonical/commands/verification/peer-ai-review.md` の Step 2.5（SOプロンプト構成）にある「計画レビュー」タイプから、Plan Review テンプレートを参照できるようにする。

追加は最小限（1-2行のリンク/参照）。peer-ai-review の構造を壊さない。

!! GATE: Step 2 完了レビュー

- 追加した参照が既存ファイルの構造・フローを壊していないか
- 参照先のパスが正しいか

### Step 3: sync 対応確認（概算: 15分）

- [ ] `scripts/sync/sync-cursor.sh` が `canonical/skills/adversarial-review/` を正しく同期するか確認
- [ ] `scripts/sync/sync-claude.sh` が同様に同期するか確認
- [ ] 必要に応じて sync スクリプトに追記（canonical/skills/ をワイルドカードで拾っているなら追記不要の可能性）

### Step 4: 試用（概算: 30分）

本リポまたはサービス開発リポで1回以上試用する。

#### 4.1 Plan Review の試用

- 既存の kickoff または plan ファイルを対象に、Plan Review テンプレートでサブエージェントを起動
- 結果の有用性を確認（過剰指摘していないか、重要な問題を見つけられるか）

#### 4.2 Compliance Review の試用

- 直近のタスク完了報告を対象に、Compliance Review テンプレートでサブエージェントを起動
- 実コードとの照合が機能しているか確認

試用ログは手元メモまたは `tmp/` 配下で十分（コミット不要）。

!! GATE: Step 4 完了 — 試用結果の判定

- 試用で致命的な問題が見つかった場合は Step 1 に戻って修正
- 軽微な調整は試用結果を踏まえてその場で対応

### Step 5: 成果物の AI レビュー（概算: 15分）

完成した SKILL.md に対して `so-compare` でセカンドオピニオンを取得する。プランどおりに作っても、意図した品質・網羅性になっているかは別問題。

- [ ] `so-compare -w "$(pwd)" "canonical/skills/adversarial-review/SKILL.md のレビュー。Plan Review / Compliance Review の起動条件の明確さ、プロンプトテンプレートの実用性、キャリブレーション（過剰指摘抑制）の妥当性を検証してください"` を実行
- [ ] 重大な指摘があれば修正。軽微な指摘は試用（Step 4）の結果と合わせて判断

!! GATE: Step 5 — AI レビュー結果の判定

- 重大な構造的欠陥の指摘がないか
- 指摘への対処判断（修正 / 受容 / 保留）を記録

## ライセンス

- superpowers リポジトリは MIT License
- プロンプトテンプレートは「独自表現に落とし込み」であり、そのままのコピペではない
- SKILL.md 冒頭または末尾に出典への帰属を1行記載する: 「superpowers (obra/superpowers, MIT) の Spec Document Reviewer / Spec Compliance Reviewer を参考に独自構成」

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| Plan Review が過剰指摘（ノイズ化） | レビューが無視されるようになる | キャリブレーション（「本当の問題だけ」）を強めに設定。試用で調整 |
| Compliance Review のコンテキスト消費 | メインセッションのコンテキストを圧迫 | サブエージェントとして起動し、結論サマリのみ返す構造にする |
| superpowers の表現をそのまま使ってしまう | ライセンス上のリスク、自スタックとの不整合 | Step 1 GATE で独自表現への落とし込みを確認 |

## 完了条件

- [ ] `canonical/skills/adversarial-review/SKILL.md` が存在する
- [ ] Plan Review / Compliance Review の2モードが定義されている
- [ ] サブエージェント注入用プロンプトテンプレートが Task tool でそのまま使える
- [ ] `kickoff-to-plan` から Plan Review への参照導線がある
- [ ] `peer-ai-review` から Plan Review への参照導線がある
- [ ] sync で `~/.cursor/skills/adversarial-review/` に配置される
- [ ] 1回以上試用し、結果に基づく調整が完了している
- [ ] 出典への帰属が記載されている

## スコープ外

- フック（`stop` / `subagentStop`）による自動起動 → #17（Tier 1.5）
- 全体完了時の成功条件照合（C レベル）→ Tier 3 以降
- Compliance Review の結果を構造化データとして保存する仕組み → orchestration-research Phase 4

## 参照

- [Issue #11](https://github.com/stlwolf/ai-development-hub/issues/11) — 本キックオフの対象
- [Epic #10](https://github.com/stlwolf/ai-development-hub/issues/10) — 親 Epic
- [Epic #10 補足コメント](https://github.com/stlwolf/ai-development-hub/issues/10#issuecomment-4150201176) — Tier 1 運用ルール
- [superpowers](https://github.com/obra/superpowers) — 出典リポジトリ（MIT）
- `projects/orchestration-research/synthesis/architecture-sketch.md` — adversarial review §3
- `projects/orchestration-research/synthesis/harness-engineering-mapping.md` — ハーネス対応
- [Cursor hooks 仕様](https://cursor.com/docs/hooks) — フック統合の設計参考
- [Issue #17](https://github.com/stlwolf/ai-development-hub/issues/17) — フック基盤整備（Tier 1.5）
