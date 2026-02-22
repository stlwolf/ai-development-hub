---
name: AutoGen
repo: microsoft/autogen
last_reviewed: 2026-02-22
category: framework
---

## AutoGen (Microsoft) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/microsoft/autogen
- **言語:** Python（.NETも公式サポート）
- **最終更新:** 2026-01-22
- **規模:** 54,713 stars / 559 contributors / 8,239 forks / 98 releases
- **ライセンス:** MIT
- **一言で:** Microsoft発の非同期イベント駆動型マルチエージェントAIフレームワーク。会話ベース協調の先駆者

### ⚠️ 重要: メンテナンスモード

**2025年10月、メンテナンスモードに移行。** Microsoft Agent Framework (github.com/microsoft/agent-framework) に統合。新機能は追加されない。AG2（共同創設者Chi Wang氏のフォーク）がコミュニティ版として存在。

### これは何か・何を解決するのか

マルチエージェントの会話ベース協調を広めた先駆者。複数AIエージェントが対話で問題解決するパラダイムを提唱し、CrewAI/LangGraph等に影響を与えた。

### 設計思想・アーキテクチャ

#### v0.4 レイヤードアーキテクチャ（完全再設計）

```
┌─────────────────────────────────┐
│  Extensions (autogen-ext)       │ ← LLMクライアント、コード実行器、ツール
├─────────────────────────────────┤
│  AgentChat (autogen-agentchat)  │ ← 高レベルAPI（Team, Agent, Conditions）
├─────────────────────────────────┤
│  Core (autogen-core)            │ ← イベント駆動アクターフレームワーク
└─────────────────────────────────┘
```

- **Core層**: 非同期メッセージパッシング、Actor Model、Topic-based Pub/Sub
- **AgentChat層**: AssistantAgent, UserProxyAgent, GroupChat系チーム
- **Extensions層**: モデルクライアント、コード実行器、ツール統合

#### メッセージパッシング設計

Topic-based Publish/Subscribe。`@event`（一方向通知）と`@rpc`（リクエスト/レスポンス）の2パターン。AgentChat層では`BaseGroupChatManager`が中央Hub。

メッセージ型: TextMessage, MultiModalMessage, ToolCallRequestEvent, ToolCallExecutionEvent, HandoffMessage, StopMessage 等

### 機能一覧

#### エージェント

| 機能 | 概要 | 分類 |
|------|------|------|
| **AssistantAgent** | LLMベース汎用エージェント。ツール使用、ストリーミング | コア |
| **UserProxyAgent** | 人間の入力をチャットに注入 | コア |
| **CodeExecutorAgent** | コード実行専用（承認フロー付き） | コア |
| **SocietyOfMindAgent** | チーム全体を1エージェントとしてカプセル化 | 差別化 |
| **MessageFilterAgent** | メッセージフィルタリング | ユーティリティ |

#### チーム/オーケストレーション

| 機能 | 概要 | 分類 |
|------|------|------|
| **RoundRobinGroupChat** | 固定順序巡回 | コア |
| **SelectorGroupChat** | LLMが次の発言者を動的選択 | コア |
| **Swarm** | OpenAI Swarmスタイルのハンドオフ | コア |
| **MagenticOneGroupChat** | Magentic-Oneパターンの高度なオーケストレーション | 差別化 |
| **GraphFlow (DiGraph)** | グラフベースのワークフロー定義 | 差別化 |
| **AgentTool** | エージェントをツールとして他エージェントに公開 | 差別化 |

#### 終了条件（8種）

MaxMessage, TextMention, StopMessage, TokenUsage, Handoff, Timeout, External, Functional — `|` `&`演算子で合成可能

#### コード実行サンドボックス（5実装）

Docker, Docker Jupyter, Azure Container Apps, Local, Jupyter

#### モデルクライアント

OpenAI / Azure OpenAI / Anthropic / Ollama / llama.cpp / Semantic Kernel統合 / キャッシュ / リプレイ

#### ツール統合

MCP, LangChain Tools, Semantic Kernel Tools, GraphRAG, Azure Tools, HTTP Tools, Code Execution

#### 特殊エージェント

WebSurfer, FileSurfer, VideoSurfer, Magentic-One Agents, Azure AI Agent, OpenAI Assistant Agent

#### 開発者ツール

- **AutoGen Studio**: ノーコードGUI（ドラッグ&ドロップ）
- **agbench**: エージェントベンチマークスイート
- **Magentic-One CLI**: コマンドライン実行

#### インフラ

gRPC分散ランタイム, State管理（保存/復元）, Memory, Auth, Cache Store, OpenTelemetry

### 特徴的な点

**1. GroupChatのマルチエージェント会話制御**

4戦略: RoundRobin（固定順序）、Selector（LLM動的選択）、Swarm（ハンドオフ）、MagenticOne（計画+進捗追跡+委任）。`BaseGroupChatManager`がHub。

**2. コード実行サンドボックスの多層設計**

Docker（使い捨てコンテナ）、Docker Jupyter（セッション状態維持）、Azure Container Apps（クラウド隔離）、Local（開発用）、Jupyter。`CodeExecutorAgent`に承認フローも内蔵。

**3. SocietyOfMindAgent — チームのネスト**

チーム全体を1エージェントとしてカプセル化。階層的マルチエージェント（チームのチーム）が可能。

**4. GraphFlow — 宣言的ワークフロー**

`DiGraphBuilder`で有向グラフベースのワークフロー定義。条件分岐、並列実行、ループ。

**5. MCP統合**

`McpWorkbench`でMCPサーバーをツールとして接続。READMEクイックスタートにPlaywright MCP統合を紹介。

### v0.2 → v0.4 変更

| 観点 | v0.2 | v0.4 |
|------|------|------|
| 設計 | 同期・手続き的 | 非同期・イベント駆動（Actor Model） |
| パッケージ | モノリシック（`pyautogen`） | 分割（core, agentchat, ext） |
| メッセージング | 直接関数呼び出し | Topic-based Pub/Sub + RPC |
| GroupChat | 単一クラス | 5種（RoundRobin, Selector, Swarm, MagenticOne, GraphFlow） |
| 型安全性 | 限定的 | Pyright strict |
| 言語 | Python | Python + .NET |
| 分散実行 | なし | gRPCランタイム |

### 使い方

```bash
pip install -U "autogen-agentchat" "autogen-ext[openai]"
```

```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_ext.models.openai import OpenAIChatCompletionClient

async def main():
    model_client = OpenAIChatCompletionClient(model="gpt-4.1")
    agent = AssistantAgent("assistant", model_client=model_client)
    print(await agent.run(task="Say 'Hello World!'"))

asyncio.run(main())
```

### エコシステム

- **採用:** Novo Nordisk、Microsoft内部、Tufts University、University of Louisville
- **Magentic-One**: GAIAベンチマークでSOTA競争力
- **AG2**: 共同創設者Chi Wang氏がフォーク（github.com/ag2ai/ag2）
- **AutoGen Studio**: ノーコードGUI
- **559人コントリビューター、3,776コミット**
- **評判:**
  - 肯定: 「マルチエージェントAIの民主化」「GroupChatの柔軟性」
  - 否定: 「本番の顧客向けアプリには実用的でない」「複雑なマルチホップQAが苦手」

### 制約

1. **メンテナンスモード**: 新機能は追加されない
2. 本番適性の課題（複雑タスクの信頼性）
3. v0.2→v0.4→Agent Frameworkと二重移行リスク
4. `activeRepoStatus: false`（Microsoft内部で非アクティブ）
5. AG2とのコミュニティ分裂

### 深掘り候補

- `_selector_group_chat.py` (35KB) — LLM動的発言者選択のプロンプト設計
- `_magentic_one/` — Orchestratorの計画・進捗追跡・リプラン
- `_graph/` — GraphFlowの有向グラフ実装
- `_assistant_agent.py` — ツール呼び出しループ、Workbench統合
- `code_executors/docker/` — Dockerコンテナライフサイクル
- `runtimes/grpc/` — 分散ランタイム
- `tools/mcp/` — McpWorkbench実装
