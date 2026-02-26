# Landscape 調査インデックス

> 調査日: 2026-02-22
> 調査方法: oss-researcher サブエージェントによる並列調査（4並列 × 5バッチ）
> 元データ: [orchestration-oss-landscapes.md](./orchestration-oss-landscapes.md)

---

## カテゴリ別一覧

### 1. ワークフロー定義・タスクオーケストレーション型


| ツール                                                    | Stars | 言語         | 一言                                                           | 調査    |
| ------------------------------------------------------ | ----- | ---------- | ------------------------------------------------------------ | ----- |
| [TAKT](./takt.md)                                      | 424   | TypeScript | YAML定義ワークフロー + Faceted Prompting。「強制力」の設計哲学                  | 15KB  |
| [agent-orchestrator](./agent-orchestrator-composio.md) | 710   | TypeScript | 8スロットプラグインアーキテクチャ + Reactionsパターン。30並列                       | 20KB  |
| [CAO](./cao-aws.md)                                    | 254   | Python     | tmux + MCP + ANSIパース。3モード(Handoff/Assign/SendMessage) + Flow | 7KB   |
| [Agent Squad](./agent-squad-aws.md)                    | 7,452 | Python/TS  | LLMインテント分類によるルーティング特化。Agent Overlap Analysis                 | 3.4KB |


### 2. グラフ/状態管理型フレームワーク


| ツール                             | Stars  | 言語         | 一言                                                           | 調査    |
| ------------------------------- | ------ | ---------- | ------------------------------------------------------------ | ----- |
| [LangGraph](./langgraph.md)     | 24,933 | Python/TS  | Pregel着想のグラフランタイム。チェックポイント + Time Travel。月3450万DL            | 12KB  |
| [Mastra](./mastra.md)           | 21,283 | TypeScript | TS世界のLangChain。Agent+Workflow+RAG+Memory+MCP+Evals統合。YC $13M | 5.3KB |
| [ControlFlow](./controlflow.md) | 1,388  | Python     | Prefect 3.0上のタスク中心フレームワーク。⚠️ **アーカイブ済み** → Marvin 3.0        | 1.6KB |


### 3. マルチエージェント協調フレームワーク


| ツール                                         | Stars  | 言語                | 一言                                                            | 調査    |
| ------------------------------------------- | ------ | ----------------- | ------------------------------------------------------------- | ----- |
| [AutoGen](./autogen.md)                     | 54,713 | Python            | 会話ベース協調の先駆者。GroupChat 4戦略。⚠️ **メンテナンスモード** → Agent Framework  | 3.7KB |
| [CrewAI](./crewai.md)                       | 44,400 | Python            | Role/Goal/Backstory + Flows。Fortune 500の60%。LangGraphの5.76x高速 | 4.3KB |
| [OpenAI Agents SDK](./openai-agents-sdk.md) | 19,068 | Python/TS         | Swarm後継。Handoff vs Agent-as-Tool。Guardrails並列実行。100+ LLM      | 12KB  |
| [Google ADK](./google-adk.md)               | 17,802 | Python/Go/Java/TS | A2Aプロトコルネイティブ。LLM動的ルーティング。Session Rewind                      | 5.4KB |
| [MetaGPT](./metagpt.md)                     | 64,300 | Python            | 仮想ソフトウェア会社SOP。cause_byベースの暗黙的ルーティング。ICLR 2024+2025            | 3.2KB |
| [BeeAI](./beeai.md)                         | 3,113  | TypeScript/Python | IBM→Linux Foundation。RequirementAgent（宣言的ルール制御）。A2A対応         | 1.3KB |
| [PydanticAI](./pydanticai.md)               | 15,000 | Python            | 型安全エージェント定義。4出力モード + 自動リトライ。Durable Execution 3方式             | 4.2KB |


### 4. 自律コーディング・サンドボックス環境型


| ツール                         | Stars  | 言語     | 一言                                                                | 調査    |
| --------------------------- | ------ | ------ | ----------------------------------------------------------------- | ----- |
| [OpenHands](./openhands.md) | 68,060 | Python | Docker隔離 + EventStream + StuckDetector 5パターン。Series A $18.8M      | 6.1KB |
| [SWE-agent](./swe-agent.md) | 18,528 | Python | ACI（Agent-Computer Interface）の学術的貢献。NeurIPS 2024。→ mini-SWE-agent | 3KB   |
| [Aider](./aider.md)         | 40,835 | Python | Repository Map（PageRank + tree-sitter）。Git統合。Architect Mode       | 4.8KB |


### 5. Claude Code / IDE特化型


| ツール                                                             | Stars  | 言語         | 一言                                        | 調査    |
| --------------------------------------------------------------- | ------ | ---------- | ----------------------------------------- | ----- |
| [Claude Code Agent Teams](./claude-code-agent-teams.md)         | —      | TypeScript | Claude Code内蔵。ファイルベースmailbox、Team lead/Teammates、Delegate mode | 新規 |
| [Claude Flow](./claude-flow.md)                                 | 14,337 | TypeScript | ⚠️ **85%がモック実装。** 実態はClaude CLIのプロンプトラッパー | 2.9KB |
| [oh-my-claude-code / o-m-cc](./oh-my-claude-code-and-o-m-cc.md) | 0 / 4  | JS / Bash  | 中央オーケストレーター型 vs 分散P2P型。o-m-ccの方が活発で設計が成熟  | 2.8KB |


### 6. ドメイン特化・低レベル基盤


| ツール                                     | Stars       | 言語        | 一言                                      | 調査    |
| --------------------------------------- | ----------- | --------- | --------------------------------------- | ----- |
| [PentAGI / Orca](./pentagi-and-orca.md) | 6,592 / 284 | Go / Rust | ペンテスト特化マルチエージェント / Rust LLMパイプライン（開発停止） | 2.6KB |


### 7. 個人開発者ツールキット（番外）

> steipete（Peter Steinberger）の実践的CLI群。フレームワークではなく、小さな単機能CLIの組み合わせによるオーケストレーション。

| ツール | Stars | 言語 | 一言 | 調査 |
|---|---|---|---|---|
| [agent-scripts](./steipete-ecosystem/agent-scripts.md) | 349 | TS/Bash | AGENTS.MDポインター、docs-list read_when、committer。Ralph（削除済み） | ✅ |
| [Oracle](./steipete-ecosystem/oracle.md) | 1,500 | TypeScript | マルチモデル並列SO。API+ブラウザデュアルエンジン、セッション管理 | ✅ |
| [mcporter](./steipete-ecosystem/mcporter.md) | 2,100 | TypeScript | MCP統合ブリッジ。generate-cliでMCP→CLI変換 | ✅ |
| [Peekaboo](./steipete-ecosystem/peekaboo.md) | 2,300 | Swift | macOSスクリーンキャプチャ+AI画像認識+GUI自動操作 | ✅ |
| [OpenClaw](./steipete-ecosystem/openclaw.md) | 224,000+ | TypeScript | パーソナルAIアシスタント基盤。20+チャネル統合 | ✅ |

詳細: [steipete-ecosystem/INDEX.md](./steipete-ecosystem/INDEX.md)


---

## ツール間の関係性マップ

### Claude Code エコシステムの階層

Claude Codeを中心とした4層のオーケストレーション手段が存在する。上に行くほど自動化度が高く、下に行くほど透明性・制御性が高い。

```
Layer 4: フレームワーク型（Claude Code非依存）
  Agent Orchestrator ──── CAO ──── TAKT
  │ 複数CLI統合              │ tmux+MCP     │ YAML定義
  │ 8スロットPlugin          │ 3モード       │ Faceted Prompting
  └──────────────────────────┴──────────────┘

Layer 3: Claude Code Plugin型
  oh-my-claude-code ──── o-m-cc
  │ 中央オーケストレーター    │ P2P (TeammateTool利用)
  │ Hooks駆動               │ Progressive Disclosure
  └──────────────────────────┘

Layer 2: Claude Code 内蔵機能
  Agent Teams ──── Subagents
  │ ファイルベースmailbox    │ 単一セッション内
  │ Delegate mode            │ 結果のみ返却
  │ コスト2x                 │ 低コスト
  └──────────────────────────┘

Layer 1: 手動CLIオーケストレーション
  steipete agent-scripts ──── Oracle ──── Peekaboo
  │ AGENTS.MDポインター       │ マルチモデルSO   │ 画面認識+GUI
  │ docs-list (read_when)    │ デュアルエンジン  │ v3エージェントフロー
  └──────────────────────────┴────────────────┘
```

### 関係性の詳細

| 関係 | 内容 |
|---|---|
| **steipete → Agent Teams** | steipeteの手動tmuxオーケストレーションが、Agent Teams公式化に影響を与えたと推測。同じファイルベース通信の思想 |
| **Agent Teams → o-m-cc** | o-m-ccはAgent TeamsのTeammateToolを活用してP2P協調を実現。Agent Teamsの上に構築 |
| **Agent Orchestrator ↔ CAO** | 共にtmux + 複数CLI統合だが、Agent Orchestratorは8スロットPlugin、CAOは3モード + ANSIパース。競合関係 |
| **Oracle ↔ arena-compare** | 同じ「マルチモデル並列比較」の発想。OracleはAPI+ブラウザデュアルエンジン+セッション管理付きのフルスペック版 |
| **TAKT ↔ CrewAI** | 共にYAML定義+ロール設計だが、TAKTは音楽メタファ+Faceted Prompting、CrewAIはRole/Goal/Backstory+Flows |
| **Agent Teams ↔ CAO** | 共にmailbox/inbox方式の非同期通信。Agent TeamsはJSON、CAOはInbox+Watchdog |
| **LangGraph ↔ Agent Teams** | LangGraphのCheckpoint+Time TravelはAgent Teamsにない。Agent TeamsはLangGraphよりシンプルだが状態管理が弱い |
| **mcporter ↔ MCP対応ツール全般** | mcporterのgenerate-cli（MCP→CLI変換）はMCPのコンテキストコスト問題への解答。steipete: "CLIs beat MCPs" |
| **Peekaboo ↔ Playwright/SWE-agent ACI** | Peekabooは視覚的認識（スクリーンショット+AI）、PlaywrightはDOM操作、ACIはLM専用IF。補完関係 |

### 設計思想の2軸

```
重量（フレームワーク）───────────────── 軽量（CLI組み合わせ）
  │                                          │
  LangGraph                                steipete agent-scripts
  Mastra                                   o-m-cc
  CrewAI                                   TAKT
  Agent Orchestrator                       CAO
                                           Oracle

内蔵（特定ツール依存）──────────────── 独立（ツール非依存）
  │                                          │
  Agent Teams (Claude Code)                LangGraph
  o-m-cc (Claude Code)                     CrewAI
  oh-my-claude-code (Claude Code)          PydanticAI
  Claude Flow (Claude Code)                Agent Orchestrator (複数CLI)
```

---

## 注目すべき発見

### 予想外のネガティブ発見

- **Claude Flow**: 14.3k starsだが85%のMCPツールがモック実装。テレメトリは`Math.random()`。独立監査で確認済み
- **AutoGen**: 54.7k starsだが2025年10月にメンテナンスモード移行。Microsoft Agent Frameworkへ統合
- **ControlFlow**: Prefect社CEOが開発したが2025年8月にアーカイブ。Marvin 3.0に吸収

### 予想外のポジティブ発見

- **o-m-cc (4 stars)**: 小規模だがPeer-to-Peer Agent Teams、HANDOVER.md VCS知識管理、Progressive Disclosure（-33%トークン削減）など設計が洗練されている
- **PentAGI**: 35種のプロンプトテンプレート、認可フレームワーク、要約認識プロトコルなど、ドメイン特化のプロンプトエンジニアリング知見が豊富
- **BeeAI**: RequirementAgent（宣言的ルール制御）は他にない独自アプローチ。小規模モデルでも正しい実行パスを保証

---

## 自分の独自レイヤーとの対応

> 詳細は `../synthesis/` に別途作成予定。以下は調査から見えた概要マッピング。


| 自分の概念           | 最も近いOSS                                                         | カバー度   | 調査で判明した補足                                                 |
| --------------- | --------------------------------------------------------------- | ------ | --------------------------------------------------------- |
| 認知協調（セカンドオピニオン） | TAKT（レビューループ）/ LangGraph（interrupt）                             | 部分的    | BeeAIのRequirementAgentが「強制的にレビューを挟む」パターンとして近い             |
| ルーラーエージェント      | Claude Flow（Trust System）→ **実態はモック** / TAKT（supervisor）        | 概念のみ   | Agent SquadのClassifier + Overlap Analysisが判断ルーティングとして実用的  |
| 4層コンテキストモデル     | LangGraph（Checkpoint永続化）/ Mastra（4層Memory）                      | インフラ層  | Mastraの Observational Memory（Observer/Reflector自動圧縮）が最も近い |
| 正準エージェント定義      | PydanticAI（型定義）/ TAKT（YAML piece） / CrewAI（Role/Goal/Backstory） | 構造のみ   | Google ADKのAgentCard（A2A）がエージェント発見の標準化として独自               |
| コンテキスト・エンベロープ   | OpenHands（EventStream）                                          | 概念的に近い | o-m-ccのHANDOVER.md VCS知識管理が軽量な代替パターン                      |
| ドキュメント設計原則      | MetaGPT（SOP受け渡し）                                                | 部分的    | MetaGPTのcause_byベース暗黙的ルーティングが文書フローの参考                     |


---

## 次のステップ

- [x] `../concepts/` 完了（domain/ 10領域 + implementation/ 4ファイル + cross-cutting/ 4テーマ）
- [x] `../synthesis/context-foundation.md` コンテキスト基盤の統合設計ノート初版
- [ ] `../synthesis/` 残りの独自概念（認知協調、正準エージェント定義等）
- [ ] 必要に応じて `vendor-inspector` で個別ツールの深掘り（ralph.ts, docs-list.ts等）
- [ ] 薄いファイル（BeeAI, ControlFlow等）をサブエージェントの元結果から補完するか判断

