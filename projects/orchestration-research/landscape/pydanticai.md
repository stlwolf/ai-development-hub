---
name: PydanticAI
repo: pydantic/pydantic-ai
last_reviewed: 2026-02-22
category: framework
---

## PydanticAI 調査結果

### 基本情報
- **リポジトリ:** https://github.com/pydantic/pydantic-ai
- **言語:** Python (3.10+)
- **最終更新:** 2026-02-18 (v1.62.0)
- **規模:** 15k stars / 1.7k forks / 週1-2回リリース
- **ライセンス:** MIT
- **一言で:** Pydanticの型安全性をLLMエージェントに持ち込む、FastAPIライクなPythonエージェントフレームワーク

### これは何か・何を解決するのか

FastAPIがWebフレームワークにもたらした「型ヒントベースの開発体験」をAIエージェント開発に持ち込む。LLM出力の型安全性、ツール定義ボイラープレート削減、プロバイダ間統一API、テスト容易性、依存注入を解決。

**設計哲学（AGENTS.md）:** "Light-weight library... prefer strong primitives, powerful abstractions, and general solutions"

### 設計思想・アーキテクチャ

**4つのPythonパッケージ:**

| パッケージ | 役割 |
|---|---|
| `pydantic-ai-slim` | コアフレームワーク |
| `pydantic-graph` | 型ヒントベースグラフライブラリ |
| `pydantic-evals` | 評価フレームワーク |
| `clai` | CLI / Web UIツール |

**コアの型パラメータ:** `Agent[DepsType, OutputType]`

```python
support_agent = Agent(
    'openai:gpt-5.2',
    deps_type=SupportDependencies,
    output_type=SupportOutput,
)
```

**コア抽象:**
- `Agent[DepsT, OutputT]` — エージェント定義の中心
- `RunContext[DepsT]` — 依存注入コンテナ（FastAPIのDepends相当）
- `ToolDefinition` — JSON Schema定義 + `prepare`関数で動的カスタマイズ
- `OutputSpec` — 4出力モード（Tool/Native/Prompted/Text）

### 機能一覧

#### コア

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **Agent[DepsT, OutputT]** | ジェネリック型パラメータによるエージェント定義 | `agent/` | コア |
| **型安全な出力** | Pydantic BaseModelでLLM出力を型保証 + バリデーション失敗自動リトライ | `_output.py` | コア |
| **依存注入（RunContext）** | ContextVarベース、非同期安全。ツール・プロンプト・バリデータに伝搬 | `_run_context.py` | コア |
| **ツールシステム** | デコレータベース。docstringからJSON Schema自動生成 | `tools.py`, `_function_schema.py` | コア |
| **マルチモデル対応** | 20+プロバイダー | `models/` | コア |
| **ストリーミング** | 構造化出力の逐次バリデーション付き | `result.py` | コア |
| **リトライ機構** | バリデーション失敗→LLMフィードバック→再試行 | `retries.py` | コア |

#### 差別化

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **4つの出力モード** | Tool/Native/Prompted/Text + auto選択 | `output.py` | 差別化 |
| **Toolsetアーキテクチャ** | Combined/Filtered/Prefixed/Renamed/Approval等の合成可能Toolset | `toolsets/` | 差別化 |
| **Human-in-the-Loop** | ToolApproved/ToolDenied承認フロー | `tools.py` | 差別化 |
| **Deferred Tools** | 外部実行が必要なツールの遅延実行 | `tools.py` | 差別化 |
| **pydantic-graph** | 型ヒントベースグラフ定義（Mermaid図自動生成） | `pydantic_graph/` | 差別化 |
| **pydantic-evals** | コードファースト評価（LLM-as-Judge対応） | `pydantic_evals/` | 差別化 |
| **Durable Execution** | Temporal/Prefect/DBOSの3方式対応 | `durable_exec/` | 差別化 |
| **Model Profiles** | プロバイダーごとの能力・制約を自動検出 | `profiles/` | 差別化 |

#### ユーティリティ

| 機能 | 概要 | 分類 |
|------|------|------|
| MCP統合 | stdio/SSE/StreamableHTTP | ユーティリティ |
| A2A統合 | FastA2A経由 | ユーティリティ |
| AG-UI統合 | CopilotKit連携 | ユーティリティ |
| 組み込みツール | CodeExecution/WebSearch/Memory/FileSearch/ImageGeneration | ユーティリティ |
| Logfire統合 | OpenTelemetryオブザーバビリティ | ユーティリティ |
| clai CLI | ターミナルからLLMチャット | ユーティリティ |
| Fallbackモデル | 障害時自動フォールバック | ユーティリティ |
| Concurrency制御 | Agent/Model同時実行数制限 | ユーティリティ |
| SSRF防御 | ファイルURL取得時のローカルネットワーク制限 | ユーティリティ |

### 特徴的な点

**1. 型安全な出力 + 自動リトライ**

最大の差別化。バリデーション失敗→LLMにフィードバック→再試行をフレームワークレベルで保証。

**2. 4つの構造化出力モード**

- `ToolOutput` — ツールコール経由（デフォルト）
- `NativeOutput` — プロバイダーのネイティブ構造化出力
- `PromptedOutput` — プロンプトにJSONスキーマ埋め込み
- `TextOutput` — プレーンテキスト + 関数後処理

`auto`モードでプロバイダー能力に応じ最適選択。

**3. RunContextによる依存注入**

ContextVarベースでasync安全。FastAPIのDependsと同等の開発体験。

**4. Toolset合成パターン**

デコレータパターンで合成可能: Filtered→Prefixed→Renamed→Approval→Combined。ステップごとにツール定義を動的変更する`PreparedToolset`も。

**5. Durable Execution 3方式**

Temporal（リプレイ）、Prefect（トランザクション）、DBOS（チェックポイント）。公開APIのみ使用、他のdurable executionシステムとの統合リファレンス。

### 使い方

```python
from pydantic_ai import Agent
from pydantic import BaseModel, Field

class AnalysisResult(BaseModel):
    summary: str
    risk_level: int = Field(ge=0, le=10)

agent = Agent('openai:gpt-5.2', output_type=AnalysisResult)
result = agent.run_sync('Analyze this data')
# result.output は AnalysisResult 型保証
```

```python
# 依存注入 + ツール
@agent.tool
async def get_user_data(ctx: RunContext[MyDeps], include_history: bool) -> dict:
    return await ctx.deps.db.get_user(ctx.deps.user_id, include_history)

result = await agent.run('Analyze this user', deps=MyDeps(db=conn, user_id=42))
```

### エコシステム

- **採用:** Boosted.ai（日次5万+ワークフロー）、Tiger Data、ARIJ Network、Mixam
- **盛り上がりの文脈:** Pydanticブランドの信頼性（OpenAI/Anthropic SDK等がPydantic内部利用）+ v1.0 GA（2025年9月）
- **周辺:** Logfire, FastA2A, CopilotKit, Prefect/Temporal/DBOS
- **評判:**
  - 肯定: 型安全性、FastAPIユーザーへの親和性
  - 否定: プロバイダー間スキーマ互換問題、Logfire商用誘導、日本語情報少

### 他ツールとの比較

| 観点 | PydanticAI | OpenAI Agents SDK | LangGraph |
|---|---|---|---|
| 設計思想 | 型安全・Pythonic API | OpenAIエコシステム最適化 | グラフベース状態管理 |
| 型安全性 | Pydantic + ジェネリクスで完全保証 | 基本的 | TypedDict |
| 依存注入 | RunContext[DepsT]正式DI | なし | なし |
| 構造化出力 | 4モード + 自動リトライ | Function calling | パーサー |
| 耐障害性 | Temporal/Prefect/DBOS 3方式 | なし | Checkpointer |
| MCP | ネイティブ | なし | コミュニティ |
| A2A | FastA2A | なし | なし |

### 制約

1. プロバイダー間のスキーマ互換問題（TypedDictオプショナル等がGeminiで動かない）
2. マルチエージェントはpydantic-graph経由でやや重い
3. リリース頻度が高く追従コスト
4. Logfire商用への誘導
5. 日本語情報少なめ

### 深掘り候補

- `_agent_graph.py` — エージェント実行ループの内部グラフ
- `_output.py` — 4出力モード + バリデーション→リトライ
- `_function_schema.py` — Python関数→JSON Schema変換
- `toolsets/abstract.py` — Toolset合成パターン基底
- `pydantic_graph/graph.py` — 型ヒントベースグラフ
- `durable_exec/temporal/` — Temporal統合
- `pydantic_evals/` — 評価フレームワーク設計
