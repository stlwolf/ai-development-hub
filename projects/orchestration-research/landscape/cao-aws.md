---
name: CLI Agent Orchestrator (CAO)
repo: awslabs/cli-agent-orchestrator
last_reviewed: 2026-02-22
category: orchestrator
---

## CLI Agent Orchestrator (CAO) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/awslabs/cli-agent-orchestrator
- **言語:** Python 94.2% (FastAPI + FastMCP + SQLAlchemy)
- **最終更新:** 2026-02-21
- **規模:** 254 stars, 56 forks, 20 contributors, v1.0.2
- **作成日:** 2025-07-29
- **ライセンス:** Apache-2.0
- **一言で:** CLI型AIコーディングツール（Amazon Q CLI / Kiro CLI / Claude Code / Codex CLI）をtmuxセッション内の階層型マルチエージェントとして統合し、MCPで連携させる軽量オーケストレーター

### これは何か・何を解決するのか

AWS Open Source Blogの公式発表によれば、CAOの問題意識は「個々の開発者CLIツールは優れたフォーカスタスクを実行できるが、エンタープライズ規模の複雑なプロジェクトは単一エージェントの能力を超える」。

CAOの解決策は「既存のCLI AIツールをそのまま使い、tmuxセッションで分離された複数のエージェントを階層的に協調させる」こと。各エージェントは元のCLIツールの全機能をフルに使える状態で、supervisorが上位レイヤーでタスクの委任・結果収集を制御する。

### 設計思想・アーキテクチャ

#### レイヤード・アーキテクチャ

すべてが HTTP API (localhost:9889) 経由。Provider は「ターミナル出力のパターンマッチ」で状態検知。tmux が真の実行基盤。MCP でエージェント間通信を標準化。

#### 3つのオーケストレーションモード

| モード | 動作 | ユースケース |
|--------|------|-------------|
| **Handoff** | 同期引き継ぎ。workerの完了まで待機 | 順次実行タスク |
| **Assign** | 非同期並行。workerは独立実行し、完了時にsend_messageで報告 | 並列タスク |
| **Send Message** | 既存セッションへのメッセージ送信。Inbox + Watchdogで配信制御 | 結果報告、追加指示 |

### 機能一覧

#### Core

| 機能 | 概要 | 場所 |
|------|------|------|
| **3つのオーケストレーションモード** | Handoff / Assign / Send Message | `mcp_server/server.py` |
| **Provider 抽象レイヤー** | Q CLI / Kiro CLI / Claude Code / Codex CLI の統一IF | `providers/` |
| **セッション・ターミナル管理** | tmuxセッション＋ウィンドウのライフサイクル管理 | `services/session_service.py` |
| **Inbox + Watchdog** | 非同期メッセージキューイング + IDLE検知自動配信 | `services/inbox_service.py` |
| **SQLite 永続化** | ターミナル, Inbox, Flow の3テーブル | `clients/database.py` |
| **エージェントプロファイル** | Markdown + YAML frontmatter でエージェント定義 | `agent_store/` |
| **REST API** | Sessions / Terminals / Inbox のフルCRUD | `api/main.py` |
| **ターミナルステータス検知** | IDLE/PROCESSING/COMPLETED/WAITING/ERROR をANSI正規表現で判定 | `providers/*.py` |

#### Differentiator

| 機能 | 概要 | 場所 |
|------|------|------|
| **Flow（スケジュール実行）** | cron式 + 条件付きスクリプトで定期実行 | `services/flow_service.py` |
| **ユーザー直接Worker操作** | tmuxにattachしてリアルタイム指示 | tmux自体の機能 |
| **Context Preservation** | supervisorが各workerに必要最小限のコンテキストのみ渡す | エージェントプロファイル設計 |

### 特徴的な点・注目ポイント

1. **ターミナル出力のANSI正規表現パース**: CLIツールのAPI/SDKを使わず、実際のターミナル表示をリアルタイム正規表現解析して状態判定。既存CLIに変更を加えずに統合できるが、UI更新で壊れるリスクがある。

2. **Inbox + Watchdog**: watchdogライブラリがターミナルログファイルを監視し、IDLE検知時に自動メッセージ配信。並列Assignワークフローで特に重要。

3. **Flow（条件付きスケジュール実行）**: cron + 外部スクリプトで条件付き定期実行。他のオーケストレーターにはない独自機能。

4. **エージェントプロファイル**: Hugo/Jekyll風のMarkdown + YAML frontmatter。MCPサーバー設定をエージェント定義に埋め込み。

### エコシステム・実利用状況

- **採用事例:** プロダクション利用の公式事例はなし。AWS Labs公式ブログで発表済み
- **盛り上がりの文脈:** AWS Open Source Blog (2026-01-23) での公式発表が起点。Kiro CLIがデフォルトプロバイダーに変更（AWS推し）
- **コミュニティ:** 19 open issues。Feature requests多数（モデルパラメータ、tmux pane化等）
- **評判:** ANSI正規表現パースの脆弱性（Claude Code 2.xのUI変更で壊れた事例）が課題

### 他ツールとの比較・ポジショニング

| 比較軸 | CAO | TAKT | Agent Orchestrator (Composio) |
|--------|-----|------|------|
| 思想 | 既存CLIを「そのまま」tmuxで上位オーケストレーション | ワークフローの各ステップを仕組みとして強制 | 大量並列エージェントのライフサイクル全体管理 |
| エージェント接続 | ターミナル出力パース（ANSI正規表現） | プロセス起動 + SDK | tmux + git worktree |
| 通信 | Handoff / Assign / Send Message (MCP) | Movement間データ受け渡し | Event-driven (33イベントタイプ) |
| スケジュール実行 | あり（Flow） | なし | なし |
| 差別化 | AWS統合、スケジュール、ユーザー直接介入 | Faceted Prompting、強制品質ループ | 大量並列、PR→Mergeライフサイクル |

### 制約・注意点

1. **ターミナル出力パースの脆弱性**: CLIのUI更新で壊れる。メンテナンス負荷が高い
2. **tmux 3.3+必須**: macOSデフォルトでは不十分
3. **ローカル実行のみ**: リモート/クラウド分散は未対応
4. **品質保証はプロンプト依存**: TAKTのような強制ループがない
5. **PyPI未公開**: `uv tool install git+...` のみ
6. **Kiro CLIデフォルト化**: AWS固有ツールへの依存

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 理由 |
|------|------|------|
| tmuxクライアント | `clients/tmux.py` | send_keysのchunking、pipe-paneログ取得 |
| terminal_service | `services/terminal_service.py` | ターミナル作成→Provider初期化の完全フロー |
| Provider状態検知 | `providers/*.py` の `get_status()` | ANSI正規表現パース戦略の詳細 |
| Inbox Watchdog | `services/inbox_service.py` | IDLE検知→自動配信のメカニズム |
| Flow Service | `services/flow_service.py` | cron + 条件付き実行の実装 |
