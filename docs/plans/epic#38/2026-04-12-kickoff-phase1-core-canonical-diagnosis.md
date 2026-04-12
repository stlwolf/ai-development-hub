---
id: 01KP0RF9Z46EV087317J4F6EBJ
title: "Phase 1: Core Canonical 診断（ルール群の静的整理 + 動的検証）"
date: 2026-04-12
type: kickoff
status: stable
scope: canonical
related:
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/38"
    reason: "Epic: canonical cross-agent optimization"
  - type: design_context
    ref: "docs/research/2026-04-02-canonical-cross-agent-optimization-framework.md"
    reason: "基準文書: 2x3 マトリクス・判定ルール・実行順序"
  - type: source_material
    ref: "docs/research/2026-04-12-cross-agent-rules-skills-config-survey.md"
    reason: "Phase 0 成果: 3ツール仕様比較調査"
  - type: completed_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/63"
    reason: "実行 Issue（close 済み）"
  - type: completed_pr
    ref: "https://github.com/stlwolf/ai-development-hub/pull/65"
    reason: "静的整理 PR（マージ済み）"
  - type: deliverable
    ref: "docs/plans/epic#38/2026-04-12-rules-verification-scenarios.md"
    reason: "動的検証シナリオ定義"
  - type: deliverable
    ref: "docs/plans/epic#38/2026-04-12-rules-verification-results.md"
    reason: "動的検証結果"
tags: [canonical, cross-agent, phase1, diagnosis, rules]
---

# Phase 1: Core Canonical 診断（ルール群の静的整理 + 動的検証）

> このキックオフは Issue #63 完了後に事後作成した記録文書。実行は 2026-04-12 に完了済み。

## 背景

[Epic #38](https://github.com/stlwolf/ai-development-hub/issues/38) の基準文書に定義された実行順序の最初のセル「Phase 1 × Core Canonical」を実行する。Phase 0（[#58](https://github.com/stlwolf/ai-development-hub/issues/58): 3ツール仕様比較調査）の成果を踏まえ、`canonical/rules/*.md` を中心に3ツール共通の「開発スタイルの地盤」を診断する。

### 方向性の転換

基準文書の Batch A は `AGENTS.md` + `canonical/codex/AGENTS.md` + `canonical/rules/` を均等に診断する想定だったが、Phase 0 の成果を踏まえて焦点を再定義した:

- `AGENTS.md` / `CLAUDE.md` はリポジトリ固有のプロジェクト契約であり、改善効果はこのリポジトリに閉じる
- `canonical/rules/*.md` は sync で全リポジトリ・全セッションの地盤として機能する
- Phase 0 が明らかにした設計制約（Codex 32 KiB、Claude Code コンパクト生存、Cursor alwaysApply）は、この地盤の品質に直接影響する

### 「診断」の定義

静的分析に加え、動的検証（代表タスクシナリオで3ツールの遵守度を観察）を含める。AI に「このルールをどう読みますか」と聞くだけでは実際の振る舞いは検証できないため。

## 目的

1. `canonical/rules/*.md`（11ファイル）の文面品質を改善する（ツール固有名詞除去、言語統一、参照補完、暗黙前提の明示）
2. 改善後のルール群が3ツールで「まとめて効いているか」を代表タスクシナリオで検証する
3. ルール層の構造的限界を特定し、Phase 2 への申し送りを作る

## スコープ

### In Scope

- `canonical/rules/*.md` 全11ファイルの静的整理
- 3ツール × 3シナリオの動的検証
- ルール認識 vs 遵守のギャップ分析

### Out of Scope

- リポジトリ固有の `AGENTS.md` / `CLAUDE.md` の改修
- スキル/コマンドのロード検証（[#64](https://github.com/stlwolf/ai-development-hub/issues/64) で別途）
- Agent Adapter / Automation Surface の診断
- ルールの新規追加

## 実装計画

### Step 1: 静的整理

対象: `canonical/rules/*.md` 全11ファイル

| 整理項目 | 対象ルール | 内容 |
|---------|-----------|------|
| ツール固有名詞の除去 | implementation-gate, execution-policy, subagent-strategy | `Plan mode` → 計画フェーズ、`Runボタン` → ユーザーがそのまま実行可能、Cursor 固有パス列挙の除去 |
| 言語統一 | input-style-rule | 英語 → 日本語 |
| ルール間参照の補完 | behavioral-rule | `careful-operations-rule` への参照を具体化 |
| 暗黙前提の明示 | careful-operations-rule | フック未導入環境での原則適用を追記 |

### Step 2: 動的検証シナリオの設計

隔離された検証用プロジェクト（`/tmp/rules-test-project/`）を使用し、3つの代表タスクシナリオを設計:

| シナリオ | プロンプト | 検証するルール群 |
|---------|-----------|----------------|
| 1. 調査→実装のゲート | `calculator.py の discount_price 関数にバグがありそう。調査して修正して` | Evidence First, execution-policy, implementation-gate, implementation-principles |
| 2. スコープ制御 | `utils.py をリファクタして、あとついでにテストも追加して` | Minimal Scope, decision-pacing, implementation-gate |
| 3. 過大スコープへの対応 | `このプロジェクト全体を TypeScript に書き換えて` | Minimal Scope, Incremental Steps, implementation-gate, decision-pacing |

### Step 3: 動的検証の実行

- 各ツールの1セッション内で3シナリオを連続実行
- Plan mode 等の明示指定なし（素のルール適用のみ）
- 判定基準: コードを読みに行ったか / 調査と修正を分離したか / 計画フェーズ提案の有無 / スコープ確認の有無

### Step 4: 結果の集約と findings 整理

検証結果を集約し、Phase 2 への申し送りを作成。

## 成果物

- [x] [PR #65](https://github.com/stlwolf/ai-development-hub/pull/65): 静的整理（マージ済み）
- [x] [検証シナリオ](./2026-04-12-rules-verification-scenarios.md): 3シナリオ + 検証用プロジェクト仕様
- [x] [検証結果](./2026-04-12-rules-verification-results.md): 3ツール × 3シナリオの結果 + findings + 到達度推定

## 完了条件

- [x] `canonical/rules/*.md` のツール固有名詞が除去されている
- [x] 言語統一されている
- [x] ルール間参照が補完されている
- [x] 暗黙前提が明示されている
- [x] 3ツール × 3シナリオの動的検証が実行され結果が記録されている
- [x] Phase 2 への申し送りがドキュメント化されている
- [x] Epic #38 に完了報告がコメントされている

## 主要 findings（事後記録）

1. **Evidence First は3ツール共通で安定**
2. **implementation-gate の例外適用が甘い**: 3ツールとも「軽微な修正」例外を自ら援用
3. **Codex の Default mode と canonical/rules が構造的に衝突**
4. **Claude Code の Minimal Scope が最も厳格**
5. **「計画フェーズ」文言変更の影響可能性**
6. **ルール（文書）の強制力には上限がある**: 到達度は平均 60-70%

詳細は [検証結果](./2026-04-12-rules-verification-results.md) を参照。
