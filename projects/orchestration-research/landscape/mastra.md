---
name: Mastra
repo: mastra-ai/mastra
last_reviewed: 2026-02-22
category: framework
---

## Mastra 調査結果

### 基本情報
- **リポジトリ:** https://github.com/mastra-ai/mastra
- **言語:** TypeScript（モノレポ、pnpm + Turbo）
- **最終更新:** 2026-02-22
- **規模:** 21,283 stars / 1,581 forks / 320+ contributors / v1.5.0 / 66 releases
- **ライセンス:** Apache-2.0
- **資金調達:** $13M（YC W25）
- **npmダウンロード:** 30万/週
- **一言で:** TypeScriptネイティブのオールインワンAIエージェントフレームワーク。Gatsby創業チーム開発。

### これは何か・何を解決するのか

Python中心のAIエージェント開発に対し、TypeScript/Next.jsの文脈で同等の機能を提供。Agent, Workflow, RAG, Memory, MCP, Evalsを統合提供し、「TypeScript世界のLangChain/LangGraph」というポジション。よりバッテリー同梱なアプローチ。

### 設計思想・アーキテクチャ

- TypeScriptファースト（Zodスキーマによる型安全）
- Agent + Workflow の二層構造
- Vercel AI SDK統合（40+ LLMプロバイダ）
- プラグイン可能なストレージ（20+アダプタ）
- サーバーアダプタパターン（Express, Hono, Fastify, Koa）

### 機能一覧

#### コア

| 機能 | 概要 | 分類 |
|------|------|------|
| Agent | LLM + Toolsの自律推論エージェント | Core |
| Workflow Engine | `.then()/.branch()/.parallel()/.foreach()` | Core |
| Model Router | `"provider/model"` 文字列で40+プロバイダに接続 | Core |
| Tool System | Zodスキーマのtype-safeツール | Core |
| Storage Abstraction | 20+バックエンド（pg, libsql, mongodb, pinecone等） | Core |

#### メモリシステム

| 機能 | 概要 | 分類 |
|------|------|------|
| Observational Memory | Observer/Reflectorによる自動圧縮長期記憶 | Differentiator |
| Semantic Recall | ベクトル類似度検索 | Core |
| Working Memory | 構造化スクラッチパッド | Core |
| Message History | 会話履歴 | Core |

#### ワークフロー制御

| 機能 | 概要 | 分類 |
|------|------|------|
| Suspend/Resume | ステップ単位の一時停止・再開 | Core |
| Human-in-the-loop | Suspendベースの人間介在 | Differentiator |
| Loop primitives | `.dountil()/.dowhile()/.foreach()` | Core |
| Nested Workflows | ワークフローの再利用 | Core |

#### MCP統合

| 機能 | 概要 | 分類 |
|------|------|------|
| MCPClient | 外部MCPサーバーのツール取得 | Core |
| MCPServer | Mastra定義をMCPで外部公開 | Differentiator |

#### 開発者体験

| 機能 | 概要 | 分類 |
|------|------|------|
| Mastra Studio | ローカルプレイグラウンドUI | Differentiator |
| Evals/Scorers | エージェント品質評価 | Core |
| CLI | `mastra dev`, `npm create mastra@latest` | Core |

### 特徴的な点・注目ポイント

1. **Workflow API**: メソッドチェーンDSLでグラフベースワークフローを宣言的に定義
2. **Human-in-the-loop**: `suspend()/resume()` + 型安全スキーマ。デプロイ跨ぎ・再起動耐性あり
3. **Observational Memory**: Observer/Reflectorによる自動圧縮。非同期バッファリングでUX阻害なし
4. **MCP双方向統合**: クライアントとサーバーの両方を提供
5. **Mastra Studio**: ローカルプレイグラウンドUI（Agent Chat, Workflow可視化, Tool Testing）

### エコシステム・実利用状況

- **採用事例:** Replit（数千エージェントインスタンス/日）、PayPal, Adobe, Docker, SoftBank
- **盛り上がりの文脈:** YC W25、$13M調達、v1.0で「Pythonなしで本番AIエージェント」の選択肢を提示
- **コミュニティ:** Discord活発、469 open issues、Zenn/Qiitaに日本語記事多数
- **評判:**
  - 肯定的: 統合フレームワーク、TypeScriptネイティブ、Studio DX
  - 否定的: マルチエージェント連携の無限ループ問題、APIの進化が早い

### 他ツールとの比較

| 観点 | Mastra | LangGraph | ControlFlow |
|------|--------|-----------|-------------|
| 言語 | TypeScript | Python / TS | Python |
| 設計 | オールインワン | 低レベルグラフランタイム | Prefectベース |
| ワークフロー | メソッドチェーンDSL | node/edge定義 | task/flowデコレータ |
| メモリ | 4層（Observational等） | Checkpointer | 外部依存 |
| Stars | 21k | 25k | ~4k |

### 制約・注意点

1. APIの進化が早い（Codemods提供で支援）
2. Observational Memoryのresource scopeはexperimental
3. マルチエージェント連携のガバナンス機構は自前設計が必要
4. LangGraphほどの低レベル制御粒度はない
5. Pythonエコシステムとの直接統合なし

### 深掘り候補

| 対象 | パス | 理由 |
|------|------|------|
| Workflow Engine | `packages/core/src/workflows/` | `.then()/.branch()/.parallel()` の内部実装 |
| Memory統合 | `packages/memory/src/index.ts` | Observer/Reflectorオーケストレーション |
| MCPServer | `packages/mcp/src/server/` | agents/workflowsからMCPツールへの自動変換 |
| Storage抽象化 | `packages/core/src/storage/` | インターフェース設計 |
