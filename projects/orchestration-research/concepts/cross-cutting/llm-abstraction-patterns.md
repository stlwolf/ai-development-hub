# LLM Abstraction Patterns — LLMプロバイダー抽象化パターン

> エージェントがLLMに接続する際の中間抽象レイヤーの設計パターン。

**横断する領域**: [01 Agent Definition](../domain/01-agent-definition.md)（モデル選択）+ [04 Execution & Runtime](../domain/04-execution-runtime.md)（ランタイム依存）+ [09 Tooling & Integration](../domain/09-tooling-integration.md)（プロバイダー接続）

## なぜ横断的か

LLMプロバイダー抽象は「どのモデルを使うか」（Agent Definition）、「どう接続するか」（Tooling）、「ランタイムに何が必要か」（Runtime）を同時に決定する。単独のドメイン領域では扱いきれない。

## 4つの抽象パターン

### 1. 統一ラッパー型（litellm）

OpenAI互換APIで全プロバイダーに接続する薄いラッパー。

| ツール | 利用方式 | プロバイダ数 |
|---|---|---|
| OpenHands | LiteLLM直接利用 | 100+ |
| SWE-agent | litellm経由 | 100+ |
| Aider | litellm経由 | 100+ |
| OpenAI Agents SDK | LiteLLMをMultiProvider経由で利用（opt） | 100+ |

**特徴**:
- `litellm/anthropic/claude-3-opus` のようなプレフィックスベースルーティング
- 最小の統合コスト。1行の変更でプロバイダー切り替え
- Python エコシステムでの事実上の標準

**制約**:
- OpenAI API形式に正規化するため、プロバイダー固有機能（Anthropicのextended thinking等）が使えない場合がある
- Python only

### 2. フレームワーク統合型（langchain-core）

LangChainエコシステムのLLM抽象レイヤーを利用。

| ツール | 利用方式 |
|---|---|
| LangGraph | langchain-core 必須依存 |
| Agent Squad | langchain_core 経由 |
| ControlFlow | langchain_core + Prefect 3.0 |
| PentAGI | langchaingo (Go fork) |

**特徴**:
- LangChainエコシステム（プロンプトテンプレート、チェーン、メモリ等）との統合
- ChatModel / LLM の抽象クラス階層

**制約**:
- LangChain依存によるオーバーヘッド。LangGraphは「langchain-coreなしでも利用可能」と明記するほど
- 抽象の漏れ（leaky abstraction）問題。LangChain固有の概念がドメインに侵入

### 3. SDK直接統合型

特定のSDKを直接統合し、プロバイダー抽象を自前で実装。

| ツール | 統合先 | 特徴 |
|---|---|---|
| TAKT | Claude Code SDK, Codex SDK, OpenCode SDK | 3 SDKを直接統合。Provider Profiles（5段階優先度解決） |
| Mastra | Vercel AI SDK | 40+プロバイダ。TypeScriptエコシステム |

**特徴**:
- プロバイダー固有機能を完全に活用可能
- TAKTのProvider Profiles: Persona単位でプロバイダー/モデルを切り替え（coder=Codex, reviewer=Claude）

**制約**:
- SDK更新への追従コスト
- 対応プロバイダー追加に個別実装が必要

### 4. 自前抽象型

独自のプロバイダー抽象レイヤーを実装。

| ツール | 方式 | プロバイダ数 |
|---|---|---|
| CrewAI | 独自実装（LangChainから完全独立） | 多数 |
| PydanticAI | 独自実装 + Model Profiles | 20+ |
| BeeAI | `ChatModel.from_name("provider:model")` | 20+ |
| Google ADK | 独自（モデル非依存設計） | 多数 |
| OpenAI Agents SDK | 独自 ModelProvider | OpenAI native + MultiProvider |

**特徴**:
- 完全な制御。プロバイダー固有の最適化が可能
- PydanticAIの **Model Profiles**: プロバイダーごとの能力・制約を自動検出し、ツール呼び出し方式等を自動調整

**制約**:
- 実装・メンテナンスコストが高い
- プロバイダー追加のたびにコード変更が必要

## 設計判断のマトリクス

| 判断軸 | litellm | langchain-core | SDK直接 | 自前抽象 |
|---|---|---|---|---|
| 統合コスト | 低 | 中 | 中 | 高 |
| プロバイダー数 | 100+ | 多数 | 限定 | 要実装 |
| 固有機能アクセス | △ | △ | ◎ | ◎ |
| エコシステム依存 | litellm | LangChain | 各SDK | なし |
| TypeScript対応 | × | △ (langgraphjs) | ◎ (Vercel AI SDK) | ◎ |

## 自前ツール構築への示唆

- **Python + 多プロバイダー**: litellmが現実解。100+プロバイダを最小コストで
- **TypeScript**: Vercel AI SDK（Mastra方式）が有力
- **プロバイダー固有の最適化が必要**: SDK直接統合 + 薄い抽象レイヤー（TAKT方式）
- **長期的な独立性**: PydanticAIのModel Profiles方式。プロバイダー能力の自動検出は将来的に重要
