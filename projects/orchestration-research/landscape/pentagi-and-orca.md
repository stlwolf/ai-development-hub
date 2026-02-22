---
name: PentAGI / Orca
repo: vxcontrol/pentagi, scrippt-tech/orca
last_reviewed: 2026-02-22
category: agent-runtime
---

## PentAGI (vxcontrol) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/vxcontrol/pentagi
- **言語:** Go 76%, TypeScript 20.5%
- **最終更新:** 2026年2月時点で活発にメンテナンス中
- **規模:** 6,592 stars / 786 forks / v1.1.0 (2026-01-17)
- **ライセンス:** MIT
- **一言で:** ペネトレーションテスト特化の自律型マルチエージェントシステム

### これは何か・何を解決するのか

セキュリティ専門家向けの自律型ペネトレーションテストプラットフォーム。ターゲットと目標を指定するとAIエージェントが自律的にサブタスク分解し、20以上のセキュリティツール（nmap, metasploit, sqlmap等）をDocker上のサンドボックスで実行。

### 設計思想・アーキテクチャ

**「目的指示 vs 手段指示」の設計判断:**

エージェントに「何を達成するか（purpose）」のみを伝え、「どうやるか（means）」は委ねる。`primary_agent.tmpl`では各スペシャリストの用途・期待出力・ツール群は定義するが、具体的手順は指定しない。

**マルチエージェント委譲パターン:**

```
primary_agent (オーケストレーター)
├── pentester (攻撃実行)
├── searcher (情報収集・OSINT)
├── coder (スクリプト開発)
├── adviser (戦略コンサルタント)
├── memorist (記憶検索)
└── installer (環境構築)
```

各スペシャリストも他スペシャリストに再委譲可能（再帰的委譲）。

**デュアルメモリシステム:**

1. **guide（長期ガイド）**: `search_guide` / `store_guide` で再利用可能な手法を保存・検索
2. **Graphiti（エピソード記憶）**: Neo4jベースの知識グラフ。6種の検索タイプ（`recent_context`, `successful_tools`, `episode_context`, `entity_relationships`, `diverse_results`, `entity_by_label`）

**自己修正メカニズム:**

`performer.go`のエージェントループ: ツールコール未発行時に`performReflector`で自己反省。最大3回リトライ、`repeatingDetector`でループ防止。`Summarizer`でコンテキストオーバーフロー防止。

### 機能一覧

| カテゴリ | 機能 | 場所 |
|---|---|---|
| **コア** | マルチエージェント委譲システム | `pkg/providers/performer.go` |
| **コア** | サブタスク自動生成・リファイン | `pkg/templates/prompts/subtasks_*.tmpl` |
| **コア** | Dockerサンドボックス実行 | `pkg/docker/` |
| **コア** | 20+セキュリティツール統合 | `pentester.tmpl` |
| **差別化** | Graphiti知識グラフ（Neo4j） | `pkg/graphiti/` |
| **差別化** | チェイン要約（コンテキスト圧縮） | `pkg/csum/` |
| **差別化** | Reflectorによる自己反省 | `reflector.tmpl` |
| **差別化** | Dockerイメージ自動選択 | `image_chooser.tmpl` |
| **差別化** | ToolCall修正機構 | `toolcall_fixer.tmpl` |
| **ユーティリティ** | 6種の外部検索API連携 | `pkg/tools/tavily.go` etc. |
| **ユーティリティ** | Webブラウザスクレイピング | `pkg/tools/browser.go` |
| **ユーティリティ** | REST/GraphQL API | `pkg/graph/`, `pkg/server/` |
| **ユーティリティ** | Langfuse連携（LLM観測） | `pkg/observability/langfuse/` |
| **ユーティリティ** | Grafana/Prometheus/Jaeger | `observability/` |
| **ユーティリティ** | マルチLLMプロバイダ | OpenAI, Anthropic, Gemini, Ollama, Bedrock, Custom |

### 特徴的な点

1. **35種のプロンプトテンプレート**: エージェントロール + メタ機能（reflector, enricher, summarizer, flow_descriptor, toolcall_fixer）に専用プロンプト。プロンプトエンジニアリングの工数が突出

2. **「認可フレームワーク」設計**: 全エージェントプロンプトに `AUTHORIZATION FRAMEWORK` セクション。LLMが「許可を求めるループ」に入ることを防止。ドメイン特化の実践知見

3. **要約認識プロトコル**: `SUMMARIZATION AWARENESS PROTOCOL` で過去の要約の模倣・コピーを防止

4. **langchaingo のフォーク版使用**: `github.com/vxcontrol/langchaingo`。本家にない`reasoning`や`streaming`パッケージを追加

### エコシステム

- pentagi.comで商用版提供
- CybersecurityNews等メディア掲載
- Discordコミュニティあり
- 周辺: `vxcontrol/scraper`, `vxcontrol/pgvector`, `vxcontrol/kali-linux`

### 制約
- セキュリティツールの悪用リスク（EULA別途存在）
- Docker必須、GPU不要だがLLM APIコスト大
- langchaingo フォーク版に依存

### 深掘り候補

- `pkg/providers/performer.go` — エージェントループ全体設計
- `pkg/providers/subtask_patch.go` — サブタスク動的修正
- `pkg/tools/executor.go` — ツール実行の抽象化
- `pkg/templates/prompts/reflector.tmpl` — 自己反省プロンプト

---

## Orca (scrippt-tech) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/scrippt-tech/orca (→ santiagomed/orca)
- **言語:** Rust
- **最終更新:** 2024-03-14（開発停止）
- **規模:** 284 stars / 22 forks / v0.1.0（crates.io未公開）
- **ライセンス:** Apache-2.0
- **一言で:** Rust製LLMパイプライン実行フレームワーク（学習プロジェクト、開発停止）

### これは何か・何を解決するのか

RustでLLMアプリケーションを構築するための軽量パイプラインフレームワーク。Handlebarsベースのプロンプトテンプレーティング、Simple/Sequential パイプライン、Qdrant連携RAGが主要機能。READMEで作者が「currently learning about LLM orchestrations」と述べており、学習プロジェクト。

### 設計思想

**モジュール構成:**

```
orca-core/src/
├── llm/        # LLMプロバイダ抽象化 (OpenAI, Bert, Quantized)
├── pipeline/   # パイプライン (simple, sequential, mapreduce[unstable])
├── prompt/     # Handlebarsテンプレートエンジン + Chat構造
├── record/     # ドキュメントローダ (HTML, PDF)
├── memory.rs   # メモリ管理
└── qdrant.rs   # Qdrantベクトルストア
```

**Rustのトレイト設計:**
- `LLM`: `generate(prompt) -> LLMResponse`
- `Embedding`: `generate_embedding` / `generate_embeddings`
- `Pipeline`: `execute(target) -> PipelineResult`
- `Prompt`: `save`, `to_chat`, `clone_prompt`

**Handlebarsプロンプトテンプレーティング:**

`{{#chat}}`, `{{#system}}`, `{{#user}}`, `{{#assistant}}` のカスタムヘルパーでテンプレートからChat Completion形式を生成。

```rust
"{{#chat}}{{#user}}What is {{topic}}?{{/user}}{{/chat}}"
// → ChatPrompt([Message { role: User, content: "What is ..." }])
```

### 機能一覧

| カテゴリ | 機能 | 場所 |
|---|---|---|
| コア | Handlebarsプロンプトテンプレーティング | `prompt/` |
| コア | Simpleパイプライン | `pipeline/simple.rs` |
| コア | Sequentialパイプライン | `pipeline/sequential.rs` |
| コア | LLMトレイト抽象化 | `llm/mod.rs` |
| ユーティリティ | OpenAI Chat連携 | `llm/openai.rs` |
| ユーティリティ | Bert推論（Candle ML） | `llm/bert.rs` |
| ユーティリティ | 量子化モデル推論 | `llm/quantized.rs` |
| ユーティリティ | Qdrantベクトルストア | `qdrant.rs` |
| ユーティリティ | HTML/PDFドキュメントローダ | `record/` |
| unstable | MapReduceパイプライン | `pipeline/mapreduce/` |

### WASMコンセプト

READMEでWebAssemblyによるポータブルLLMアプリケーションを構想していた。2023年11月にWASM関連コミットがあるが、以降進展なし。エッジデバイス/サーバーレスのビジョンは先見的だったが実装に至らず。

### 開発停止の分析

- 2023年11月: 活発に開発（パイプラインリファクタ、WASM、Bert）
- 2023年12月: RAG改善、JSON mode
- 2024年1月: 外部PRマージのみ
- 2024年3月: Candleコンパイル修正（最終コミット）
- 以降2年間コミットなし

推定停止理由: 学習プロジェクト（crates.io未公開）、後発ライブラリの登場（`orch`, `rig`）、LLM APIの急速な変化への追従コスト。

### 制約
- **開発完全停止**（2024年3月以降）
- crates.io未公開、Agent/Tool calling未対応
- 後発の`orch` (guywaldman), `rig` (0xPlaygrounds) が上回る
- 歴史的資料としてのみ

### 深掘り候補

- `prompt/chat.rs` — Handlebarsカスタムヘルパーの実装（テンプレート→Chat構造変換は他言語でも参考に）
- `pipeline/sequential.rs` — `Arc<RwLock>`による安全なパイプラインチェーン
- `llm/quantized.rs` — Candle経由の量子化モデル推論

---

## 2プロジェクト横断の所感

| 観点 | PentAGI | Orca |
|---|---|---|
| 活動状況 | 活発（v1.1.0, 2026年1月） | 停止（最終: 2024年3月） |
| スコープ | ドメイン特化型完全システム | 汎用パイプラインライブラリ |
| エージェント設計 | マルチエージェント + 委譲 + 自己反省 | なし（パイプラインのみ） |
| プロンプト工学 | 35種テンプレート、認可・要約認識 | Handlebarsカスタムヘルパー |
| 参考価値 | ドメイン特化AIの設計パターン全般 | Rust型システムによるLLM抽象化の初期例 |
