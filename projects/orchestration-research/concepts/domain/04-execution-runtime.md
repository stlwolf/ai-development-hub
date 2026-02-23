# Execution & Runtime — 実行・ランタイム

> エージェントを **どこで・どう動かすか** を定める概念群。実行環境の隔離、プロセス管理、ランタイム抽象を扱う。

## この領域の問い

- エージェントの実行をどう隔離するか（安全性・再現性）
- ワークスペース（コード、ファイル）をどう分離するか
- ランタイム（Docker, tmux, プロセス等）をどう抽象化・差し替え可能にするか
- セッションのライフサイクルをどう管理するか

## 核となる概念

### Sandbox / Isolation（サンドボックス / 隔離）

エージェントの実行環境を隔離し、ホストや他エージェントへの影響を防ぐ。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenHands | Docker Sandbox | 1セッション = 1Dockerコンテナ。Overlay Mounts（CoW）でファイルシステム分離 |
| SWE-agent | SWE-ReX Deployment | Docker / Modal / AWS で実行環境を抽象化 |
| AutoGen | Code Execution Sandbox | Docker / Docker Jupyter / Azure Container Apps / Local / Jupyter |
| PentAGI | Docker Sandbox | Dockerコンテナ内でペンテストツール実行 |
| Google ADK | AgentEngineSandbox | コード実行サンドボックス（1秒以下起動） |

**コーディングエージェントでは隔離が必須。** フレームワーク型（LangGraph, CrewAI等）は隔離を提供しない — アプリケーション側の責務。

### Workspace（ワークスペース）

エージェントが操作するコード・ファイルの作業領域。

| ツール | 用語 | 特徴 |
|---|---|---|
| Agent Orchestrator | `Workspace` (worktree / clone) | 8スロットPluginの1つ。ワークスペース戦略を差し替え可能 |
| TAKT | `Worktree Isolation` | `git clone --shared` による完全分離 |
| CAO | `git worktree` | セッションごとにworktreeを作成 |
| Aider | Git統合 | リポジトリ全体が作業領域。auto-commit で変更追跡 |
| o-m-cc | `isolation: worktree` | worktreeベースの隔離 |

**ワークスペース隔離のバリエーション**: `git worktree`（軽量、共有リポジトリ）vs `git clone --shared`（完全分離）vs Docker volume mount（重量だが完全隔離）

### Runtime Provider（ランタイムプロバイダー）

エージェントの実行基盤を差し替え可能にする抽象層。

| ツール | 用語 | 特徴 |
|---|---|---|
| Agent Orchestrator | `Runtime` Plugin Slot | tmux, process, docker, k8s 等をプラグインで差し替え |
| OpenHands | Runtime | Docker, Local, Remote, K8s, Modal, Runloop, Daytona, E2B（8種） |
| SWE-agent | SWE-ReX | Local / Docker / Modal / AWS の4デプロイメント |
| TAKT | `Provider` | エージェントプロバイダー抽象。5段階優先度解決のProvider Profiles |
| CAO | `Provider` | プロバイダー抽象レイヤー |

### Terminal Abstraction（ターミナル抽象）

ターミナルの操作・出力パースを抽象化する層。CLIラッパー型ツールに特有。

| ツール | 用語 | 特徴 |
|---|---|---|
| CAO | Terminal Status Detection | IDLE/PROCESSING/COMPLETED/WAITING/ERROR をANSI正規表現で判定 |
| Agent Orchestrator | `Terminal` Plugin Slot | iterm2, web 等。プラグインで差し替え |
| SWE-agent | ACI (Agent-Computer Interface) | LM専用設計のツール群。100行ウィンドウ付きファイルビューア |

### Session（セッション）

エージェントの実行コンテキストのライフサイクル管理。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenHands | `Session` | 1セッション = 1 Dockerコンテナ。Session Replay機能 |
| LangGraph | `Thread` (`thread_id`) | スレッドIDで実行コンテキストを識別 |
| Agent Orchestrator | `Session` / `SessionStatus` | 14状態（spawning → working → pr_open → ci_failed等） |
| Google ADK | `Session` | InMemory/SQLite/Database/Spanner/Vertex AI の5バックエンド |
| Agent Squad | `ChatStorage` | (user_id, session_id, agent_id) の3キー管理 |
| o-m-cc | `SessionStart` | 依存コマンド確認、古いプランアーカイブ、前回状態復元 |

## パターン・バリエーション

### 隔離の粒度

```
隔離なし ──── プロセス分離 ──── worktree ──── Dockerコンテナ ──── VM/クラウド
  │              │                │              │                 │
  LangGraph    TAKT(nohup)     CAO/o-m-cc    OpenHands          SWE-agent(Modal)
  CrewAI                       Agent Orch.    PentAGI
```

- **隔離なし**: フレームワーク型は隔離を提供しない。ライブラリとしてアプリに組み込まれるため
- **Docker**: コーディングエージェントの標準。再現性と安全性のバランスが良い
- **git worktree**: 軽量だがファイルシステムレベルの隔離は不完全

### CLIラッパー型の実行パターン

Agent Orchestrator, CAO, Claude Flow等の「CLIラッパー型」に固有のパターン:

- **tmux多重化**: Agent Orchestrator, CAO。tmuxでターミナルセッションを管理
- **ANSI出力パース**: CAO。ターミナル出力の状態（完了/エラー/待機中）を正規表現で判定
- **プロセス分離**: claude-safe（`nohup`でTTY競合回避）。軽量だがモニタリングが難しい

## 独自レイヤーとの接点

- この領域はOSSが最も厚く実装している「インフラ層」。自前で書く必要性は低い
- ただし、ランタイムプロバイダーの抽象設計は自前ツール構築時のアーキテクチャ判断に直結する
