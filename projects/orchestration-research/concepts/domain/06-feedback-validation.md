# Feedback & Validation — フィードバック・検証

> エージェントの出力や行動の **品質をどう保証するか** を定める概念群。事前制約、実行時監視、事後検証の3時点で品質を管理する。

## この領域の問い

- 不適切な出力をどう事前に防ぐか
- 実行中の異常（ループ、スタック）をどう検出するか
- 出力の品質をどう事後的に検証するか
- 宣言的なルールでエージェントの行動をどう制約するか

## 核となる概念

### Guardrail（ガードレール）

入力や出力の安全性・妥当性を自動チェックする仕組み。**事前防止** のメカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenAI Agents SDK | `Guardrail` (4種) | `InputGuardrail`, `OutputGuardrail`, `ToolInputGuardrail`, `ToolOutputGuardrail`。`tripwire` で即座にhalt |
| CrewAI | `Task Guardrails` | 関数ベース / LLMベース。タスク単位で設定 |
| PentAGI | `Authorization Framework` | 全プロンプトにAUTHORIZATION FRAMEWORKセクションを強制注入 |

**ガードレールは「エージェントの外側」から制約をかける。** エージェント自身の判断には依存しない。

### Requirement / Constraint（宣言的制約）

エージェントの行動を宣言的なルールで制約する。ガードレールより粒度が細かく、実行フローに介入する。

| ツール | 用語 | 特徴 |
|---|---|---|
| BeeAI | `RequirementAgent` | `ConditionalRequirement` で制約を宣言: `force_at_step`, `only_after`, `max_invocations`, `min_invocations`, `consecutive_allowed` |
| BeeAI | `AskPermissionRequirement` | 特定アクションの前に許可を要求 |
| ControlFlow | `Result Validator` | カスタムバリデーション関数 |
| ControlFlow | `Labels` | `result_type=["option_a", "option_b"]` でLLMに選択を強制 |

**BeeAIのRequirementAgentは独自性が高い。** 宣言的ルールで「小規模モデルでも正しい実行パスを保証」するアプローチは他にない。

### Loop / Stuck Detection（ループ・スタック検出）

エージェントが無限ループやデッドロックに陥った状態を検出し、回復する。**実行時監視** のメカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenHands | `StuckDetector` (5パターン) | 同一Action反復、エラーループ、モノローグ、A-B-A-Bパターン、コンテキストウィンドウエラー |
| TAKT | `Loop Monitor` / `Cycle Detection` | 無限ループ検出と仲裁ステップの自動挿入 |
| PentAGI | `repeatingDetector` | 反復検出。Reflectorによる自己反省と組み合わせ |
| o-m-cc | `stop-guard.sh` | Sisyphusガード: DONE + code-review確認 + スロットリング |
| o-m-cc | `focus-guard.sh` | タスク進行中の脱線防止 |

**OpenHandsのStuckDetector（5パターン検出）は最も体系的。** 単なるリトライではなく、スタックの「種類」を判別する設計が参考になる。

### Review（レビュー）

タスク完了前に品質を確認する。**事後検証** のメカニズム（ただしsubmit前）。

| ツール | 用語 | 特徴 |
|---|---|---|
| SWE-agent | `Reviewer` | submit前レビュー。レビュー結果を反映して再修正 |
| TAKT | Phase 2/3 | Phase 2（レポート出力）→ Phase 3（AI judgeによるステータス判定）|
| Agent Orchestrator | `Reactions` | PR提出後のCI結果・レビュー結果に自動対応 |

### Evaluation / Scoring（評価・スコアリング）

エージェントの出力品質を定量的に評価する。**事後検証** のメカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| Google ADK | `Agent Evaluator` (5種) | LLM-as-Judge, Trajectory Evaluator, Safety Evaluator, Hallucination Evaluator, Custom |
| PydanticAI | `pydantic-evals` | コードファースト評価。LLM-as-Judge対応 |
| Mastra | `Evals` / `Scorers` | エージェント品質評価 |
| TAKT | `Rule Evaluation` (3種) | Tag-based / AI judge / Aggregate (`all()`, `any()`) |

### Security Analysis（セキュリティ分析）

エージェントのアクションのリスクを事前評価する。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenHands | `SecurityAnalyzer` | EventStreamにサブスクライブしてアクションのリスクを事前評価。LLM Risk, Invariant Analyzer, GraySwan Cygnal |

### Self-Reflection（自己反省）

エージェント自身が自分の出力や行動を振り返り、改善する。

| ツール | 用語 | 特徴 |
|---|---|---|
| PentAGI | `Reflector` / `performReflector` | 自己反省メカニズム。repeatingDetectorと組み合わせ |
| Mastra | `Observational Memory` (Reflector) | 自動圧縮長期記憶の一部として反省を組み込み |

## パターン・バリエーション

### 検証の3時点

```
事前防止 ──────── 実行時監視 ──────── 事後検証
   │                  │                  │
   Guardrail       StuckDetector       Review
   Requirement     LoopMonitor         Evaluation
   Authorization   FocusGuard          AI Judge
```

- **事前**: 入力/出力のフィルタリング。低コストだが偽陽性リスク
- **実行時**: 異常パターンの検出。リアルタイムだが検出精度に課題
- **事後**: 結果の品質評価。高精度だがコスト（LLM呼出）がかかる

### 制約の表現力

- **バイナリ（通過/拒否）**: OpenAI SDK の tripwire。シンプルだが柔軟性に欠ける
- **条件付き（宣言的ルール）**: BeeAI RequirementAgent。`force_at_step`, `max_invocations` 等の組み合わせ
- **スコアリング（定量的）**: Google ADK Evaluator, PydanticAI evals。閾値で判断

### エージェント内 vs エージェント外

- **エージェント内**: Self-Reflection（PentAGI Reflector）。エージェント自身が反省
- **エージェント外**: Guardrail, SecurityAnalyzer, StuckDetector。外部から監視・制約

## 独自レイヤーとの接点

- **認知協調（セカンドオピニオン）**: 事後検証の拡張。単なるスコアリングではなく「別の視点からの判断」を求める点が独自。BeeAIの RequirementAgent（`force_at_step` で強制レビュー挿入）がメカニズムとして最も近い
- **ルーラーエージェント**: [02 Routing](./02-routing-delegation.md) での判断結果をこの領域で検証する。「判断履歴のナビゲーション」はOSSにない独自概念。Agent SquadのOverlap Analyzer（TF-IDF + コサイン類似度）が定量分析の参考
