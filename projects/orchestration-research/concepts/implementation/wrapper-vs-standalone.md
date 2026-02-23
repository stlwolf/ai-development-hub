# Wrapper vs Standalone — ラッパー vs スタンドアロン分析

> ツールが独自実装なのか、既存ツール/CLIのラッパーなのかの分類。自前ツール構築時の「何を自分で書き、何を流用するか」の設計判断に関わる。

## 分類

### スタンドアロン（独自実装）

LLMとの通信からフロー制御まで、コア機能を独自実装しているツール。

| ツール | LLM接続層 | 備考 |
|---|---|---|
| LangGraph | langchain-core | LangChain依存だがグラフランタイムは独自 |
| CrewAI | 独自（LangChainから完全独立と明記） | LangGraphの5.76x高速を主張 |
| OpenAI Agents SDK | 独自 + LiteLLM (opt) | OpenAI APIネイティブ。LiteLLM経由で100+ |
| Google ADK | 独自（モデル非依存設計） | Gemini最適化バイアスあり |
| PydanticAI | 独自（20+プロバイダ直接対応） | Model Profilesでプロバイダごとの能力自動検出 |
| BeeAI | 独自 (`ChatModel.from_name`) | 20+プロバイダ対応 |
| AutoGen | 独自 + MCP/LangChain/Semantic Kernel統合 | 最も広いツール統合 |
| MetaGPT | 独自（10+プロバイダ） | config.yamlで設定 |
| Mastra | Vercel AI SDK | 40+プロバイダに接続 |
| TAKT | Claude Code SDK / Codex SDK / OpenCode SDK | 3 SDKを直接統合。プロバイダー抽象化レイヤーあり |
| OpenHands | LiteLLM | EventStream/AgentController/StuckDetectorは独自 |
| SWE-agent | litellm | ACI/SWE-ReX/HistoryProcessorは独自 |
| Aider | litellm | Repository Map/Edit Format/Git統合は独自 |
| PentAGI | langchaingo (fork) | 35種テンプレート/Graphiti統合/認可フレームワークは独自 |
| Orca | 独自 | Rust実装。開発停止 |

### CLIラッパー（単一対象）

特定のエージェントCLIをラップして拡張する。

| ツール | ラップ対象 | ラップ方式 | 付加価値 |
|---|---|---|---|
| Claude Flow | Claude Code CLI | `child_process.spawn('claude')` | オーケストレーション（主張）。ただし85%モック |
| oh-my-claude-code | Claude Code | Plugin (Hooks) | 中央オーケストレーター、専門エージェントチーム |
| o-m-cc | Claude Code | Plugin (Hooks + Agent Teams) | P2P協調、HANDOVER.md、Progressive Disclosure |

### CLIラッパー（複数対象）

複数のエージェントCLIを統合的にオーケストレーションする。

| ツール | ラップ対象 | ラップ方式 | 付加価値 |
|---|---|---|---|
| Agent Orchestrator | Claude Code, Codex, Aider, OpenCode | tmux + Plugin Slot | 8スロットPlugin、Reactions、30並列管理 |
| CAO | Amazon Q, Kiro, Claude Code, Codex | tmux + ANSI出力パース | 3モード(Handoff/Assign/SendMessage)、Flowスケジュール |

## LLM接続の抽象化レイヤー

スタンドアロンツールがLLMに接続する際の中間層。

### 主要なLLM抽象レイヤー

| レイヤー | 利用ツール | プロバイダ数 | 言語 |
|---|---|---|---|
| **litellm** | OpenHands, SWE-agent, Aider, OpenAI SDK (opt) | 100+ | Python |
| **langchain-core** | LangGraph, Agent Squad, ControlFlow | 多数 | Python |
| **Vercel AI SDK** | Mastra | 40+ | TypeScript |
| **独自実装** | CrewAI, PydanticAI, BeeAI, Google ADK | 10〜20+ | 各言語 |

**litellmが Python エコシステムでの事実上の標準。** OpenAI互換APIで100+プロバイダに接続。

### ラップの深さ

```
薄い（設定注入のみ）──────────────── 厚い（プロセス管理・出力パース）
    │                                        │
    o-m-cc                                 CAO (ANSI出力パース)
    (Hooks + frontmatter)                  Agent Orchestrator (tmux + Plugin)
    oh-my-claude-code                      Claude Flow (spawn)
    (Hooks + Intent Gate)
```

- **薄いラッパー**: ホストツールのHooksやプラグインAPIを利用。ホストの機能に制約される
- **厚いラッパー**: プロセスを外部から管理し、出力をパースして制御。柔軟だが脆い（出力フォーマット変更で破壊）

## パターン・傾向

### ラッパー型の利点と制約

**利点**:
- 既存ツールの機能（コード編集、ファイル操作、git統合等）をそのまま利用
- 実装コストが低い（オーケストレーション層のみ自前）
- ホストツールのエコシステム（MCP等）を継承

**制約**:
- ホストツールのAPIに依存。変更で破壊されるリスク
- 出力パース方式は特に脆い（CAOのANSI正規表現等）
- デバッグが困難（ホストツール内部の動作が不透明）

### スタンドアロン型の利点と制約

**利点**:
- 完全な制御。内部動作をすべて把握・カスタマイズ可能
- 安定したAPI。外部依存による破壊リスクが低い
- テスト・デバッグが容易

**制約**:
- 実装コストが高い（全レイヤーを自前で構築）
- エコシステムの構築が必要

### 自前ツール構築への示唆

- **検証段階**: ラッパー型で素早くプロトタイプ。o-m-ccの薄いラッパー方式が参考
- **プロダクション段階**: コア機能はスタンドアロン化。LLM接続にはlitellm等の実績ある抽象層を利用
- **ハイブリッド**: コアはスタンドアロン、特定エージェントCLI統合はプラグインで提供（Agent Orchestratorの8スロット方式）
