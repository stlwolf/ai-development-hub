# エージェントオーケストレーション OSS ランドスケープ

> 調査日: 2026-02-22
> 目的: 既存OSSのオーケストレーションツールを網羅的にリストアップし、設計パターン・概念・実装方式の抽出起点とする。
> 注: Geminiによる初期リストを検証し、補足・追加・修正を行った版。

---

## 1. ワークフロー定義・タスクオーケストレーション型

YAML/コードでワークフローを宣言的に定義し、エージェントの実行順序・レビューループ・品質ゲートを管理するツール群。

### TAKT (nrslib)

- **GitHub:** https://github.com/nrslib/takt
- **言語:** TypeScript
- **概要:** YAML定義のpiece（ワークフロー）にしたがい、計画→実装→レビュー→修正ループを自動実行。Claude Code / Codex / OpenCode対応。音楽メタファー（piece = workflow, movement = step）で設計されている。
- **注目点:**
  - Worktree隔離による安全な並行作業
  - Faceted Prompting（persona/policy/knowledge/instructionの分離合成）
  - NDJSON実行ログによるトレーサビリティ
  - GitHub Actions連携（issue comment → 自動実行 → PR作成）
  - 日本語ドキュメント完備
- **流用観点:** エージェント定義のモジュール性、YAMLベースのワークフロー宣言、レビューループの実装パターン

### agent-orchestrator (ComposioHQ)

- **GitHub:** https://github.com/ComposioHQ/agent-orchestrator
- **言語:** TypeScript (pnpm monorepo)
- **概要:** 複数AIコーディングエージェント（Claude Code / Codex / Aider）を並列管理するオーケストレーター。各エージェントに独立したgit worktree・ブランチ・PRを割り当て、CI失敗やレビューコメントへの自動対応を行う。
- **注目点:**
  - Agent-agnostic / Runtime-agnostic（tmux / Docker）/ Tracker-agnostic（GitHub / Linear）
  - 8つのスワップ可能なスロット設計（`packages/core/src/types.ts`で全インターフェース定義）
  - Reactionsパターンによるフィードバックループ
  - Web Dashboard（localhost:3000）
  - テスト 3,288件
- **流用観点:** プラグインアーキテクチャ、worktree隔離の実装、フィードバックルーティング

### CLI Agent Orchestrator / CAO (AWS Labs)

- **GitHub:** https://github.com/awslabs/cli-agent-orchestrator
- **言語:** Python (FastAPI)
- **概要:** CLIベースのAI開発ツール（Amazon Q CLI / Claude Code / Kiro CLI / Codex CLI）を階層的マルチエージェントシステムとして統合。tmuxセッションでエージェントを隔離し、MCP経由で協調させる。
- **注目点:**
  - Handoff（同期引き継ぎ）/ Assign（非同期並行）/ Send Message（既存セッションへの通信）の3モード
  - Provider抽象レイヤー（CLIツールごとのアダプター実装）
  - SQLiteによるセッション・メッセージ管理
  - Inbox + Watchdogによるメッセージ配信制御（IDLE検知 → 自動送信）
  - Flowによるスケジュール実行
- **流用観点:** CLIエージェントの抽象化パターン、tmuxセッション管理、非同期メッセージング設計

### Agent Squad (AWS Labs, 旧 Multi-Agent Orchestrator)

- **GitHub:** https://github.com/awslabs/agent-squad
- **言語:** Python / TypeScript
- **概要:** LLMベースのインテント分類でユーザーリクエストを最適なエージェントに動的ルーティングするフレームワーク。エージェントの種類（Bedrock / OpenAI / Lex Bot / Lambda / LangChain等）を問わず統一インターフェースで扱える。
- **注目点:**
  - インテント分類器（Classifier）: エージェントの説明文 + 会話履歴を元にLLMがルーティング先を判断
  - ユーザーID / セッションID / エージェントIDでスコープされたコンテキスト管理
  - Agent Overlap Analysis（エージェント間の責務重複を検出する機能）
  - ストレージ抽象化（InMemory / DynamoDB / SQL、プラグイン可能）
  - ストリーミング・非ストリーミング両対応
  - AWS Lambda / ローカル / 任意クラウドにデプロイ可能
- **流用観点:** インテントベースのルーティング設計、エージェント抽象インターフェース（技術非依存のAgent基底クラス）、会話ストレージのプラグイン設計
- **備考:** CAO（CLI Agent Orchestrator）とは別プロジェクト。CAOはCLIツール統合特化、Agent-Squadは汎用ルーティング特化

---

## 2. グラフ/状態管理型フレームワーク

エージェントの判断の連鎖をグラフ構造で管理し、チェックポイント・リジューム・分岐を提供するフレームワーク。

### LangGraph (LangChain)

- **GitHub:** https://github.com/langchain-ai/langgraph
- **言語:** Python / TypeScript
- **概要:** グラフ理論ベースの状態遷移・ワークフロー制御基盤。LangChainエコシステムのデファクト。
- **注目点:**
  - チェックポイントによるState永続化・リジューム
  - Human-in-the-loop（中断→人間の判断→再開）
  - 条件分岐・ループ・並列の宣言的記述
  - LangSmithとのトレーシング統合
- **流用観点:** 状態永続化（4層コンテキストモデルの「State」化）、割り込み処理の設計パターン

### Mastra

- **GitHub:** https://github.com/mastra-ai/mastra
- **言語:** TypeScript (Next.js / Node.js)
- **概要:** Gatsby創業チームによるTypeScriptネイティブのAIフレームワーク。Agent / Workflow / RAG / Memory / MCP / Evalsを統合提供。YC企業。
- **注目点:**
  - `.then()` / `.branch()` / `.parallel()`による直感的なフロー記述
  - Human-in-the-loop（サスペンド / レジューム）
  - 短期・長期メモリシステム
  - Mastra Studio（ローカルプレイグラウンド）
  - Vercel AI SDK UIとの統合
  - 40+ LLMプロバイダー対応
- **流用観点:** TypeScript環境でのワークフロー記述パターン、メモリ永続化の設計、eval統合

### ControlFlow (Prefect)

- **GitHub:** https://github.com/PrefectHQ/ControlFlow
- **言語:** Python
- **概要:** Prefect社が提供するタスク指向のPythonicなワークフロー制御フレームワーク。既存Pythonコードにエージェントフローを自然に組み込める。
- **注目点:**
  - 構造化されたタスク依存関係管理
  - Prefectエコシステム（オブザーバビリティ）との統合
- **流用観点:** タスク依存関係のモデリング、Pythonネイティブなフロー記述

---

## 3. マルチエージェント協調フレームワーク

複数エージェント間のメッセージパッシング・役割分担・ハンドオフを管理する汎用フレームワーク。

### AutoGen (Microsoft)

- **GitHub:** https://github.com/microsoft/autogen
- **言語:** Python
- **概要:** エージェント同士がメッセージパッシングで協調する基盤。会話ベースの協調パターンが特徴。
- **注目点:**
  - 安全なローカルコード実行コンテナの設計
  - 柔軟なエージェント間通信パターン
  - GroupChatによる複数エージェントの会話制御
- **流用観点:** メッセージパッシングの設計、コード実行サンドボックス

### CrewAI

- **GitHub:** https://github.com/crewAIInc/crewAI
- **言語:** Python
- **概要:** Role / Goal / Backstoryを与えてプロセス順に処理させるフレームワーク。
- **注目点:**
  - 役割ベースのエージェント定義（正準エージェント定義フォーマットとの比較対象）
  - タスク依存関係管理ロジック
  - Sequential / Hierarchical プロセスモード
- **流用観点:** 役割定義のモデリング、タスク依存関係の解決ロジック

### OpenAI Agents SDK（Swarm後継）

- **GitHub:** https://github.com/openai/openai-agents-python (Python) / https://github.com/openai/openai-agents-js (TypeScript)
- **言語:** Python / TypeScript
- **概要:** Swarmの正式プロダクション版。軽量プリミティブ（Agent / Handoff / Guardrails / Sessions / Tracing）でマルチエージェントワークフローを構築。プロバイダー非依存（100+ LLM対応）。
- **注目点:**
  - Handoff: エージェント間の制御移譲のコアメカニズム
  - Guardrails: 入出力バリデーションを実行と並列で走らせる
  - Sessions: 会話履歴の自動管理（永続メモリレイヤー）
  - Tracing: ビルトインの実行トレース
  - Agent as Tool: サブエージェントをツールとして呼び出すパターン
- **流用観点:** ハンドオフのコアロジック（Swarmから進化した実装）、ガードレールの並列実行パターン
- **備考:** 旧Swarm（`openai/swarm`）は教育的参照としてまだ有用だが、プロダクション用途ではこちらが推奨

### Google ADK (Agent Development Kit)

- **GitHub:** https://github.com/google/adk-python
- **言語:** Python / Go / Java
- **概要:** Google製のモデル非依存エージェント開発キット。A2A（Agent-to-Agent）プロトコルをネイティブサポートし、エージェント間のリモート通信を標準化。
- **注目点:**
  - A2Aプロトコル: エージェントをマイクロサービス的に公開・発見・呼び出し（AgentCard JSON）
  - Sequential / Parallel / Loop のワークフローエージェント
  - LLM駆動の動的ルーティング（LlmAgent transfer）
  - セッション管理とRewind（巻き戻し）機能
  - Vertex AI Code Execution Sandbox統合
- **流用観点:** A2Aプロトコルの設計思想（エージェント間通信の標準化）、AgentCardによるエージェント発見メカニズム

### MetaGPT

- **GitHub:** https://github.com/geekan/MetaGPT
- **言語:** Python
- **概要:** 仮想ソフトウェア会社をシミュレートするMAS。PM→Architect→Engineer等の役割でSOPドキュメントを受け渡す。
- **注目点:**
  - SOP（標準作業手順書）のドキュメント受け渡し設計
  - 役割間の成果物フロー
- **流用観点:** ドキュメント駆動のエージェント間協調パターン

### BeeAI Framework (IBM)

- **GitHub:** https://github.com/i-am-bee/beeai-framework
- **言語:** TypeScript / Python
- **概要:** IBM製の堅牢なマルチエージェントシステム。並列・逐次実行の高度な制御。
- **注目点:**
  - エンタープライズ向けのオーケストレーション設計
  - TypeScript / Python両対応
- **流用観点:** エンタープライズ品質の並列実行制御

---

## 4. 自律コーディング・サンドボックス環境型

コード生成→実行→検証のループを自律的に回すための隔離環境・プロセス管理を提供するツール群。

### OpenHands (旧 OpenDevin)

- **GitHub:** https://github.com/All-Hands-AI/OpenHands
- **言語:** Python
- **概要:** 自律型AIソフトウェアエンジニア。Docker/E2Bによる堅牢なワークスペース隔離。
- **注目点:**
  - Dockerベースのサンドボックス環境
  - イベントストリーム管理（エージェントの行動ログをストリームとして扱う）
  - ブラウザ統合
- **流用観点:** **インフラ層の宝庫。** サンドボックス隔離、イベントストリーム、プロセス管理の実装

### SWE-agent (Princeton NLP)

- **GitHub:** https://github.com/princeton-nlp/SWE-agent
- **言語:** Python
- **概要:** GitHub Issue解決に特化。観察→仮説→実行→検証のループ。
- **注目点:**
  - 専用ターミナル環境の設計
  - SWE-benchでの実績
- **流用観点:** 「観察→仮説→実行→検証」ループの実装パターン

### Aider

- **GitHub:** https://github.com/Aider-AI/aider
- **言語:** Python
- **概要:** Git統合のAIペアプログラミングツール。100+言語対応、自動コミット。
- **注目点:**
  - リポジトリ全体のマップ生成（大規模コードベース対応）
  - 差分ベースの編集（git nativeなワークフロー）
  - SWE-bench高スコア
  - `/architect`モード（計画）と`/ask`モード（質問）の分離
- **流用観点:** git統合の設計パターン、リポジトリマップの実装、差分ベース編集のアーキテクチャ

---

## 5. Claude Code / IDE特化型

Claude CodeやIDE環境でのマルチエージェント実行に特化したツール。

### Claude Flow (ruvnet)

- **GitHub:** https://github.com/ruvnet/claude-flow
- **言語:** TypeScript
- **概要:** Claude Code向けマルチエージェントスウォームプラットフォーム。MCP経由でClaude Codeと統合。14.2k stars。
- **注目点:**
  - スウォーム（群れ）型オーケストレーション（Queen-led coordination）
  - Anti-drift機能（エージェントのゴールからの逸脱防止）
  - AgentDB（SQLiteベースの永続メモリ、セマンティック検索）
  - WASM accelerated orchestration
  - Claude Code Agent Teams機能との統合
  - Trust System（エージェントの信頼度スコアリング）
- **流用観点:** スウォーム型協調の実装、anti-drift機構、CLAUDE.md/CLAUDE.local.mdを制御プレーンとして活用する設計思想
- **注意:** 機能の網羅性は高いが、実際の動作品質については要検証

### oh-my-claude-code

- **GitHub:** https://github.com/zephyrpersonal/oh-my-claude-code
- **言語:** JavaScript/Markdown
- **概要:** Claude Code向けマルチエージェントオーケストレーションプラグイン。Ultraworkモード（obsessive task completion）搭載。
- **注目点:**
  - コスト意識の意思決定フレームワーク（FREE → CHEAP → EXPENSIVE）
  - YAML-based agent definitions
  - Hooks / Todo Continuation
- **流用観点:** Claude Codeプラグインの設計パターン、コスト意識型エージェント選択

---

## 6. エージェント定義・型安全性特化

エージェントの入出力定義やモジュール性に焦点を当てたツール。

### PydanticAI

- **GitHub:** https://github.com/pydantic/pydantic-ai
- **言語:** Python
- **概要:** Pydanticによる型安全なエージェント定義。入出力スキーマを厳格に定義。
- **注目点:**
  - 型安全なエージェント定義（正準エージェント定義フォーマットとの比較対象）
  - Pydanticのバリデーション基盤の活用
- **流用観点:** エージェント入出力の型設計、バリデーション統合

### o-m-cc (kok1eee)

- **GitHub:** https://github.com/kok1eee/o-m-cc
- **Zenn:** https://zenn.dev/kok1eeeee/articles/o-m-cc-takt-inspired-update
- **言語:** —
- **概要:** taktインスパイアのマルチエージェント会話制御・コンテキスト管理ツール。
- **注目点:**
  - 認知協調レイヤーの実装サンプル
  - 会話制御ロジック
- **流用観点:** 会話制御の実装、4層コンテキストモデルとの統合可能性
- **備考:** 個人プロジェクト規模。コードリーディング対象として有用

---

## 7. ドメイン特化型

特定の目的に最適化されたオーケストレーション。

### pentagi (vxcontrol)

- **GitHub:** https://github.com/vxcontrol/pentagi
- **言語:** Go
- **概要:** ペネトレーションテストに特化した自律型AIエージェントオーケストレーション。
- **注目点:**
  - 高度な専門手順のオーケストレーション化
  - 「目的指示 vs 手段指示」の設計判断
- **流用観点:** ドメイン特化のワークフロー設計パターン

---

## 8. 低レベル基盤・Rust製

パフォーマンスやメモリ安全性を重視した低レベル基盤。

### Orca (scrippt-tech)

- **GitHub:** https://github.com/scrippt-tech/orca
- **言語:** Rust
- **概要:** Rust製のLLMオーケストレータ。パイプライン・チェーン実行。
- **注目点:**
  - Handlebarベースのプロンプトテンプレーティング
  - WASM対応の構想
  - メモリ安全なLLMパイプライン
- **流用観点:** Rust環境でのLLMオーケストレーション設計
- **備考:** 開発は2023年後半で停滞気味。設計思想の参照向け

---

## 9. プロトコル・標準規格

エージェント間通信やツール統合の標準化を目指す仕様。

### A2A (Agent-to-Agent Protocol)

- **仕様:** https://google.github.io/adk-docs/a2a/
- **提唱:** Google (2025年4月)
- **概要:** AIエージェント間の相互運用性を確保するオープン通信標準。AgentCard（JSONによる能力記述）をwell-knownエンドポイントに公開し、エージェント発見・呼び出しを標準化。
- **注目点:** MCP（ツール統合）との補完関係。MCPが「エージェント→ツール」、A2Aが「エージェント→エージェント」を担当。

### MCP (Model Context Protocol)

- **仕様:** https://modelcontextprotocol.io/
- **提唱:** Anthropic
- **概要:** LLMと外部ツール・データソースの接続を標準化。多くのオーケストレーションツールがMCPを通信レイヤーとして採用。

### AGENTS.md

- **仕様:** https://openai.github.io/agents-spec/
- **提唱:** OpenAI
- **概要:** リポジトリ内にエージェントの振る舞い・権限・ツール制約を宣言するMarkdown規約。

---

## 10. 補足: 確認時の所見

### Geminiリストからの修正点

| 項目 | 修正内容 |
|------|----------|
| Swarm (OpenAI) | 正式にOpenAI Agents SDKへ移行済み。Swarmは「experimental/educational」の位置づけ。プロダクション用途ではAgents SDKを参照すべき |
| Agno (Phidata) | Geminiリストにはagno-agi/agnoとあるが、GitHub検索では存在未確認。PhidataはAgnoに名称変更している模様。要追加調査 |
| Orca (scrippt-tech) | 存在確認済みだが、開発は2023年後半で停滞。Rustベースの参照実装としての価値はあるが、活発なプロジェクトではない |

### Geminiリストに無かった追加候補

| ツール | repo | 追加理由 |
|--------|------|----------|
| **OpenAI Agents SDK** | openai/openai-agents-python | Swarmの後継。現在のOpenAI公式オーケストレーション基盤 |
| **Google ADK** | google/adk-python | A2Aプロトコル統合。エージェント間通信の標準化で重要 |
| **Agent Squad (AWS)** | awslabs/agent-squad | インテントベースの動的ルーティング。過去調査で確認済みだがGemini詳細リストに欠落 |
| **Mastra** | mastra-ai/mastra | TypeScript圏の主要フレームワーク。READMEの調査対象にも記載済みだが、Geminiの詳細リストには欠落 |
| **oh-my-claude-code** | zephyrpersonal/oh-my-claude-code | Claude Code向けプラグイン型。コスト意識型エージェント選択が興味深い |
| **Open Orchestra** | 0xSero/orchestra | OpenCode向けのhub-and-spokeパターンオーケストレーター。Neo4jメモリ統合 |
| **GitHub Agentic Workflows** | github/gh-aw | GitHub Actions統合の公式エージェントワークフロー。CI/CD連携の参考 |

---

## カテゴリ横断: 自分の独自レイヤーとの対応マップ

| 自分の概念 | 最も近いOSS | カバー度 | 備考 |
|-----------|------------|---------|------|
| 認知協調（セカンドオピニオン） | LangGraph（割り込み）/ TAKT（レビューループ） | 部分的 | 「セカンドオピニオンを自動挟む」仕組みは未実装 |
| ルーラーエージェント | Claude Flow（Trust System）/ TAKT（supervisor persona） | 概念的に近い | 判断履歴ナビゲーションは独自 |
| 4層コンテキストモデル | LangGraph（State永続化）/ Mastra（Memory） | インフラ層のみ | episodes→decisions→contextの昇格フローは独自 |
| 正準エージェント定義 | PydanticAI（型定義）/ TAKT（agents.yaml） | 構造のみ | ツール非依存のフォーマットは独自 |
| コンテキスト・エンベロープ | OpenHands（イベントストリーム） | 概念的に近い | original_intent + trajectory + payloadの構造は独自 |
| ドキュメント設計原則 | MetaGPT（SOP受け渡し） | 部分的 | write:read比率判断は独自 |

---

## 推奨コードリーディング優先度

### インフラ層の流用元（実装をパクる）

1. **OpenHands** — サンドボックス隔離、イベントストリーム管理
2. **agent-orchestrator (Composio)** — worktree隔離、Reactionsフィードバック
3. **CAO (AWS Labs)** — CLIエージェント抽象化、tmuxセッション管理

### 設計パターンの参考（考え方をパクる）

1. **OpenAI Agents SDK** — ハンドオフ、ガードレール、Agent as Toolの最小設計
2. **TAKT** — YAML宣言型ワークフロー、Faceted Prompting
3. **LangGraph** — 状態永続化、チェックポイント/リジューム
4. **Google ADK + A2A** — エージェント間通信の標準化思想

### 型設計・定義の参考

1. **PydanticAI** — エージェント入出力の型安全性
2. **Mastra** — TypeScriptでの統合的フレームワーク設計
