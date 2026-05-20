---
name: cursor-kickoff
description: Cursor Composer 2.5 で壁打ち〜計画立案フェーズを実用化するためのお膳立てスキル。音声入力の断片を解釈し、暗黙の前提を読み、N≥3 案で多角展開し、必要に応じて question-driven-design / plan-to-kickoff / kickoff-to-plan / adversarial-review を呼び出す wrapper。壁打ち、設計、方針、ハーネス、canonical、sync 等のキーワードで発火。
depends:
  - skill: question-driven-design
  - skill: plan-to-kickoff
  - skill: kickoff-to-plan
  - skill: adversarial-review
---

# Cursor Kickoff — Composer 2.5 向け壁打ち〜計画立案ハーネス

## いつ使うか

- 音声入力の断片的・探索的指示を受け取ったとき
- 「壁打ち」「設計」「方針」「筋いい？」など実装前の議論フェーズ
- Cursor Composer 2.5 が以下の挙動を示しそうな状況:
  - 利用可能ツール（terminal 等）を最初に「使えません」と拒否しそうな状況
  - オープンクエスチョンを単一回答で打ち切ろうとする
  - 暗黙の前提（既存パターン、制約）を読まずに答えそう
- 暗黙の設計判断が複数ある新規タスク

## いつ使わないか

- 単純な事実確認（FACT_CHECK モード）
- ユーザーが明示的に実装方針を指定済み
- 既存パターン踏襲で済む軽微な修正

## 設計方針

本スキルは**新規実装ではなく wrapper / orchestrator**。Composer 2.5 が拾いきれない暗黙のお膳立てを補い、既存の汎用スキル (`question-driven-design`, `plan-to-kickoff`, `kickoff-to-plan`, `adversarial-review`) へ橋渡しする。

「贅肉」（解釈能力の弱さを補う冗長性）は意図的なコスト。再実装はしない。

観測可能な protocol で構成する。抽象的な「反省せよ」「よく考えよ」は性能劣化を招く（[arXiv:2503.00902 Instruct-of-Reflection](https://arxiv.org/abs/2503.00902)）。

## 上位 rule との関係

`canonical/cursor/rules/cursor-first-turn.mdc` が alwaysApply で常時注入される。本スキルはその rule が分類した `WALL_BOUNCE` / `PLAN` モード、あるいは Kickoff trigger キーワードを受けて発火する。

## Phase 1: 入力解釈

音声入力由来の可能性を前提に解釈する。

### 出力フォーマット

```md
### 入力解釈

#### 主意図
<one paragraph>

#### 補完した前提
- <implicit assumption>

#### タスク種別
`FACT_CHECK` | `WALL_BOUNCE` | `PLAN` | `EXECUTE`
```

ルール:

- 文法エラーを批評しない
- 妥当な解釈があれば聞き返さない
- 複数解釈ありなら列挙し、最も妥当な案で続行

## Phase 2: 能力 / コンテキスト確認

「使えません」と宣言する前に必ず検証する。

### 検査対象（関連する範囲のみ）

```text
README.md
canonical/
canonical/CATALOG.md
canonical/cursor/
canonical/rules/
canonical/skills/
docs/
scripts/
.cursor/
```

### 出力フォーマット

```md
### 能力確認

#### 確認できたこと
- <fact + path>

#### 未確認のこと
- <unknown>

#### 次に確認すべきこと
- <next inspection>
```

ルール:

- 「terminal は使えない」「ツールが無い」と verified なしに宣言しない
- repo 探索可能なら、一般論で答える前に既存パターンを確認する

## Phase 3: 根拠の分類

主要な主張を必ずラベル付けする。

| ラベル | 意味 |
|---|---|
| `確証` | inspected ファイル / 公式 docs / ログ / 直接観測した動作 |
| `推測` | 利用可能な context からの推論 |
| `未確認` | もっともらしいが検証していない |

ルール:

- 推測を事実として提示しない
- 不確実性を隠さない

## Phase 4: 多角展開

`WALL_BOUNCE` または `PLAN` モードでは N≥3 案を出す。

### 出力フォーマット

```md
### 候補案

#### Option A: <name>
- 概要:
- 向く条件:
- 強み:
- 弱み:
- 検証方法:

#### Option B: <name>
- ...

#### Option C: <name>
- ...
```

ルール:

- 「どうするか」「ありか」「筋いいか」系の問いには最低 3 案を提示
- 単独回答で打ち切らない
- ユーザーが明示的に 1 案を要求した場合のみ単案で良い

### 補助スキル

設計判断が多くて分岐の洗い出しが先に必要な場合、`question-driven-design` skill を呼び出す（質問駆動で前提を掘る）。

## Phase 5: 推奨

候補案の後に必ず推奨を出す。

### 出力フォーマット

```md
### 推奨

第一候補: <Option>

理由:
- <reason>

採用しない案:
- <Option>: <why not now>
```

ルール:

- 最小で可逆な変更を優先
- ハーネス変更は検証可能なものを優先
- always-on の冗長化は反復失敗が観測されてから

## Phase 6: Kickoff Doc 生成

`PLAN` モードに収束したら Kickoff Doc を生成する。

詳細フォーマットと変換ルールは `plan-to-kickoff` / `kickoff-to-plan` skill に従う。**ここで再実装しない**。

### Kickoff Doc 最低限スキーマ

```md
# Kickoff: <title>

## 1. Goal
## 2. Background
## 3. Confirmed facts
## 4. Assumptions
## 5. Constraints
## 6. Non-goals
## 7. Options
## 8. Recommendation
## 9. Implementation plan
## 10. Files to inspect or change
## 11. Validation
## 12. Risks
## 13. Open questions
```

Kickoff Doc を Plan に展開する場合は `kickoff-to-plan` skill を呼び出す。

## Phase 7: 品質チェック（Adversarial Review）

Plan が成立したら `adversarial-review` skill で漏れ・矛盾・曖昧さを検出する。

実装フェーズに入る前のゲートとして使う。

## Phase 8: 出力の圧縮

最終応答は次の構造に圧縮する。

```md
## 結論
<short recommendation>

## 確証 / 推測
<labeled facts and inferences>

## 候補
<options>

## 推奨
<recommendation>

## Kickoff Doc / 次の手
<doc if requested, or proposed next step>
```

避けるべき出力:

- 業界一般論の段落
- 漠然としたベストプラクティス
- ユーザー入力の言い換え反復
- 「状況による」と判定基準なし
- 無駄な聞き返し

## 関連スキル

| スキル | 役割 | 呼び出すタイミング |
|---|---|---|
| `question-driven-design` | 設計分岐の質問駆動掘り下げ | Phase 4 で分岐洗い出しが先に必要なとき |
| `plan-to-kickoff` | Cursor Plan → Kickoff Doc 変換 | Phase 6 で Cursor Plan Mode 出力を文書化するとき |
| `kickoff-to-plan` | Kickoff Doc → 実行可能 Plan 展開 | Phase 6 後、実装フェーズに入る前 |
| `adversarial-review` | Plan / Spec の品質チェック | Phase 7（実装ゲート前） |

## 関連 rule

- `canonical/cursor/rules/cursor-first-turn.mdc` — ターン1の自己能力宣言 / 即拒否禁止 / output mode 分類
- `canonical/rules/input-style-rule.md` — 音声入力解釈の汎用ルール
- `canonical/rules/decision-pacing-rule.md` — 「やるかどうか」を先に決める
- `canonical/rules/implementation-gate-rule.md` — 実装前の計画フェーズ強制

## 参考

- [Cursor Composer 2.5 公式 blog](https://cursor.com/blog/composer-2-5/) — training に "Reminder: Available tools..." 形式 feedback を使用
- [arXiv:2503.00902 — Instruct-of-Reflection](https://arxiv.org/abs/2503.00902) — static reflection は性能劣化、観測可能 protocol が必要
- [NLAH (arXiv:2603.25723)](https://arxiv.org/abs/2603.25723) — State Semantics / Failure Taxonomy 概念
- 戦略文書: `docs/draft/cursor-harness-strategy.md`
