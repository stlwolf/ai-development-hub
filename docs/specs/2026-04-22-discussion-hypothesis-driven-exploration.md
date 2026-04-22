---
id: "01KPT49WX219D2VFWTWMWAXWSQ"
title: "仮説駆動探索の再現性 — 設計判断における網羅的選択肢探索"
date: 2026-04-22
type: discussion
status: draft
related:
  - type: evidence_for
    ref: projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md
    reason: "TTY direct write 発見プロセス — 本 discussion の具体的な事例"
  - type: design_context
    ref: projects/agent-verification-flow/docs/DESIGN_PRINCIPLES.md
    reason: "案B 逐次専門化（事実収集→仮説生成→仮説検証）のパターン"
  - type: design_context
    ref: ideas/20260208/hypothesis-second-opinion-review-flow.md
    reason: "SO レビューフローの仮説 — 反証担当の固定が核心"
  - type: sibling
    ref: docs/specs/2026-04-06-discussion-multi-round-control-loop.md
    reason: "多周制御の仕様 — findings 収束管理。本 discussion は仮説拡張の方向"
  - type: design_context
    ref: projects/orchestration-research/synthesis/architecture-sketch.md
    reason: "認知協調層（arena=発散、peer-review=収束）の位置づけ"
  - type: design_context
    ref: projects/orchestration-research/concepts/domain/06-feedback-validation.md
    reason: "BeeAI RequirementAgent の min_invocations パターン"
  - type: design_context
    ref: projects/arena-compare/docs/episodes/2026-03-04-exploration-mode-and-command-path.md
    reason: "探索モード — persistent-exploration の行動制約を SO/Arena に自動注入"
  - type: design_context
    reason: "別プロジェクトの Sentry 調査中に抽出されたコードパス網羅原則。同じ「網羅性が保証される前に結論に飛ぶな」構造"
tags: [hypothesis-driven, exploration, so-compare, arena-compare, persistent-exploration, reproducibility, exhaustion-before-conclusion]
---

# 仮説駆動探索の再現性 — 設計判断における網羅的選択肢探索

## 1. 問題

wez notify の設計検証で、SO ゼロベースレビューにより初期選択肢セット（A/B）に含まれていなかった option C（TTY 直接書き込み）が発見され、最適解として採用された（詳細: [episode](../../projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md)）。

この発見は**人間の即興的判断**に依存していた。「確定したけど、もう一回ゼロベースで聞いてみよう」という判断がなければ、副作用のある command string 方式で確定していた。

**問い**: この種の「確定する前に、未探索の代替案がないか網羅的に探索する」パターンを、再現可能な仕組みにできないか。

## 2. 発見プロセスの構造分析

### 今回揃った4条件

| # | 条件 | 今回の具体例 | 再現の障壁 |
|---|------|-------------|-----------|
| 1 | 確定後のゼロベース再探索 | A に確定した後で SO に「他に選択肢はないか」と依頼 | 人間が「もう一回聞いてみよう」と判断する必要がある |
| 2 | 反証可能なプロンプト | 「確認して」ではなく「ゼロベースで検証して」 | プロンプト設計が暗黙知 |
| 3 | 提案の即時実機検証 | Claude の提案をその場で検証コマンド実行 | 検証コマンドの生成と実行が手動 |
| 4 | 検証環境の即時利用可能性 | WezTerm が動いていてすぐ試せた | ドメイン依存 |

条件1と2はプロンプト構造化で対処可能。条件3は半自動化の余地あり。条件4はドメイン固有で仕組み化が難しい。

### コードパス網羅原則との構造的類似

別プロジェクトの Sentry 調査中に、同じ構造の問題がバグ調査ドメインで発生・記録されている。

**事象**: エラー調査で、入力→出力のコードパスに未読区間が残った状態で外部仮説（インフラ差異）に飛んだ。コードを全て読んでいれば 2 ステップで解決するところを 6 ステップかかった。

**抽出された原則 — コードパス網羅原則（Code Path Exhaustion Principle）**:
> エラー調査において、入力から出力までのコードパスに未読区間がある限り、外部要因の仮説に進むな。

**仮説ファイルによるループ検出**: 各仮説を `tmp/hypothesis-NNN.md` に外部化し、空転（同じ抽象度での横移動）を物理的に可視化する概念。N 個蓄積で Hook/オーケストレーション層が介入（スキル強制ロード等）。

### 共通する上位原則

| バグ調査（コードパス網羅） | 設計判断（今回） |
|---|---|
| コードパスに未読区間がある状態で外部仮説に飛ぶ | 選択肢に未探索の代替案がある状態で確定する |
| 「全て読んでから外部仮説に進め」 | 「ゼロベースで代替案を探索してから確定しろ」 |
| 仮説ファイルの外部化でループ検出 | 選択肢の外部化で探索網羅性を可視化 |
| N 個蓄積で介入 | 確定前にゼロベース SO を強制 |

**Exhaustion Before Conclusion**: 網羅性が保証される前に結論に飛ぶな。

## 3. 既存ツール群のギャップ

| 今回起きたこと | 既存ツールでの対応 | ギャップ |
|---|---|---|
| 確定後にゼロベース再探索 | **なし** | persistent-exploration は「不可能」判定時のみ発動。設計判断の「確定」前には発動しない |
| 選択肢の拡張（A,B → A,B,C） | arena-compare（発散） | arena は「同一質問を複数モデルに聞く」。**「知らない選択肢を生成させる」プロンプト構造がない** |
| 即時実機検証 | **なし** | SO/Arena の出力は読むだけ。検証コマンドの生成・実行は人間が手動 |
| 検証結果の再注入 | `so-compare --prev` | 手動チェーン。「検証結果を踏まえて再提案」のループが構造化されていない |

最大のギャップ: 「A で確定、先に進む」が通常フローで、「確定前にまだ探索する」トリガーがない。

## 4. 学術的アプローチとの接続

2026年の最新研究で、今回のパターンと構造的に類似するアプローチが複数報告されている。

| 研究 | アプローチ | 今回との接点 |
|------|-----------|-------------|
| **EXPERIGEN** | Generator（仮説提案）+ Experimenter（実験的検証）の2相。ベイジアン最適化的探索 | 「SO が提案→即時検証」のループと同型 |
| **Nomad** | Exploration Map を構築し系統的に traversal。独立 Verifier がチェック | 選択肢の構造化 + 独立検証の分離 |
| **Re-TRAC** | trajectory 後に「証拠・不確実性・失敗・今後の計画」を要約し次の条件に | 検証結果のフィードバックループ |
| **DeepVerifier** | 失敗分類（5大分類・13小分類）から rubric を自動生成 | 探索の網羅性を rubric で保証 |

共通するパターン: **仮説生成と仮説検証を分離し、検証結果を構造化してフィードバックする**。

## 5. 既存の蓄積との接続

### agent-verification-flow 案B（逐次専門化）

バグ調査で実証済みのパターン: 事実収集者→仮説生成者→仮説検証者+対立仮説探索者。設計判断への未適用。

### 多周制御（discussion-multi-round-control-loop）

SO の findings 収束を管理する仕様。findings の**縮小**（resolved/dismissed で閉じる）は定義済みだが、findings の**拡張**（新しい選択肢の生成）は未定義。

### 探索モード（arena-compare exploration-mode）

persistent-exploration の行動制約を peer-ai-review / arena に自動注入。ただしトリガーは「不可能」回答 or モデル間の結論分裂。「確定前の網羅性チェック」はトリガーに含まれない。

### BeeAI RequirementAgent

`min_invocations` / `force_at_step` で試行回数を宣言的に強制。「確定前にゼロベース探索を最低1回実行」をルールとして表現可能な概念。

## 6. 方向性

### 層1: プロンプト構造化（即効性あり）

SO / Arena に投げるプロンプトに「選択肢拡張セクション」を構造テンプレートとして追加する。

```markdown
## 選択肢拡張（必須）
- 上記の選択肢以外に、技術的に可能な代替アプローチを提案してください
- 提案には「検証可能な条件」を必ず付与してください
- 「なぜこの選択肢が元の選択肢群に含まれていなかったか」を説明してください
```

適用タイミング: 設計判断（DJ-N）を含むキックオフや SO レビュー時。so-compare スキルのプロンプト設計原則セクションに追加。

### 層2: スキルまたはコマンドの新設

persistent-exploration の設計判断版。形態（スキル / コマンド / 既存スキル拡張）は層1 の実践結果を見て決定。

考えられる要素:
- トリガー: 設計判断の「確定」直前
- 行動制約: 最低1回のゼロベース SO を実施してから確定
- 探索木: 選択肢とその検証結果を構造化（persistent-exploration の探索木フォーマット応用）
- 完了条件: 「新規選択肢なし」または「新規選択肢を検証して採否を決定」
- 仮説ファイルプロトコル: コードパス網羅原則で提案された外部化メカニズムの設計判断版

### 層3: 検証ループ半自動化（将来）

オーケストレーション研究の BeeAI RequirementAgent パターン（`min_invocations`, `force_at_step`）を参考に、SO/Arena の出力から「検証可能な仮説」を抽出して検証コマンドを提案するフローを構造化。EXPERIGEN の Generator + Experimenter パターンとも整合。

## 7. 次のアクション

- [ ] 層1: so-compare スキルの「プロンプト設計原則」に選択肢拡張テンプレートを追加
- [ ] 層1 を次の設計判断（wez notify 実装中、または別タスク）で実践し、効果を観察
- [ ] 実践結果を踏まえて層2 の形態（スキル / コマンド / 既存拡張）を判断
- [ ] コードパス網羅原則の仮説ファイルプロトコルと合わせて、設計判断版の外部化メカニズムを検討
