---
name: o-m-cc（+ 旧: zephyrpersonal/oh-my-claude-code）
repo: kok1eee/o-m-cc
last_reviewed: 2026-02-22
category: orchestrator
note: このファイルは元々 zephyrpersonal/oh-my-claude-code と kok1eee/o-m-cc の2つを調査したもの。zephyrpersonal版は破棄扱い（下記参照）。
---

> **⚠️ zephyrpersonal/oh-my-claude-code について**
> このファイルの前半で調査した `zephyrpersonal/oh-my-claude-code`（Stars 0）は、メジャープロジェクト [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)（7,800+ stars）とは**完全に別物**の個人プロジェクト。リサーチ対象としての価値は低いため、前半の分析は**参考程度**に留め、oh-my-claudecodeのメジャー版は [oh-my-claudecode.md](./oh-my-claudecode.md) を参照のこと。
>
> 同様に、[code-yeongyu/oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)（35,600+ stars）はOpenCode用の別プロジェクトで、o-m-ccとは無関係。詳細は [oh-my-opencode.md](./oh-my-opencode.md) を参照。

## oh-my-claude-code (zephyrpersonal) 調査結果 — ⚠️ 破棄扱い

### 基本情報
- **リポジトリ:** https://github.com/zephyrpersonal/oh-my-claude-code
- **言語:** JavaScript / Markdown
- **最終更新:** 2025-01頃（v1.2.0）
- **規模:** 0 stars, 0 forks, コントリビューター1名
- **一言で:** コスト意識型モデルルーティングを持つClaude Code用マルチエージェントプラグイン
- **⚠️ ステータス:** 開発停滞。メジャー版（Yeachan-Heo）とは別物。リサーチ対象として破棄扱い

### これは何か・何を解決するのか

Claude Codeに「専門エージェントチーム」を追加するプラグイン。中央オーケストレーターがタスクを分類し、コストを考慮して適切なエージェントに委譲する。

### 設計思想

**中央オーケストレーター型（Hub-and-Spoke）**: 全リクエストが`orchestrator`エージェントを経由し、Intent Gateでタスク分類→委譲。

**コスト意識型モデルルーティング（FREE → CHEAP → EXPENSIVE）**:
- `COST_LEVELS: { FREE: 'haiku', CHEAP: 'sonnet', EXPENSIVE: 'opus' }`
- オーケストレーターのプロンプトに段階的エスカレーション方針を埋め込み
- コスト判断はプロンプト指示ベース（ルールベースの自動振り分けではない）

**Hooks駆動のワークフロー制御**: Node.js製の3フック
- `UserPromptSubmit` → ultrawork-detector（キーワード検出でモード注入）
- `Stop` → todo-continuation-enforcer（未完了TODO検出で停止ブロック）
- `PostToolUse` → post-tool-processor（コメント品質チェック + 診断リマインダー）

### 機能一覧

| 機能 | 種別 | 概要 |
|------|------|------|
| **Orchestrator Agent** | コア | Intent Gate + コスト意識型委譲 |
| **Explore Agent** | コア | haiku（FREE）で高速コードベース検索 |
| **Librarian Agent** | コア | sonnet（CHEAP）で外部ドキュメント調査 |
| **Oracle Agent** | コア | opus（EXPENSIVE）で深い分析・アーキテクチャ判断 |
| **Frontend UI/UX Engineer** | 実装系 | ビジュアル変更の専門家 |
| **Document Writer** | 実装系 | 技術文書作成 |
| **Multimodal Looker** | 分析系 | PDF/画像解析 |
| **Ultrawork Mode** | 差別化 | `ulw`キーワードでSisyphusモード有効化。`--max-iterations`, `--thoroughness`, `--completion-signal` パラメータ対応 |
| **Todo Continuation Enforcer** | 差別化 | 未完了TODO時の停止ブロック |
| **Comment Checker** | ユーティリティ | AI風コメント検出（40%閾値 + 13フレーズ検出） |
| **Auto-Diagnostics Reminder** | ユーティリティ | ファイル変更時のLSP診断リマインダー |
| **Progress Visualization** | ユーティリティ | ASCIIプログレスバー + 時間見積もり |

### 特徴的な点

1. **コスト意識型パターン**: YAMLフロントマターで`x-omo-cost: FREE/CHEAP/EXPENSIVE`メタデータ付与。段階的エスカレーション
2. **Ultraworkのパラメータ制御**: キーワード + 正規表現パラメータ抽出 + Context注入。`completion-signal`でカスタム完了条件指定可能
3. **Comment Checker**: コメント比率閾値40% + AI風フレーズ13個の検出。Claude Codeの冗長コメント防止
4. **Ralph Loopとの比較を自認**: ULWは「ステートフル（TODO追跡）」、Ralph Loopは「ステートレス」と位置づけ

### 制約
- 0 stars、開発停滞気味、並列実行未実装、コスト振り分けはプロンプト依存、Node.js 18+必要

---

## o-m-cc (kok1eee) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/kok1eee/o-m-cc
- **言語:** Shell (Bash) / Markdown / Python / JSON
- **最終更新:** 2026年（v0.17.1、活発に開発中）
- **規模:** 4 stars, 0 forks, コントリビューター1名
- **一言で:** Peer-to-peer Agent Teamsによる分散型マルチエージェント協調プラグイン

### これは何か・何を解決するのか

Claude Codeに「不屈の開発者」マインドセットを注入するプラグイン。14の専門エージェントがTeammateTool（Claude Code Agent Teams）を通じてpeer-to-peerで協調し、TODO完了まで止まらないワークフロー。

### 設計思想

**分散型Peer-to-Peer（中央オーケストレーターなし）**: CLAUDE.mdで「全エージェントを統括する『マスターエージェント』の導入」を明示的にアンチパターンとして禁止。

**7つの設計原則:**

| 原則 | 説明 |
|------|------|
| Peer-to-peer協調 | 中央制御なし。エージェント同士が対等に議論・共有 |
| VCSベースのナレッジ | HANDOVER.mdのgit/jj履歴がナレッジベース。外部DB不要 |
| Sisyphus（止まらない） | タスク完了まで止まらない。hooksのexit codeで制御 |
| Lightweight | Markdown + Shellのみ。ビルド不要 |
| Progressive Disclosure | frontmatter→本文→参照ファイルの3段階でトークン最小化 |
| Plugin ネイティブ | Claude Codeプラグインシステム準拠 |
| エージェント自律性 | 各エージェントは専門家として自律判断 |

**ディスパッチ戦略（タスク規模別）:**

| 規模 | 方式 | 判断基準 |
|------|------|---------|
| S | Leadが直接実行 | Glob/Grep 1回で答えが出る |
| M | Agent Teams (2-3 teammates) | 判断・分析が必要 |
| L | Agent Teams (5+ teammates) + TaskCreate | 複数工程・並列作業 |

### 機能一覧

#### エージェント群（14体）

| カテゴリ | エージェント | Model | 特記 |
|----------|-------------|-------|------|
| 分析・調査 | explore, analyst, researcher, scout, learnings-researcher, vision | haiku/sonnet | explore/researcher/learnings-researcher は `background: true` |
| 設計・計画 | designer, planner, critic, advisor | opus/sonnet | designer/planner/debugger は `isolation: worktree` |
| 実装 | frontend | sonnet | worktree 分離 |
| 品質 | code-reviewer, security-reviewer | sonnet | 並列 spawn 推奨 |
| デバッグ | debugger | sonnet | worktree 分離 |

#### Hooks（11イベント）

| Hook | イベント | 概要 |
|------|---------|------|
| **stop-guard.sh** | Stop | Sisyphusガード: DONE + code-review確認 + スロットリング |
| **generate-handover.sh** | Stop | HANDOVER.md自動生成 |
| **promote-checker.sh** | Stop | VCS履歴からパターン検出→スキル自動昇格 |
| **focus-guard.sh** | UserPromptSubmit | タスク進行中の脱線防止 |
| **security_reminder_hook.py** | PreToolUse(Write\|Edit) | セキュリティパターン検出 |
| **auto-verify.sh** | PostToolUse(Write\|Edit) | フェーズ完了時の自動検証 |
| **check-dependencies.sh** | SessionStart | 依存コマンド確認 |
| **archive-plans.sh** | SessionStart | 古いプランのアーカイブ |
| **resume-session.sh** | SessionStart | 前回セッション状態復元 |
| **teammate-idle.sh** | TeammateIdle | idle teammateへの残タスク再割り当て |
| **task-completed.sh** | TaskCompleted | 進捗表示 + 依存タスクアンブロック |

#### Skills（6スキル）

`/o-m-cc:init`, `/o-m-cc:plan`, `/o-m-cc:review`, `/o-m-cc:handover`, `/o-m-cc:audit`, `/o-m-cc:promote`

### 特徴的な点

**1. Peer-to-Peer Agent Teams**

Claude Code Agent Teams (TeammateTool) をフル活用。計画フローはCouncil（並列議論）+ Pipeline（逐次処理）のハイブリッド:

```
Phase 1: Discovery Council  (learnings-researcher + analyst + scout → peer-to-peer)
Phase 2: Pipeline           (designer → planner)
Phase 4: Review Council     (critic + advisor → peer-to-peer)
```

**2. HANDOVER.md VCS知識管理**

外部DB不要。HANDOVER.mdをVCS（git/jj）でコミットし、diff履歴をナレッジベースとして活用。`learnings-researcher`がVCS横断検索、`promote-checker.sh`が繰り返しパターン検出→スキル昇格。

**3. Stop Guard + code-review統合**

`stop-guard.sh`の動作:
- DONE検出 + code-reviewer未実行 → ブロック + レビュー要求
- DONE + Critical問題あり → ブロック + 修正要求
- DONE + Criticalなし → 終了許可
- 同一理由3回連続ブロック → スロットリングで強制停止

**4. Focus Guard（脱線防止）**

`focus-guard.sh`が未完了タスク中の別作業依頼にsystemMessageを注入。ブロックはしないがガイダンス提供。

**5. Progressive Disclosure（-33%トークン削減）**

v0.17.0で全エージェント定義から詳細リファレンスを`facets/references/`に分離（2107行→1403行）。初期トークン消費を~1010トークン（Opus 1Mの0.1%）に抑制。

**6. jj (Jujutsu) VCS サポート**

gitとjjの両方に対応。jjを優先して差分取得するフォールバック構造。

---

## 両プロジェクトの比較

| 次元 | oh-my-claude-code | o-m-cc |
|------|------|------|
| **アーキテクチャ** | 中央オーケストレーター型 | 分散型Peer-to-Peer |
| **エージェント数** | 7 | 14 |
| **実装言語** | JavaScript (Node.js) | Bash + Python + Markdown |
| **コスト制御** | FREE→CHEAP→EXPENSIVE段階 | モデル固定 |
| **Sisyphus実装** | TODO未完了で停止ブロック | DONE + code-review確認 + スロットリング |
| **知識管理** | なし | HANDOVER.md VCS履歴 + 自動スキル昇格 |
| **トークン最適化** | なし | Progressive Disclosure（-33%） |
| **会話制御** | なし | focus-guard + resume-session |
| **Agent Teams** | 未対応 | フル活用（Council + Pipeline） |
| **成熟度** | v1.2.0（停滞気味） | v0.17.1（17回以上リリース、活発） |

**設計思想の本質的な違い:** oh-my-claude-codeは「賢い中央司令官がコストを考えて部下に振る」モデル。o-m-ccは「専門家チームが対等に議論し自律的に協調する」モデル。Agent Teamsのネイティブサポートが進んだことで、o-m-ccの方がClaude Codeエコシステムとの親和性が高い。

### 深掘り候補

**oh-my-claude-code:**
- `hooks/ultrawork-detector.js` — パラメータ抽出とContext注入
- `agents/orchestrator.md` — Intent Gate分類とコスト判断

**o-m-cc:**
- `hooks/stop-guard.sh` — Sisyphus Guard + code-review + スロットリング全容
- `hooks/promote-checker.sh` — VCS履歴からのパターン自動検出
- `hooks/focus-guard.sh` — 脱線防止systemMessage注入
- `facets/references/` — Progressive Disclosure参照ファイル群
- `hooks/teammate-idle.sh` + `hooks/task-completed.sh` — Agent Teamsイベント駆動制御
