---
name: oh-my-claudecode
repo: Yeachan-Heo/oh-my-claudecode
last_reviewed: 2026-03-01
category: orchestrator
---

## oh-my-claudecode 調査結果

### 基本情報

- **リポジトリ:** [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
- **言語:** TypeScript
- **Stars:** 7,788（2026-03-01時点）
- **Forks:** 542
- **最終更新:** 活発に開発中（v4.5.1、2026年2月時点で週次リリース）
- **npmパッケージ名:** [`oh-my-claude-sisyphus`](https://www.npmjs.com/package/oh-my-claude-sisyphus)（ブランド名とnpmパッケージ名が異なる）
- **作者:** Yeachan Heo（韓国のソロ開発者）
- **ライセンス:** MIT
- **一言で:** Claude Codeをマルチエージェントオーケストレーターに変貌させるプラグイン。「Claude Codeのoh-my-zsh」

### これは何か・何を解決するのか

oh-my-claudecode（OMC）は、Claude Code CLIの上に構築されたマルチエージェントオーケストレーションレイヤー。Claude Codeの機能を直接拡張し、**32の専門エージェント**、**37以上のスキル**、**31のフック**、**15のカスタムツール**（LSP/AST/REPL）を提供する。

**解決する課題:**

1. **Claude Codeの学習コスト:** 「Claude Codeを学ぶな。OMCを使え」をモットーに、自然言語で複雑なタスクを指示するだけで適切なエージェント・モードが自動選択される
2. **単一エージェントの限界:** 1つのClaude Codeセッションでは並列処理やタスク分解ができない。OMCは複数の専門エージェントを並列に稼働させ、タスクプールから作業を分配
3. **コスト非効率:** すべてのタスクに高コストなOpusを使うのは無駄。OMCはタスク複雑度に応じてHaiku/Sonnet/Opusを自動ルーティングし、30-50%のトークン節約を実現
4. **作業の途中放棄:** Claude Codeが途中で止まる問題を、Ralph mode（完了まで永続実行）やverify/fixループで解決
5. **マルチAI活用:** Claude Code単体だけでなく、Codex CLI・Gemini CLIをtmux上で並列起動し、クロスバリデーションや多角的分析を実現

**対象ユーザー:** Claude Code Max/ProユーザーまたはAnthropicAPIキー保有者で、開発生産性の最大化を求めるソフトウェアエンジニア。

### 設計思想・アーキテクチャ

#### コアアーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code CLI                          │
├─────────────────────────────────────────────────────────────┤
│                  oh-my-claudecode (OMC)                     │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐ │
│  │   Skills    │   Agents    │    Tools    │   Hooks     │ │
│  │ (37 skills) │ (32 agents) │(LSP/AST/REPL)│ (31 hooks) │ │
│  └─────────────┴─────────────┴─────────────┴─────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Features Layer                             ││
│  │ model-routing | boulder-state | verification | notepad  ││
│  │ delegation-categories | task-decomposer | state-manager ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

OMCのアーキテクチャは4つのレイヤーで構成される:

1. **Skills:** 行動注入（behavior injection）。エージェントを切り替えるのではなく、スキルを合成してオーケストレーターの振る舞いを変える
2. **Agents:** 32の専門エージェント。3段階のモデルティア（Haiku/Sonnet/Opus）で自動ルーティング
3. **Tools:** LSP（12）+ AST（2）+ Python REPL（1）= 15のIDE級カスタムツール
4. **Hooks:** 31のイベントドリブンフック。`UserPromptSubmit`、`Stop`、`PreToolUse`、`PostToolUse`の4イベントでライフサイクル全体をカバー

#### スキル合成（Skill Composition）

OMCの最も独特な設計は、スキルを3つのレイヤーで合成する点:

```
┌─────────────────────────────────────────────────────┐
│  GUARANTEE LAYER（任意）                              │
│  ralph: "検証完了まで停止禁止"                        │
├─────────────────────────────────────────────────────┤
│  ENHANCEMENT LAYER（0-N個のスキル）                   │
│  ultrawork（並列）| git-master（コミット）| frontend-ui-ux │
├─────────────────────────────────────────────────────┤
│  EXECUTION LAYER（メインスキル）                      │
│  default（構築）| orchestrate（調整）| planner（計画）   │
└─────────────────────────────────────────────────────┘
```

**合成式:** `[Execution Skill] + [0-N Enhancements] + [Optional Guarantee]`

例: `ultrawork: refactor API with proper commits` → `ultrawork + default + git-master` の3スキルが合成される。

#### マルチエージェントオーケストレーション構造

**エージェントは5つのレーンに組織化:**

| レーン | エージェント群 | モデル |
|--------|--------------|--------|
| **Build/Analysis** | explore, analyst, planner, architect, debugger, executor, verifier | Haiku〜Opus |
| **Review** | quality-reviewer, security-reviewer, code-reviewer | Sonnet〜Opus |
| **Domain Specialists** | deep-executor, test-engineer, build-fixer, designer, writer, qa-tester, scientist, git-master, code-simplifier | Haiku〜Opus |
| **Coordination** | critic | Opus |
| **互換性維持** | document-specialist（旧researcher） | Sonnet |

各エージェントは `agents/*.md` にMarkdownプロンプトテンプレートを持ち、`src/agents/definitions.ts` でモデルとツール権限を定義。ティアードバリアント（`-low`, `-medium`, `-high`）により、同じロールでも異なるモデル階層で実行可能。

**エージェントロール分離の原則（`definitions.ts`より）:**

| エージェント | 役割 | やること | やらないこと |
|------------|------|---------|------------|
| architect | コード分析 | コード分析、デバッグ、検証 | 要件定義、計画作成、計画レビュー |
| analyst | 要件分析 | 要件のギャップ発見 | コード分析、計画、計画レビュー |
| planner | 計画作成 | 作業計画の作成 | 要件、コード分析、計画レビュー |
| critic | 計画レビュー | 計画品質のレビュー | 要件、コード分析、計画作成 |

推奨ワークフロー: `explore → analyst → planner → critic → executor → architect (verify)`

#### Team Mode（v4.1.7+の正式オーケストレーション）

v4.1.7以降、**Team**がOMCの正式なオーケストレーション面。旧来のswarm/ultrapilotはTeamへのファサード。

**Teamのパイプライン:**
`team-plan → team-prd → team-exec → team-verify → team-fix (loop)`

`src/team/` は34ファイルからなる大規模モジュールで、以下を含む:
- `phase-controller.ts`: タスク状態からフェーズ（initializing/planning/executing/fixing/completed/failed）を推論
- `task-router.ts`: タスクを適切なワーカーに割り当て
- `inbox-outbox.ts`: ワーカー間のメッセージングシステム
- `merge-coordinator.ts`: 並列ワーカーの成果物マージ
- `heartbeat.ts` / `worker-health.ts`: ワーカーのヘルスモニタリング
- `git-worktree.ts`: Git worktreeによるワーカー分離
- `tmux-session.ts` / `tmux-comm.ts`: tmuxベースのワーカープロセス管理
- `audit-log.ts` / `activity-log.ts`: 監査ログ

Claude Code native teams（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）を活用し、tmux上で複数のCLIプロセスを実際に起動する。

#### 実行モード

| モード | トリガー | 仕組み | 用途 |
|--------|---------|--------|------|
| **Team** | `/team N:role` | 段階的パイプライン。複数Claudeエージェントが共有タスクリストで協調 | 推奨モード |
| **omc-teams** | `/omc-teams N:codex` | tmuxでClaude/Codex/Gemini CLIを起動 | マルチAI協調 |
| **ccg** | `/ccg` | Codex（分析）+ Gemini（デザイン）並列、Claudeが統合 | トリプルモデル |
| **Autopilot** | `autopilot:` | 単一リードエージェントの自律実行 | エンドツーエンド開発 |
| **Ultrawork** | `ulw` | 最大並列実行（non-team） | バースト修正 |
| **Ralph** | `ralph:` | verify/fixループ付き永続モード | 完遂必須タスク |
| **Pipeline** | `pipeline` | 逐次ステージ処理 | 変換パイプライン |
| **Swarm/Ultrapilot** | `swarm`/`ultrapilot` | レガシー（Teamにルーティング） | 後方互換 |

#### Hooks設計

`src/hooks/bridge.ts`（1,420行）がHookシステムの中核。Shell hookスクリプトがTypeScriptロジックを呼び出すブリッジとして機能。

**主要フック（31個）:**
- **keyword-detector:** ユーザー入力からmagicキーワードを検出し、適切な実行モードをアクティベート
- **autopilot / ralph / ultrawork / ultrapilot:** 各実行モードのライフサイクル管理
- **team-pipeline:** Teamパイプラインの段階遷移
- **learner:** セッションから再利用可能なパターンを自動抽出
- **recovery:** エラーリカバリ
- **rules-injector:** ルールファイルの動的注入
- **subagent-tracker:** サブエージェントの追跡・ダッシュボード
- **project-memory:** プロジェクト記憶の永続化
- **permission-handler:** 権限バリデーション
- **pre-compact / preemptive-compaction:** コンテキスト圧縮管理
- **think-mode:** 推論モード強化
- **session-end:** セッション終了処理（通知送信含む）

#### コスト最適化（モデルルーティング）

`src/features/model-routing/` は複雑度ベースの自動モデル選択を実装:

**シグナル抽出:**
1. **Lexical Signals:** タスクプロンプトのキーワードマッチング（`architecture`→高, `find`→低）
2. **Structural Signals:** プロンプトの構造的特徴（長さ、複雑さ）
3. **Context Signals:** エージェントタイプ、過去の失敗回数

**スコアリング → ティア決定:**
- LOW → Haiku（クイックルックアップ、簡単な操作）
- MEDIUM → Sonnet（標準実装）
- HIGH → Opus（複雑な推論、アーキテクチャ）

**デリゲーションカテゴリ（`src/features/delegation-categories/`）:**

| カテゴリ | ティア | Temperature | Thinking Budget | 用途 |
|---------|--------|-------------|-----------------|------|
| visual-engineering | HIGH | 0.7 | high | UI/フロントエンド |
| ultrabrain | HIGH | 0.3 | max(32K tokens) | 複雑な推論・デバッグ |
| artistry | MEDIUM | 0.9 | medium | 創造的作業 |
| quick | LOW | 0.1 | low | 簡単な検索 |
| writing | MEDIUM | 0.5 | medium | ドキュメント |

カテゴリはキーワードマッチングで自動検出（2個以上のキーワードマッチで確信度判定）し、プロンプトにカテゴリ固有のガイダンスを追加。

### 機能一覧

#### Core（コア）

| 機能 | 概要 | 場所 |
|------|------|------|
| 32専門エージェント | Build/Analysis、Review、Domain Specialists、Coordinationの4レーン構成 | `src/agents/`, `agents/*.md` |
| Team Mode | 段階的パイプライン（plan→prd→exec→verify→fix loop） | `src/team/`, `skills/team/` |
| Model Routing | 複雑度ベースのHaiku/Sonnet/Opus自動選択 | `src/features/model-routing/` |
| Delegation Categories | タスク種別に応じたティア・温度・思考バジェットの自動設定 | `src/features/delegation-categories/` |
| Skill Composition | Execution + Enhancement + Guaranteeの3層合成 | `skills/`, `src/hooks/` |
| Hook System（31フック） | 4つのライフサイクルイベントでの行動注入 | `src/hooks/` |
| Verification Protocol | BUILD/TEST/LINT/FUNCTIONALITY/ARCHITECT/TODO/ERROR_FREEの7項目検証 | `src/features/verification/` |

#### Differentiator（差別化）

| 機能 | 概要 | 場所 |
|------|------|------|
| Ralph Mode | verify/fixループ付き永続実行。完了するまで停止しない | `src/hooks/ralph/`, `skills/ralph/` |
| tmux CLI Workers | Codex/Gemini CLIをtmuxペインで実際に起動するマルチAIオーケストレーション | `src/team/tmux-*.ts`, `skills/omc-teams/` |
| ccg（Tri-Model） | Codex（分析）+ Gemini（デザイン）の並列実行、Claudeが統合 | `skills/ccg/` |
| Learner | セッションから再利用可能なパターンを自動抽出 | `src/hooks/learner/`, `skills/learner/` |
| HUD Statusline | リアルタイムのオーケストレーション指標（セッション使用量、エージェント状況） | `src/hud/` |
| LSP/ASTツール（15個） | IDE級のコードインテリジェンス（定義ジャンプ、リファレンス検索、AST検索/置換） | `src/tools/lsp/`, `src/tools/ast-tools.ts` |
| Magic Keywords | 自然言語中のキーワードでモード自動起動（`ralph:`, `ulw`, `autopilot:`, etc.） | `src/hooks/keyword-detector/` |
| Notepad Wisdom | 計画スコープごとの知見キャプチャ・再利用 | `src/features/notepad-wisdom/`, `src/hooks/notepad/` |
| Rate Limit Wait | レート制限リセット時にセッションを自動再開するデーモン | `src/features/rate-limit-wait/` |

#### Utility（ユーティリティ）

| 機能 | 概要 | 場所 |
|------|------|------|
| 通知（Telegram/Discord/Slack） | セッション完了時やイベント発生時の通知配信 | `src/notifications/` |
| omc-setup / omc-doctor | インストール・診断 | `skills/omc-setup/`, `skills/omc-doctor/` |
| OpenClaw Gateway | 外部自動化のためのWebhookゲートウェイ | `src/openclaw/` |
| State Manager | ローカル/グローバルの状態管理（.omc/state/） | `src/features/state-manager/` |
| Analytics & Cost Tracking | トークン使用量の追跡・分析 | `src/cli/analytics.ts` |
| Background Tasks | バックグラウンドタスク管理 | `src/features/background-tasks.ts` |
| Continuation Enforcement | セッション中断時の自動再開 | `src/features/continuation-enforcement.ts` |
| Delegation Enforcer | デリゲーション遵守の強制 | `src/features/delegation-enforcer.ts` |
| Project Memory | プロジェクト記憶の永続化 | `src/hooks/project-memory/` |
| Writer Memory | ライティングパターンの記憶 | `skills/writer-memory/` |
| Python REPL | データ分析用のPersistent REPL | `src/tools/python-repl/` |
| i18n Prompt Translation | プロンプトの動的翻訳 | `src/hooks/keyword-detector/` |

### 特徴的な点・注目ポイント

#### 1. 「CONDUCTOR, not performer」の設計哲学

OMCのシステムプロンプト（`omcSystemPrompt` in `definitions.ts`）は、メインエージェントを**指揮者**として位置づけ、自ら作業せず専門エージェントにデリゲートすることを徹底する。「NEVER STOP WITH INCOMPLETE WORK」「PERSIST RELENTLESSLY」といった強い命令で、作業の途中放棄を禁止。これはRalph modeのverify/fixループと組み合わさり、タスク完遂の保証を目指す設計。

#### 2. Skill Compositionによるモード合成

従来の「モードA or モードB」ではなく、スキルを合成して振る舞いを構成する設計は、oh-my-zshのプラグインシステムに着想を得ている。例えば `ralph` + `ultrawork` でタスクを完遂保証付きで並列実行、`autopilot` + `git-master` で自律開発にアトミックコミットを付与、といった組み合わせが可能。

#### 3. tmuxベースのマルチAI CLI Workers

v4.4.0で従来のMCPサーバーアーキテクチャ（Codex/Gemini用）を全廃し、tmuxの分割ペインで実際のCLIプロセスを起動する方式に移行。これにより:
- 実プロセスとして目に見える形でCodex/Geminiが稼働
- オンデマンド起動・タスク完了時に自動終了
- MCP抽象化のオーバーヘッドを排除

#### 4. LSP/ASTツール統合によるIDE級機能

MCPサーバー経由で12のLSPツール（hover, goto definition, find references, diagnostics等）と2つのASTツール（ast-grep search/replace）を提供。TypeScript/Python/Rust/Go/Java等10言語をサポート。単なるテキスト操作ではなく、型情報に基づくリファクタリングや構造的コード検索が可能。

#### 5. 証拠ベースの検証プロトコル

`src/features/verification/index.ts` は7項目の標準検証チェック（BUILD/TEST/LINT/FUNCTIONALITY/ARCHITECT/TODO/ERROR_FREE）を定義。エビデンスは5分以内の鮮度が要求され、実際のコマンド出力を含む。並列/逐次実行、fail-fast、オプショナルチェックスキップに対応。

### 使い方・典型的なワークフロー

#### インストール

```bash
# Claude Codeプラグインとしてインストール
/plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
/plugin install oh-my-claudecode

# セットアップ
/omc-setup
```

#### 日常的なワークフロー（実利用者のレビューに基づく）

**1. ralplan（計画→実行）:** 複雑なフィーチャー実装のとき

```
ralplan: ユーザー認証システムを実装
```

インタビュー形式で要件を収集 → 計画策定 → 完了まで実行。

**2. autopilot（自律実行）:** タスクが明確なとき

```
autopilot: REST APIのCRUDエンドポイントを実装
```

**3. ultraqa（品質保証サイクル）:** テスト・修正の自動反復

```
ultraqa: 全APIエンドポイントのテストを書く
```

**4. Team Mode（推奨）:**

```bash
/team 3:executor "全TypeScriptエラーを修正"
```

3つのexecutorエージェントがTeamパイプラインで協調。

**5. マルチAI協調:**

```bash
/omc-teams 2:codex "セキュリティレビュー"
/omc-teams 2:gemini "UIコンポーネントのリデザイン"
/ccg このPRをレビュー — アーキテクチャ(Codex)とUI(Gemini)
```

**6. コードレビュー:**

```
/security-review    # セキュリティ脆弱性チェック
/code-review        # 包括的コードレビュー
/review             # 一般コードレビュー
/analyze            # コードベース分析
```

#### Claude Code Teams有効化設定

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

`~/.claude/settings.json` に追記が必要。

### エコシステム・実利用状況

- **採用事例:**
  - 具体的な企業名の公開事例は確認できず。個人開発者・小規模チームでの利用が中心
  - あるレビュアーは4日間の集中使用で約$200相当のトークン消費（サブスクリプションモデルのため実費ではない）を報告（[ソース](https://sonim1.com/en/blog/oh-my-claudecode)）
  - 別の事例では、4ヶ月間でClaude Codeにより80%以上のコード変更を生成し、40%の生産性向上を実現（[ソース](https://dev.to/dzianiskarviha/integrating-claude-code-into-production-workflows-lbn)）

- **盛り上がりの文脈:**
  - 2025年後半〜2026年初頭のClaude Code普及に伴い急成長
  - oh-my-zshの「拡張プラグイン」という親しみやすいメタファーが受け入れられた
  - Codex CLI/Gemini CLIとの統合（マルチAI）が差別化要因として注目
  - 7,800+ Starsは同カテゴリ（Claude Code拡張）で最大級

- **コミュニティ:**
  - GitHub Issues: 活発。v4.4.0〜v4.5.1で毎リリース30-80以上のIssueをクローズ
  - 多言語対応: README日本語版（`README.ja.md`）、韓国語、中国語、スペイン語、ベトナム語、ポルトガル語
  - 韓国語コミュニティが特に活発（作者が韓国人のため）

- **周辺ツール:**
  - [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex): 同作者によるOpenAI Codex CLI版
  - OpenClaw/Clawdbot: 外部自動化連携のためのゲートウェイサポート
  - tmux: CLI Workers実行の前提（必須依存）

- **評判:**
  - **肯定的:** 「Legal Doping for Claude Code」（[ソース](https://sonim1.com/en/blog/oh-my-claudecode)）。3-5xの高速化、30-50%のコスト削減。HUDによるリアルタイム使用量追跡が実用的（[ソース](https://sonim1.com/en/blog/oh-my-claudecode)）
  - **肯定的:** 「The Only Agents Swarm Orchestration You Need」（[Medium, 2026-01](https://medium.com/@joe.njenga/i-tested-oh-my-claude-code-the-only-agents-swarm-orchestration-you-need-7338ad92c00f)）
  - **否定的/懸念:** Claude Code自体のcompaction/compact機能が壊れている問題により、長時間セッションでの安定性に課題（[GitHub Issue #18211](https://github.com/anthropics/claude-code/issues/18211)）。並列Exploreエージェントでのメモリ枯渇（4GB超でクラッシュ）の報告あり（[GitHub Issue #18471](https://github.com/anthropics/claude-code/issues/18471)）

### 他ツールとの比較・ポジショニング

| 比較軸 | oh-my-claudecode | o-m-cc (kok1eee) | Agent Orchestrator (Composio) | Claude Code Agent Teams |
|--------|-----------------|------------------|-------------------------------|------------------------|
| **位置づけ** | Claude Code専用プラグイン | Claude Code拡張（軽量） | 汎用マルチエージェントフレームワーク | Anthropic公式の実験的機能 |
| **エージェント数** | 32（ティアードバリアント含む） | 少数（基本構成） | 設定次第 | N/A（基盤機能） |
| **モデルルーティング** | Haiku/Sonnet/Opus自動ルーティング | 限定的 | プロバイダー非依存 | なし |
| **マルチAI** | Claude + Codex + Gemini（tmux） | Claude中心 | 複数プロバイダー対応 | Claude Code内蔵 |
| **インストール** | `/plugin install` | 手動設定 | pip/npm | 環境変数1つ |
| **成熟度** | v4.5.1（活発開発中） | 初期段階 | 本番利用可 | 実験的 |
| **スター数** | 7,800+ | 数百〜 | 数千 | N/A（公式機能） |
| **学習コスト** | 低（magic keywords） | 低〜中 | 中〜高 | 低 |
| **カスタマイズ性** | 高（37スキル、31フック） | 中 | 高 | 低（設定限定） |
| **依存** | Claude Code CLI必須 | Claude Code CLI必須 | LLMプロバイダーAPI | Claude Code内蔵 |

**ポジショニングの特徴:**
- OMCはClaude Code**専用**の最大規模拡張で、oh-my-zshのようにClaude Code体験を根本的に変える
- Agent Orchestrator（Composio）は汎用フレームワークであり、Claude Codeに特化していない。一方OMCはClaude Codeのhook/plugin APIと深く統合
- Claude Code Agent Teamsは公式の実験的機能で、OMCはv4.1.7+でこれを内部的に活用している（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）
- o-m-cc（kok1eee）は同名の別プロジェクトで、OMCより軽量だが機能は限定的

### 制約・注意点

1. **Claude Codeへの完全依存:** Claude Code CLIの変更に直接影響を受ける。Claude Codeのcompactionバグやメモリ問題はOMCでも発現する
2. **実験的機能への依存:** Team Modeは `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` フラグに依存。Anthropicがこの実験的APIを変更・廃止すれば影響大
3. **tmux必須（CLI Workers）:** マルチAIオーケストレーション（omc-teams, ccg）はtmuxセッション内での実行が前提
4. **コスト管理:** 32エージェントの並列実行はトークン消費が大きい。モデルルーティングで30-50%節約するものの、重度の利用ではMax planのレート制限に頻繁に到達する（レビュアーは週末4日で5回到達と報告）
5. **Windows対応:** v4.4.2でWSL/MSYS2サポートが追加されたが、ネイティブWindowsは制限あり（起動時に警告表示）
6. **ドキュメントの膨大さ:** 32エージェント、37スキル、31フック、15ツールと機能が多く、どこから始めるか分かりにくい。実利用者は「ralplan/autopilot/ultraqaの3つから始める」ことを推奨
7. **npmパッケージ名の混乱:** リポジトリ名は `oh-my-claudecode` だがnpmパッケージは `oh-my-claude-sisyphus`。ブランドの一貫性に欠ける
8. **ソロメンテナ:** 急速な開発ペース（週次リリース）だが、主要メンテナは1人。バス係数のリスク
9. **大規模コードベースでの安定性:** 並列エージェントが大量ファイルを検索する際にClaude Codeのヒープが4GBを超えてクラッシュする事例が報告されている

### 深掘り候補（コードリーディング対象）

| ファイル/ディレクトリ | 読む目的 | 優先度 |
|---------------------|---------|--------|
| `src/hooks/bridge.ts` (1,420行) | Hookシステムの全体像。UserPromptSubmit/Stop/PreToolUse/PostToolUseの全処理フローを理解 | 高 |
| `src/features/model-routing/router.ts` | 実際のルーティングロジック。スコアリング→ティア決定→エスカレーションの詳細 | 高 |
| `src/features/model-routing/signals.ts` | シグナル抽出の具体的実装（Lexical/Structural/Context） | 中 |
| `src/team/runtime.ts` | Teamモードの実行ランタイム。ワーカー管理・タスク分配の中核 | 高 |
| `src/team/unified-team.ts` | 統一されたTeamインターフェース | 中 |
| `src/team/inbox-outbox.ts` | ワーカー間メッセージング | 中 |
| `src/hooks/keyword-detector/index.ts` | Magic Keywordの検出ロジック | 中 |
| `src/hooks/ralph/index.ts` | Ralph modeの永続実行ロジック | 中 |
| `src/hooks/autopilot/index.ts` | Autopilot modeの自律実行ロジック | 中 |
| `src/tools/lsp-tools.ts` | LSPツール定義。MCPサーバー経由での言語サーバー統合 | 低 |
| `src/features/task-decomposer/` | タスク分解のアルゴリズム | 低 |
| `agents/architect.md` | 最重要エージェント（Opus）のプロンプトテンプレート例 | 低 |
| `src/agents/utils.ts` | `loadAgentPrompt()`の実装。Markdownプロンプトの読み込みメカニズム | 低 |
