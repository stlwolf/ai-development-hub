# Skills/Rulesレベルのオーケストレーションパターン

FWレイヤー（landscape/ の21ツール）の下位にある、Skills/Rules/Hooksレベルの軽量オーケストレーション手法の調査と設計洞察。

## 調査動機

- FWレイヤーは網羅的に調査済み（landscape/）
- 一方、Claude Code Skills や Cursor Rules を組み合わせた「小さい粒度」のオーケストレーションが多数出現
- これらに共通する本質的パターンを大別・体系化し、自前ツール設計の入力とする

---

## 5つの基本パターン

### Pattern 1: Skills-as-Knowledge-Injection（知識注入型）

汎用エージェントに `SKILL.md` で専門知識を遅延ロードし「専門家化」させる。FWではなく **Markdownが専門性の源泉**。

- YAML frontmatter（name, description）→ セッション開始時に常時ロード（エージェントがスキルの存在を認識）
- Markdown本文 → 必要時にのみコンテキスト展開（progressive disclosure）
- `scripts/`, `references/`, `assets/` で補助リソースを同梱
- `allowed-tools` でツールアクセスを制限し安全に専門化

**コンテキスト共有**: スキル自体がコンテキスト。共有はgitリポジトリ経由（`.claude/skills/`）

**代表例**: [claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase)（5,539 stars）、[SkillMD.ai](http://skillmd.ai) のsecurity-review/code-reviewer skills

### Pattern 2: Multi-Instance Coordination（複数インスタンス協調型）

複数の独立したClaude Codeインスタンスが **共有タスクリスト + Inbox（JSON）** で協調。サブエージェント（fire-and-forget）とは異なり双方向メッセージング可能。

```
~/.claude/teams/{team-name}/
├── config.json              # チームメタデータ・メンバーリスト
└── inboxes/
    ├── team-lead.json       # リーダーのInbox
    └── worker-N.json        # 各ワーカーのInbox

~/.claude/tasks/{team-name}/
├── 1.json                   # タスク（依存関係・状態管理付き）
└── ...
```

**コンテキスト共有**:
- Spawn prompt: タスク固有の詳細・ファイルパス・受入基準をインスタンス生成時に注入
- タスクメタデータ: 共有タスクリスト（pending → in_progress → completed）
- Inbox JSON: エージェント間直接メッセージング
- ファイル所有権: 各エージェントに担当ファイルを明示的割当て → 競合回避

**専門チーム構成の典型**:

| ロール | モデル | 専門性 |
|--------|--------|--------|
| PM/Orchestrator | Opus | 計画・委譲・統合 |
| Developer | Sonnet | 実装 |
| Reviewer | Sonnet | セキュリティ・品質レビュー |
| Tester | Sonnet | テスト戦略・検証 |

**代表例**: [Claude Code Agent Teams](https://docs.anthropic.com/en/docs/claude-code/agent-teams)（公式）、[kieranklaassen/swarm-orchestration](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)（Fork 87）、[zircote/claude-team-orchestration](https://github.com/zircote/claude-team-orchestration)

### Pattern 3: Single-Conversation Multi-Role（単一会話マルチロール型）

1つのLLMが同一会話内で複数の「マスク（ロール）」を切替え。**コンテキストロスをゼロにする** ことが最大の設計目的。

- 従来のマルチエージェント最大の課題 = ハンドオフ時のコンテキスト損失を根本解決
- 全ロールが同一コンテキストウィンドウ共有 → 完全な記憶連続性
- `discuss → plan → execute` の構造化ワークフロー
- Spec-Scriptループ: 自然言語仕様 → 決定論的スクリプト実行

**コンテキスト共有**: 不要（同一コンテキスト）。ただしコンテキストウィンドウ上限が制約

**トレードオフ**: コンテキスト連続性は完璧だが並列実行不可。長大タスクではウィンドウ飽和

**代表例**: [thiswind/cursor-agent-team](https://github.com/thiswind/cursor-agent-team)（[Zenodo論文](https://zenodo.org/records/18605311)付き）

### Pattern 4: Hook-Driven State Machine（フック駆動状態機械型）

エージェントの行動をHooks（PreToolUse/PostToolUse）で **決定論的に制約** し、ステートマシンとしてワークフローを強制。プロンプトの80%準拠を100%に引き上げる。

- 状態ファイルがsingle source of truth → エージェントは状態をスキップできない
- `PreToolUse` = 安全ゲート（許可/拒否/エスカレーション）
- `PostToolUse` = 品質ゲート（追加コンテキスト注入）
- 3エージェント構成例: Lead → Developer → Reviewer の決定論的サイクル

**コンテキスト共有**: 状態ファイル + Hooksによるコンテキスト注入（`additionalContext`）。エージェント自身の判断ではなくシステムレベルで強制的にコンテキストを流す

**代表例**: [NTCoding/autonomous-claude-agent-team](https://github.com/NTCoding/autonomous-claude-agent-team)、[Dotzlaw Consulting記事](https://www.dotzlaw.com/insights/claude-deterministic-agent-engineering/)

### Pattern 5: Document-Mediated Handoff（ドキュメント媒介型ハンドオフ）

構造化された `HANDOFF.md` や成果物ドキュメントがエージェント間の唯一の通信チャネル。エージェント非依存（Claude以外でも読める）。

HANDOFF.md構造: Goal / Completed work / Failed approaches / Key decisions / Current state / Resume instructions

**Assemble skillのWave実行パターン**:
1. PM（リーダー）がプロジェクトボードを生成 → 人間が承認
2. 依存関係に基づくWave単位で並列サブエージェントを実行
3. 各Wave完了時にチェックポイント → 人間が continue/adjust/stop 判断
4. 各チームはファイル成果物（`docs/research-notes.md` 等）を書き出し
5. PMは成果物を読んで次Waveのエージェントに渡す

**コンテキスト共有**: ファイル成果物そのもの。各エージェントは前段の成果物ファイルを入力として受取る

**代表例**: [willseltzer/claude-handoff](https://github.com/willseltzer/claude-handoff)、[Assemble skill](https://github.com/LakshmiSravyaVedantham/assemble)

---

## 横断分析

### コンテキスト共有の3層モデル

| 層 | メカニズム | 例 |
|----|----------|-----|
| 起動時注入 | Spawn prompt / 初期コンテキスト | タスク詳細、ファイルパス、受入基準 |
| 実行時同期 | 共有ファイル / Inbox / 状態ファイル | タスクJSON、Inbox JSON、HANDOFF.md |
| 成果物引継 | ドキュメント成果物の連鎖 | research-notes.md → implementation-plan.md |

### 専門エージェントの分業パターン

| カテゴリ | 具体ロール | 実装方式 |
|----------|----------|----------|
| 計画・調整 | PM / Orchestrator | Opusモデル + 委譲専用モード |
| 実装 | Frontend / Backend Developer | Sonnet + ファイル所有権制約 |
| 品質 | Reviewer（セキュリティ/パフォーマンス/テスト各観点） | 並列レビュー（同一PRを3視点で同時レビュー） |
| 調査 | Researcher / Explorer | Haiku（read-only） + Explore subagent |
| 検証 | Tester / QA | テスト戦略策定 + 実行 + カバレッジ検証 |

### FWレイヤーとの差分

| | FWレイヤー | Skills/Rulesレベル |
|-|----------|------------------|
| ランタイム | 独自ランタイム | Claude Code / Cursor自体がランタイム |
| 定義形式 | コード（Python/TS） | Markdown + YAML frontmatter |
| 協調メディア | メモリ / イベントバス / API | ファイルシステム（JSON/MD） |
| 専門化 | エージェントクラス定義 | SKILL.md + spawn prompt |
| 制約の強制 | コードレベルの型・バリデーション | Hooks（middleware相当） |
| 並列性 | FW側が管理 | tmux / iTerm2 / in-process |

### ポータビリティ（他者のSkillsをそのまま使えるか）

| 種類 | ポータビリティ | 例 |
|------|-------------|-----|
| プロセス系 | 高い | git操作、PR作成手順、コミット規約、test-fix-cycle |
| ドメイン知識系 | 中程度 | セキュリティレビューOWASP Top10、REST API設計規約 |
| プロジェクト固有系 | 低い | 特定アーキテクチャの実装パターン、独自ワークフロー |

---

## 長時間自律実行の実態

### 成功するタスクの共通条件

**機械的に検証可能な完了基準** が存在すること。

| 実例 | 規模 | 手法 |
|------|------|------|
| 9PRD分の審議基盤実装 | Python 3,455行、141テスト | 複数の一晩セッション、イテレーションごとにフレッシュコンテキスト |
| 認証モジュールリファクタ | 8ファイル1,200行、47イテレーション | テストカバレッジ62%→87%をゴールに |
| 88タスクバッチ処理 | 27時間連続 | TODOリスト + チェックボックス方式 |

### Ralph Loopパターン（長時間自律実行の標準手法）

- Stop Hookでエージェントの終了を傍受
- 完了基準（テスト全通過、lint clean、型チェック通過等）を判定
- 未達ならフレッシュコンテキストで再起動（前回の成果物はファイルシステムに永続化）
- コンテキストウィンドウ枯渇問題を「イテレーションごとにリセット」で回避

### 失敗パターン

- 30-60分でコンテキスト劣化、自分の過去の判断と矛盾
- テスト結果の捏造（嘘の通過報告）
- フレーキーテストで2状態を延々往復
- 目的ドリフト（勝手に機能追加）
- 予算制御なしで$200消費

### 自己修復ループ（fix-until-green）のオーケストレーション内位置づけ

タスク内のサブパターンであり、タスク間協調（オーケストレーション）とは別レイヤー:

```
[オーケストレーション層]
  └─ タスクA: 実装
  └─ タスクB: テスト → fix-loop  ← ここが自己修復ループ
  └─ タスクC: レビュー
```

オーケストレーターの「テスト・修正フェーズ」にプラグインとして組込み可能。

### 企業レベルの実態

| 企業 | 規模 | アーキテクチャ |
|------|------|-------------|
| AT&T | 日80億トークン、10万ユーザー | super agent + worker agents、コスト90%削減 |
| Dropbox | 55万ファイルインデックス、月100万行AI生成コード | Cursor Cloud Agents |
| NVIDIA | 3万開発者がCursor日次使用 | — |

最適ワーカー数は2-3。10+並列はオーバーヘッドが上回る。

---

## 設計洞察

### 自律性と事前コンテキスト量のトレードオフ

```
自律度         高い ← ──────────────── → 低い
事前コンテキスト 大量必要 ← ──────────────── → 少なくていい
対話タッチポイント 少ない（失敗時の手戻り大） ← → 多い（各回が軽い）
```

TAKT型 = 左端。全専門知識とプロダクト理解を事前に仕込んで自走。
Skills型 = 右寄り。必要な時に必要なスキルだけロードして人間が方向を決める。

### 自前ツールの位置づけ: 選択肢B

| 選択肢 | 何を作るか | 何を借りるか |
|--------|----------|-------------|
| A. ランタイムから自前 | プロセス管理・ツール呼出し・コンテキスト管理全部 | LLM APIだけ |
| **B. CLIランタイムは借りて協調層を自前** | **Skills定義・タスクグラフ・ハンドオフプロトコル・Hooks** | **Claude Code/Cursorのプロセス管理・ツール実行** |
| C. 全部借りる | 設定・プロンプトだけ | Agent Teams機能そのまま |

landscape/ の21ツール調査はAの世界。本調査はB〜Cの世界。自前ツールの方向はB — ランタイムは既存CLIに乗り、独自の価値は協調プロトコルとコンテキスト設計に集中。

### 不変のアトム

プラットフォーム（Claude Code / Cursor / Codex）は変わる。Skills frontmatterの仕様も変わる。Agent Teams APIも変更される可能性がある。

しかし **「構造化されたMarkdown/JSONでLLMを誘導する」というアトム** は変わらない。

- Skillsの実体 = Markdown
- Handoffの実体 = Markdown
- コンテキスト・エンベロープの実体 = 構造化ドキュメント
- タスク定義の実体 = 構造化ドキュメント

自前ツールの本質は **構造化ドキュメントのルーティングエンジン**。入力ドキュメント → 適切なエージェント（CLIプロセス）に渡す → 出力ドキュメントを受取る → 次のエージェントに渡す。その間のフォーマット・フロー・検証のプロトコル。

コード量は少ない。本質は設計。設計の対象はコードではなくドキュメントプロトコル。

---

## 参考リンク

- [Claude Code Agent Teams公式](https://docs.anthropic.com/en/docs/claude-code/agent-teams)
- [Claude Code Custom Subagents公式](https://docs.anthropic.com/en/docs/claude-code/subagents)
- [Swarm Orchestration Skill（Gist、Fork 87）](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)
- [Assemble Skill（チーム自動構成・Wave並列実行）](https://dev.to/lakshmisravyavedantham/i-built-a-claude-code-skill-that-assembles-ai-teams-and-runs-them-in-parallel-50ab)
- [claude-handoff（ドキュメント媒介型ハンドオフ）](https://github.com/willseltzer/claude-handoff)
- [autonomous-claude-agent-team（Hook駆動状態機械）](https://github.com/NTCoding/autonomous-claude-agent-team)
- [cursor-agent-team（単一会話マルチロール）](https://github.com/thiswind/cursor-agent-team)
- [claude-code-showcase（Skills/Hooks/Agents包括例）](https://github.com/ChrisWiles/claude-code-showcase)
- [Dotzlaw: Skills, Hooks, and Context Flow](https://www.dotzlaw.com/insights/claude-deterministic-agent-engineering/)
- [Markdown-as-Runtime（FW置換、140行Python）](https://dev.to/avansledright/i-replaced-my-agent-framework-with-markdown-files-and-140-lines-of-python-3323)
- [terraform-module-markdown-agent](https://github.com/AIOpsCrew/terraform-module-markdown-agent)
- [Ralph Loop: Autonomous Agent Architecture](https://blakecrosley.com/blog/ralph-agent-architecture)
- [Claude Code Ralph Wiggum Technique](https://claudefa.st/blog/guide/mechanics/ralph-wiggum-technique)
- [Episodic Execution for Overnight Agents](https://dev.to/thebasedcapital/why-your-overnight-ai-agent-fails-and-how-episodic-execution-fixes-it-2g50)
- [AT&T 8B tokens/day orchestration](https://venturebeat.com/orchestration/8-billion-tokens-a-day-forced-at-and-t-to-rethink-ai-orchestration-and-cut)
