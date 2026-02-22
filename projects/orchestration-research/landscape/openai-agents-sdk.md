---
name: OpenAI Agents SDK
repo: openai/openai-agents-python
last_reviewed: 2026-02-22
category: framework
---

## OpenAI Agents SDK 調査結果

### 基本情報
- **リポジトリ:**
  - Python: https://github.com/openai/openai-agents-python
  - TypeScript: https://github.com/openai/openai-agents-js
- **言語:** Python (primary) / TypeScript
- **最終更新:** 2026-02-22（両リポジトリともアクティブ）
- **規模:**
  - Python: 19,068 stars / 3,175 forks / v0.9.3 / MIT
  - TypeScript: 2,317 stars / 613 forks / MIT
- **作成日:** Python 2025-03-11 / TypeScript 2025-05-31
- **一言で:** Swarmの本番後継。最小限のプリミティブ（Agent / Handoff / Guardrails / Sessions / Tracing）でマルチエージェントワークフローを構築する軽量フレームワーク

### これは何か・何を解決するのか

OpenAI Agents SDKは、OpenAIが2024年にリリースした実験的フレームワーク「Swarm」の **本番対応（production-ready）後継** として2025年3月にリリースされた。

**解決する課題:** マルチエージェントワークフローの構築において、LangChainやCrewAIのような重厚なフレームワークではなく、**最小限のプリミティブ**で柔軟にエージェント間連携を組み立てたいという需要に応える。設計哲学は「少数の明確な抽象だけを提供し、残りはユーザーのPythonコードで表現する」。

**ターゲットユーザー:**
- カスタマーサポート、リサーチ、翻訳など、複数の専門エージェントが連携するワークフローを構築する開発者
- 既存のLLMアプリをマルチエージェント化したいが、巨大なフレームワークは避けたい開発者
- OpenAI以外のモデルも使いたいが、統一的なインターフェースが欲しい開発者

### 設計思想・アーキテクチャ

#### コアの設計判断

1. **最小プリミティブ主義:** 5つのプリミティブ（Agent, Handoff, Guardrail, Session, Tracing）で全てを表現
2. **ループベースの実行モデル:** `Runner.run()` が「LLM呼出 → ツール実行 → 再度LLM呼出」のループを回す
3. **Handoff vs. Agent-as-Tool の二項対立:** エージェント間連携を「制御の移譲（Handoff）」と「ツールとしての呼出（as_tool）」の2パターンに明確に分離
4. **Provider-agnostic:** `ModelProvider` / `Model` インターフェースによる抽象化。`MultiProvider` がプレフィックスベースでルーティング

#### プロジェクト固有の用語

| 用語 | 意味 |
|------|------|
| **Agent** | LLM + instructions + tools + guardrails + handoffs の構成単位 |
| **Handoff** | エージェント間の制御移譲（会話履歴を引き継ぐ） |
| **Agent-as-Tool** | エージェントをツールとして呼出（独立実行、結果を返す） |
| **Guardrail** | 入力/出力/ツールレベルの安全性チェック。tripwire で即座にhalt |
| **Session** | 会話履歴の永続化（SQLite/Redis/OpenAI Conversations） |
| **RunConfig** | 1回の実行に対するグローバル設定 |
| **Trace/Span** | 実行の追跡単位。Traceが全体、Spanが個別操作 |

#### ディレクトリ構造（Python版 `src/agents/`）

```
src/agents/
├── agent.py             # Agent, AgentBase, as_tool()
├── agent_output.py      # 構造化出力スキーマ
├── guardrail.py         # InputGuardrail, OutputGuardrail
├── tool_guardrails.py   # ToolInputGuardrail, ToolOutputGuardrail
├── handoffs.py          # Handoff, handoff(), input_filter
├── memory/              # Session, SQLiteSession, RedisSession, etc.
├── models/              # Model, ModelProvider, MultiProvider, OpenAIProvider
├── extensions/
│   └── models/litellm_provider.py  # LiteLLM統合
├── run.py               # Runner, RunConfig
├── tool.py              # FunctionTool, WebSearchTool, ShellTool, etc.
├── tracing/             # Trace, Span, TracingProcessor
├── voice/               # VoicePipeline (STT → Agent → TTS)
└── realtime/            # RealtimeAgent, RealtimeSession
```

### 機能一覧

#### Core（コア機能）

| 機能 | 概要 | 場所 |
|------|------|------|
| **Agent** | LLM + instructions + tools + handoffs の構成単位。`output_type` で構造化出力対応 | `agent.py` |
| **Runner（エージェントループ）** | `Runner.run()` / `run_sync()` / `run_streamed()` でループ実行。`max_turns` で制限 | `run.py` |
| **Handoff** | `handoffs=[]` で制御移譲先を宣言。LLMには `transfer_to_{name}` ツールとして見える | `handoffs.py` |
| **Agent-as-Tool** | `agent.as_tool()` でエージェントをFunctionToolに変換。制御を手放さず結果だけ受け取る | `agent.py` |
| **Structured Output** | `output_type` にPydantic/dataclassを指定 | `agent_output.py` |
| **Streaming** | `Runner.run_streamed()` でリアルタイムイベント配信 | `stream_events.py` |
| **Context** | `TContext` ジェネリクスによるミュータブルな共有コンテキスト | `run_context.py` |

#### Differentiator（差別化機能）

| 機能 | 概要 | 場所 |
|------|------|------|
| **Input Guardrails（並列実行）** | LLM実行と並列で入力チェック。tripwire で即halt | `guardrail.py` |
| **Output Guardrails** | 最終出力に対する事後検証 | `guardrail.py` |
| **Tool Guardrails** | ツール呼出の前後に挟むバリデーション。allow/reject_content/raise_exception | `tool_guardrails.py` |
| **Sessions（会話メモリ）** | SQLiteSession / RedisSession / OpenAIConversationsSession | `memory/` |
| **Tracing** | 自動Trace/Span生成。OpenAI Dashboard + 20以上の外部プロセッサ対応 | `tracing/` |
| **Provider-agnostic** | MultiProvider + LiteLLM で100+ LLM対応 | `models/multi_provider.py` |
| **Human-in-the-Loop** | ツール実行前の承認フロー | examples |
| **Voice Pipeline** | STT → Agent → TTS の3段パイプライン | `voice/` |
| **Realtime Agents** | WebSocket/WebRTC経由のリアルタイム音声会話 | `realtime/` |

#### Utility（ユーティリティ機能）

| 機能 | 概要 | 場所 |
|------|------|------|
| **MCP統合** | Model Context Protocol サーバーからツールを動的取得 | `mcp.py` |
| **Web Search Tool** | OpenAI組込みのWeb検索 | `tool.py` |
| **File Search Tool** | ファイル検索 | `tool.py` |
| **Code Interpreter Tool** | コード実行 | `tool.py` |
| **Computer Tool** | コンピュータ操作（CUA） | `computer.py` |
| **Shell Tool** | シェル実行 | `tool.py` |
| **Apply Patch Tool** | パッチ適用 | `editor.py` |
| **Dynamic Instructions** | `instructions` にCallableを渡してランタイム生成 | `agent.py` |
| **Lifecycle Hooks** | AgentHooks / RunHooks でライフサイクルにフック | `lifecycle.py` |
| **Handoff Input Filters** | handoff時の会話履歴フィルタリング | `extensions/handoff_filters.py` |
| **Compaction** | 長い会話のトークン圧縮 | `memory/` |
| **Visualization** | graphviz でエージェントグラフ可視化 | optional |

### 特徴的な点・注目ポイント

#### 1. Handoff vs. Agent-as-Tool の二項対立

核心的な設計判断。エージェント間連携を2つの明確に異なるパターンに分離:

**Handoff（制御の移譲）:** 新エージェントが会話を「引き継ぐ」。会話履歴全体が渡される。カスタマーサポートのルーティング等。

**Agent-as-Tool（ツールとしての呼出）:** 元のエージェントが制御を保持。サブエージェントは独立実行して結果だけ返す。翻訳の並列実行等。

```python
# Handoff: 制御を完全に移譲
triage = Agent(handoffs=[billing_agent, support_agent])

# Agent-as-Tool: 結果だけ受け取る
orchestrator = Agent(tools=[
    translator.as_tool(tool_name="translate_fr"),
])
```

#### 2. Guardrails の並列実行パターン

入力ガードレールはデフォルトでLLMの実行と**同時に**走る。高速な安価モデルでガードレール、遅い高価モデルで本体、という使い分けが可能。tripwire発火で即halt。

#### 3. Provider-agnostic 設計

`MultiProvider` + `LiteLLM` で100+ LLM対応。プレフィックスベースルーティング（`litellm/anthropic/claude-3`）。

#### 4. Swarmからの進化

| 観点 | Swarm (2024) | Agents SDK (2025-) |
|------|-------------|-------------------|
| ステータス | 実験的 | 本番対応 |
| ガードレール | なし | Input / Output / Tool の3レイヤー |
| セッション | なし | SQLite / Redis / OpenAI Conversations |
| トレーシング | なし | 組込み + 20以上の外部連携 |
| Agent-as-Tool | なし | `agent.as_tool()` |
| プロバイダ非依存 | OpenAIのみ | 100+ LLM |
| 音声 | なし | Voice Pipeline + Realtime |

### 使い方・典型的なワークフロー

```python
from agents import Agent, Runner

# 最小構成
agent = Agent(name="Assistant", instructions="You are a helpful assistant")
result = Runner.run_sync(agent, "Hello!")

# Handoffによるルーティング
triage = Agent(
    name="Triage",
    handoffs=[spanish_agent, english_agent],
)

# Agent-as-Tool
orchestrator = Agent(
    tools=[fr_agent.as_tool(tool_name="translate_fr")],
)

# 非OpenAIモデル
from agents.extensions.models.litellm_model import LitellmModel
agent = Agent(model=LitellmModel(model="litellm/anthropic/claude-sonnet-4"))
```

### エコシステム・実利用状況

- **採用事例:** Microsoft Azure OpenAI + API Management との統合ガイドが公式ブログで公開。バンキングシステム等のエンタープライズ事例報告あり
- **盛り上がりの文脈:** 2025年3月の「New tools for building agents」発表が起点。Swarmユーザーの自然移行 + OpenAI公式推奨
- **コミュニティ:** Python版 Open Issues 93件、JS版 35件。日本語圏ではZenn・Qiitaに実装ガイドが複数存在
- **周辺ツール:** トレーシング20以上（Langfuse, LangSmith, Braintrust等）、LiteLLM、Vercel AI SDK adapter
- **評判:**
  - 肯定的: 「Swarmの良さを保ちつつ本番対応になった」「学習コストが低い」
  - 否定的: まだv0.9.3で破壊的変更リスク。LiteLLM統合はベータ。JS版がPython版に遅れている

### 他ツールとの比較・ポジショニング

| 観点 | Agents SDK | LangGraph | CrewAI | AutoGen |
|------|-----------|-----------|--------|---------|
| 設計哲学 | 最小プリミティブ | グラフベースの状態機械 | ロール指向のクルー | マルチエージェント会話 |
| 学習コスト | 低い | 中〜高 | 中 | 高い |
| プロバイダ | 100+（LiteLLM経由） | 任意 | 任意 | 任意 |
| トレーシング | 組込み + 20+外部 | LangSmith統合 | 組込み | 限定的 |
| 音声対応 | 組込み | なし | なし | なし |

### 制約・注意点

- v0.9.3、v1.0未到達。API変更リスクあり
- LiteLLM統合はベータ
- Input Guardrailは最初のエージェントでのみ実行
- Output Guardrailは最後のエージェントでのみ実行
- JS版がPython版より機能が遅れている（Sessions未実装等）
- Python 3.10+必須

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 理由 |
|------|------|------|
| エージェントループ本体 | `src/agents/run.py` | Runner.run() のループ実装詳細 |
| Agent-as-Tool の状態管理 | `src/agents/agent_tool_state.py` | ネストされたエージェント実行の承認・再開 |
| Handoff実装 | `src/agents/handoffs.py` | input_filter、会話コンテキスト伝搬 |
| MultiProvider ルーティング | `src/agents/models/multi_provider.py` | プレフィックスベースのプロバイダ解決 |
| LiteLLM Provider | `src/agents/extensions/models/litellm_provider.py` | Responses API → Chat Completions API 変換 |
| トレースプロセッサ | `src/agents/tracing/` | BatchTraceProcessor のバッチ処理 |
| Voice Pipeline | `src/agents/voice/` | STT → Agent → TTS パイプライン |
