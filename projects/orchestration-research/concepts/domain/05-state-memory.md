# State & Memory — 状態・メモリ

> エージェントが **何を覚えているか・どう永続化するか** を定める概念群。実行状態の保存と、知識・記憶の管理を扱う。

## この領域の問い

- 実行状態（どこまでやったか）をどう保存・復元するか
- 短期記憶と長期記憶をどう区別し管理するか
- コンテキストウィンドウの制約にどう対処するか
- 外部知識（ドキュメント、コードベース）をどう参照するか

## 核となる概念

### Checkpoint / Snapshot（チェックポイント / スナップショット）

実行状態のある時点を保存し、後から復元・フォークできる仕組み。「どこまでやったか」の記録。

| ツール | 用語 | 特徴 |
|---|---|---|
| LangGraph | `Checkpoint` | グラフ状態のスナップショット。全履歴を保持 |
| LangGraph | `Time Travel` | チェックポイント履歴を遡り、任意の地点から実行をフォーク |
| LangGraph | `Durable Execution` | チェックポイントベースの障害復帰 |
| MetaGPT | `Serialization` / `Recovery` | 実行状態をJSON保存。復元して再開可能 |
| CrewAI | `Flow Persistence` | フロー状態永続化、一時停止・再開 |
| PydanticAI | `Durable Execution` | Temporal / Prefect / DBOS の3方式 |
| Google ADK | `Session Rewind` | 指定invocation IDまで巻き戻し、状態・アーティファクトを復元 |

**Checkpoint ≠ Memory。** Checkpointは「実行状態の保存」、Memoryは「知識の蓄積」。前者は再開・巻き戻し用、後者は学習・参照用。

### Working Memory（ワーキングメモリ）

現在のタスク遂行に必要な短期的な情報を保持するスクラッチパッド。

| ツール | 用語 | 特徴 |
|---|---|---|
| Mastra | `Working Memory` | 構造化スクラッチパッド |
| CrewAI | `Short-term Memory` | 直近の会話・タスク結果 |
| LangGraph | `Channel` / `Reducer` | 状態値の管理チャネル。Reducerでマージ戦略を定義 |

### Long-term Memory（長期メモリ）

セッションをまたいで永続化される記憶。エピソード記憶、エンティティ情報、学習結果を含む。

| ツール | 用語 | 特徴 |
|---|---|---|
| CrewAI | `Long-term Memory` / `Entity Memory` | エンティティ情報の蓄積 |
| Mastra | `Observational Memory` | Observer/Reflectorによる自動圧縮長期記憶 |
| Mastra | `Semantic Recall` | ベクトル類似度検索による記憶想起 |
| PentAGI | `Graphiti` | Neo4jベースの知識グラフ。エピソード記憶。6種の検索タイプ |
| PentAGI | `guide` | 長期ガイド。`search_guide` / `store_guide` |
| Claude Flow | `AgentDB` | HNSW + SQLite + ONNX Runtime（ただし実態はモック） |

### Context Compression（コンテキスト圧縮）

LLMのコンテキストウィンドウ制約に対処するための圧縮・要約メカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenHands | `Memory` / `Condenser` | LLM要約によるコンテキスト圧縮 |
| SWE-agent | `HistoryProcessor` | LLMコンテキスト窓を最大活用する履歴圧縮 |
| PentAGI | `Summarizer` | チェイン要約（コンテキストオーバーフロー防止） |
| PentAGI | `Summarization Awareness Protocol` | 過去の要約の模倣・コピーを防止するプロトコル |
| BeeAI | メモリ戦略 (4種) | `Unconstrained`, `Sliding Window`, `Summarize`, `Token-based` |
| o-m-cc | `Progressive Disclosure` | frontmatter→本文→参照ファイルの3段階。-33%トークン削減 |

### Knowledge / RAG（知識 / 検索拡張生成）

外部ドキュメント・コードベースからの情報検索と参照。

| ツール | 用語 | 特徴 |
|---|---|---|
| Aider | `Repository Map` | tree-sitter + PageRankでコードベース構造マップ生成。トークン予算内で動的選択 |
| CrewAI | `Knowledge Sources` | PDF, CSV, Excel, JSON, Text等からRAGナレッジ構築 |
| MetaGPT | `RAG` | Retrieval-Augmented Generation |
| PentAGI | `Graphiti` (6種検索) | recent_context, successful_tools, episode_context, entity_relationships, diverse_results, entity_by_label |

### VCS-based Knowledge（VCSベースの知識）

バージョン管理システムの履歴自体を知識源として活用するパターン。

| ツール | 用語 | 特徴 |
|---|---|---|
| o-m-cc | `HANDOVER.md` | git/jj履歴がナレッジベース。VCSベースの知識管理 |
| Aider | `Git Auto-Commit` | 変更ごと自動コミット。dirty file事前別コミット |

### Session / Context Management（セッション / コンテキスト管理）

会話履歴やユーザーコンテキストの管理。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenAI Agents SDK | `Session` | SQLite / Redis / OpenAI Conversations の3バックエンド |
| Google ADK | `Session` | InMemory / SQLite / Database / Spanner / Vertex AI の5バックエンド |
| Agent Squad | `ChatStorage` | (user_id, session_id, agent_id) 3キー管理 |
| Mastra | `Message History` + `Storage Abstraction` | 20+バックエンド（pg, libsql, mongodb, pinecone等） |

## パターン・バリエーション

### メモリの時間軸

```
即座（Working Memory）── セッション内 ── セッション間（Long-term）── 永続（Knowledge）
       │                     │                   │                      │
   Mastra Working         LangGraph          CrewAI Long-term        Aider RepoMap
   LangGraph Channel      Checkpoint         Mastra Observational    PentAGI Graphiti
                          Session            PentAGI guide
```

### 圧縮戦略

- **ウィンドウ制限**: BeeAI Sliding Window。単純だが文脈喪失リスク
- **要約**: OpenHands Condenser, PentAGI Summarizer。要約品質に依存
- **段階的開示**: o-m-cc Progressive Disclosure。必要に応じて詳細を展開
- **構造的選択**: Aider Repository Map。PageRankで重要部分のみ選択

### ストレージ抽象化

ほとんどのツールがストレージバックエンドを差し替え可能にしている:
- LangGraph: PostgreSQL, SQLite, MongoDB, Redis等のCheckpointer
- Mastra: 20+バックエンド
- Google ADK: InMemory → SQLite → Spanner の段階的スケール

## 独自レイヤーとの接点

- **4層コンテキストモデル**: episodes → decisions → context の昇格フロー。Mastraの Observational Memory（Observer/Reflector自動圧縮）が最も近いが、「昇格」の概念はOSSにない
- **コンテキスト・エンベロープ**: original_intent + trajectory + payload のJSON構造。OpenHandsのEventStreamが概念的に近い。o-m-ccのHANDOVER.mdが軽量な代替パターン
