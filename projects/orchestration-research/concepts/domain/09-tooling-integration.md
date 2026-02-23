# Tooling & Integration — ツール・統合

> エージェントが **外部世界とどうつながるか** を定める概念群。ツール定義、プロトコル、プラグイン機構、外部サービス統合を扱う。

## この領域の問い

- エージェントが使えるツールをどう定義・スキーマ化するか
- エージェント同士をどんなプロトコルで接続するか
- 拡張ポイント（プラグイン）をどう設計するか
- 外部サービス（SCM、Issue Tracker等）とどう統合するか

## 核となる概念

### Tool Definition（ツール定義）

エージェントが利用するツール（関数）のスキーマ定義。

| ツール | 用語 | 特徴 |
|---|---|---|
| PydanticAI | `ToolDefinition` / `Toolset` | `Combined`, `Filtered`, `Prefixed`, `Renamed`, `Approval` の合成パターン |
| Mastra | Tool System | Zodスキーマのtype-safeツール定義 |
| OpenAI Agents SDK | `FunctionTool` | 関数からツールを自動生成 |
| Google ADK | `FunctionTool` | 関数デコレータでツール定義 |
| SWE-agent | ACI (Agent-Computer Interface) | LM専用設計のツール群。ビューア、検索、エディタ、リンターを統合 |
| LangGraph | `ToolNode` | ツール呼び出しノードのプリビルト |
| SWE-agent | `Tool Bundles` | registry, edit_anthropic, windowed, windowed_edit_linting 等 |

**PydanticAIのToolset合成パターン（Filter, Prefix, Rename, Approval）は設計の参考になる。** ツールの組み合わせ・制限・名前空間管理を宣言的に行える。

### MCP — Model Context Protocol

LLMツール接続の事実上の標準プロトコル。ほぼ全ツールが対応。

| ツール | 用語 | 特徴 |
|---|---|---|
| Mastra | `MCP Client` / `MCP Server` | Mastra定義をMCPで外部公開可能 |
| OpenAI Agents SDK | MCP統合 | MCPサーバーからツールを取得 |
| Google ADK | `MCPToolset` | MCPツールセットの統合 |
| AutoGen | `McpWorkbench` | MCP統合レイヤー |
| BeeAI | `MCP Tool` / `MCP Server` | MCPクライアント&サーバー両対応 |
| PydanticAI | MCP統合 | stdio / SSE / StreamableHTTP の3トランスポート |
| CrewAI | MCP Support | MCPサポート |
| CAO | MCP | FastMCP統合 |

### A2A — Agent-to-Agent Protocol

Google主導のエージェント間通信プロトコル。AgentCardでエージェントを発見・接続する。

| ツール | 用語 | 特徴 |
|---|---|---|
| Google ADK | `RemoteA2aAgent` / `A2A Server` | A2Aプロトコルネイティブ対応 |
| CrewAI | `A2A Protocol` / `LiteAgent` | A2A対応の軽量エージェント |
| BeeAI | `A2AAgent` / `A2AServer` / `ACP` | A2A + Agent Communication Protocol |
| PydanticAI | FastA2A | FastA2A経由でA2A対応 |

**MCPが「ツール接続」のプロトコルなら、A2Aは「エージェント接続」のプロトコル。** 補完関係にある。

### Plugin / Slot（プラグイン / スロット）

拡張ポイントを差し替え可能にするアーキテクチャ。

| ツール | 用語 | 特徴 |
|---|---|---|
| Agent Orchestrator | 8スロットPlugin | `Runtime`, `Agent`, `Workspace`, `Tracker`, `SCM`, `Notifier`, `Terminal`, `Lifecycle`。各スロットを独立に差し替え |
| SWE-agent | Tool Bundles | ツールセットをバンドルとして差し替え |

**Agent Orchestratorの8スロットPluginは最も体系的なプラグイン設計。** オーケストレーションの各関心事を独立したスロットに分離している。

### SCM / Tracker Integration（ソース管理・Issue管理統合）

Git、GitHub、Linear等の外部サービスとの統合。

| ツール | 用語 | 特徴 |
|---|---|---|
| Agent Orchestrator | `Tracker` / `SCM` Plugin Slot | GitHub / Linear 統合。Issueから自動spawn |
| Aider | Git Auto-Commit | 変更ごと自動コミット。Conventional Commits準拠メッセージ生成 |
| o-m-cc | VCS統合 | git / jj (Jujutsu) VCSサポート |

### Notification（通知）

外部への通知配信メカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| Agent Orchestrator | `Notifier` Plugin Slot | desktop, slack, composio, webhook。優先度別にチャンネル振り分け |

## パターン・バリエーション

### プロトコルの階層

```
アプリケーションレベル
  │
  A2A (Agent-to-Agent) ── エージェント間通信
  │
  MCP (Model Context Protocol) ── ツール接続
  │
基盤プロトコル (HTTP, gRPC, WebSocket)
```

- **MCP**: 「エージェントが何を使えるか」（ツール発見・呼び出し）
- **A2A**: 「エージェントが誰と話せるか」（エージェント発見・委任）

### プラグインの粒度

- **粗粒度（8スロット）**: Agent Orchestrator。オーケストレーション全体の関心事を分離
- **中粒度（ツールバンドル）**: SWE-agent。ツールセット単位で差し替え
- **細粒度（個別ツール）**: PydanticAI Toolset。ツール単位のFilter/Prefix/Rename

### ツール定義のアプローチ

- **コード由来**: PydanticAI, OpenAI SDK。関数のシグネチャ・docstringからスキーマ自動生成
- **スキーマ由来**: Mastra (Zod), Google ADK (OpenAPI Tool)。スキーマを先に定義
- **LM専用設計**: SWE-agent ACI。人間用ではなくLMのために最適化されたインターフェース

## 独自レイヤーとの接点

- **正準エージェント定義**: A2AのAgentCardが「ツール非依存のエージェント発見」として最も近い。[01 Agent Definition](./01-agent-definition.md) と合わせて参照
- Agent Orchestratorの8スロットPlugin設計は、自前ツール構築時のアーキテクチャ参考になる
