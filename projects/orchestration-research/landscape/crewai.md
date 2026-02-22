---
name: CrewAI
repo: crewAIInc/crewAI
last_reviewed: 2026-02-22
category: framework
---

## CrewAI 調査結果

### 基本情報
- **リポジトリ:** https://github.com/crewAIInc/crewAI
- **言語:** Python (>=3.10 <3.14)
- **最終更新:** 2026-02-19 (v1.9.3安定版 / v1.10.0a1プレリリース)
- **規模:** 44,400+ stars / 280+ contributors / 5,960 forks / 138 releases
- **ライセンス:** MIT
- **運営:** CrewAI Inc.（Series A $18M、Andrew Ng等がエンジェル投資）
- **一言で:** Role/Goal/Backstoryベースのマルチエージェントフレームワーク。Crews（自律協調）とFlows（イベント駆動制御）の2軸

### これは何か・何を解決するのか

「ロールプレイング型の自律AIエージェントをチームとして編成し、複雑なタスクを協調実行する」フレームワーク。各エージェントにRole/Goal/Backstoryを定義するだけでLLMが自律的にタスクをこなす。LangChainから完全独立。Fortune 500の60%が採用、100,000人超の認定開発者。

### 設計思想・アーキテクチャ

**コア抽象:**

| 概念 | 説明 |
|------|------|
| **Agent** | Role/Goal/Backstoryの3属性で定義される自律エンティティ |
| **Task** | description + expected_output + agent の3要素 |
| **Crew** | エージェント群+タスク群+実行プロセス |
| **Flow** | `@start`/`@listen`/`@router`デコレータでイベント駆動ワークフロー |
| **Process** | Sequential（線形）/ Hierarchical（マネージャー委任） |

**アーキテクチャ:**

```
lib/crewai/src/crewai/
├── agent/         # ReAct実行エンジン
├── agents/        # BaseAgent、ビルダー
├── crew.py        # Crew（プロセス実行、バリデーション）
├── task.py        # Task（guardrails, context, output format）
├── process.py     # Sequential, Hierarchical
├── flow/          # Flow（persistence, visualization, human_feedback）
├── memory/        # Unified Memory（encoding/recall flow）
├── knowledge/     # Knowledge sources（PDF, CSV, Excel, JSON, Text）
├── tools/         # BaseTool, MCP, agent_tools
├── a2a/           # Agent-to-Agent対応
├── security/      # Fingerprint
├── hooks/         # LLM/Tool hooks
├── events/        # イベントバス
├── mcp/           # MCP対応
├── lite_agent.py  # LiteAgent（A2A対応）
└── experimental/  # evaluation
```

### 機能一覧

#### コア

| 機能 | 概要 | 分類 |
|------|------|------|
| **Role-Based Agent** | Role/Goal/Backstoryで人格的定義 | コア |
| **Sequential Process** | タスクを定義順に線形実行。前タスク出力がcontext | コア |
| **Hierarchical Process** | マネージャーエージェント自動生成→委任・検証 | コア |
| **Task Context/Dependency** | Task.contextで明示的依存関係 | コア |
| **Flows** | `@start`/`@listen`/`@router` + `or_`/`and_`論理結合 | コア |
| **Crew Kickoff** | `kickoff()`, `akickoff()`, `kickoff_for_each()` | コア |

#### 差別化

| 機能 | 概要 | 分類 |
|------|------|------|
| **Unified Memory** | Short-term/Long-term/Entity統合。encoding_flow/recall_flow | 差別化 |
| **Knowledge Sources** | PDF/CSV/Excel/JSON/Text等からRAGナレッジ構築 | 差別化 |
| **Task Guardrails** | 関数/LLMベースガードレール + リトライ。Hallucination guardrail | 差別化 |
| **Conditional Task** | 前タスク出力で実行/スキップを動的判定 | 差別化 |
| **A2A Protocol** | Google A2A対応 | 差別化 |
| **LiteAgent** | 軽量エージェント。A2A対応、FlowTrackable | 差別化 |
| **Flow Persistence** | フロー状態永続化（一時停止・再開） | 差別化 |
| **Flow Visualization** | DAGの視覚化 | 差別化 |
| **Human-in-the-Loop** | human_input=True + flow/human_feedback | 差別化 |
| **Crew Planning** | 実行前にAgentPlannerが計画生成 | 差別化 |
| **Structured Output** | output_json/output_pydantic/response_model | 差別化 |
| **Streaming** | crew.stream=Trueでリアルタイム出力 | 差別化 |
| **Security/Fingerprint** | エージェント・タスク・クルーに一意識別子。監査・追跡 | 差別化 |

#### ユーティリティ

| 機能 | 概要 | 分類 |
|------|------|------|
| MCP Support | MCPサーバーのツール接続 | ユーティリティ |
| Platform Apps | Asana/GitHub/Gmail/Slack/Jira統合 | ユーティリティ |
| Agent Delegation | allow_delegationで委任 | ユーティリティ |
| Caching | ツール実行結果キャッシュ | ユーティリティ |
| RPM Controller | レートリミット制御 | ユーティリティ |
| i18n/Translations | 多言語プロンプト | ユーティリティ |
| Training | Human Feedbackによる反復改善 | ユーティリティ |
| Replay | 特定タスクからリプレイ | ユーティリティ |
| CLI | `crewai create/run/test/replay` | ユーティリティ |
| Hooks | LLM/ツール実行前後にフック | ユーティリティ |
| Events | EventBusオブザーバビリティ | ユーティリティ |
| Async Execution | タスク単位非同期並列 | ユーティリティ |

### 特徴的な点

**1. Role/Goal/Backstoryモデル**: YAML宣言的定義が直感的。非技術者にも理解しやすい

**2. Sequential vs Hierarchical Process**:
- Sequential: タスク定義順に線形。前タスク出力がcontext
- Hierarchical: `manager_llm`/`manager_agent`でマネージャー自動生成。AgentToolsで委任

**3. Task Dependency Resolution**: contextフィールドで明示的依存。`validate_context_no_future_tasks`で未来タスク参照を禁止。暗黙的DAG解決なし、リスト順序=実行順

**4. Flows + Crews二層アーキテクチャ**: Crews=自律協調、Flows=精密制御。PydanticのState管理、`@router`で条件分岐

**5. LangGraphの5.76倍高速（README内ベンチマーク）**

### 使い方

```bash
uv pip install crewai
crewai create crew my-project
crewai run
```

```python
class MyFlow(Flow[MyState]):
    @start()
    def fetch_data(self):
        return {"sector": "tech"}

    @listen(fetch_data)
    def analyze(self, data):
        crew = Crew(agents=[...], tasks=[...], process=Process.sequential)
        return crew.kickoff(inputs=data)

    @router(analyze)
    def route(self):
        if self.state.confidence > 0.8:
            return "execute"
        return "review"
```

### エコシステム

- **採用:** PepsiCo, Johnson & Johnson, PwC, 米国国防総省。20億回ワークフロー実行
- **Andrew NgのDeepLearning.AIコース**2コースで教材
- **セキュリティ懸念:** GPT-4oで65%テストシナリオでデータ漏洩報告（暗黙的信頼）
- **評判:**
  - 肯定: LangGraph比5.76x高速、セットアップ簡単、YAML直感的
  - 否定: セキュリティ（暗黙的信頼）、テレメトリがデフォルト有効、AMP Suite依存

### 他ツールとの比較

| 観点 | CrewAI | LangGraph | AutoGen | OpenAI Agents SDK |
|------|--------|-----------|---------|-------------------|
| 抽象モデル | Role-Based Team | 状態グラフ | 会話駆動 | 軽量プリミティブ |
| 学習曲線 | 低い | 高い | 中 | 低い |
| メモリ | Unified Memory | Checkpointer | なし（標準） | なし |
| 実行速度 | 5.76x vs LangGraph | 基準 | 中 | 軽量・高速 |
| メンテナンス | 活発 | 活発 | **メンテナンスモード** | 活発 |

### 制約

1. セキュリティ: エージェント間暗黙的信頼がデフォルト
2. タスク依存性はDAGではなくリスト順序
3. テレメトリがデフォルト有効（`OTEL_SDK_DISABLED=true`で無効化）
4. 商用AMP Suite依存（エンタープライズ機能）
5. Unified Memoryはアルファ（v1.10.0a1）
6. consensualプロセスは未実装

### 深掘り候補

- `tools/agent_tools/agent_tools.py` — Hierarchical delegation
- `memory/encoding_flow.py`, `recall_flow.py` — Unified Memory
- `flow/flow.py` — `@start/@listen/@router`のDAG実行
- `agent/` — ReAct実行ループ
- `a2a/wrapper.py` — A2A統合
- `lite_agent.py` — 軽量エージェント
- `utilities/guardrail.py` — ガードレール検証・リトライ
- `translations/` — マネージャーエージェントのプロンプト
