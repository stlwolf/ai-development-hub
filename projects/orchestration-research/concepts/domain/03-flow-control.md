# Flow Control — フロー制御

> **どんな順序で実行するか** を定める概念群。タスクやエージェントの実行順序・並列性・分岐・反復を制御する。

## この領域の問い

- タスクを順次実行するか、並列実行するか
- 条件によって実行パスを分岐できるか
- ループ・反復をどう表現し、いつ終了するか
- 複雑なフローをどの抽象（グラフ、ステートマシン、デコレータ等）で表現するか

## 核となる概念

### Sequential Execution（逐次実行）

タスクを定義順に1つずつ実行する。最も単純なフロー。

| ツール | 用語 | 特徴 |
|---|---|---|
| CrewAI | `Sequential Process` | デフォルトの実行モード |
| Google ADK | `SequentialAgent` | 子エージェントを順序実行する専用エージェント型 |
| MetaGPT | `BY_ORDER` | 定義順に順次実行 |
| o-m-cc | `Pipeline` | 逐次処理チーム。Designer → Planner の順序 |
| Orca | `Sequential Pipeline` | パイプラインパターン |

### Parallel Execution（並列実行）

複数タスク/エージェントを同時に実行し、結果を集約する。

| ツール | 用語 | 特徴 |
|---|---|---|
| Google ADK | `ParallelAgent` | 子エージェントを並列実行する専用エージェント型 |
| TAKT | `Parallel Movements` | 複数レビュアーの並列実行 + 集約評価 |
| LangGraph | `Send` (fan-out/fan-in) | 同一ノードを異なる状態で並列実行しMap-Reduce |
| LangGraph | `Deferred Nodes` | 全並列ブランチ完了を待って実行 |
| CrewAI | `Async Execution` | タスク単位の非同期並列 |
| Mastra | 並列ステップ | ワークフロー内の並列ブランチ |

### Conditional Branch（条件分岐）

ノード/タスクの出力に基づいて実行パスを分岐する。

| ツール | 用語 | 特徴 |
|---|---|---|
| LangGraph | `Conditional Edges` | ノード出力に基づく動的分岐。関数で次のノードを決定 |
| CrewAI | `@router` | デコレータで条件分岐。`Conditional Task` で前タスク出力による動的スキップも可能 |
| Mastra | 条件分岐 | ワークフロー内の分岐ステップ |

### Loop / Iteration（ループ・反復）

条件を満たすまで処理を繰り返す。エージェントの基本動作（ReActループ）も含む。

| ツール | 用語 | 特徴 |
|---|---|---|
| Google ADK | `LoopAgent` | `escalate` で脱出、`max_iterations` で上限設定 |
| Mastra | `.dountil()` / `.dowhile()` / `.foreach()` | ループプリミティブ |
| OpenAI Agents SDK | `Runner.run()` | LLM呼出→ツール実行→再LLM呼出のReActループ |
| MetaGPT | `REACT` / `PLAN_AND_ACT` | think-actループ / Plan生成→Plan内Task順次実行 |

### Graph / State Machine（グラフ / ステートマシン）

ノードとエッジで実行フローを表現する汎用的な抽象。上記の Sequential / Parallel / Branch / Loop をすべて包含できる。

| ツール | 用語 | 特徴 |
|---|---|---|
| LangGraph | `StateGraph` | Pregel着想のグラフランタイム。ノード=関数、エッジ=遷移 |
| AutoGen | `GraphFlow` / `DiGraphBuilder` | 有向グラフ定義 |
| BeeAI | `Workflow` | ステートマシン。transitions: `END`, `SELF`, `NEXT`, `PREV`, `START` |
| PydanticAI | `pydantic-graph` | 型ヒントベースのグラフ定義。Mermaid図自動生成 |
| Mastra | `Workflow Engine` | 内部的にグラフベース |

### Turn Strategy（ターン戦略）

マルチエージェント会話で「次に誰が発言するか」を制御する戦略。

| ツール | 用語 | 特徴 |
|---|---|---|
| ControlFlow | Turn Strategy (6種) | `Popcorn`, `RoundRobin`, `Random`, `MostBusy`, `Moderated`, `SingleAgent` |
| AutoGen | GroupChat (4戦略) | `RoundRobin`, `Selector` (LLM選択), `Swarm`, `MagenticOne` |
| o-m-cc | Council | 並列議論（Peer-to-peer） |

### Termination Conditions（終了条件）

フロー全体またはループの終了を判定する条件。

| ツール | 用語 | 特徴 |
|---|---|---|
| AutoGen | 終了条件 (8種) | `MaxMessage`, `TextMention`, `StopMessage`, `TokenUsage`, `Handoff`, `Timeout`, `External`, `Functional`。`|` `&` 演算子で合成可能 |
| ControlFlow | `Execution Conditions` | `AllComplete`, `AnyComplete`, `AnyFailed`, `MaxLLMCalls`, `MaxAgentTurns` |

## パターン・バリエーション

### 表現力の軸

```
低い（シンプル）──────────────────── 高い（汎用）
   │                                     │
   Sequential/Parallel                   Graph (LangGraph)
   (Google ADK, CrewAI)                  State Machine (BeeAI)
                                         Typed Graph (PydanticAI)
```

- **シンプル側**: 専用エージェント型（Google ADKの `SequentialAgent` / `ParallelAgent` / `LoopAgent`）で直感的
- **汎用側**: グラフ定義は何でも表現できるが、学習コストが高い

### 宣言型 vs プログラム型

- **宣言型**: TAKT（YAMLでMovement定義）、BeeAI（transitionsで宣言）
- **プログラム型**: LangGraph（Pythonでグラフ構築）、Mastra（TypeScript API）
- **デコレータ型**: CrewAI（`@start` / `@listen` / `@router`）。コード内に宣言を埋め込むハイブリッド

### ネスティングと合成

- LangGraph: `Subgraph` でグラフのネスト（階層的ワークフロー）
- Mastra: `Nested Workflows` でワークフローの再利用
- ControlFlow: `Task Dependencies`（`depends_on`, `parent`）でサブタスク階層

## 独自レイヤーとの接点

- フロー制御自体は独自レイヤーの主要対象ではない。OSSが厚く実装している領域
- ただし、フロー内に「認知協調ポイント」（セカンドオピニオン）をどう挿入するかは [06 Feedback & Validation](./06-feedback-validation.md) との接点
