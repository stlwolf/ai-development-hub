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
| [Claude Flow](./claude-flow.md)                                 | 14,337 | TypeScript | ⚠️ **85%がモック実装。** 実態はClaude CLIのプロンプトラッパー | 2.9KB |
| [oh-my-claude-code / o-m-cc](./oh-my-claude-code-and-o-m-cc.md) | 0 / 4  | JS / Bash  | 中央オーケストレーター型 vs 分散P2P型。o-m-ccの方が活発で設計が成熟  | 2.8KB |


### 6. ドメイン特化・低レベル基盤


| ツール                                     | Stars       | 言語        | 一言                                      | 調査    |
| --------------------------------------- | ----------- | --------- | --------------------------------------- | ----- |
| [PentAGI / Orca](./pentagi-and-orca.md) | 6,592 / 284 | Go / Rust | ペンテスト特化マルチエージェント / Rust LLMパイプライン（開発停止） | 2.6KB |


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

- `../synthesis/` に独自レイヤーとの統合設計ノートを作成
- 薄いファイル（BeeAI, ControlFlow等）をサブエージェントの元結果から補完するか判断
- `../concepts/` に横断的パターン（Handoffパターン、ループ検出パターン、メモリ永続化パターン等）を抽出

