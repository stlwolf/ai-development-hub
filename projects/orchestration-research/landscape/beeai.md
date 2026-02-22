---
name: BeeAI Framework
repo: i-am-bee/beeai-framework
last_reviewed: 2026-02-22
category: framework
---

## BeeAI Framework 調査結果

### 基本情報
- **リポジトリ:** https://github.com/i-am-bee/beeai-framework
- **言語:** TypeScript (56.2%) / Python (38.5%)
- **最終更新:** 2025/08/25（ACP → A2A 統合アナウンス）
- **規模:** 3,113 stars / 409 forks / 70 contributors / 159 releases
- **ライセンス:** Apache 2.0
- **ガバナンス:** Linux Foundation AI & Data（2025年4月にIBMから寄贈、Incubation stage）
- **一言で:** IBM発のエンタープライズ向けマルチエージェントフレームワーク。宣言的ルールによるエージェント実行制御が特徴。

### これは何か・何を解決するのか

プロダクション環境で信頼性の高いAIエージェントおよびマルチエージェントシステムを構築するための包括的ツールキット。IBM Researchが開発しLinux Foundationに寄贈。

**解決する課題:**
1. **エージェントの予測不能性:** プロダクション環境でエージェントが重要なステップをスキップ、不適切なツール選択、早期終了する問題
2. **モデル間の実行差異:** 異なるLLMで同じタスクに対して異なる実行パターンが発生する問題
3. **エコシステムのサイロ化:** フレームワーク間でエージェントが連携できない問題（A2A/ACPプロトコルで解決）
4. **デバッグの困難さ:** 非決定的な動作のトラブルシューティング

### 設計思想・アーキテクチャ

**コア設計原則:**
- **宣言的ルールベース:** エージェントの振る舞いを「要件（Requirements）」として宣言的に定義。フレームワークがオーケストレーションを自動処理
- **デュアル言語パリティ:** Python と TypeScript で完全な機能等価性を維持
- **プロトコル中心:** A2A / MCP などのオープンプロトコルを第一級でサポート
- **Emitter パターン:** すべての実行にイベントが発行され、オブザーバビリティを標準装備

**モジュール構成（TypeScript / Python 共通）:**

```
src/
├── agents/          # エージェント実装
│   ├── react/       # ReAct パターン
│   ├── requirement/ # RequirementAgent（宣言的ルール）
│   ├── toolCalling/ # Tool Calling パターン
│   └── lite/        # 軽量エージェント（Python）
├── adapters/        # LLM プロバイダー・プロトコルアダプター
├── backend/         # ChatModel 統一インターフェース
├── workflows/       # ワークフローエンジン
├── tools/           # ツール群
├── memory/          # メモリ戦略
├── serve/           # サーバーホスティング
├── cache/           # キャッシュ
├── emitter/         # イベントシステム
├── middleware/      # ミドルウェア
├── serializer/      # シリアライズ
└── logger/          # ロギング
```

**重要な用語:**
- **RequirementAgent:** ルールベースで実行を制御するエージェント
- **ConditionalRequirement:** ツールの使用条件を宣言する単位（`force_at_step`, `only_after`, `max_invocations` 等）
- **HandoffTool:** エージェント間でタスクを委譲するツール
- **AgentWorkflow:** マルチエージェントワークフローの高レベルAPI
- **Workflow:** ステートマシンベースのワークフローエンジン（`END`, `SELF`, `NEXT`, `PREV`, `START` トランジション）

### 機能一覧

#### コア機能

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **RequirementAgent** | 宣言的ルールでエージェント実行を制御。ループ防止、ツール使用順序の強制、最小/最大呼び出し回数制約 | `agents/requirement/` | 差別化 |
| **ReAct Agent** | Reason + Act パターン | `agents/react/` | コア |
| **Tool Calling Agent** | LLM ネイティブのツール呼び出し | `agents/toolCalling/` | コア |
| **Workflow Engine** | ステートマシンベース。ステップ間遷移、ネスト、条件分岐 | `workflows/` | コア |
| **AgentWorkflow** | マルチエージェントワークフローの高レベルAPI | `workflows/agent.ts` | コア |
| **Backend / ChatModel** | `ChatModel.from_name("provider:model")` で任意プロバイダーに接続 | `backend/` | コア |

#### ツール群

| 機能 | 概要 | 分類 |
|------|------|------|
| **HandoffTool** | エージェント間タスク委譲 | 差別化 |
| **ThinkTool** | ReActパターンの「推論」ステップ | コア |
| **MCP Tool** | Model Context Protocol統合 | コア |
| **OpenAPI Tool** | OpenAPIスペックからツール自動生成 | ユーティリティ |
| **DuckDuckGo / Wikipedia / ArXiv** | 検索ツール群 | ユーティリティ |
| **Python Execution** | Pythonコード実行 | ユーティリティ |
| **LLM Tool** | LLMをツールとして使用 | ユーティリティ |

#### プラットフォーム機能

| 機能 | 概要 | 分類 |
|------|------|------|
| **A2A Protocol** | Agent-to-Agentプロトコル（サーバー/クライアント） | 差別化 |
| **MCP Server** | エージェントをMCPサーバーとしてホスト | コア |
| **Serve Module** | A2A/MCP/watsonx Orchestrate等マルチプロトコルホスティング | コア |
| **メモリ戦略** | Unconstrained, Sliding Window, Summarize, Token-based の4種 | コア |
| **キャッシュ** | LLM呼び出しキャッシュ | ユーティリティ |
| **シリアライゼーション** | エージェント状態の保存・復元 | ユーティリティ |
| **イベントシステム** | Emitterパターンによるオブザーバビリティ | コア |

#### LLMプロバイダーアダプター

OpenAI, Anthropic, Amazon Bedrock, Google Vertex, Groq, Ollama, IBM watsonx, Azure OpenAI, Vercel AI SDK, xAI, LangChain互換, Dummy（テスト用）

### 特徴的な点・注目ポイント

**1. RequirementAgent — 宣言的エージェント制御（最大の差別化要素）**

他のフレームワークにない独自アプローチ。エージェントの振る舞いを「要件」として宣言し、フレームワークが自動的にツール選択とフロー制御を行う。

```python
ConditionalRequirement(ThinkTool, force_at_step=1)
ConditionalRequirement(DuckDuckGoSearchTool, only_after=[OpenMeteoTool], min_invocations=1)
ConditionalRequirement(OpenMeteoTool, consecutive_allowed=False, min_invocations=1)
```

約32行で「まず考える → 天気を調べる → 検索する」を強制可能。LLMのモデル差異を吸収し、小規模モデルでも正しい実行パスを保証。`AskPermissionRequirement` によるHuman-in-the-Loop制御も組み込み済み。

**2. A2A プロトコル — IBM主導のエージェント間通信標準**

IBMが2025年3月にAgent Communication Protocol (ACP) を発表し、Google主導のA2Aプロトコルと統合。Linux Foundation下でオープン標準として管理。BeeAI Frameworkは A2AAgent（クライアント）とA2AServer（サーバー）の両方を実装。

**3. デュアル言語パリティ**

TypeScript版が先行し（2024/09〜）、Python版は2025/02にアルファリリース。モジュール構成がほぼ同一で、Python版はPydantic、TypeScript版はZodでスキーマバリデーション。

**4. Serve モジュール — マルチプロトコルエージェントホスティング**

エージェントをA2A / MCP / AgentStack / watsonx Orchestrate / OpenAI APIs など複数のプロトコルでホスト可能。

### 使い方・典型的なワークフロー

```bash
pip install beeai-framework
pip install 'beeai-framework[a2a]'
pip install 'beeai-framework[mcp]'
npm install beeai-framework
```

```python
from beeai_framework.agents.requirement import RequirementAgent
from beeai_framework.tools.handoff import HandoffTool

weather_agent = RequirementAgent(
    llm=ChatModel.from_name("ollama:granite3.3:8b"),
    tools=[OpenMeteoTool()],
    role="Weather Specialist",
)

main_agent = RequirementAgent(
    llm=ChatModel.from_name("ollama:granite3.3:8b"),
    tools=[
        ThinkTool(),
        HandoffTool(weather_agent, name="WeatherLookup", description="..."),
    ],
    requirements=[ConditionalRequirement(ThinkTool, force_at_step=1)],
)

response = await main_agent.run("What's the weather in Tokyo?")
```

### エコシステム・実利用状況

- **採用事例:** IBM自身がwatsonx Orchestrateと統合。IBMによるマルチエージェント契約管理チュートリアルが公開済み。独立した企業での公開事例は確認できず
- **盛り上がりの文脈:**
  - 2025/04: Linux Foundation AI & Data に寄贈 → オープンガバナンス化
  - 2025/06: RequirementAgent リリース → エージェント信頼性の新アプローチ
  - 2025/08: ACP が A2A に統合 → プロトコル標準化
- **コミュニティ:** 3,113 stars / 4 open issues（消化率高い）/ Discord / GitHub Discussions
- **周辺ツール:** beeai-framework-py-starter / beeai-framework-ts-starter, AgentStack(983 stars), Arize Phoenix統合, OpenTelemetry統合
- **評判:**
  - 肯定的: 「RequirementAgentは既存フレームワークにないアプローチ」「デュアル言語が便利」
  - 否定的: 「Python版アルファ」「ビルトイン評価機能なし」「ツール実行が同期的で遅延」
  - 独立レビュー記事は少なく、IBM発信が大半

### 他ツールとの比較・ポジショニング

| 比較軸 | BeeAI | LangGraph | Mastra |
|--------|-------|-----------|--------|
| コア思想 | 宣言的ルールによるエージェント制御 | グラフベースの状態遷移 | Webアプリ統合のAIフレームワーク |
| 主要言語 | Python + TypeScript（等価） | Python中心 | TypeScript専用 |
| 成熟度 | Python版アルファ | 成熟（18.5k stars） | 成長中 |
| 差別化 | RequirementAgent（宣言的制御） | グラフ構造 + Human-in-the-Loop | DX + Web統合 |

**ポジショニング:** 「エージェントの信頼性・予測可能性」に最もフォーカスしたフレームワーク。IBM watsonxとの深い統合が既存IBMエコシステム組織には大きな利点。

### 制約・注意点

1. **Python版の成熟度:** 2025/02アルファリリース
2. **評価機能の欠如:** ビルトインなし、DeepEval/LangSmith等の外部ツールに依存
3. **同期実行パターン:** ツール実行完了を待つ設計。長時間ツール実行時にUXが低下
4. **IBM依存リスク:** Legal noticeに「IBM is under no obligation to provide enhancements」と明記
5. **独立事例の少なさ:** IBM外での公開プロダクション事例が確認できない
6. **日本語情報の欠如:** Zenn/Qiitaでのカバレッジがほぼゼロ
7. **LangGraph/CrewAI比でのエコシステム規模:** Stars数で約1/6

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 理由 |
|------|------|------|
| RequirementAgent本体 | `agents/requirement/` | 宣言的ルールエンジンの実装詳細 |
| Workflowエンジン | `workflows/workflow.ts` | ステートマシン実装 |
| AgentWorkflow | `workflows/agent.ts` | マルチエージェントオーケストレーション |
| HandoffTool | `tools/handoff.ts` | エージェント間委譲の実装パターン |
| A2Aアダプター | `adapters/a2a/` | A2Aプロトコル実装の詳細 |
| Serveモジュール | `serve/` | マルチプロトコルホスティングの抽象化 |
| Emitterパターン | `emitter/emitter.ts` | イベントシステム。全モジュールの基盤 |
| Backend ChatModel | `backend/` | プロバイダー抽象化。`ChatModel.fromName()` のリゾルバ |
