---
name: OpenHands
repo: OpenHands/OpenHands
last_reviewed: 2026-02-22
category: agent-runtime
---

## OpenHands (formerly OpenDevin) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/OpenHands/OpenHands
- **言語:** Python (75.8%)
- **最終更新:** 2026-02-22
- **規模:** 68,060 stars / 440 contributors / 8,481 forks / v1.4.0
- **ライセンス:** MIT（`enterprise/` は別ライセンス）
- **資金:** Series A $18.8M
- **一言で:** LLM駆動の自律型ソフトウェアエンジニア。Docker隔離サンドボックス内でコード実行・ファイル編集・ブラウジングを行うエージェントプラットフォーム

### これは何か・何を解決するのか

LLMにコードを生成させるだけでなく、実際にコードを実行・検証・修正するループを回すプラットフォーム。Devinにインスパイアされたオープンソース代替として誕生。個人（CLI/ローカルGUI）〜企業（Cloud/Enterprise）まで複数の利用形態を提供。

### 設計思想・アーキテクチャ

V0（レガシー）とV1が共存中（V0は2026年4月削除予定）。

```
User → Session → AgentController → Agent → LLM
                      ↕                    ↕
                 EventStream ←→ Runtime (Docker Container)
```

- 1セッション = 1 Dockerコンテナ（完全プロセス隔離）
- EventStreamがappend-onlyのPub/Sub中央ハブ
- Action/Observationの型安全イベントフレームワーク

### 機能一覧

#### コア

| 機能 | 概要 | 分類 |
|------|------|------|
| CodeActAgent | メインのコーディングエージェント | Core |
| Docker Sandbox | セッションごとのDockerコンテナ隔離 | Core |
| EventStream | append-onlyイベントログ + Pub/Sub | Core |
| Action/Observation型 | Action 10種、Observation 6種の型安全フレームワーク | Core |
| LLM統合 (LiteLLM) | 任意のLLMプロバイダー対応 | Core |

#### 差別化

| 機能 | 概要 | 分類 |
|------|------|------|
| 複数ランタイム | Docker, Local, Remote, K8s, Modal, Runloop, Daytona, E2B | Differentiator |
| BrowserGym統合 | Playwright経由のWebブラウジング | Differentiator |
| SecurityAnalyzer | LLMリスク評価、Invariant Analyzer、GraySwan統合 | Differentiator |
| StuckDetector | 5パターンのループ検出 | Differentiator |
| Criticモデル | 推論時スケーリング用の報酬予測 | Differentiator |
| GitHub Issue Resolver | Issue→PR自動パイプライン | Differentiator |
| Microagent | リポジトリ固有ガイダンスのプロンプト注入 | Differentiator |

#### ユーティリティ

| 機能 | 概要 | 分類 |
|------|------|------|
| MCP対応 | Model Context Protocol統合 | Utility |
| Memory/Condenser | コンテキスト圧縮（LLM要約） | Utility |
| 外部サービス統合 | GitHub, GitLab, Bitbucket, Azure DevOps, Jira, Slack, Linear | Utility |
| Session Replay | イベント履歴の再生 | Utility |
| Overlay Mounts | Copy-on-Writeファイルシステム分離 | Utility |

### 特徴的な点・注目ポイント

1. **Docker Sandbox設計**: クライアント-サーバー型。ホストのOpenHandsがDockerコンテナ内のActionExecutionServerにHTTPで通信。ポートレンジ管理、イメージビルドパイプライン、Overlay Mount対応。

2. **EventStream**: 全コンポーネント間通信の中枢。スレッドセーフPub/Sub、FileStore永続化、シークレット自動マスキング。V1ではPydanticモデルベースに進化。

3. **StuckDetector**: 5パターンの無限ループ検出（同一Action反復、エラーループ、モノローグ、A-B-A-Bパターン、コンテキストウィンドウエラー）。

4. **SecurityAnalyzer**: EventStreamにサブスクライブしてアクションのリスクを事前評価。LLM Risk, Invariant Analyzer, GraySwan Cygnalの3方式。

5. **ブラウザ統合**: BrowserGym + Playwright。BrowsingAgent（テキストベース）とVisualBrowsingAgent（スクリーンショットベース）。

### エコシステム・実利用状況

- **採用事例:** AMD, Apple, Google, Amazon, Netflix, TikTok, NVIDIA, Mastercard, VMware
- **盛り上がりの文脈:** 2024年3月OpenDevinとして公開、2025年11月Series A $18.8M、SWE-bench 72% Verified
- **Cloud料金:** Free / Growth $500/月 / Enterprise カスタム
- **評判:**
  - 肯定: SWE-benchトップクラス、Docker隔離の安心感
  - 否定: 部分的完了が多い、無限ループ監視が必要、Docker依存は摩擦

### 他ツールとの比較

| 項目 | OpenHands | SWE-agent | Aider | Devin |
|------|-----------|-----------|-------|-------|
| 形態 | フルプラットフォーム | 研究ツール | CLIツール | プロプライエタリ |
| 隔離 | Docker/K8s/Remote | Docker | なし | プロプライエタリ |
| SWE-bench | ~72% Verified | ~74% Mini | - | - |
| ブラウザ | BrowserGym | なし | なし | あり |
| セキュリティ | SecurityAnalyzerフレームワーク | なし | なし | プロプライエタリ |

### 制約・注意点

1. V0→V1移行中（V0は2026年4月削除予定）
2. Docker依存（ローカル利用にDocker必須）
3. 並列実行時のリソース消費が大きい
4. エージェントの信頼性は不完全（人間の監視が必要）

### 深掘り候補

| 対象 | パス | 理由 |
|------|------|------|
| ActionExecutionServer | `runtime/action_execution_server.py` (43KB) | サンドボックス内アクション実行の核心 |
| AgentController | `controller/agent_controller.py` (58KB) | メインループ、State遷移、StuckDetector統合 |
| Runtime Base | `runtime/base.py` (52KB) | Runtime抽象基底クラス |
| V1 Software Agent SDK | github.com/OpenHands/software-agent-sdk/ | V1コア設計 |
| StuckDetector | `controller/stuck.py` | 5パターンのループ検出実装 |
| BrowserEnv | `runtime/browser/browser_env.py` | BrowserGym統合詳細 |
