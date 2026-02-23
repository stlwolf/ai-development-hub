# Coordination Topologies — マルチエージェント協調トポロジー

> 複数エージェントがどんな構造で協調するかのメタパターン。

**横断する領域**: [02 Routing & Delegation](../domain/02-routing-delegation.md)（振り分け方式）+ [03 Flow Control](../domain/03-flow-control.md)（実行順序）+ [05 State & Memory](../domain/05-state-memory.md)（状態共有方式）

## なぜ横断的か

マルチエージェント協調のトポロジーは、ルーティング（誰が判断するか）、フロー制御（どう実行するか）、状態共有（何を共有するか）を同時に決定する。単独のドメイン領域では全体像を捉えられない。

## 4つのトポロジー

### 1. 中央集権型（Hub-and-Spoke）

1つのオーケストレーターが全エージェントを管理・指示する。

```
         ┌──────────┐
    ┌───→│ Worker A  │
    │    └──────────┘
┌───┴──┐
│ Orch  │──→ Worker B
└───┬──┘
    │    ┌──────────┐
    └───→│ Worker C  │
         └──────────┘
```

| ツール | 実装 | 特徴 |
|---|---|---|
| oh-my-claude-code | Orchestrator Agent | Hub-and-Spoke。中央が全タスクを分配 |
| CrewAI | Hierarchical Process | マネージャーエージェントを自動生成 |
| CAO | Supervisor / Worker | supervisorが必要最小限のコンテキストのみ渡す |
| Agent Orchestrator | Orchestrator Agent | 全セッションを統合管理 |

**利点**: 制御が容易、全体の一貫性を保ちやすい
**制約**: オーケストレーターがボトルネック。スケーラビリティに限界

### 2. 分散P2P型（Peer-to-Peer）

中央オーケストレーターなし。エージェント同士が直接やり取りする。

```
┌──────────┐     ┌──────────┐
│ Agent A   │←───→│ Agent B   │
└──┬───────┘     └───────┬──┘
   │                     │
   ↕                     ↕
┌──────────┐     ┌──────────┐
│ Agent C   │←───→│ Agent D   │
└──────────┘     └──────────┘
```

| ツール | 実装 | 特徴 |
|---|---|---|
| o-m-cc | TeammateTool | Claude Code Agent Teamsを通じてP2P協調。中央オーケストレーターなし |
| MetaGPT | `cause_by` + Environment | メッセージのAction型でルーティング。Pub/Subで疎結合 |
| AutoGen | Topic-based Pub/Sub | `@event` / `@rpc` で非同期通信 |

**利点**: ボトルネックがない、スケーラブル、障害耐性
**制約**: 全体の一貫性を保つのが困難、デバッグが複雑

### 3. ハイブリッド型（Council + Pipeline）

並列議論（Council）と逐次処理（Pipeline）を組み合わせる。

```
Phase 1: Council (並列)        Phase 2: Pipeline (逐次)
┌────────┐ ┌────────┐         ┌──────────┐   ┌──────────┐
│Scout A  │ │Scout B │   ──→  │ Designer │──→│ Planner  │
└────────┘ └────────┘         └──────────┘   └──────────┘
    ↕          ↕
  (peer-to-peer)
```

| ツール | 実装 | 特徴 |
|---|---|---|
| o-m-cc | Agent Teams | Phase 1: Discovery Council（並列議論）→ Phase 2: Pipeline（Designer → Planner） |
| TAKT | Team Leader Movement | タスク分解 → 並列実行 → 集約評価 |

**利点**: 探索（並列）と収束（逐次）を使い分けられる
**洞察**: o-m-ccのPhaseベース設計は、「いつ並列にし、いつ逐次にするか」の判断フレームワーク

### 4. Swarm型（動的切り替え）

エージェント間でHandoffにより動的に制御を移譲する。固定的なトポロジーがない。

```
Agent A ──handoff──→ Agent B ──handoff──→ Agent C
                         │
                         └──handoff──→ Agent D
```

| ツール | 実装 | 特徴 |
|---|---|---|
| OpenAI Agents SDK | Handoff | 制御移譲。会話履歴を引き継ぐ |
| AutoGen | Swarm GroupChat | OpenAI Swarmスタイル |
| Google ADK | `transfer_to_agent` | LLMが動的にHandoff先を決定 |

**利点**: 柔軟。事前にフローを定義する必要がない
**制約**: LLMの判断に依存。予測不可能な実行パス

## 状態共有方式との関係

トポロジーによって状態共有の方式が異なる:

| トポロジー | 状態共有 | 特徴 |
|---|---|---|
| 中央集権 | オーケストレーター経由 | オーケストレーターが全状態を把握。Workerは自分の担当分のみ |
| P2P | メッセージベース | 各エージェントが独自の状態を持つ。`cause_by` で必要な情報のみ伝播 |
| ハイブリッド | Phase間で集約 | Council内はP2P、Phase遷移時に集約してPipelineに引き継ぎ |
| Swarm | Handoff時に全履歴引き継ぎ | 会話履歴をそのまま渡す。コンテキスト膨張リスク |

## トポロジー選択の判断軸

```
タスクが事前定義可能 ──────── タスクが動的に変化
      │                             │
  中央集権 or Pipeline           Swarm or P2P
  (CrewAI, CAO)                (OpenAI SDK, o-m-cc)

探索的（多様な視点が必要）──── 収束的（一貫した結果が必要）
      │                             │
  Council (並列議論)              Pipeline (逐次処理)
  (o-m-cc Phase 1)               (o-m-cc Phase 2)
```

## 独自レイヤーとの接点

- **認知協調（セカンドオピニオン）**: Council型の応用。「複数の視点で並列にレビュー → 集約」は協調トポロジーそのもの
- **ルーラーエージェント**: 中央集権型のオーケストレーターの一種だが、「判断履歴のナビゲーション」という固有機能を持つ。純粋なルーティングとは異なる上位概念
