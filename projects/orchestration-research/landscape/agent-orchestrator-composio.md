---
name: Agent Orchestrator
repo: ComposioHQ/agent-orchestrator
last_reviewed: 2026-02-22
category: orchestrator
---

## Agent Orchestrator (ComposioHQ) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/ComposioHQ/agent-orchestrator
- **言語:** TypeScript (89.1%), pnpm monorepo (ESM)
- **最終更新:** 2026-02-22
- **規模:** ~710 stars, 97 forks, 77 open issues, コントリビューター1名 (AgentWrapper)
- **作成日:** 2026-02-13 (10日前)
- **リリース:** 3 (latest: metrics-v1, 2026-02-20)
- **一言で:** 並列AIコーディングエージェント群をプラグイン可能な8スロットで管理するオーケストレーター

### これは何か・何を解決するのか

Agent Orchestratorは、複数のAIコーディングエージェント（Claude Code, Codex, Aider等）を並列に実行し、それぞれに独立したgit worktree・ブランチ・PRを割り当て、CIの失敗やレビューコメントへの自動対応まで含めたライフサイクル全体を管理するプラットフォーム。

**解決する問題:** 1つのAIエージェントをターミナルで動かすのは簡単だが、30個を同時に異なるissue・ブランチ・PRで走らせると「人間の注意力」がボトルネックになる。ブランチ作成、エージェント起動、スタック検出、CI失敗の読み取り、レビューコメントの転送、マージ可能PRの追跡 — これらすべてを自動化し、人間は「判断が必要なとき」だけ呼び戻される。

**コア思想:** "Push, not pull." — エージェントをspawnしたら放置。通知が来るまで待つ。人間がポーリングすることは想定されていない。

**出典:** [著者ブログ](https://pkarnal.com/blog/open-sourcing-agent-orchestrator), [README](https://github.com/ComposioHQ/agent-orchestrator)

### 設計思想・アーキテクチャ

#### 8スロット・プラグインアーキテクチャ

すべての抽象化がスワップ可能な8つのスロットで構成。各スロットはTypeScriptインターフェースとして`packages/core/src/types.ts`(1,084行)に定義。

| スロット | インターフェース | デフォルト | 代替 |
|-----------|-------------|---------|------|
| Runtime | `Runtime` | tmux | process (docker, k8s, ssh, e2bは設定で言及あるが未実装) |
| Agent | `Agent` | claude-code | codex, aider, opencode |
| Workspace | `Workspace` | worktree | clone |
| Tracker | `Tracker` | github | linear |
| SCM | `SCM` | github | — |
| Notifier | `Notifier` | desktop | slack, composio, webhook |
| Terminal | `Terminal` | iterm2 | web |
| Lifecycle | (core) | — | — |

**プラグインパターン:** 各プラグインは`PluginManifest` + `create()` 関数をexportし、`satisfies PluginModule<T>` でコンパイル時型チェックを保証。実装は`packages/plugins/{slot}-{name}/` に配置。

**ステートレス設計:** データベースなし。セッションメタデータはフラットな `key=value` ファイル、イベントログはJSONL形式。これは元々のbashスクリプト版との後方互換性のための設計判断。

**Zodバリデーション:** YAML設定ファイルはロード時にZodで検証。パスの `~` 展開もサポート。

#### コアサービス（プラグイン不可）

- **SessionManager** — セッションのCRUD（spawn, restore, list, kill, cleanup, send）
- **LifecycleManager** — ポーリングループによる状態遷移 + リアクションエンジン
- **PluginRegistry** — プラグインの発見・ロード・登録

#### セッションライフサイクル

`SessionStatus` は14の状態を持つ: `spawning → working → pr_open → ci_failed / review_pending / changes_requested → approved → mergeable → merged → done`。 `ActivityState` は6つ: `active, ready, idle, waiting_input, blocked, exited`。ターミナル状態（dead）判定やリストア可能性判定のヘルパー関数も型定義ファイルに含まれている。

### 機能一覧

#### コア機能

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **並列エージェントSpawn** | Issue番号指定でエージェントをspawn。git worktree作成→ブランチ切り→tmuxセッション起動→エージェント起動を自動化 | `packages/core/src/session-manager.ts` | コア |
| **Batch Spawn** | 複数issueを一括spawn (`ao batch-spawn proj INT-1 INT-2 INT-3`) | `packages/cli/` | コア |
| **セッションライフサイクル管理** | 14状態の遷移を自動管理するステートマシン | `packages/core/src/lifecycle-manager.ts` | コア |
| **Activity Detection** | Claude CodeのJSONLイベントファイルを直接パースしてエージェントの活動状態を検出（ターミナル出力パースは非推奨） | `packages/plugins/agent-claude-code/` | コア |
| **プラグインレジストリ** | 8スロットへのプラグイン動的ロード・登録 | `packages/core/src/plugin-registry.ts` | コア |
| **YAML設定 + Zodバリデーション** | プロジェクト定義、プラグイン選択、リアクション設定をYAMLで宣言 | `packages/core/src/config.ts` | コア |

#### Reactions（フィードバックループ）

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **CI失敗自動修正** | CI失敗検知→失敗ログをエージェントに送信→自動修正（リトライ回数設定可、エスカレーション付き） | `reactions.ci-failed` in config | 差別化 |
| **レビューコメント自動対応** | `changes_requested`検知→レビューコメントをエージェントに転送→修正push | `reactions.changes-requested` | 差別化 |
| **Approved+Green通知/Auto-merge** | PR承認+CI通過時に通知、またはauto-merge | `reactions.approved-and-green` | 差別化 |
| **Agent Stuck検出** | 一定時間無活動で`stuck`判定→人間にエスカレート通知 | `reactions.agent-stuck` | 差別化 |
| **イベント駆動型アーキテクチャ** | 33種のイベントタイプ（session.*, pr.*, ci.*, review.*, merge.*, reaction.*等）+ 4段階優先度（urgent/action/warning/info） | `packages/core/src/types.ts` EventType | 差別化 |

#### ワークスペース・分離

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **Git Worktree分離** | セッションごとにworktreeを作成し、完全にファイルシステムレベルで分離 | `packages/plugins/workspace-worktree/` | コア |
| **Clone分離** | worktreeの代替としてfull cloneも可能 | `packages/plugins/workspace-clone/` | ユーティリティ |
| **Symlink設定** | `.env`, `.claude` 等をworktreeにシンボリックリンクで注入 | `symlinks` in config | ユーティリティ |
| **postCreateフック** | worktree作成後に`pnpm install`等を自動実行 | `postCreate` in config | ユーティリティ |
| **Workspace Hooks** | エージェント固有の設定をworktreeに書き込み（Claude Codeの場合`.claude/settings.json`にPostToolUseフック設定） | `Agent.setupWorkspaceHooks()` | コア |

#### ダッシュボード・UI

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **Webダッシュボード** | Next.js 15 (App Router) + Tailwindのリアルタイムダッシュボード | `packages/web/` | コア |
| **SSEリアルタイム更新** | Server-Sent Eventsでポーリングなしのリアルタイム状態更新 | `packages/web/` | コア |
| **Attention Zones** | セッションを「要対応」「要確認」「作業中」「完了」にグルーピング | `packages/web/` | 差別化 |
| **ライブターミナル** | xterm.jsでブラウザ内にエージェントのターミナル出力をリアルタイム表示 | `packages/plugins/terminal-web/` | 差別化 |
| **iTerm2統合** | macOSのiTerm2でセッションタブを自動展開 | `packages/plugins/terminal-iterm2/` | ユーティリティ |

#### CLI

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **`ao` CLI** | Commander.jsベースのCLIツール | `packages/cli/` | コア |
| **`ao init --auto`** | プロジェクト設定の自動生成 | CLI | ユーティリティ |
| **`ao spawn`/`ao batch-spawn`** | エージェントのspawn | CLI | コア |
| **`ao status`** | 全セッション概要表示 | CLI | コア |
| **`ao send`** | 実行中エージェントへのメッセージ送信 | CLI | コア |
| **`ao session restore`** | クラッシュしたエージェントの復活 | CLI | ユーティリティ |
| **`ao session cleanup`** | 完了済みセッションの一括削除 | CLI | ユーティリティ |
| **`ao open`** | 全セッションをターミナルタブで展開 | CLI | ユーティリティ |

#### 通知・外部連携

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **デスクトップ通知** | macOSのネイティブ通知 | `packages/plugins/notifier-desktop/` | コア |
| **Slack通知** | Webhook経由のSlack通知 | `packages/plugins/notifier-slack/` | ユーティリティ |
| **Webhook通知** | 汎用Webhook | `packages/plugins/notifier-webhook/` | ユーティリティ |
| **Composio通知** | Composioプラットフォーム経由の通知 | `packages/plugins/notifier-composio/` | ユーティリティ |
| **通知ルーティング** | 優先度(urgent/action/warning/info)別にチャンネルを振り分け | `notificationRouting` in config | 差別化 |

#### エージェント固有

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **Claude Codeプラグイン** | JSONL直接パースによるActivity Detection、セッション復元、コスト推定 | `packages/plugins/agent-claude-code/` | コア |
| **Codexプラグイン** | Codex CLI対応 | `packages/plugins/agent-codex/` | ユーティリティ |
| **Aiderプラグイン** | Aider対応 | `packages/plugins/agent-aider/` | ユーティリティ |
| **OpenCodeプラグイン** | OpenCode対応 | `packages/plugins/agent-opencode/` | ユーティリティ |
| **agentRules/agentRulesFile** | プロジェクトごとのエージェント指示をインラインまたはファイルで注入 | `ProjectConfig.agentRules` | ユーティリティ |
| **セッション復元** | クラッシュ後にエージェントセッションを再開（Claude CodeのsessionId保持） | `Agent.getRestoreCommand()` | 差別化 |

#### オーケストレーター・エージェント

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **Orchestrator Prompt生成** | `ao start`でオーケストレーター専用エージェントを起動。プロジェクト情報・コマンド一覧・ワークフローを自動注入 | `packages/core/src/orchestrator-prompt.ts` | 差別化 |
| **spawnOrchestrator** | SessionManagerに専用の`spawnOrchestrator`メソッドがあり、ワーカーエージェントとは異なる起動パスを持つ | `SessionManager` interface | 差別化 |

#### テスト・品質

| 機能 | 概要 | 場所 | 重要度 |
|------|------|------|--------|
| **3,288テストケース** | vitest使用、ユニット+インテグレーション | `packages/*/src/__tests__/`, `packages/integration-tests/` | コア |
| **ESLint + Prettier** | `no-any`ルール、strict mode強制 | ルートの設定 | ユーティリティ |
| **Changesets** | バージョン管理・リリース管理 | `@changesets/cli` | ユーティリティ |

### 特徴的な点・注目ポイント

**1. Reactions パターン — イベント駆動フィードバックループ**

最大の差別化要素。CI失敗・レビュー・承認などのGitHubイベントに対して、設定ベースの自動応答チェーンを定義できる。`auto: true` + `action: send-to-agent` + `retries: 2` + `escalateAfter: 30m` のように宣言的にフィードバックループを構築。著者ブログによれば、41件のCI失敗が全て人間の介入なしに自己修正され、CI成功率は84.6%に達した。

**2. エージェントのActivity Detectionが非ターミナルパース**

Claude CodeのJSONLイベントファイルを直接読み取ることで、ターミナル出力のパース（不安定でエージェントが「嘘をつく」問題がある）に依存しない。`getActivityState()` が推奨で、`detectActivity(terminalOutput)` は`@deprecated`マーク済み。

**3. オーケストレーター・エージェント（メタ層）**

`ao start` で起動するのは「コードを書くエージェント」ではなく「ワーカーエージェントを管理するオーケストレーターエージェント」。`orchestrator-prompt.ts`がプロジェクト情報・利用可能コマンド・ワークフローガイドを自動生成してシステムプロンプトに注入する。

**4. 自己構築（dogfooding）**

40,000行のTypeScript、17プラグイン、3,288テストが8日間で30並列エージェントによって構築された。bash版オーケストレーターでTypeScript版オーケストレーターを構築するというメタ構造。すべてのコミットに`Co-Authored-By`トレーラー付き（Claude Opus 4.6: 512, Sonnet 4.5: 373, Sonnet 4.6: 124）。

**5. セキュリティ意識**

`execFile`強制（`exec`禁止 — シェルインジェクション防止）、`JSON.stringify`によるシェルエスケープ禁止、タイムアウト必須など、CLAUDE.mdで明確にセキュリティルールを定義。

### 使い方・典型的なワークフロー

```bash
# インストール
git clone https://github.com/ComposioHQ/agent-orchestrator.git
cd agent-orchestrator && bash scripts/setup.sh

# プロジェクト設定
cd ~/your-project && ao init --auto

# オーケストレーター起動
ao start

# Issue指定でエージェントspawn
ao spawn my-project 123
ao batch-spawn my-project INT-1 INT-2 INT-3

# モニタリング
ao status
ao dashboard  # http://localhost:3000

# エージェントへの介入
ao send my-app-1 "テストを修正して"
ao session attach my-app-1
ao session restore my-app-1
ao session cleanup -p my-project
```

設定ファイル `agent-orchestrator.yaml` の典型例:

```yaml
port: 3000
defaults:
  runtime: tmux
  agent: claude-code
  workspace: worktree
  notifiers: [desktop]

projects:
  my-app:
    repo: org/my-app
    path: ~/my-app
    defaultBranch: main
    sessionPrefix: app
    symlinks: [.env, .claude]
    postCreate: ["pnpm install"]
    agentConfig:
      permissions: skip

reactions:
  ci-failed:
    auto: true
    action: send-to-agent
    retries: 2
  changes-requested:
    auto: true
    action: send-to-agent
    escalateAfter: 30m
  approved-and-green:
    auto: false
    action: notify
```

### エコシステム・実利用状況

- **採用事例:** 作者（pkarnal / ComposioHQ）自身が30並列エージェントで本プロジェクト自体を構築。外部の本番採用事例は2026-02時点では確認できず（公開10日目）。
- **盛り上がりの文脈:** 2026年2月の「AIコーディングエージェント並列実行」トレンドのど真ん中に登場。Claude Code Agent Teams（Anthropicネイティブ）、claude-flow（14K stars）、workmux、cctakt、Agency等が同時期に出現し、カテゴリ自体が急速に形成中。著者の「20エージェント並列bash版」ブログが先行バズを作り、その8日後にOSS版として公開。
- **コミュニティ:** 77 open issues（作成10日で）。Feature request多数: Jira対応(#137), OpenRouter対応(#135), Mission Controlビジュアライゼーション(#81), ピアコードレビュー(#139)。Discussions機能は未使用。
- **周辺ツール:** Composioプラットフォーム（同社の主力SaaS — AIエージェント用APIインテグレーション層）のnotifierプラグインが組み込み済み。
- **評判:** ポジティブな反応が主だが、ダッシュボードのバグ報告(#80 PRメタデータ問題, #117 CI表示問題)、TOCTOU競合(#124)など品質面の指摘もある。

### 他ツールとの比較・ポジショニング

| 項目 | Agent Orchestrator (ComposioHQ) | TAKT | workmux | Claude Code Agent Teams | claude-flow |
|------|------|------|------|------|------|
| 言語 | TypeScript | TypeScript | Rust | Built-in | TypeScript |
| エージェント対応 | Claude Code, Codex, Aider, OpenCode | Claude/Codex/OpenCode | エージェント非依存 | Claude Code専用 | Claude Code + MCP |
| 分離方式 | git worktree / clone | git clone --reference | git worktree | セッション内並列 | 多様 |
| フィードバックループ | Reactions設定（CI, review, stuck自動対応） | pieceルール + AI Judge | なし（手動） | ネイティブ共有タスクリスト | 分散swarm |
| ダッシュボード | Next.js Web + xterm.js | なし | ターミナル内ステータス | なし | なし |
| Issue Tracker | GitHub, Linear | GitHub | なし | なし | なし |
| 通知 | Desktop, Slack, Webhook, Composio | Slack Webhook | なし | なし | なし |
| 規模想定 | 30+並列 | 数個〜10個程度 | 数個〜10個程度 | 数個 | 60+（公称） |
| 成熟度 | 10日目 (2026-02) | 1ヶ月 (v0.22) | v0.1.120 | Experimental | 14K stars |

### 制約・注意点

1. **成熟度:** 公開10日目。710 starsは急速だが、コントリビューター1名（作者のみ）。外部本番利用の実績報告はまだない。
2. **既知のバグ:** PRメタデータの書き込み問題(#80)、CI表示のfalse negative(#117)、ターミナルポートのTOCTOU競合(#124)、`ao stop`のログ誤り(#111)。
3. **未実装のプラグイン:** Docker/K8s/SSHランタイム、Jiraトラッカーは設定ファイルで言及されているが実装されていない。
4. **スケーラビリティ:** ステートレス設計（フラットファイル+JSONL）は30セッション程度なら問題ないが、数百レベルへのスケールは未検証。
5. **Claude Code依存度:** Activity Detection（JSONLパース）の品質はClaude Codeプラグインが最も高く、他エージェントの実装品質は不明。
6. **セキュリティ:** `permissions: skip`（`--dangerously-skip-permissions`）が設定で簡単に有効化できる点は、チーム利用時のリスク。

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 理由 |
|------|------|------|
| ライフサイクルマネージャー | `packages/core/src/lifecycle-manager.ts` | Reactionsの実行エンジン、状態遷移ロジックの中核 |
| セッションマネージャー | `packages/core/src/session-manager.ts` | spawn/restore/cleanupの実装詳細 |
| Claude Code Activity Detection | `packages/plugins/agent-claude-code/src/index.ts` | JSONLパースの実装品質、idle/stuck判定ロジック |
| プラグインレジストリ | `packages/core/src/plugin-registry.ts` | 動的ロードの仕組み |
| SCM GitHub | `packages/plugins/scm-github/src/index.ts` | CI/Review/Merge Readinessの`gh`コマンド呼び出し実装 |
| Webダッシュボード SSE | `packages/web/` | リアルタイム更新の実装 |
| Prompt Builder | `packages/core/src/prompt-builder.ts` | エージェントへのコンテキスト注入方法 |
