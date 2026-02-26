---
name: Claude Code Agent Teams
repo: （Claude Code内蔵機能。OSSリポジトリなし）
last_reviewed: 2026-02-25
category: built-in-orchestrator
---

## Claude Code Agent Teams 調査結果

### 基本情報

- **提供元**: Anthropic（Claude Codeの実験的機能）
- **リリース**: 2026-02-05（Opus 4.6と同時）
- **言語**: TypeScript（Claude Code内部実装）
- **状態**: Feature Preview（実験的）
- **有効化**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- **一言要約**: Claude Codeセッション間のファイルベースmailboxによるマルチエージェント協調機能

### これは何か・何を解決するのか

Claude Codeの複数セッションを「チーム」として組織し、team lead + teammates構成で並列作業を可能にする内蔵オーケストレーション機能。subagents（単一セッション内で結果だけ返す）とは異なり、teammates同士が直接通信でき、独立したコンテキストウィンドウを持つ。

**解決する問題**:
- 大きなタスクの並列分割（frontend/backend/tests等のレイヤー分担）
- 異なる仮説の並列検証（debugging with competing hypotheses）
- 新機能の独立開発（ファイル競合を避けた並列作業）

### 設計思想・アーキテクチャ

#### ファイルベース通信

クラウドオーケストレーションは一切使わず、すべて **ローカルファイルシステム上のJSONファイル** で協調する。

```
~/.claude/teams/[project]/
├── config.json              # チーム構成（join/leave で動的変化）
├── tasks/                   # タスクファイル（個別JSON、ファイルロックで排他）
│   ├── task-001.json
│   └── task-002.json
└── inboxes/                 # エージェント別メールボックス
    ├── team-lead.json
    ├── teammate-frontend.json
    └── teammate-backend.json
```

#### 通信プロトコル

- **SendMessage ツール**: JSON blobをinboxファイルにappend
- **非同期**: エージェントはターン間（実行中ではなく）にinboxをチェック
- **mailbox方式**: 各teammateが独自のinboxファイルを持つ

#### Subagentsとの比較

| 観点 | Subagents | Agent Teams |
|---|---|---|
| コンテキスト | 独自ウィンドウ、結果のみ返却 | 独自ウィンドウ、完全独立 |
| 通信 | 親エージェントへの結果報告のみ | teammates間の直接メッセージング |
| 協調 | 親が全作業を管理 | 共有タスクリスト + 自己協調 |
| トークンコスト | 低い | **約2倍** |
| 用途 | 集中タスク（結果だけ必要） | 協調が必要な複雑な作業 |

### 機能一覧

**Core**:
- Team lead / teammates の役割分担
- ファイルベースmailboxによる非同期メッセージング
- 共有タスクリスト（ファイルロックで排他制御）
- 独立セッション（各teammateが自律的に作業）

**Differentiator**:
- **In-process mode**: Shift+Up/Downでteammate間を切り替え（単一ターミナル内）
- **Delegate mode** (Shift+Tab): team leadを協調専任に制限（コード変更禁止）
- **Split-pane mode**: tmux/iTerm2で全teammateを同時表示
- teammates同士の直接通信（team leadを介さない）
- 人間がいつでも個別teammateに直接介入可能

**Utility**:
- セッション永続化（各teammateのコンテキスト維持）
- タスクのclaim/complete管理

### 特徴的な点・注目ポイント

1. **ファイルベースの設計**: `~/.claude/teams/` にJSONファイルを書くだけ。DB不要、サーバー不要。steipeteのagent-scripts（`.ralph/progress.md`）やo-m-cc（HANDOVER.md）と同じ「ファイルがプロトコル」の思想
2. **非同期mailbox**: リアルタイム通信ではなくターン間チェック。CAOのInbox + Watchdogパターンと同構造
3. **コスト2倍**: 各teammateが独自コンテキストを維持するため。コスト最適化の観点ではsubagentsの方が効率的
4. **Delegate mode**: team leadがコードを書かず協調だけ行うモード。概念的にはCAOのSupervisorと同じだが、より明示的にモード切り替え

### 使い方・典型的なワークフロー

```bash
# 有効化
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Claude Code起動
claude

# チーム作成（プロンプトで指示）
"frontendとbackendとtestsの3人チームで作業して"

# Delegate modeに切り替え（team leadを協調専任に）
# Shift+Tab

# 個別teammateに切り替え
# Shift+Up/Down

# Split-pane表示（tmux必須）
# tmux起動状態でClaude Codeを実行
```

### エコシステム・実利用状況

- 2026-02-05リリース。Feature Preview段階
- steipete等の「手動tmuxオーケストレーション」実践者の影響を受けたと推測される
- o-m-ccはAgent Teamsの `TeammateTool` を活用してP2P協調を実現している

### 他ツールとの比較・ポジショニング

| 観点 | Agent Teams | o-m-cc | CAO | Agent Orchestrator |
|---|---|---|---|---|
| ホスト | Claude Code内蔵 | Claude Code Plugin | 独立API Server | 独立CLI |
| 通信 | ファイルベースmailbox | TeammateTool | tmux + Inbox/Watchdog | tmux + Plugin |
| トポロジー | Team lead + Teammates | P2P（中央なし） | Supervisor/Worker | Orchestrator/Worker |
| 対象エージェント | Claude Codeのみ | Claude Codeのみ | 複数CLI（Q, Kiro, Claude, Codex） | 複数CLI（Claude, Codex, Aider） |
| コスト管理 | なし（2x） | COST_LEVELS | なし | なし |
| 設定 | 環境変数のみ | Markdown frontmatter | Markdown + YAML | YAML |

### 制約・注意点

- **実験的機能**: セッション再開、タスク協調、シャットダウン挙動に既知の制限あり
- **Claude Code専用**: 他のエージェントCLI（Codex, Aider等）との連携不可
- **コスト**: subagentsの約2倍。個人開発での常用にはコスト懸念
- **ファイル競合**: 同一ファイルへの並行編集は推奨されない。teammate間でファイル担当を明示的に分ける必要がある
- **タスク粒度**: 1 teammateあたり5-6タスクが推奨。細かすぎるとオーバーヘッド

### 深掘り候補

- [ ] `~/.claude/teams/` のJSON構造の詳細解析（スキーマ、ロック機構）
- [ ] Delegate mode の内部実装（team leadの制約はどう実現されているか）
- [ ] o-m-cc の TeammateTool との統合パターン
- [ ] Hooks（PreToolUse, PostToolUse等）との連携可能性

### concepts/ との対応

| Agent Teams の概念 | 該当するドメイン領域 |
|---|---|
| Team lead / Teammates | 02 Routing (Hierarchical Delegation) |
| ファイルベースmailbox | 08 Event (Messaging) |
| 共有タスクリスト | 03 Flow Control + 05 State |
| Delegate mode | 02 Routing（Supervisor専任化） |
| Split-pane / In-process | 04 Execution & Runtime |
| 直接通信 | cross-cutting: Coordination Topologies（P2P要素あり） |

### 自前ツール構築への示唆

- **ファイルベース通信は実用的**: Anthropic自身がファイルベースmailboxを選択した。DB不要の設計がvalidated
- **コスト2倍問題**: 並列エージェントのコンテキスト維持コストは無視できない。コスト最適化が必須
- **CLIラッパー型の限界**: Agent TeamsはClaude Code専用。複数エージェントCLIを束ねるならCAO/Agent Orchestrator型が必要
- **subagents vs teams の使い分け**: 「結果だけ必要」→ subagents、「協調が必要」→ teams。これは Handoff vs Agent-as-Tool の二項対立と同構造

### 参考リンク

- [公式ドキュメント: Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Agent Teams: The Complete Guide 2026](https://claudefa.st/blog/guide/agents/agent-teams)
- [Claude Code Agent Teams: How They Work Under the Hood](https://www.claudecodecamp.com/p/claude-code-agent-teams-how-they-work-under-the-hood)
- [Agent Teams Controls: Delegate Mode, Hooks & More](https://claudefa.st/blog/guide/agents/agent-teams-controls)
