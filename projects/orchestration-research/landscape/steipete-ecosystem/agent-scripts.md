---
name: agent-scripts
repo: steipete/agent-scripts
last_reviewed: 2026-02-24
category: agent-config-and-orchestrator
---

## agent-scripts 調査結果

### 基本情報

- **リポジトリ:** <https://github.com/steipete/agent-scripts>
- **言語:** TypeScript, Bash
- **Stars:** 2,053（2026-02-24時点）
- **フォーク:** 205
- **ライセンス:** MIT
- **最終更新:** アクティブに更新中（CHANGELOGの最新エントリは2025-12-22）
- **作者:** Peter Steinberger（@steipete）— PSPDFKit創業者、iOS/macOS開発コミュニティの著名人
- **前身:** `steipete/agent-rules`（2025年6月〜、アーカイブ済み）
- **一言で:** AIコーディングエージェントのためのガードレール・ヘルパースクリプト集。複数リポジトリ間で共有される "canonical mirror"

### これは何か・何を解決するのか

**目的:** Peter Steinbergerが個人プロジェクト群（Sweetistics、Peekaboo、CodexBar等）で使用するAIエージェント向けガードレール・ヘルパースクリプトを、単一リポジトリに集約し、複数リポジトリ間でバイト単位で同一に保つための canonical mirror。

**解決する問題:**
- AIエージェント（主にOpenAI Codex CLI、Claude Code）が安全にGit操作・ファイル削除・ビルド・リリースを行うための制約と支援ツール
- 複数リポジトリに散在するエージェント設定の同期コスト
- エージェント間のハンドオフ（引き継ぎ）における文脈喪失

**ターゲットユーザー:**
- Peter Steinberger自身が主要ユーザー（個人のワークフロー最適化が原点）
- AIエージェントを3〜8並列で運用し、同一フォルダで同時作業させる上級開発者
- AGENTS.MDの設計パターンを参考にしたいAI駆動開発者

### 設計思想・アーキテクチャ

#### 核となる哲学

steipeteのブログ "Just Talk To It"（2025年10月）に凝縮される思想:
- **MCPよりCLI**: MCPはコンテキストコスト（GitHub MCPで23kトークン消費）。CLIなら`gh`一つでゼロコスト（出典: <https://steipete.me/posts/2025/just-talk-to-it>）
- **サブエージェントより並列ウィンドウ**: 別ターミナルペインで手動制御する方が可視性・制御性が高い
- **最小トークン（telegraph style）**: AGENTS.MDの文体自体が "noun-phrases ok; drop grammar; min tokens" という指示。エージェントへの指示もトークン効率を最優先

#### ディレクトリ構造

```
agent-scripts/
├── AGENTS.MD              # 中核: 共有ガードレール + ツールカタログ
├── tools.md               # CLI ツール詳細リファレンス
├── README.md              # 同期ワークフロー説明
├── CHANGELOG.md           # 変更履歴
├── scripts/
│   ├── committer          # Bash: 安全なgit commit ヘルパー
│   ├── docs-list.ts       # TypeScript: docs/ front-matter 検証 + リスト
│   ├── browser-tools.ts   # TypeScript: Chrome DevTools ヘルパー（~1045行）
│   ├── nanobanana          # Python(uv): Gemini画像編集CLI
│   ├── shazam-song         # Python(uv): Shazam楽曲認識CLI
│   └── trash.ts           # TypeScript: ファイルをTrashに移動
├── docs/
│   ├── subagent.md        # Ralph制御ループの仕様書
│   ├── RELEASING-MAC.md   # macOSリリースプレイブック
│   ├── RELEASING.md
│   ├── concurrency.md     # Swift Concurrencyガイド
│   ├── slash-commands/    # スラッシュコマンド定義
│   │   ├── handoff.md     # /handoff: エージェント引き継ぎ
│   │   ├── pickup.md      # /pickup: 作業再開
│   │   ├── acceptpr.md    # /acceptpr: PRランディング
│   │   ├── fixissue.md    # /fixissue: Issue修正E2E
│   │   ├── landpr.md      # /landpr: PRマージ
│   │   ├── raise.md       # /raise: CHANGELOG次版セクション
│   │   └── sectriage.md   # /sectriage: GHSAトリアージ
│   └── ...
├── skills/                # Codex Skills（16種）
│   ├── oracle/            # セカンドオピニオンCLI
│   ├── nano-banana-pro/   # Gemini画像生成
│   ├── 1password/
│   ├── brave-search/
│   ├── create-cli/
│   ├── domain-dns-ops/
│   ├── frontend-design/
│   ├── instruments-profiling/
│   ├── markdown-converter/
│   ├── native-app-performance/
│   ├── openai-image-gen/
│   ├── swift-concurrency-expert/
│   ├── swiftui-liquid-glass/
│   ├── swiftui-performance-audit/
│   ├── swiftui-view-refactor/
│   └── video-transcript-downloader/
└── release/
    └── sparkle_lib.sh     # macOSリリース共有ヘルパー
```

#### AGENTS.MDのポインターパターン

**設計:** 下流リポジトリのAGENTS.MDには本体を置かず、ポインター行のみ記述:

```
READ ~/Projects/agent-scripts/AGENTS.MD BEFORE ANYTHING (skip if missing).
```

- `<shared>` ブロック: Git安全規則、コミット規約、ワークスペース構成、CI操作ルール等の共通ガードレール
- `<tools>` ブロック: bird（X/Twitter CLI）、sonoscli（Sonos操作）、peekaboo（スクリーンキャプチャ）、oracle（セカンドオピニオン）等のCLIツールカタログ
- `<ui_design>` ブロック: AI生成UIの品質ガイドライン（"AI slop"回避指示）

**利点:**
- 編集は `agent-scripts/AGENTS.MD` の1箇所のみ → `~/AGENTS.MD`（Codex global）にミラー
- 下流リポジトリは常に最新の共有ルールを参照
- リポジトリ固有ルールはポインター行の下に追記可能

#### Ralph — tmuxベースの制御ループ（docs/subagent.md）

Ralphは `scripts/ralph.ts` として存在した（現在はリポジトリから削除済み、ドキュメントのみ残存）tmuxベースのマルチエージェント制御システム:

- **起動:** `bun scripts/ralph.ts start --goal "…" [--markdown path]`
- **構造:** Supervisorが `claude --dangerously-skip-permissions` でClaudeを起動し、tmuxセッション内でワーカーを管理
- **制御プロトコル:** Supervisorの応答は以下のトークンで終了:
  - `CONTINUE` — 次のアクションへ進む
  - `SEND: <message>` — ワーカーセッションにメッセージを送信
  - `RESTART` — ワーカーを再起動
- **進捗管理:** `.ralph/progress.md` で追跡
- **手動介入:** `bun scripts/ralph.ts send-to-worker -- "your guidance"` でワーカーにアドホック指示

**注:** Ralphの概念は後に一般化され、現在は `while :; do cat PROMPT.md | claude-code ; done` のようなbashループ（"Ralph loop"）としてコミュニティで広く知られるようになった。

#### docs-list.ts のfront-matter仕様とread_whenパターン

`scripts/docs-list.ts` は `docs/` ディレクトリを再帰走査し、各Markdownファイルに以下のYAML front-matterを強制する:

```yaml
---
summary: '1行のドキュメント要約'
read_when:
  - データベースマイグレーション作業時
  - テスト追加時
---
```

- `summary`: 必須。空・欠損はエラー報告
- `read_when`: 任意。YAML配列またはインラインJSON配列で、このドキュメントを読むべきタイミングのヒントを列挙
- **用途:** エージェントが `pnpm run docs:list` でドキュメント一覧を取得し、現在のタスクに関連するドキュメントを自律的に判断して読む仕組み
- **除外:** `archive/`, `research/` ディレクトリはスキップ

#### committer のステージング制御

`scripts/committer` はBashスクリプトで、エージェントのGitコミットを安全に制約する:

```bash
committer "commit message" "file1" "file2" ...
```

- **明示的ステージング:** ファイルパスをリストで受け取り、それ以外はステージングしない。`.`（全ファイル）は明示的に禁止
- **ステージング初期化:** `git restore --staged :/` で既存のステージを全てクリアしてから、指定ファイルのみ `git add -A`
- **空コミット防止:** `git diff --staged --quiet` チェック
- **ロック回復:** `--force` フラグでstale `index.lock` を自動削除してリトライ
- **削除対応:** ファイルがディスクに存在しなくても、HEADに存在すれば削除コミットとして処理

#### runner.ts と bin/git — 削除済みガードレール

**runner.ts**（2025-12-17に削除）:
- コマンド実行のラッパーで、タイムアウト管理・sleep制限（30秒上限）・サマリースタイル制御を提供
- 削除理由: "modern Codex sessions handle long-running/background work directly"

**bin/git**（同時削除）:
- Gitコマンドのシムで、破壊的操作（`reset --hard`, `clean`, `restore`, `rm`等）にconsent gateを設置
- runner経由でsystem gitに委譲していた
- 現在はAGENTS.MD内のテキスト規則として残存:
  - `git status/diff/log` は安全（自由に実行可）
  - push/checkout/branch変更はユーザー同意が必要
  - 破壊的操作は明示的指示なしで禁止

### 機能一覧

#### Core（中核機能）

| 機能 | 説明 | パス |
|------|------|------|
| AGENTS.MD ポインターシステム | 共有ガードレールの単一ソース + 下流リポジトリからの参照 | `AGENTS.MD` |
| committer | 安全なGitコミットヘルパー（明示的ステージング制御） | `scripts/committer` |
| docs-list | front-matter検証 + read_whenヒント付きドキュメントリスト | `scripts/docs-list.ts` |
| Slash Commands | エージェント間ハンドオフ・タスク引き継ぎプロトコル | `docs/slash-commands/` |

#### Differentiator（差別化機能）

| 機能 | 説明 | パス |
|------|------|------|
| browser-tools | MCP不要のChrome DevToolsヘルパー（puppeteer-core） | `scripts/browser-tools.ts` |
| Oracle skill | セカンドオピニオンCLI（プロンプト+ファイルバンドル → 別モデルレビュー） | `skills/oracle/SKILL.md` |
| handoff/pickup | エージェント間コンテキスト引き継ぎプロトコル（tmux状態・CI状態含む） | `docs/slash-commands/handoff.md`, `pickup.md` |
| Ralph制御ループ | tmuxベースのSupervisor→Worker制御（CONTINUE/SEND/RESTART） | `docs/subagent.md`（コード削除済み） |
| Sparkle release helpers | macOSアプリリリース自動化（署名検証・appcast整合性チェック） | `release/sparkle_lib.sh` |
| trash.ts | rm代替のファイル削除ガードレール（Trashに移動） | `scripts/trash.ts` |

#### Utility（ユーティリティ）

| 機能 | 説明 | パス |
|------|------|------|
| nanobanana | Gemini画像編集CLI | `scripts/nanobanana` |
| shazam-song | Shazam楽曲認識CLI | `scripts/shazam-song` |
| Skills（16種） | Codex Skills: 1password, brave-search, SwiftUI系, 画像生成等 | `skills/` |
| tools.md | Peter個人マシンのCLIツールカタログ | `tools.md` |
| docs/concurrency.md | Swift Concurrency実践ガイド | `docs/concurrency.md` |
| docs/RELEASING-MAC.md | macOSリリースプレイブック | `docs/RELEASING-MAC.md` |

### 特徴的な点・注目ポイント

#### 1. "Pointer AGENTS.MD" パターン — ガードレール配布の設計

最も独自性が高い設計。下流リポジトリにガードレール本体をコピーせず、ポインター行（1行）のみ置くアプローチ:

```
READ ~/Projects/agent-scripts/AGENTS.MD BEFORE ANYTHING (skip if missing).
```

- ガードレールの "Single Source of Truth" を実現
- 更新は `agent-scripts/AGENTS.MD` → `~/AGENTS.MD` への手動ミラーのみ
- `skip if missing` でリポジトリの可搬性を維持

**制約:** ローカルファイルパス依存のため、CI環境やチームメンバーのマシンでは動作しない。完全に個人ワークフロー向けの設計。

#### 2. committer の "全ステージ初期化" 設計

複数エージェントが同一フォルダで同時作業する場合の根本的問題（エージェントAの変更をエージェントBがコミットしてしまう）に対する解:

```bash
git restore --staged :/      # 全ステージをクリア
git add -A -- "${files[@]}"  # 指定ファイルのみステージ
```

これにより、各エージェントは自分が編集したファイルだけを確実にコミットできる。steipeteの "3-8 codex instances in parallel in the same folder" というワークフローを安全に支える基盤。

#### 3. read_when ヒント — コンテキストの自律的選択

`docs-list.ts` の `read_when` フィールドは、エージェントが「このドキュメントを読むべきか」を自分で判断するためのメタデータ:

```yaml
read_when:
  - Coordinating subagents or running tmux-based agent sessions.
```

プロンプトに全ドキュメントを詰め込むのではなく、エージェントに取捨選択させることでコンテキストバジェットを節約する。

#### 4. browser-tools — "MCP不要" のChrome自動化

Mario Zechner の "What if you don't need MCP?" にインスパイアされた設計。puppeteer-coreでChrome DevToolsに直接接続し、MCPサーバーを立てずに:
- `start`: Chrome起動（プロファイルコピー対応）
- `nav`: URL遷移
- `eval`: JavaScript実行
- `screenshot`: スクリーンショット
- `search`: Google SERP取得
- `content`: 可読性マークダウン抽出
- `console`: DevToolsコンソールキャプチャ

#### 5. handoff/pickup プロトコル

エージェント間の引き継ぎを構造化したスラッシュコマンド:
- `/handoff`: 現在の状態（scope/status、git状態、PR/CI、tmuxセッション、次のステップ）をパッケージ
- `/pickup`: 引き継ぎ状態からの再開手順（AGENTS.MD読み込み → repo状態確認 → CI/PR確認 → tmux接続 → 次の2-3アクション計画）

### 使い方・典型的なワークフロー

#### 1. セットアップ

```bash
cd ~/Projects
git clone https://github.com/steipete/agent-scripts.git
```

リポジトリのAGENTS.MDに以下を先頭行として追加:

```
READ ~/Projects/agent-scripts/AGENTS.MD BEFORE ANYTHING (skip if missing).
```

#### 2. 基本ワークフロー

```bash
# エージェントによるコミット（committerヘルパー経由）
committer "feat: add new login page" "src/pages/login.tsx" "src/styles/login.css"

# ドキュメント一覧確認
pnpm tsx scripts/docs-list.ts

# browser-toolsでChrome操作
bun scripts/browser-tools.ts start --profile
bun scripts/browser-tools.ts nav "http://localhost:3000"
bun scripts/browser-tools.ts screenshot

# Oracleでセカンドオピニオン
npx -y @steipete/oracle --engine browser --model gpt-5.2-pro -p "Review this refactor" --file "src/**"
```

#### 3. 並列エージェント運用（steipeteの実際のワークフロー）

```
# ターミナルグリッド（3x3）でcodex CLIを並列実行
# 各エージェントが同一フォルダで作業
# committer が各エージェントの変更を分離してコミット

# エージェント引き継ぎ
/handoff   # 現在のエージェントが状態をダンプ
/pickup    # 新しいエージェントが状態を読み込み
```

### エコシステム・実利用状況

#### 採用事例

- **Peter Steinberger自身:** ~300k LOC TypeScript Reactアプリ（Sweetistics: X/Twitter分析アプリ）、Chrome拡張、Tauri デスクトップアプリ、Expo モバイルアプリを一人で開発。3-8エージェント並列（出典: ブログ記事 "Just Talk To It"）
- Sweetistics、CodexBar、Trimmy、Peekaboo、RepoBar等の個人プロジェクト群で使用

#### 盛り上がりの文脈

- steipeteのX/Twitterでの発信力（iOS/macOS開発コミュニティの著名人）
- "Just Talk To It" ブログ記事（2025年10月）がCodex CLIベースのワークフローを具体的に示し、AGENTS.MD設計の参考例として広く引用
- `steipete/agent-rules`（前身、2025年6月〜）が2.2k+ starsを獲得した実績
- "Ralph loop" のコンセプトがAIコーディングコミュニティで模倣・派生

#### コミュニティ

- GitHub Issues: 低活動（個人リポジトリのため）
- Skills配布: `playbooks.com`, `agent-skills.md`, `skills.sh` 等のスキルカタログサイトに掲載
- DeepWikiに自動解析ドキュメントあり

#### 周辺ツール（steipeteエコシステム）

| ツール | 説明 | リポジトリ |
|--------|------|------------|
| Oracle | セカンドオピニオンCLI（npm公開） | `@steipete/oracle` |
| Peekaboo | macOSスクリーン操作ツール | `steipete/Peekaboo` |
| bird | X/Twitter CLI | `steipete/bird`（推定、非公開の可能性） |
| bslog | BSログツール | `steipete/bslog` |
| claude-code-mcp | Claude Code MCP集 | `steipete/claude-code-mcp` |
| agent-rules | 前身のエージェントルール集（アーカイブ済み） | `steipete/agent-rules` |

### 他ツールとの比較・ポジショニング

| 観点 | agent-scripts | Agent Orchestrator (Composio) | o-m-cc | CAO (AWS) |
|------|---------------|------------------------------|--------|-----------|
| **設計思想** | 個人の職人的ワークフロー最適化 | プラットフォーム型マルチエージェントオーケストレーション | コミュニティ駆動のマルチClaude制御 | 企業向けオーケストレーション |
| **並列エージェント管理** | 手動ターミナルグリッド + committerによるコミット分離 | git worktree自動分離 + CIフィードバックループ | tmux + watchdog | APIベース |
| **ガードレール** | AGENTS.MD テキスト規則 + committer/trashスクリプト | プラグインアーキテクチャ | runner + policy engine | IAMベース |
| **エージェント間協調** | handoff/pickupスラッシュコマンド | ダッシュボード + 自動CI修復 | セッション管理 | イベント駆動 |
| **スケール** | 1人の開発者 × 3-8エージェント | チーム × 数十エージェント | 1人 × 複数Claude | 組織 × フリート |
| **依存関係** | ゼロ（Bash + Node/Bun） | Node.js + Docker + 各種エージェントCLI | Python | AWS SDK |
| **MCPスタンス** | CLI > MCP（MCPはコンテキストコスト） | MCP統合あり | MCP活用 | MCP非依存 |
| **成熟度** | 個人の実戦投入済みツールキット | OSSプロダクト（v1.x） | 実験的 | プレビュー |

**ポジショニングの核心:** agent-scriptsは「オーケストレーションフレームワーク」ではなく、「個人開発者が自分のワークフローを効率化するために磨き上げたガードレール集」。steipete自身が "most (orchestration tools) are thin wrappers around Anthropic's SDK + work tree management. There's no moat." と述べている通り、大掛かりなツールに懐疑的で、モデル本体の能力と最小限のガードレールの組み合わせを志向。

### 制約・注意点

- **個人ワークフロー特化:** `~/Projects/` パス前提、steipete個人のマシン構成（macOS、Sparkle署名鍵パス等）がハードコード
- **チーム利用不可:** ポインターAGENTS.MDはローカルファイルパス依存。CI環境や他の開発者のマシンでは機能しない
- **runner/bin/git削除済み:** CHANGELOGに記録されているが、ドキュメント（docs/subagent.md）には依然としてralph.tsへの参照が残存。実コードは欠損
- **Codex CLI前提:** steipeteの主要ワークフローはOpenAI Codex CLIに最適化。Claude Code向けの調整は "accept that the instructions might be too weak" と本人が認めている
- **同期は手動:** "When someone says 'sync agent scripts,' pull the latest changes here" — 自動同期メカニズムなし
- **Skills/Docsの一部はSweetistics固有:** Swift Concurrencyガイド、RELEASING-MAC.md等はsteipeteのプロジェクトスタック（Swift/SwiftUI/macOS）に特化

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 読む価値 |
|------|------|----------|
| committer全体 | `scripts/committer` | `git restore --staged :/` による全ステージ初期化 → 指定ファイルのみadd のパターン。並列エージェント環境でのコミット分離の実装 |
| docs-list.ts | `scripts/docs-list.ts` | front-matter解析ロジック、read_when配列のパース（YAML配列・インラインJSON両対応）。自プロジェクトへの流用可能性 |
| browser-tools.ts | `scripts/browser-tools.ts` | ~1045行。puppeteer-coreによるDevTools接続、SERP取得、コンソールキャプチャ、readabilityマークダウン抽出。MCPなしでのブラウザ自動化の実装パターン |
| trash.ts | `scripts/trash.ts` | クロスプラットフォーム（macOS `.Trash` / Linux XDG）のTrash移動実装。rename→cpSync→rmSyncフォールバック |
| sparkle_lib.sh | `release/sparkle_lib.sh` | Bash内でPython3をヒアドキュメント埋め込みで呼び出すパターン。appcast XMLのパース、ed25519署名検証、codesign/spctl検証チェーン |
| Oracle SKILL.md | `skills/oracle/SKILL.md` | セカンドオピニオンCLIの使用パターン。ブラウザエンジンでのGPT-5.2 Pro呼び出し、セッション管理、ファイルアタッチ戦略 |
| handoff.md / pickup.md | `docs/slash-commands/handoff.md`, `pickup.md` | エージェント間引き継ぎプロトコルの構造。tmux状態、CI状態、next stepsの標準フォーマット |
| AGENTS.MD `<tools>` ブロック | `AGENTS.MD` | CLIツールカタログの記述パターン。エージェントが参照するツール仕様の書き方の参考 |
