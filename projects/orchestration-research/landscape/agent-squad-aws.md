---
name: Agent Squad
repo: awslabs/agent-squad
last_reviewed: 2026-02-22
category: framework
---

## Agent Squad (AWS Labs) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/awslabs/agent-squad
- **旧名称:** Multi-Agent Orchestrator
- **言語:** Python 63.8% / TypeScript 36.2%（両言語完全実装）
- **最終更新:** 2026-02-11
- **規模:** 7,452 stars / 699 forks / 30 contributors / Apache 2.0
- **リリース:** 17リリース、最新python_1.0.2（2025-06-25）
- **一言で:** LLMベースのインテント分類でユーザークエリを最適なエージェントに動的ルーティングするフレームワーク

### これは何か・何を解決するのか

複数の特化型AIエージェントを束ねて複雑な会話を処理する軽量オーケストレーション。エージェント選択の自動化、技術非依存の統合、会話コンテキスト維持が核心。カスタマーサポート、ヘルスケアAI、旅行計画システムなどがターゲット。

### 設計思想・アーキテクチャ

**Classifier中心アーキテクチャ:**

```
User Input → Classifier（LLM意図分類）→ Agent選択 → Agent処理 → Storage保存 → Response
```

ルーティングロジックをLLMに委ね、各エージェントのdescription＋会話履歴をもとに分類。

**用語:**

| 概念 | 説明 |
|------|------|
| AgentSquad | オーケストレーター本体 |
| Classifier | LLMベース意図分類器 |
| Agent | 処理ユニット抽象基底 |
| ChatStorage | (user_id, session_id, agent_id) 3キー管理 |
| SupervisorAgent | 階層的チーム協調 |
| ChainAgent | 逐次パイプライン |

### 機能一覧

#### Core

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **LLMベースIntent Classification** | agent description + 会話履歴からLLMが分類 | `classifiers/` | Core |
| **Request Routing** | 分類→処理→保存を一貫実行 | `orchestrator.py` | Core |
| **Streaming/Non-streaming** | エージェント単位で制御 | `orchestrator.py` | Core |
| **Context Management** | user/session/agent単位の会話履歴 | `storage/` | Core |
| **Default Agent Fallback** | 分類失敗時のフォールバック | `orchestrator.py` | Core |

#### Differentiator

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **SupervisorAgent** | lead agentがteamに並列タスク委譲。`send_messages`toolで同時送信 | `agents/supervisor_agent.py` | 差別化 |
| **Agent Overlap Analyzer** | TF-IDF + コサイン類似度でdescription重複検出 | `typescript/agentOverlapAnalyzer.ts` | 差別化 |
| **ChainAgent** | 逐次パイプライン | `agents/chain_agent.py` | 差別化 |
| **Tool Use Classification** | 分類結果を構造化出力（selected_agent, confidence） | `classifiers/bedrock_classifier.py` | 差別化 |
| **Modular Install** | `pip install agent-squad[aws]` 等 | `pyproject.toml` | 差別化 |

#### 組み込みエージェント

BedrockLLMAgent, Amazon Bedrock Agent, AnthropicAgent, OpenAIAgent, LexBotAgent, LambdaAgent, BedrockFlowsAgent, BedrockInlineAgent, BedrockTranslatorAgent, ComprehendFilterAgent, ChainAgent, SupervisorAgent, StrandsAgent（MCP対応）

#### ストレージ

InMemoryChatStorage, DynamoDbChatStorage（TTL対応）, SqlChatStorage（libsql/Turso）

### 特徴的な点

**1. Intent Classifierの設計**

プロンプトに`{{AGENT_DESCRIPTIONS}}`と`{{HISTORY}}`を埋め込み、LLMが「AgentMatcher」として最適エージェントを選択。フォローアップ検出（短い応答→前回エージェント継続）、コンテキストスイッチ対応。BedrockClassifierはtoolUseで`{selected_agent, confidence}`を構造化出力。`temperature: 0.0`で決定的分類。

**2. Agent Overlap Analysis**

TF-IDF（`natural`ライブラリ）でdescriptionをベクトル化、コサイン類似度でペアワイズ重複計算。閾値: >30% = High conflict, >10% = Medium, <10% = Low。エージェント追加時にClassifier分類精度低下を事前防止。

**3. Storage抽象の3キー設計**

`(user_id, session_id, agent_id)` の3組でメッセージ管理。`fetch_chat(agent_id)` = 特定エージェントの会話、`fetch_all_chats()` = 全エージェントの会話をタイムスタンプ順にマージ。Assistantメッセージに`[agent_id]`プレフィックス付与でClassifierがどのエージェントの応答か識別。

**4. SupervisorAgent — Agent-as-Tools パターン**

lead agentに`send_messages` toolを提供し、teamメンバーに`asyncio.gather()` + `asyncio.to_thread()`で並列送信。`toolMaxRecursions = 40`。SupervisorAgent自体をClassifierのagentとして登録すれば階層的システム構築可能。

### Google ADKとの比較

| 観点 | Agent Squad | Google ADK |
|------|-------------|-----------|
| ルーティング | 専用Classifier（フラット1層分類） | 親AgentのLLMがsub_agentsに委譲（階層的） |
| エージェント構造 | フラットレジストリ | 階層ツリー |
| オーケストレーション | ルーティング + Supervisor + Chain | 8パターン（Sequential/Parallel/Loop/Coordinator等） |
| 分類粒度 | Tool Use構造化出力 | LLMの自然な推論フロー |
| Agent Overlap検出 | TF-IDF + コサイン類似度 | なし |
| エージェント自律性 | 単一呼び出し（loopなし） | LlmAgentが自律的に反復 |

**核心的な違い:** Agent Squadはルーティングレイヤー特化。ADKはフルオーケストレーションフレームワーク。

### 使い方

```python
from agent_squad.orchestrator import AgentSquad
from agent_squad.agents import BedrockLLMAgent, BedrockLLMAgentOptions

orchestrator = AgentSquad()
orchestrator.add_agent(BedrockLLMAgent(BedrockLLMAgentOptions(
    name="Tech Agent",
    description="Specializes in technology topics",
)))
response = await orchestrator.route_request("What is Lambda?", 'user123', 'session456')
```

### エコシステム

- **採用事例:** AWS Communityで多数の実装例（フライト予約、E-commerce、コールセンター等）。企業名での本番事例は未公開
- **盛り上がりの文脈:** AWS re:Inventでのマルチエージェント文脈。Multi-Agent Orchestrator→Agent Squadにリブランド
- **コミュニティ:** GitHub Discussions活発。Issue #374「LLMラッパーから真のAgenticシステムへ」が代表的要望
- **リリース頻度鈍化:** 最終リリースが2025-06-25
- **日本語コミュニティ:** ほぼなし（Amazon Bedrock AgentCoreの方が議論されている）

### 制約

1. **Agentic Loop不在:** 各エージェントは1回呼び出しで完結。ReActパターン未対応
2. **コンテキスト非効率:** `fetch_all_chats()`で全エージェント履歴をClassifierに渡す→トークン消費増大
3. **Agent Overlap AnalyzerがTypeScriptのみ**
4. **AWS偏重:** 14エージェントの多くがAWSサービス
5. **SupervisorAgentの制約:** lead_agentはBedrock/Anthropicに限定
6. **テスト基盤が不明**
7. **リリース頻度鈍化**

### 深掘り候補

| ファイル | 理由 |
|---------|------|
| `classifiers/bedrock_classifier.py` | Tool Use構造化分類の実装 |
| `agents/supervisor_agent.py` | send_messagesツール + asyncio並列実行 |
| `typescript/agentOverlapAnalyzer.ts` | TF-IDF + コサイン類似度の実装 |
| `agents/strands_agent.py` | Strands SDK + MCP統合 |
