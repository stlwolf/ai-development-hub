# Cross-Cutting Themes — 横断的テーマ

> `domain/` の10領域に収まりきらない、複数領域にまたがる設計テーマ。

## 選定基準

domain/ の個別ファイルで既にカバーされている内容は除外し、**2つ以上の領域を横断する設計判断**として独立した価値があるテーマのみを収録する。

## テーマ一覧

| テーマ | 横断する領域 | 概要 |
|---|---|---|
| [LLM Abstraction Patterns](./llm-abstraction-patterns.md) | 01 + 04 + 09 | LLMプロバイダー接続の抽象化レイヤー。litellm / langchain-core / Vercel AI SDK / 直接統合 |
| [Prompt as Architecture](./prompt-as-architecture.md) | 01 + 02 + 06 | プロンプト設計をアーキテクチャとして扱うパターン。Faceted Prompting、Progressive Disclosure |
| [Cost Optimization](./cost-optimization.md) | 01 + 02 + 05 | モデルルーティング、コンテキスト圧縮、トークン予算管理によるコスト制御 |
| [Coordination Topologies](./coordination-topologies.md) | 02 + 03 + 05 | マルチエージェント協調のトポロジー。中央集権 vs P2P、同期 vs 非同期 |

## domain/ との関係

以下のテーマは横断的だが、domain/ 内で十分カバーされているため cross-cutting/ には含めない:

- **ループ検出・スタック防止**: [06 Feedback & Validation](../domain/06-feedback-validation.md) で網羅
- **人間介入の統合**: [07 Human Interaction](../domain/07-human-interaction.md) で網羅
- **イベント駆動アーキテクチャ**: [08 Event & Reaction](../domain/08-event-reaction.md) で網羅
- **永続実行・復旧**: [05 State & Memory](../domain/05-state-memory.md) のCheckpoint / Durable Execution で網羅
- **セキュリティ・信頼**: [06 Feedback & Validation](../domain/06-feedback-validation.md) のGuardrail / SecurityAnalysis + [04 Execution & Runtime](../domain/04-execution-runtime.md) のSandbox で網羅
- **知識管理**: [05 State & Memory](../domain/05-state-memory.md) のKnowledge / VCS-based Knowledge で網羅
