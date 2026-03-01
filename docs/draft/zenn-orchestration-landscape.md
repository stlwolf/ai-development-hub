---
title: "AIエージェント・オーケストレーション21ツールを調べて見えた設計パターンの地図"
emoji: "🗺️"
type: "tech"
topics: ["AI", "agent", "LLM", "orchestration"]
published: false
---

## はじめに

AI駆動開発が当たり前になりつつある中で、「コーディングエージェントにどうタスクを振るか」「複数エージェントをどう協調させるか」というオーケストレーションの問題が出てきます。自前のオーケストレーションツールを検討するにあたり、既存のOSSツール21個を調査し、どんな概念・パターンで作られているかを整理しました。

**注意**: 本記事は自分自身がオーケストレーションツールの設計を検討するために行った調査の整理であり、網羅的なベンチマークや推薦記事ではありません。調査対象にはオーケストレーションツールだけでなく、関連するコーディングエージェント（Aider, SWE-agent等）や汎用エージェントフレームワークも含めています。21ツールを横断して見たときに浮かび上がる**設計パターンの全体像**を共有するものとして読んでいただければと思います。

調査はAIサブエージェントを活用して**2026年2月下旬時点**の情報を収集・整理しており、各ツールの最新状況とは異なる場合があります。Star数やステータスも調査時点のものです。

## 調査した21ツール

まず一覧です。リポジトリへのリンクと調査時点のStars数を載せておきます（2026年2月下旬時点）。

| ツール | リポジトリ | Stars | 言語 | 一言 |
|---|---|---|---|---|
| OpenHands | [OpenHands/OpenHands](https://github.com/OpenHands/OpenHands) | 68,060 | Python | Docker隔離 + EventStream + StuckDetector |
| SWE-agent | [SWE-agent/SWE-agent](https://github.com/SWE-agent/SWE-agent) | 18,528 | Python | Agent-Computer Interface。NeurIPS 2024 |
| Aider | [Aider-AI/aider](https://github.com/Aider-AI/aider) | 40,835 | Python | Repository Map（PageRank + tree-sitter） |
| TAKT | [nrslib/takt](https://github.com/nrslib/takt) | 424 | TypeScript | YAML定義ワークフロー + Faceted Prompting |
| Agent Orchestrator | [ComposioHQ/agent-orchestrator](https://github.com/ComposioHQ/agent-orchestrator) | 710 | TypeScript | 8スロットPlugin + Reactionsパターン |
| CAO | [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator) | 254 | Python | tmux + MCP + ANSIパース |
| Agent Squad | [awslabs/agent-squad](https://github.com/awslabs/agent-squad) | 7,452 | Python/TS | LLMインテント分類ルーティング |
| LangGraph | [langchain-ai/langgraph](https://github.com/langchain-ai/langgraph) | 24,933 | Python/TS | Pregel着想のグラフランタイム |
| Mastra | [mastra-ai/mastra](https://github.com/mastra-ai/mastra) | 21,283 | TypeScript | TS世界のLangChain的統合FW |
| CrewAI | [crewAIInc/crewAI](https://github.com/crewAIInc/crewAI) | 44,400 | Python | Role/Goal/Backstory + Flows |
| OpenAI Agents SDK | [openai/openai-agents-python](https://github.com/openai/openai-agents-python) | 19,068 | Python/TS | 最小プリミティブ主義 |
| Google ADK | [google/adk-python](https://github.com/google/adk-python) | 17,802 | Python/Go/Java/TS | A2Aプロトコルネイティブ |
| MetaGPT | [geekan/MetaGPT](https://github.com/geekan/MetaGPT) | 64,300 | Python | 仮想ソフトウェア会社SOP |
| BeeAI | [i-am-bee/beeai-framework](https://github.com/i-am-bee/beeai-framework) | 3,113 | TS/Python | RequirementAgent（宣言的制約） |
| PydanticAI | [pydantic/pydantic-ai](https://github.com/pydantic/pydantic-ai) | 15,000+ | Python | 型安全エージェント定義 |
| AutoGen | [microsoft/autogen](https://github.com/microsoft/autogen) | 54,713 | Python | ⚠️ メンテナンスモード → Agent Framework |
| ControlFlow | [PrefectHQ/ControlFlow](https://github.com/PrefectHQ/ControlFlow) | 1,388 | Python | ⚠️ アーカイブ済み → Marvin 3.0 |
| PentAGI | [vxcontrol/pentagi](https://github.com/vxcontrol/pentagi) | 6,592 | Go/TS | ペンテスト特化。Graphiti知識グラフ |
| Orca | [scrippt-tech/orca](https://github.com/scrippt-tech/orca) | 284 | Rust | ⚠️ 開発停止 |
| oh-my-claudecode | [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | 7,800+ | TypeScript | Claude Code最大のオーケストレーションPlugin。Team Mode |
| o-m-cc | [kok1eee/o-m-cc](https://github.com/kok1eee/o-m-cc) | 4 | Shell | Claude Code Hooks。分散P2P型 |

⚠️マークのツールは調査時点でメンテナンスモード・アーカイブ済み・開発停止のいずれかです。調査対象に含めたのは、設計パターンの抽出には依然として価値があるためです。

### 調査過程で判明した注意点

- **Claude Flow**（14.3k stars）も調査対象に含めていましたが、コミュニティの検証でMCPツールの大部分がモック実装であることが指摘されたため、上記一覧からは除外しました。Star数と実装の実態は必ずしも一致しません
- **AutoGen**（54.7k stars）は2025年10月にメンテナンスモードに移行しています。Microsoft Agent Frameworkへ統合される方向です
- **ControlFlow**はPrefect社CEOが開発しましたが、2025年8月にアーカイブされ、Marvin 3.0に吸収されています

## まず大きく2つに分かれる

21ツールを「何を自動化するか」で見ると、**ソフトウェア開発に特化したツール**と**用途を問わない汎用エージェントフレームワーク**に大きく分かれます。

### 開発特化型

ソフトウェア開発のワークフロー（コード生成・修正・テスト・レビュー・CI対応等）に焦点を当てたツール群です。Docker隔離やgit worktree分離を備えるツールもあり、「コードを安全に書き換える」ことが設計の前提にあります。

| ツール | 概要 |
|---|---|
| OpenHands | Docker隔離のコーディングエージェント。StuckDetector（5パターン検出）等の品質機構が充実 |
| SWE-agent | SWE-bench特化。LM専用設計のAgent-Computer Interfaceが学術的にも評価 |
| Aider | ターミナルAIペアプログラミング。Repository MapでPageRank的にコード構造を選択 |
| TAKT | YAML宣言型の開発ワークフロー。Claude Code/Codex/OpenCodeの3 SDKを直接統合 |
| Agent Orchestrator | 複数コーディングCLI（Claude Code, Codex, Aider等）をtmux + 8スロットPluginで統合管理 |
| CAO | 複数エージェントCLI（Amazon Q, Claude Code等）のtmux管理。ANSI出力パースで状態検知 |
| oh-my-claudecode | Claude Code最大のオーケストレーションPlugin。32エージェント、Team Mode、Haiku/Opus自動モデルルーティング |
| o-m-cc | Claude CodeのHooksプラグイン。分散P2P型。HANDOVER.mdでVCSベースの知識管理 |

なお、Claude Codeには実験的機能として**Agent Teams**が内蔵されています（2026年2月時点）。ファイルベースのmailbox通信で複数セッションを協調させる機能で、oh-my-claudecodeはTeam Modeとして、o-m-ccはTeammateToolによるP2P協調として、それぞれAgent Teamsの上にオーケストレーションを構築しています。

### 汎用フレームワーク型

コーディングに限らず、任意のタスクのエージェントワークフローを構築するためのフレームワークです。ライブラリとしてアプリケーションに組み込む形が主流です。

| ツール | 概要 |
|---|---|
| LangGraph | Pregel着想のグラフベースエージェントランタイム。Checkpoint + Time Travel |
| OpenAI Agents SDK | 最小プリミティブ主義。Handoff vs Agent-as-Toolの使い分けが明確 |
| Google ADK | 4言語対応。A2Aプロトコルネイティブ。Session Rewind |
| PydanticAI | ジェネリック型による型安全なエージェント定義。4出力モード |
| CrewAI | ロール・ゴール・バックストーリーでチーム定義。Flows |
| AutoGen | マルチエージェント会話フレームワーク。GroupChat 4戦略 ⚠️ |
| BeeAI | 宣言的制約（`force_at_step`等）ベースのエージェント制御 |
| Mastra | Vercel AI SDK統合。Agent+Workflow+RAG+Memory+MCPの統合 |
| MetaGPT | SOP（標準作業手順）ベース。`cause_by`による暗黙的ルーティング |
| Agent Squad | 意図分類（TF-IDF + コサイン類似度）ベースのルーティング |

PentAGI（ペンテスト特化）、ControlFlow（⚠️ アーカイブ済み）、Orca（⚠️ 開発停止）はドメイン特化または停止中のため上記からは分けています。設計パターンの抽出には参考になりました。なお、OpenCode（OSSのAIコーディングCLI）向けの[oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)（35,000+ stars）も存在しますが、Claude Code / Cursor / Codex文脈の本記事のスコープ外として除外しています。

### この2分類で見えること

AI駆動開発の観点では、**開発特化型のワークフロー**を組みたいが、コンテキスト管理・ルーティング・フィードバックといった基盤設計は**汎用FW側の概念**を借りてくる、という関係があります。この記事では両方を同じ10の概念領域で分析しました。その10領域は開発特化・汎用FWに共通する語彙になっています。

## 開発特化型の実装特性（2026年2月下旬時点）

開発特化型8ツールについて、ソフトウェア開発に関わる実装特性を比較します。

| ツール | 実行隔離 | ワークスペース分離 | Git統合 | 並列実行 |
|---|---|---|---|---|
| OpenHands | Docker (1セッション=1コンテナ) | Overlay Mount (CoW) | なし | なし |
| SWE-agent | Docker / Modal / AWS | なし | なし | なし |
| Aider | なし | なし | Auto-Commit | なし |
| TAKT | なし (SDK経由) | git clone --shared | なし | 並列Movement |
| Agent Orchestrator | tmux | worktree / clone (Plugin) | SCM Plugin | 30並列 |
| CAO | tmux | git worktree | なし | 複数セッション |
| oh-my-claudecode | なし (Plugin) | なし | なし | Team Mode (32エージェント) |
| o-m-cc | なし (Plugin) | worktree | git / jj | Agent Teams (P2P) |

| ツール | コードベース理解 | ループ/スタック検出 | LLM接続 |
|---|---|---|---|
| OpenHands | なし | StuckDetector (5パターン) | litellm |
| SWE-agent | ACI (LM専用ツール群) | なし | litellm |
| Aider | Repository Map (PageRank) | なし | litellm |
| TAKT | なし | Loop Monitor / Cycle Detection | SDK直接統合 (3 SDK) |
| Agent Orchestrator | なし | なし | CLIラッパー |
| CAO | なし | Terminal Status Detection | CLIラッパー |
| oh-my-claudecode | なし | なし | CLIラッパー (自動モデルルーティング) |
| o-m-cc | Progressive Disclosure (-33%) | stop-guard / focus-guard | CLIラッパー |

### 読み取れる傾向

**隔離の方式で大きく3グループに分かれます。** Docker隔離（OpenHands, SWE-agent）は最も安全ですが重い。tmux管理（Agent Orchestrator, CAO）は軽量で並列に強いものの、ファイルシステムレベルの隔離は不完全です。Plugin型（oh-my-claudecode, o-m-cc）は最軽量ですが、ホストツールに完全依存します。

**CLIラッパー / Plugin型はLLM接続を自前で持ちません。** Agent Orchestrator, CAO, oh-my-claudecode, o-m-ccはホストのコーディングエージェントCLI（Claude Code, Codex等）をそのまま使い、LLMとの通信はホスト側に委ねています。oh-my-claudecodeは自動モデルルーティング（Haiku/Opus）を持ちますが、これはホスト側のモデル選択を制御する形です。自前でLLM接続を持つツールでは、PythonエコシステムのLiteLLMの採用が多く見られます。

**CI/PR連携まで踏み込んでいるツールは少ないです。** Agent Orchestratorの Reactions（33種のイベント × 4段階優先度でCI失敗→自動修正等）が最も体系的です。CAOのFlow（cronスケジュール実行）も該当します。多くのツールはコード生成までが守備範囲で、その先のCI/レビュー対応は手動か外部連携に頼っています。

## 汎用フレームワーク型の実装特性（2026年2月下旬時点）

汎用FWの主要な実装特性を比較します。

| ツール | 言語 | 提供形態 | 設定スタイル | LLM接続 |
|---|---|---|---|---|
| LangGraph | Python / TS | Library | Code-first | langchain-core |
| OpenAI Agents SDK | Python / TS | Library | Code-first | 独自 + litellm |
| Google ADK | Python / Go / Java / TS | Library + Web UI | Code-first | 独自 |
| PydanticAI | Python | Library | Code-first | 独自 (20+ providers) |
| CrewAI | Python | Library + CLI | Code + YAML | 独自 |
| AutoGen | Python | Library + GUI | Code-first | 独自 |
| BeeAI | TS / Python | Library | Code-first | 独自 (20+) |
| Mastra | TypeScript | Library + CLI + Web UI | Code-first | Vercel AI SDK |
| MetaGPT | Python | Library + CLI | Code + config | 独自 (10+) |
| Agent Squad | Python / TS | Library | Code-first | langchain-core |

**提供形態の凡例**: Library＝コードに組み込み / CLI＝コマンドライン / Web UI＝ブラウザ操作 / GUI＝ノーコード操作

Library + Code-firstが主流で、Pythonが圧倒的です。TypeScriptはMastra、BeeAIが対応しています。Google ADKが4言語（Python / Go / Java / TS）で最大のマルチ言語カバレッジを持っています。

## 10のドメイン概念領域

21ツールに繰り返し登場する概念を抽象化すると、10の領域に整理できました。これは開発特化型と汎用FW型の両方に共通する語彙になります。

| # | 領域 | 問い | 概要 |
|---|---|---|---|
| 01 | Agent Definition | 何者か・何ができるか | ペルソナ、能力宣言、指示・制約、出力契約 |
| 02 | Routing & Delegation | 誰がやるか | Handoff、Agent-as-Tool、意図分類、階層委任 |
| 03 | Flow Control | どんな順序で実行するか | Sequential、Parallel、条件分岐、ループ、グラフ |
| 04 | Execution & Runtime | どこで・どう動かすか | サンドボックス、ワークスペース隔離、ランタイム |
| 05 | State & Memory | 何を覚えているか | チェックポイント、Working/Long-term Memory、圧縮 |
| 06 | Feedback & Validation | 品質をどう保証するか | ガードレール、ループ検出、レビュー、評価 |
| 07 | Human Interaction | 人間がどう関与するか | Interrupt、承認、Resume、Rewind |
| 08 | Event & Reaction | 外部イベントにどう反応するか | EventStream、Hooks、スケジューリング |
| 09 | Tooling & Integration | 外部世界とどうつながるか | MCP、A2A、プラグイン |
| 10 | Observability | 何が起きているかをどう把握するか | トレーシング、可視化、Trajectory |

レイヤー構造で見ると、下層がインフラ寄り、上層がセマンティック寄りになります。

```
┌─────────────────────────────────────────┐
│  10. Observability                      │ ← 横断的関心事
├─────────────────────────────────────────┤
│  07. Human Interaction                  │
│  06. Feedback & Validation              │ ← 品質・安全性
├─────────────────────────────────────────┤
│  08. Event & Reaction                   │
│  03. Flow Control                       │ ← オーケストレーションの核
│  02. Routing & Delegation               │
├─────────────────────────────────────────┤
│  05. State & Memory                     │
│  04. Execution & Runtime                │ ← インフラ層
├─────────────────────────────────────────┤
│  09. Tooling & Integration              │
│  01. Agent Definition                   │ ← 定義・接続
└─────────────────────────────────────────┘
```

OSSが厚く実装しているのは下層（定義・ランタイム・状態管理）と中層のフロー制御です。上層の品質保証・人間介入はツールごとに設計判断が大きく分かれるか、そもそも薄い実装しかない領域でした。

AI駆動開発の文脈では、**04（Execution & Runtime）が特に重要な差別化ポイント**になります。Docker隔離、git worktree分離、ターミナル抽象化といった「コードを安全に触る」ためのインフラは、開発特化型ツールが独自に解決している領域で、汎用FWではカバーされません。

## 横断的な設計パターン

10領域に収まりきらない、複数領域にまたがるパターンをいくつか紹介します。

### マルチエージェント協調の4トポロジー

複数エージェントの協調構造は、大きく4つのトポロジーに分類できました。

**中央集権型（Hub-and-Spoke）** — 1つのオーケストレーターが全エージェントを管理します。oh-my-claudecode（Team Mode）、CrewAI（Hierarchical Process）、Agent Orchestrator等が該当します。制御しやすい反面、オーケストレーターがボトルネックになりやすいです。

**分散P2P型** — 中央管理なし、エージェント同士が直接やり取りします。MetaGPT（`cause_by`によるPub/Sub）、o-m-cc（TeammateTool）等が該当します。スケーラブルですが、一貫性の担保が難しくなります。

**ハイブリッド型（Council + Pipeline）** — 並列議論と逐次処理を組み合わせます。TAKTのTeam Leader Movement（タスク分解→並列実行→集約評価）がこのパターンに該当します。

**Swarm型（動的切り替え）** — Handoffによる動的な制御移譲です。OpenAI Agents SDK、Google ADK等が該当します。柔軟ですが、LLMの判断に依存するため実行パスが予測しにくくなります。

```
タスクが事前に定義可能 ←→ タスクが動的に変化
        │                         │
    中央集権 / Pipeline        Swarm / P2P

探索的（多様な視点）    ←→    収束的（一貫した結果）
        │                         │
    Council（並列）            Pipeline（逐次）
```

### Handoff vs Agent-as-Tool

ルーティングにおいて最も基本的な二項対立がこの2つです。

**Handoff**は制御の完全移譲です。実行権がHandoff先に移り、元のエージェントは待機または終了します（OpenAI Agents SDK, Google ADK, AutoGen等）。**Agent-as-Tool**は制御を保持したまま他エージェントを「ツール」として呼び出し、結果だけ受け取ります（OpenAI SDK `agent.as_tool()`, AutoGen `AgentTool`等）。

「任せる」か「使う」かの違いです。Handoffは会話履歴ごと移譲するため、移譲先が蓄積したコンテキストが元に戻ってきたとき膨張しやすくなります。Agent-as-Toolは呼び出し元が制御を保持するので予測しやすいですが、呼び出し元がボトルネックになりえます。

### ルーティング判断の主体: LLM vs ルール

「誰がやるか」を決める判断を誰が行うかも、大きな設計分岐になります。

**LLM動的判断**はAgent Squad（Classifier）、Google ADK（`transfer_to_agent`ツール自動注入）等で採用されています。柔軟ですが非決定的で、hallucinationリスクがあります。**ルール静的判断**はMetaGPT（`cause_by`ベースの暗黙的ルーティング）やCrewAI（`@router`デコレータによる条件分岐）等で採用されています。実装方式は異なりますが、共通して「LLMの判断に委ねず、事前定義されたルールで振り分ける」点が特徴です。決定的で予測可能ですが、事前にパターンを定義する必要があります。

実際には多くのツールがハイブリッドで、ルールで振れるものはルールで、それ以外をLLMに委ねるアプローチが多いです。

### コンテキスト圧縮の4戦略

LLMのコンテキストウィンドウ制約に対処するための圧縮戦略も、21ツールを横断すると4つのパターンに分類できました。

| 戦略 | 概要 | 代表ツール | トレードオフ |
|---|---|---|---|
| ウィンドウ制限 | 直近N件のみ保持し古い情報を切り捨て | BeeAI (Sliding Window) | シンプルだが古い文脈を喪失 |
| 構造的選択 | コードの構造的重要度で取捨選択 | Aider (Repository Map / PageRank) | 精度が高いがドメイン依存 |
| 段階的開示 | 全情報を保持しつつ必要に応じて展開 | o-m-cc (Progressive Disclosure, -33%) | 情報は失われないがコスト問題は残る |
| LLM要約 | 過去のコンテキストをLLMに要約させて圧縮 | OpenHands (Condenser) | 意味を保持するがLLMコストがかかる |

開発特化型では、Aiderの「Repository Map」（tree-sitter + PageRankでコードベースの重要部分だけをトークン予算内で選択する）が最も洗練されたアプローチです。汎用FWではBeeAIが4種のメモリ戦略を設定で切り替え可能にしています。段階的開示はドキュメント配布のパターンとしてオーケストレーション設計に直接応用できます。

## まとめ

21ツールを調査して見えたことを3つにまとめます。

**開発特化型と汎用FWでは解くべき問題が違います。** 汎用FWはエージェント定義・フロー制御・状態管理といった抽象的な問題を解いています。開発特化型はそれに加えて、コード実行の安全な隔離（Docker/worktree）、コードベース理解（Repository Map, ACI）、CI/PRとの連携といった開発固有の問題を解いています。両方の知見を組み合わせることに価値があります。

**OSSが厚い層と薄い層があります。** 下層のインフラ（実行環境・状態管理・ツール接続）と中層のフロー制御はOSSが充実しています。一方、上層の品質保証（ループ検出、多角的な検証）や、セッションをまたいだ知識管理はまだ発展途上で、ツールごとに独自のアプローチを模索している段階です。自分で工夫する余地が最も大きいのもこの上層になります。

**プロトコルの標準化が進んでいます。** ツール接続のMCPは調査対象の多くが対応しており、エージェント間通信のA2Aも対応が広がりつつあります。MCP（エージェントが何を使えるか）とA2A（エージェントが誰と話せるか）の二層構造が形成されつつあります。

「このドメインにどんなツールがあって、どんな設計パターンが存在するか」の地図として参考になれば幸いです。
