# orchestration-research

エージェントオーケストレーション・並列エージェントツール群のランドスケープ調査プロジェクト。

## 目的

既存OSSのオーケストレーションツールを体系的に調査し、設計パターン・概念・実装方式を抽出する。抽出した要素を自分の検証知見（認知協調・知識永続化）と合成し、自前のオーケストレーションツール構築の設計基盤とする。

## 背景

- ideas/ と projects/ で蓄積してきた独自の概念（セカンドオピニオン、ルーラーエージェント、4層コンテキストモデル、正準エージェント定義等）は、OSSが手を付けていない「セマンティック層」に位置する
- 一方、OSSが厚く実装している「インフラ層」（ワークスペース隔離、プロセス管理、イベント駆動フィードバック）は自前で書く必要がない
- OSSのインフラ層の設計パターンを抽出し、自分のセマンティック層と組み合わせることで、検証に使える自前ツールの構築を目指す

## 構成

```
orchestration-research/
├── README.md              # このファイル
├── landscape/             # OSSリサーチの集約（ツール単位）
├── concepts/              # 抽出した共通パターン・概念
│   ├── domain/            #   ドメイン概念10領域
│   ├── implementation/    #   実装特性（言語、IF型、デプロイ等）
│   └── cross-cutting/     #   横断的テーマ
└── synthesis/             # 自分の構想との統合設計ノート
```

### landscape/

各OSSツールの調査結果を統一フォーマットで記録。横断比較を可能にする。
`oss-researcher` サブエージェント（`cursor/agents/oss-researcher.md`）による4並列調査で21ツールを調査済み。

- [INDEX.md](./landscape/INDEX.md) — カテゴリ別一覧・注目発見・独自レイヤー対応マップ

統一フォーマット:

```markdown
---
name: <ツール名>
repo: <owner/repo>
last_reviewed: <YYYY-MM-DD>
category: <orchestrator | framework | agent-runtime>
---

## [ツール名] 調査結果

### 基本情報
（リポジトリURL、言語、Stars、最終更新、一言要約）

### これは何か・何を解決するのか
（目的、解決する問題、ターゲットユーザー）

### 設計思想・アーキテクチャ
（核となる設計判断、主要な抽象概念、ディレクトリ構造）

### 機能一覧
（Core / Differentiator / Utility の3分類で網羅的にリスト）

### 特徴的な点・注目ポイント
（他にない独自設計をピックアップ）

### 使い方・典型的なワークフロー
（Getting Started レベルの流れ + 設定例）

### エコシステム・実利用状況
（採用事例、盛り上がりの文脈、コミュニティ、周辺ツール、評判）

### 他ツールとの比較・ポジショニング

### 制約・注意点

### 深掘り候補（コードリーディング対象）
（vendor-inspector 等で実装を読む価値がある箇所をパス付きでリスト）
```

### concepts/

複数のOSSに共通して見られるパターンを抽出・整理。ツール非依存の概念として記録する。

### synthesis/

OSSから抽出した要素と、自分の独自レイヤー（認知協調・知識永続化）を統合する設計ノート。ここが最終的に自前ツール構築の設計文書になる。

## 調査対象（21ツール調査済み）

> 調査方法: `oss-researcher` サブエージェントによる並列調査（4並列 × 5バッチ）
> 調査日: 2026-02-22
> 詳細: [landscape/INDEX.md](./landscape/INDEX.md)

### ワークフロー定義・タスクオーケストレーション型

| ツール | repo | 調査 | 特徴 |
|--------|------|------|------|
| TAKT | nrslib/takt | [✅](./landscape/takt.md) | Faceted Prompting、「強制力」の設計哲学 |
| agent-orchestrator | ComposioHQ/agent-orchestrator | [✅](./landscape/agent-orchestrator-composio.md) | 8スロットプラグイン、Reactionsパターン |
| CAO | awslabs/cli-agent-orchestrator | [✅](./landscape/cao-aws.md) | tmux + MCP + ANSIパース、Flowスケジュール実行 |
| Agent Squad | awslabs/agent-squad | [✅](./landscape/agent-squad-aws.md) | LLMインテント分類ルーティング |

### グラフ/状態管理型フレームワーク

| ツール | repo | 調査 | 特徴 |
|--------|------|------|------|
| LangGraph | langchain-ai/langgraph | [✅](./landscape/langgraph.md) | Pregelランタイム、チェックポイント、Time Travel |
| Mastra | mastra-ai/mastra | [✅](./landscape/mastra.md) | TS世界のLangChain。Agent+Workflow+RAG+Memory統合 |
| ControlFlow | PrefectHQ/ControlFlow | [✅](./landscape/controlflow.md) | ⚠️ アーカイブ済み → Marvin 3.0 |

### マルチエージェント協調フレームワーク

| ツール | repo | 調査 | 特徴 |
|--------|------|------|------|
| AutoGen | microsoft/autogen | [✅](./landscape/autogen.md) | ⚠️ メンテナンスモード → Agent Framework |
| CrewAI | crewAIInc/crewAI | [✅](./landscape/crewai.md) | Role/Goal/Backstory + Flows |
| OpenAI Agents SDK | openai/openai-agents-python | [✅](./landscape/openai-agents-sdk.md) | Handoff vs Agent-as-Tool、Guardrails並列実行 |
| Google ADK | google/adk-python | [✅](./landscape/google-adk.md) | A2Aプロトコル、LLM動的ルーティング |
| MetaGPT | geekan/MetaGPT | [✅](./landscape/metagpt.md) | 仮想ソフトウェア会社SOP、cause_byルーティング |
| BeeAI | i-am-bee/beeai-framework | [✅](./landscape/beeai.md) | RequirementAgent（宣言的ルール制御） |
| PydanticAI | pydantic/pydantic-ai | [✅](./landscape/pydanticai.md) | 型安全エージェント定義、4出力モード |

### 自律コーディング・サンドボックス環境型

| ツール | repo | 調査 | 特徴 |
|--------|------|------|------|
| OpenHands | OpenHands/OpenHands | [✅](./landscape/openhands.md) | Docker隔離、EventStream、StuckDetector |
| SWE-agent | SWE-agent/SWE-agent | [✅](./landscape/swe-agent.md) | ACI（Agent-Computer Interface）、NeurIPS 2024 |
| Aider | Aider-AI/aider | [✅](./landscape/aider.md) | Repository Map（PageRank）、git統合 |

### Claude Code / IDE特化型

| ツール | repo | 調査 | 特徴 |
|--------|------|------|------|
| Claude Flow | ruvnet/claude-flow | [✅](./landscape/claude-flow.md) | ⚠️ 85%がモック実装と判明 |
| oh-my-claude-code / o-m-cc | zephyrpersonal / kok1eee | [✅](./landscape/oh-my-claude-code-and-o-m-cc.md) | 中央型 vs 分散P2P型の比較 |

### ドメイン特化・低レベル基盤

| ツール | repo | 調査 | 特徴 |
|--------|------|------|------|
| PentAGI / Orca | vxcontrol / scrippt-tech | [✅](./landscape/pentagi-and-orca.md) | ペンテスト特化 / Rust LLMパイプライン（停止） |

## 自分の独自レイヤー（OSSにないもの）

OSSがカバーしていない独自概念。landscape/ 調査の比較軸として使用し、concepts/ で10領域への位置づけを整理済み。

| 独自概念 | 概要 | concepts/での位置づけ | synthesis/ |
|---|---|---|---|
| **認知協調** | セカンドオピニオン、ルーラーエージェント（判断履歴ナビゲーション） | [06 Feedback](./concepts/domain/06-feedback-validation.md) + [07 Human](./concepts/domain/07-human-interaction.md) + [協調トポロジー](./concepts/cross-cutting/coordination-topologies.md) | 未着手 |
| **知識永続化** | 4層コンテキストモデル、昇格フロー（episodes → decisions → context） | [05 State & Memory](./concepts/domain/05-state-memory.md) + [コスト最適化](./concepts/cross-cutting/cost-optimization.md) | [context-foundation.md](./synthesis/context-foundation.md) ✅ |
| **ドキュメント設計** | write:read比率による構造化判断、目的指示 vs 手段指示 | [01 Agent Definition](./concepts/domain/01-agent-definition.md) + [Prompt as Architecture](./concepts/cross-cutting/prompt-as-architecture.md) | 未着手 |
| **エージェント定義** | 正準フォーマット（ツール非依存）、ルール分割粒度 | [01 Agent Definition](./concepts/domain/01-agent-definition.md) + [09 Tooling](./concepts/domain/09-tooling-integration.md) | 未着手 |
| **コンテキスト・エンベロープ** | original_intent + trajectory + payload のJSON構造 | [05 State & Memory](./concepts/domain/05-state-memory.md) + [08 Event](./concepts/domain/08-event-reaction.md) | [context-foundation.md](./synthesis/context-foundation.md) で部分カバー |

## 関連資料

| 資料 | 関係 |
|------|------|
| [ideas/20260204/ai-agent-orchestration.md](../../ideas/20260204/ai-agent-orchestration.md) | CLI連携の初期検証。マルチエージェントの本質分析 |
| [ideas/20260208/ai-orchestration-synthesis-next-steps.md](../../ideas/20260208/ai-orchestration-synthesis-next-steps.md) | 棚卸しと次の一手。「契約で固定、ツール名で固定しない」原則 |
| [ideas/20260212/hypothesis-canonical-agent-definition-format.md](../../ideas/20260212/hypothesis-canonical-agent-definition-format.md) | 正準エージェント定義フォーマットの仮説 |
| [ideas/20260220/context-persistence-4layer-model.md](../../ideas/20260220/context-persistence-4layer-model.md) | 4層コンテキスト永続化モデル |
| [ideas/20260221/document-format-design-principles.md](../../ideas/20260221/document-format-design-principles.md) | ドキュメントフォーマット設計原則 |
| [ideas/20260222/orchestration-tool-building-approach.md](../../ideas/20260222/orchestration-tool-building-approach.md) | このプロジェクトの着想（OSSリサーチ→要素抽出→自前構築のアプローチ） |
| [projects/agent-rule-decomposition/](../agent-rule-decomposition/) | ルール分割検証。エージェントへのルール配布の設計に関連 |
| [projects/ruler-agent-verification/](../ruler-agent-verification/) | ルーラーエージェント検証。認知協調レイヤーの実装に関連 |

## 状態

concepts/ 完了。synthesis/ のコンテキスト基盤設計ノート初版完了。

- [x] `landscape/` OSSリサーチ（21ツール調査済み、2026-02-22完了）
- [x] `concepts/domain/` ドメイン概念10領域の定義・パターン抽出
- [x] `concepts/implementation/` 実装特性マトリクス（言語、IF型、ラッパー分類、設定スタイル）
- [x] `concepts/cross-cutting/` 横断的テーマ（LLM抽象化、プロンプト設計、コスト最適化、協調トポロジー）
- [x] `synthesis/context-foundation.md` コンテキスト基盤の統合設計ノート初版
- [ ] `synthesis/` 残りの独自概念（認知協調、正準エージェント定義等）
- [ ] `synthesis/` 全体アーキテクチャ素描
- [ ] 必要に応じて `vendor-inspector` サブエージェントで個別の深掘り実施
