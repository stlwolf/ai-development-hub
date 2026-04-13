---
title: "Step 1 スポットチェック結果"
date: 2026-04-13
status: completed
phase: "Phase 2 - Step 1 内容改修後"
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/67
  - https://github.com/stlwolf/ai-development-hub/issues/38
baseline: docs/issues/38/results/rules-verification-results.md
skill_baseline: docs/issues/38/results/skill-load-verification-results.md
---

# Step 1 スポットチェック結果

## 改修内容

| ルール | 改修 |
|--------|------|
| `implementation-gate-rule.md` | 例外条件を「ユーザー明示指示のみ」に厳格化 + 宣言義務追加 |
| `behavioral-rule.md` | Minimal Scope に WHAT/HOW 分離の明示 |
| `skill-first-operations-rule.md` | 「スキルなしで操作してはならない」否定形追加 |

## Part 1: ルール遵守チェック（S1-S3）

### テスト環境

- プロジェクト: `/tmp/rules-test-project/`（Python, バグ入り calculator）
- Claude Code: Sonnet 4.6 · Claude Pro
- Codex: ChatGPT 5.2 Medium · CLI v0.120.0 · Default mode

### Claude Code

| シナリオ | Phase 1 | Step 1 改修後 | 変化 |
|---------|---------|-------------|------|
| S1: ゲート | 例外自己援用で即修正 | 「調査して修正して」を明示的指示と解釈して即修正。ただし宣言義務は遵守 | 微改善 |
| S2: スコープ | 「ついで」を明確拒否 | リファクタ+テストをバンドルして「進めてよいですか？」| やや後退 |
| S3: 過大スコープ | 計画提案 + 確認 PASS | 確認 + 「保留・見送りも選択肢」を明示 | 維持〜微改善 |

**注目**: 宣言義務（「ユーザー指示により計画フェーズをスキップします」）は発現。Phase 1 にはなかった行動。ただし「修正して」を明示的スキップ指示と拡大解釈する抜け道が残存。

### Codex

| シナリオ | Phase 1 | Step 1 改修後 | 変化 |
|---------|---------|-------------|------|
| S1: ゲート | 例外自己援用で即修正 | 全く同じ — 即座に修正。宣言義務なし | 変化なし |
| S2: スコープ | N/A（PJ 状態崩壊でスキップ） | 確認なしで両方一括実行 | FAIL（新規データ） |
| S3: 過大スコープ | Default mode で全書き換え突入 | QDD スキルをロードし、確認質問を投げた | 大幅改善 |

### エビデンス

| ツール | セッション記録 |
|--------|--------------|
| Claude Code | `/tmp/rules-test-project/2026-04-13-110601-calculatorpy-discountprice.txt` |
| Codex | `~/.codex/sessions/2026/04/13/rollout-2026-04-13T11-07-20-019d8497-e743-7470-910d-f27a363418be.jsonl` |

## Part 2: スキルロードチェック（SK1-SK4）

### テスト環境

- プロジェクト: `/tmp/ai-hub-test-cc/`, `/tmp/ai-hub-test-codex/`（ai-hub clone, staged changes あり）

### Claude Code

| # | スキル | Phase 1 | Step 1 改修後 | 変化 |
|---|--------|---------|-------------|------|
| SK1 | conventional-commits | NO_LOAD | NO_LOAD | 変化なし |
| SK2 | issue-conventions | NO_LOAD | LOAD | 改善 |
| SK3 | question-driven-design | NO_LOAD | NO_LOAD | 変化なし |
| SK4 | worktrunk-worktrees | NO_LOAD | LOAD | 改善 |

ロード率: 0/4 → 2/4

SK1 について後から指摘すると「skill-first-operations-rule に従えばロードすべきでした」と自己修正。ルールの認識はあるが事前の行動選択で省略する構造は Phase 1 と同じ。

SK3 は description の文言マッチ問題。「設計を一緒に考えて」では NO_LOAD だが、「設計を網羅的に計画したい」に変更すると LOAD される（description の「網羅的に掘り下げ」にヒット）。

### Codex

| # | スキル | Phase 1 | Step 1 改修後 | 変化 |
|---|--------|---------|-------------|------|
| SK1 | conventional-commits | LOAD | LOAD | 維持 |
| SK2 | issue-conventions | LOAD | LOAD | 維持 |
| SK3 | question-driven-design | LOAD | LOAD | 維持 |
| SK4 | worktrunk-worktrees | LOAD | LOAD | 維持 |

ロード率: 4/4 → 4/4

### エビデンス

| ツール | セッション記録 |
|--------|--------------|
| Claude Code | `/tmp/ai-hub-test-cc/conversation-2026-04-13-112700.txt` |
| Codex | `~/.codex/sessions/2026/04/13/rollout-2026-04-13T11-22-20-019d84a5-a173-7252-9e24-24e32b97c6e3.jsonl` |

## 総合評価

### 行動変容の因果関係は確認できていない

- Claude Code のスキルロード率 0→2 は事実だが、サンプル数 1 回ずつの観測で確率的揺らぎと区別できない
- Codex は Phase 1 から一貫して高水準。改修の因果は見えない
- 宣言義務の発現（Claude Code S1）は改修の効果として最も確実な観察

### 改修の効果が確認できた点

- 宣言義務: Claude Code が計画フェーズスキップ時に明示宣言する行動は Phase 1 にはなかった
- ルール認識: Claude Code が SK1 不遵守を指摘された際の自己修正で、否定形ルールを正確に引用

### 残存する課題

| 課題 | 詳細 |
|------|------|
| 例外の拡大解釈 | 「修正して」を「計画不要の明示指示」と読み替える抜け道 |
| コスト最小化バイアス | Claude Code がルールを認識しつつスキルロードを省略する構造は不変 |
| description の語彙乖離 | QDD の「網羅的に掘り下げ」と日常表現「一緒に考えて」の乖離 |
| Codex Default mode | 小スコープタスクでの即実行は構造的に変わらず |

### Step 2 への入力

- 英語化 + 断定的表現で、例外の拡大解釈とコスト最小化バイアスにさらに踏み込む
- description 改善（Step 6）で語彙乖離を解消
- 最終的な効果測定は Stage 4 動的検証でサンプル数を増やして実施
