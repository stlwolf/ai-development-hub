# Observability — 可観測性

> エージェントの実行中に **何が起きているかをどう把握するか** を定める概念群。すべての領域に横断的に関わる。

## この領域の問い

- エージェントの実行をどうトレース（追跡）するか
- フロー構造をどう可視化するか
- 実行履歴（Trajectory）をどう記録・分析・再生するか
- 実行中の出力をどうリアルタイムに配信するか

## 核となる概念

### Tracing（トレーシング）

エージェントの実行をSpan/Trace単位で追跡する。分散トレーシングの概念をエージェントに適用。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenAI Agents SDK | `Trace` / `Span` / `TracingProcessor` | OpenAI Dashboard + 20以上の外部プロセッサ対応 |
| PydanticAI | Logfire統合 | OpenTelemetryベースのオブザーバビリティ |
| PentAGI | Langfuse連携 | LLM呼び出しの観測 |
| PentAGI | Grafana / Prometheus / Jaeger | インフラレベルの観測 |

### Visualization（可視化）

エージェントのフロー構造やグラフをダイアグラムとして描画する。

| ツール | 用語 | 特徴 |
|---|---|---|
| PydanticAI | Mermaid図自動生成 | pydantic-graphからMermaid DAGを自動生成 |
| CrewAI | `Flow Visualization` | フローDAGの視覚化 |
| OpenAI Agents SDK | graphviz | エージェントグラフの可視化 |
| Mastra | Mastra Studio | Web UIでワークフロー/エージェントを視覚的に操作 |
| AutoGen | AutoGen Studio | ノーコードGUIでエージェント定義・実行・観察 |
| LangGraph | LangGraph Studio / Platform | WebベースのIDE。グラフの可視化・デバッグ |

### Trajectory（行動軌跡）

エージェントの全行動履歴の記録・分析・再生。デバッグ・改善のための事後分析基盤。

| ツール | 用語 | 特徴 |
|---|---|---|
| SWE-agent | `Trajectory Inspector` | Textual TUIで実行結果を対話分析 |
| SWE-agent | `Trajectory Replay` | 軌跡の再生 |
| SWE-agent | `Run Comparison` | 複数実行の比較 |
| OpenHands | `Session Replay` | セッションの再生 |
| Google ADK | `Trajectory Evaluator` | 軌跡の自動評価（正しい手順を踏んだか） |

### Streaming（ストリーミング）

エージェントの実行中の出力をリアルタイムに配信する。

| ツール | 用語 | 特徴 |
|---|---|---|
| LangGraph | Streaming (7モード) | `values`, `updates`, `messages`, `custom`, `checkpoints`, `tasks`, `debug` |
| CrewAI | `crew.stream=True` | リアルタイム出力 |
| OpenAI Agents SDK | `Runner.run_streamed()` | リアルタイムイベント配信 |
| PydanticAI | Streaming | 構造化出力の逐次バリデーション付きストリーミング |
| Agent Squad | Streaming/Non-streaming | エージェント単位で制御 |

**LangGraphの7モードストリーミングは最も柔軟。** 値、更新差分、メッセージ、カスタムイベント等を個別にサブスクライブ可能。

### Events / Emitters（イベント発行）

実行中のイベントを外部に通知する仕組み。[08 Event & Reaction](./08-event-reaction.md) と重なるが、ここでは「観測目的」の側面。

| ツール | 用語 | 特徴 |
|---|---|---|
| CrewAI | `EventBus` | オブザーバビリティ用のイベントバス |
| BeeAI | `Emitter` | すべての実行にイベント発行 |

### Cost Tracking（コスト追跡）

LLM呼び出しのトークン消費・コストを追跡する。

| ツール | 用語 | 特徴 |
|---|---|---|
| oh-my-claude-code | コスト意識型ルーティング | FREE → CHEAP → EXPENSIVE の段階的エスカレーション。`COST_LEVELS` |
| AutoGen | `TokenUsage` 終了条件 | トークン使用量での終了制御 |

## パターン・バリエーション

### 観測の目的別分類

```
開発時 ─────────── 運用時 ─────────── 改善時
  │                  │                  │
  Visualization    Tracing            Trajectory
  Studio/GUI       Streaming          Evaluation
  Debug mode       Cost Tracking      Run Comparison
```

- **開発時**: フロー構造の可視化、ステップ実行、デバッグ
- **運用時**: リアルタイムトレーシング、コスト監視
- **改善時**: Trajectory分析、複数実行の比較、評価

### 可視化のアプローチ

- **静的ダイアグラム**: PydanticAI (Mermaid), CrewAI (DAG)。コードから自動生成
- **対話的GUI**: Mastra Studio, AutoGen Studio, LangGraph Studio。Web UIで操作・観察
- **TUI**: SWE-agent Trajectory Inspector。ターミナル内で対話的に分析

### トレーシングの標準化

- **OpenTelemetry準拠**: PydanticAI (Logfire)。既存のオブザーバビリティ基盤と統合可能
- **プラットフォーム固有**: OpenAI SDK (OpenAI Dashboard)。ベンダーロックイン
- **OSS組み合わせ**: PentAGI (Langfuse + Grafana + Prometheus + Jaeger)。柔軟だが構築コスト

## 独自レイヤーとの接点

- **4層コンテキストモデル**: Trajectoryの記録・分析は、episodes層（生データ）に対応する。episodes → decisions → context への昇格フローの入力データとなる
- 可観測性は全領域に横断する。特に [06 Feedback & Validation](./06-feedback-validation.md)（品質評価の入力データ）と [05 State & Memory](./05-state-memory.md)（Trajectory永続化）との関連が深い
