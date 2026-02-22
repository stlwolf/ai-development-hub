---
name: Google ADK
repo: google/adk-python
last_reviewed: 2026-02-22
category: framework
---

## Google ADK (Agent Development Kit) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/google/adk-python
- **言語:** Python (95.7%)、Go / Java / TypeScript 版あり
- **最終更新:** 2026-02-18
- **規模:** 17,802 stars / 2,926 forks / 240 contributors / v1.25.0
- **リリース頻度:** 約2週間ごと（38リリース）
- **ライセンス:** Apache 2.0
- **一言で:** Google発のモデル非依存AIエージェント開発フレームワーク。A2Aプロトコルをネイティブサポート。

### これは何か・何を解決するのか

「ソフトウェア開発の原則をAIエージェント構築に適用する」フレームワーク。単一エージェントから複雑なマルチエージェントオーケストレーションまで一貫したPython APIで扱える。A2Aプロトコルによる異なるフレームワーク間のエージェント連携が最大の差別化。

### 設計思想・アーキテクチャ

- Pydantic BaseModelベースのエージェント定義
- イベント駆動アーキテクチャ（AsyncGeneratorストリーム）
- 階層的エージェントツリー（parent_agent / sub_agents）
- Runnerがステートレスオーケストレータ
- サービス抽象化（SessionService, ArtifactService, MemoryService）

### 機能一覧

#### コア

| 機能 | 概要 | 分類 |
|------|------|------|
| LlmAgent | LLM駆動の非決定的エージェント | Core |
| SequentialAgent | サブエージェント順次実行 | Core |
| ParallelAgent | サブエージェント並列実行 | Core |
| LoopAgent | ループ実行（escalate/max_iterations） | Core |
| LLM動的ルーティング | sub_agentsのdescriptionからLLMが自動ルーティング | Differentiator |
| Session管理 | InMemory/SQLite/Database/Spanner/Vertex AI | Core |
| Session Rewind | 指定invocation IDまで巻き戻し | Differentiator |

#### A2Aプロトコル

| 機能 | 概要 | 分類 |
|------|------|------|
| RemoteA2aAgent | リモートA2Aエージェントをsub_agentとして扱う | Differentiator |
| A2A Server | ADKエージェントをA2Aサーバーとして公開 | Differentiator |

#### ツールエコシステム（25+種類）

FunctionTool, MCPToolset, OpenAPI Tool, Google Search, BigQuery, Bigtable, Pub/Sub, Spanner, Computer Use, LangChain Tool, CrewAI Tool, Agent Tool, etc.

#### コード実行（6種）

BuiltIn, AgentEngineSandbox（1秒以下起動、14日永続化）, Container, GKE, Vertex AI, Unsafe Local

#### 評価・テスト

Agent Evaluator, LLM-as-Judge, Trajectory Evaluator, Safety Evaluator, Hallucination Evaluator

### 特徴的な点・注目ポイント

1. **LLM動的ルーティング**: `transfer_to_agent`ツールをLLMリクエストに自動注入。enum制約で幻覚防止
2. **A2Aプロトコルのネイティブ統合**: MCPが「エージェント→ツール」、A2Aが「エージェント→エージェント」を明確に分離
3. **Session Rewind**: セッションを指定地点まで巻き戻し。状態・アーティファクトを復元
4. **充実のコード実行サンドボックス**: AgentEngineSandbox（1秒以下起動、14日永続化、100MBファイル対応）
5. **5種のセッションバックエンド**: InMemory→SQLite→Database→Spanner→Vertex AIと段階的スケールアップ

### エコシステム・実利用状況

- **採用事例:** Renault Group, Box, Revionics がプロダクション利用
- **盛り上がりの文脈:** Google Cloud Next/I/O 2025での発表が起点。A2Aプロトコルと同時発表
- **コミュニティ:** 539 open issues、Reddit、Google Group、コミュニティリポジトリ
- **周辺ツール:** ADK Web (Dev UI), Agent Engine UI, adk-python-community, ADK Go/Java/TS
- **評判:**
  - 肯定的: Google Cloud統合、マルチ言語、A2A相互運用性
  - 否定的: 依存パッケージが重い、ビルトインツールのサブエージェント制約

### 他ツールとの比較

| 観点 | Google ADK | LangGraph | CrewAI |
|------|------------|-----------|--------|
| ルーティング | LLM動的 + 決定的ワークフロー | カスタムグラフ遷移 | 自動タスク委譲 |
| マルチ言語 | Python/Go/Java/TS | Python/JS | Python |
| エージェント間通信 | A2Aプロトコル（標準化） | なし | なし |
| 独自性 | A2A、Google Cloud統合 | 最高の状態管理粒度 | 直感的チームメタファー |

### 制約・注意点

1. 依存パッケージが35以上（Google Cloud系）で重い
2. A2Aは実験的ステータス（`@a2a_experimental`）
3. ビルトインツールがサブエージェントで使えない制約
4. 破壊的変更のリスク（2週間ごとリリース）
5. Gemini最適化バイアス

### 深掘り候補

| 対象 | パス | 理由 |
|------|------|------|
| LLMフロー推論ループ | `flows/llm_flows/` | reason-actループの核心 |
| エージェント転送 | `flows/llm_flows/agent_transfer.py` | 転送指示の組み立て |
| Runner rewind | `runners.py` | 巻き戻し時の状態復元 |
| RemoteA2aAgent | `agents/remote_a2a_agent.py` | A2A通信の実装詳細 |
| MCPToolset | `tools/mcp_tool/` | MCP接続管理 |
