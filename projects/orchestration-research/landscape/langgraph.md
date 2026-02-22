---
name: LangGraph
repo: langchain-ai/langgraph
last_reviewed: 2026-02-22
category: framework
---

## LangGraph 調査結果

### 基本情報
- **リポジトリ:** https://github.com/langchain-ai/langgraph
- **言語:** Python (メイン) / TypeScript (langgraphjs)
- **最終更新:** 2026年2月時点でアクティブに更新中
- **規模:** 24,933 stars / 4,400 forks / 月間3,450万ダウンロード（PyPI）/ v1.0.9（Production/Stable）
- **ライセンス:** MIT
- **一言で:** Google Pregel着想のグラフベース状態遷移ランタイム。長時間実行・ステートフルなAIエージェントの構築・管理・デプロイのためのローレベルオーケストレーションフレームワーク

### これは何か・何を解決するのか

LangGraphは、LLMを組み込んだ長時間実行・ステートフルなエージェントやワークフローを構築するための**ローレベルオーケストレーションフレームワーク**。LangChain Inc.が開発しているが、LangChain自体なしでも利用可能。

解決する主要課題:
1. **LLMの非決定性への対処**: チェックポイント + 承認パターンでLLMの予測不能な出力を制御可能にする
2. **長時間タスクの耐障害性**: 障害発生時に途中状態から自動復帰（Durable Execution）
3. **人間の介入**: エージェントの任意の実行ポイントで停止→人間が判断→再開（Human-in-the-Loop）
4. **LLMレイテンシの管理**: 多彩なストリーミングモードでリアルタイム出力

**設計哲学**: プロンプトやアーキテクチャを抽象化しない。開発者がグラフの全制御を持つ。

### 設計思想・アーキテクチャ

#### コア抽象: Pregel ランタイム

Google PregelとApache Beamに着想を得た**グラフベースの状態遷移エンジン**。

| 概念 | 説明 |
|------|------|
| **StateGraph** | ノードとエッジで構成されるグラフ。TypedDictで状態スキーマを定義 |
| **Node** | 状態を受け取り更新を返す関数 |
| **Edge** | ノード間の遷移。条件分岐対応 |
| **Channel** | 状態値の管理チャネル。Reducerでマージ戦略を定義 |
| **Super-step** | 並列実行可能なノード群の実行単位 |
| **Thread** | `thread_id`で識別される実行コンテキスト |
| **Checkpoint** | グラフ状態のスナップショット。履歴を保持（上書きしない） |

#### リポジトリ構成（モノレポ）

```
libs/
├── langgraph/             # コアライブラリ（Pregel runtime, Graph API, Functional API）
│   └── langgraph/
│       ├── pregel/        # Pregel実行エンジン
│       ├── graph/         # StateGraph, MessageGraph
│       ├── func/          # Functional API (@entrypoint, @task)
│       ├── channels/      # 状態チャネル
│       └── types.py       # Command, Send, Interrupt, RetryPolicy, CachePolicy
├── checkpoint/            # チェックポイント基盤
├── checkpoint-postgres/   # PostgreSQL用チェックポインタ
├── checkpoint-sqlite/     # SQLite用チェックポインタ
├── prebuilt/              # create_react_agent, ToolNode
├── cli/                   # LangGraph CLI
├── sdk-py/                # Python SDK
└── sdk-js/                # JavaScript SDK
```

#### 2つのAPI

1. **Graph API（StateGraph）**: ノード・エッジを明示的に定義。複雑なマルチエージェントシステム向き
2. **Functional API（@entrypoint / @task）**: 通常のPython関数にデコレータを付与するだけ。同じPregelランタイム上で動作

### 機能一覧

#### コア機能

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **StateGraph** | TypedDictベースの状態スキーマでグラフ定義 | `graph/state.py` | コア |
| **Functional API** | `@entrypoint` / `@task` デコレータによる関数型定義 | `func/` | コア |
| **Pregel Runtime** | 並列実行エンジン。super-step単位 | `pregel/` | コア |
| **Checkpointing** | 各super-stepで状態スナップショット。MemorySaver / SQLite / PostgreSQL | `checkpoint/` | コア |
| **Human-in-the-Loop** | `interrupt()` で停止、`Command(resume=...)` で再開 | `types.py` | コア |
| **Streaming** | 7モード: values, updates, messages, custom, checkpoints, tasks, debug | `types.py` | コア |
| **Durable Execution** | チェックポイントベースの障害復帰 | `func/` + checkpoint | コア |

#### 差別化機能

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **Time Travel** | チェックポイント履歴を遡り、任意の地点から実行をフォーク | `get_state_history()` | 差別化 |
| **Send（Map-Reduce）** | 同一ノードを異なる状態で並列実行しfan-out/fan-in | `types.py` | 差別化 |
| **Command** | 状態更新 + ノード遷移指示 + resume値を1オブジェクトで表現 | `types.py` | 差別化 |
| **Subgraph** | グラフをネストして階層的ワークフロー | Graph API | 差別化 |
| **Deferred Nodes** | 全並列ブランチ完了を待って実行 | `pregel/` | 差別化 |
| **Conditional Edges** | ノード出力に基づく動的分岐 | `graph/state.py` | 差別化 |
| **RetryPolicy** | ノード単位のリトライ（指数バックオフ、ジッター） | `types.py` | 差別化 |
| **CachePolicy** | タスク結果のキャッシュ。TTL設定可能 | `types.py` | 差別化 |

#### ユーティリティ / エコシステム統合

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **create_react_agent** | ReActパターンのエージェントを即時構築 | `prebuilt/` | ユーティリティ |
| **ToolNode** | ツール呼び出しノードのプリビルト | `prebuilt/tool_node.py` | ユーティリティ |
| **LangSmith Tracing** | 環境変数設定のみで自動トレース | LangSmith連携 | ユーティリティ |
| **LangGraph Studio** | ビジュアルデバッガーIDE | 別リポジトリ | ユーティリティ |
| **MCP Integration** | MCPサーバーのツール接続 | `langchain-mcp-adapters` | ユーティリティ |
| **Multi-Agent: Supervisor** | 階層型マルチエージェント | `langgraph-supervisor-py` | ユーティリティ |
| **Multi-Agent: Swarm** | ピア間ハンドオフ型 | `langgraph-swarm-py` | ユーティリティ |
| **Memory（Short/Long-term）** | スレッド内短期 + セッション横断長期 | checkpoint + store | ユーティリティ |

### 特徴的な点・注目ポイント

#### 1. Checkpoint＝タイムトラベルの基盤

チェックポイントは単なる「セーブポイント」ではなく、**全実行履歴の不可変ログ**。上書きせず履歴を保持するため、任意の過去の状態に戻って別の分岐をフォークできる。シリアライズは`ormsgpack`（MessagePack拡張）をプライマリ、pickle をフォールバック。

#### 2. `interrupt()` / `Command(resume=)` のペア設計

Human-in-the-Loopは `interrupt(value)` → GraphInterrupt例外 → クライアント側で値受信 → `Command(resume=answer)` で再開。`interrupt()` のIDはノードのnamespace + カウンタから`xxhash`で決定論的に生成。

#### 3. Functional API の追加による二面戦略

`@entrypoint` / `@task` はグラフ定義が冗長になりがちな問題への回答。内部的にはGraph APIと同じPregelランタイム上で動作するため、機能の一貫性が保たれている。

#### 4. `Send` によるMap-Reduce

`Send("node_name", state)` をリストで返すことで、同一ノードを異なる入力で並列実行し、Reducerで集約するMap-Reduceパターンを宣言的に表現。

### 使い方・典型的なワークフロー

```python
# 基本（Graph API）
from langgraph.graph import START, StateGraph
from typing_extensions import TypedDict

class State(TypedDict):
    text: str

graph = StateGraph(State)
graph.add_node("node_a", lambda s: {"text": s["text"] + "a"})
graph.add_edge(START, "node_a")
app = graph.compile()
result = app.invoke({"text": ""})

# Human-in-the-Loop
from langgraph.types import interrupt, Command

def review_node(state):
    answer = interrupt("Please review")
    return {"human_review": answer}

# Functional API
from langgraph.func import entrypoint, task

@task
def process(item: str) -> str:
    return item.upper()

@entrypoint(checkpointer=InMemorySaver())
def workflow(items: list[str]) -> list[str]:
    futures = [process(item) for item in items]
    return [f.result() for f in futures]
```

### エコシステム・実利用状況

- **採用事例:**
  - Klarna: 250万会話/月処理、FTE 700人相当の業務
  - LinkedIn: AI リクルーター
  - Uber: コードマイグレーション
  - Elastic: セキュリティ脅威検知
  - Replit: コーディングエージェント
  - 公式ケーススタディページに30+社
- **盛り上がりの文脈:** LangChainエコシステムのde facto standard。AgentExecutorは2026年12月に完全廃止予定でLangGraphへの移行推奨。月間3,450万DL
- **コミュニティ:** GitHub Issues/Discussions活発。LangChain Forum。Zenn/Qiitaに日本語記事多数
- **周辺ツール:** LangSmith, LangSmith Deployment, LangGraph Studio, langgraph-supervisor, langgraph-swarm, langchain-mcp-adapters, LangChain Academy
- **評判:**
  - 肯定的: プロダクション信頼性（Klarna/Replit等）、Human-in-the-Loop + チェックポイントが強力
  - 否定的: 学習曲線が急、グラフの再利用性が低い、「真のエージェントフレームワークではなくDAGランナー」との批判、商用基盤への誘導

### 他ツールとの比較・ポジショニング

| 観点 | LangGraph | Mastra | CrewAI | AutoGen |
|------|-----------|--------|--------|---------|
| 言語 | Python / TS | TypeScript | Python | Python |
| 設計思想 | ローレベル・明示的制御 | オールインワン・Web統合 | ロールベースチーム協調 | 会話型マルチエージェント |
| Durable Execution | 組み込み | デプロイ依存 | なし | なし |
| Time Travel | フル対応 | なし | なし | なし |
| 学習コスト | 高い | 中程度 | 低い | 中程度 |
| Stars | ~25k | ~8k | ~30k | ~30k |
| 月間DL | 3,450万 | 86万 | — | — |

**ポジショニング**: 「プロダクション向けの精密制御ツール」。CrewAIは「プロトタイプ向け」、Mastraは「TypeScript/Web向け」、AutoGenは「研究・実験向け」。

### 制約・注意点

1. **学習曲線**: ローレベルAPI故にプロダクション品質にするには相当な学習投資が必要
2. **グラフの再利用性**: パッケージとして配布・再利用する設計になっていない
3. **LangChain依存**: `langchain-core>=0.1` が必須依存
4. **商用基盤への誘導**: フル活用にはLangSmith等の有償サービスが必要
5. **「真のエージェント」ではない**: 開発者が設計したグラフ通りに実行するDAGランナー
6. **状態スキーマの事前定義**: 動的な状態変化への柔軟性が制限される

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 理由 |
|------|------|------|
| Pregel実行エンジン | `libs/langgraph/langgraph/pregel/` | コアランタイム。super-step、並列実行の実装 |
| StateGraph.compile() | `libs/langgraph/langgraph/graph/state.py` | グラフ→Pregelへの変換ロジック |
| チェックポイント基盤 | `libs/checkpoint/langgraph/checkpoint/base/` | BaseCheckpointSaverの抽象インターフェース |
| PostgreSQLチェックポインタ | `libs/checkpoint-postgres/` | プロダクション向けチェックポインタ |
| interrupt()の内部実装 | `libs/langgraph/langgraph/types.py` | GraphInterrupt + scratchpadによるresume値マッチング |
| Functional API: call() | `libs/langgraph/langgraph/pregel/_call.py` | @task のFuture実装と並列実行メカニズム |
