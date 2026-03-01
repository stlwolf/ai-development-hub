# Routing & Delegation — ルーティング・委任

> **誰がやるか** を決定する概念群。タスクや入力をどのエージェントに振り分けるかの設計。

## この領域の問い

- 複数のエージェントがいるとき、どれに処理させるか
- 制御を完全に移譲するか、結果だけ受け取るか
- 振り分けの判断を誰が行うか（LLM / ルール / 人間）

## 核となる概念

### Handoff（ハンドオフ）

制御の完全移譲。実行権がHandoff先のエージェントに移り、元のエージェントは待機または終了する。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenAI Agents SDK | `Handoff` | 会話履歴を引き継ぐ同期的な制御移譲。`input_filter` でコンテキスト制御 |
| AutoGen | `HandoffMessage` / `Swarm` | OpenAI Swarmスタイルのメッセージベース移譲 |
| Google ADK | `transfer_to_agent` | LLMが動的にルーティング用ツールとして自動注入 |
| CAO | `Handoff` | workerの完了まで同期待機 |
| BeeAI | `HandoffTool` | ツールとして他エージェントに委譲 |

### Agent-as-Tool（エージェントをツールとして利用）

制御を保持したまま、他エージェントを「ツール」として呼び出し結果だけ受け取る。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenAI Agents SDK | `agent.as_tool()` | 呼び出し元が制御を保持。結果のみ受け取る |
| AutoGen | `AgentTool` | エージェントをツールインターフェースで公開 |

**Handoff vs Agent-as-Tool は最も基本的な二項対立。** Handoffは「任せる」、Agent-as-Toolは「使う」。

### Intent Classification（意図分類）

LLMによるユーザー入力の意図分析に基づくエージェント選択。

| ツール | 用語 | 特徴 |
|---|---|---|
| Agent Squad | `Classifier` | agent description + 会話履歴からLLMが分類。Overlap Analyzer（TF-IDF + コサイン類似度）で重複検出 |
| Google ADK | LLM動的ルーティング | `transfer_to_agent` ツールを自動注入し、LLMが判断 |
| AutoGen | `SelectorGroupChat` | LLMが次の発言者を動的選択 |

### Rule-based Routing（ルールベースルーティング）

明示的なルール・条件による振り分け。LLMを介さない確定的なルーティング。

| ツール | 用語 | 特徴 |
|---|---|---|
| MetaGPT | `cause_by` | 生成元Action型がルーティングキー。`_watch()` で関心のあるAction型を登録 |
| oh-my-claudecode | `Intent Gate` | タスクを分類して適切なエージェントに振り分け |
| o-m-cc | タスク規模ディスパッチ | S/M/Lの規模別に処理フローを分岐 |
| CrewAI | `@router` | デコレータで条件分岐を定義 |

### Hierarchical Delegation（階層的委任）

上位エージェント（マネージャー）が下位エージェント（ワーカー）にタスクを委任する構造。

| ツール | 用語 | 特徴 |
|---|---|---|
| CrewAI | `Hierarchical Process` | マネージャーエージェントを自動生成し委任 |
| Google ADK | `parent_agent` / `sub_agents` | 階層的エージェントツリー |
| CAO | `Supervisor` / `Worker` | supervisorが必要最小限のコンテキストのみ渡す |
| PentAGI | 再帰的委譲 | サブタスク自動生成・動的修正 |
| TAKT | `Team Leader Movement` | タスクを動的にサブタスク分解し並列実行 |

### Asynchronous Delegation（非同期委任）

ワーカーが独立して実行し、完了時に報告する非同期パターン。

| ツール | 用語 | 特徴 |
|---|---|---|
| CAO | `Assign` | workerは独立実行。完了時に `send_message` で報告 |
| CAO | `Send Message` | 既存セッションへのメッセージ送信。Inbox + Watchdogで配信制御 |

## パターン・バリエーション

### ルーティング判断の主体

```
LLMが判断（動的）─────────────────── ルールが判断（静的）
   │                                      │
   Agent Squad (Classifier)               MetaGPT (cause_by)
   Google ADK (transfer_to_agent)         o-m-cc (S/M/L dispatch)
   AutoGen (SelectorGroupChat)            CrewAI (@router)
```

- **LLM判断**: 柔軟だが非決定的。hallucination リスク
- **ルール判断**: 決定的で予測可能だが、事前にパターンを定義する必要がある

### 同期 vs 非同期

- **同期Handoff**: 完了を待って結果を受け取る（OpenAI SDK, AutoGen）
- **非同期Assign**: 独立実行、完了報告（CAO）。並列処理に適するが結果集約が複雑

### 中央集権 vs 分散

- **中央オーケストレーター型**: oh-my-claudecode（Hub-and-Spoke）、CrewAI（Hierarchical）
- **分散P2P型**: o-m-cc（TeammateTool経由のpeer-to-peer）、MetaGPT（cause_byベースの暗黙的ルーティング）

## 独自レイヤーとの接点

- **ルーラーエージェント**: ルーティング判断 + 品質保証の結合点。Agent SquadのClassifier + Overlap Analysisが判断ルーティングの参考になるが、「判断履歴のナビゲーション」はOSSにない
- ルーラーエージェントはこの領域（02 Routing）と [06 Feedback & Validation](./06-feedback-validation.md) の境界に位置する
