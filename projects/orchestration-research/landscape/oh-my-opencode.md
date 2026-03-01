---
name: oh-my-opencode
repo: code-yeongyu/oh-my-opencode
last_reviewed: 2026-03-01
category: orchestrator
---

## oh-my-opencode 調査結果

### 基本情報
- **リポジトリ:** [code-yeongyu/oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- **言語:** TypeScript 99.3%（1,161ファイル、133k行）
- **Stars:** 35,626 / Forks: 2,700 / コントリビューター: 140名
- **最終更新:** 2026-02-26（v3.9.0）
- **ライセンス:** SUL-1.0（Sustainable Use License — 商用利用制限あり、後述）
- **依存先:** [OpenCode](https://github.com/opencode-ai/opencode)（60k+ stars、オープンソースAIコーディングCLI）のプラグインとして動作
- **一言で:** OpenCode向けマルチモデル・マルチエージェントオーケストレーションプラグイン。「`ultrawork`と打てば全部やる」がコンセプト

### これは何か・何を解決するのか

oh-my-opencode（通称OmO）は、オープンソースのAIコーディングツール[OpenCode](https://opencode.ai/)のプラグインで、単一エージェント・単一モデルの制約を打破するマルチエージェントオーケストレーション基盤を提供する。

**解決する課題:**

1. **単一モデルの限界:** Claude Code等は1モデルが全タスクを担当。OmOはタスクの性質（フロントエンド、深い推論、軽微修正等）に応じて最適なモデルを自動ルーティングする
2. **エージェントの途中放棄:** AIエージェントがタスクを途中で停止する問題を、Todo Enforcer・Ralph Loopなどの「規律メカニズム」で解決
3. **editツールの脆弱性:** 既存のedit toolは行番号が変わると壊れる。コンテンツハッシュ付き`LINE#ID`方式で安定編集を実現（[The Harness Problem](https://blog.can.ac/2026/02/12/the-harness-problem/)に基づく）
4. **ベンダーロックイン:** Claude / GPT / Gemini / Kimi / GLMなど複数プロバイダを横断利用し、特定ベンダーへの依存を回避
5. **設定疲労:** 「Install. Type `ultrawork`. Done.」を標語に、最小設定で強力なオーケストレーションを提供

**ターゲットユーザー:** AIコーディングツールのパワーユーザー。特にClaude Codeの単一モデル制約やCursorのサブスクリプションコストに不満を感じているユーザー。

### 設計思想・アーキテクチャ

#### プラグインアーキテクチャ

OmOはOpenCodeのプラグインAPIを通じて動作する。エントリポイント（`src/index.ts`）でOpenCodeの`Plugin`インターフェースを実装し、以下を注入する:

```
OpenCode Plugin API
    ↓
OhMyOpenCodePlugin (src/index.ts)
    ├── createManagers()   → バックグラウンドエージェント、設定、tmux管理
    ├── createTools()      → 26種のカスタムツール
    ├── createHooks()      → 44種のライフサイクルフック
    └── createPluginInterface() → chat.params, chat.message, event, tool.execute.before/after
```

主なプラグインフック:
- `chat.params` — モデルパラメータの動的調整（effort level等）
- `chat.message` — キーワード検出（`ultrawork`等）、モード切替
- `tool.execute.before/after` — ツール実行のインターセプト（ハッシュライン注入、ファイルガード等）
- `event` — セッションライフサイクル管理（リカバリ、フォールバック、通知）
- `experimental.chat.system.transform` — システムプロンプトの動的変換

#### マルチエージェントオーケストレーション構造

```
User Request
    ↓
[Intent Gate] — ユーザーの真意を分類（research / implementation / investigation / fix）
    ↓
[Sisyphus] — メインオーケストレーター（Claude Opus 4.6 / Kimi K2.5 / GLM 5）
    ↓
    ├─→ [Prometheus]  — 戦略プランナー（インタビューモード）
    │     ├─→ [Metis]   — ギャップ分析（プラン作成前の見落としチェック）
    │     └─→ [Momus]   — プランレビュー（品質ゲート）
    ├─→ [Atlas]       — 実行コンダクター（プランに基づくタスク配分）
    │     └─→ [Sisyphus-Junior] — カテゴリベースの実行者（モデルは自動選択）
    ├─→ [Hephaestus]  — 自律型ディープワーカー（GPT-5.3 Codex）
    ├─→ [Oracle]      — アーキテクチャコンサルタント（読み取り専用）
    ├─→ [Librarian]   — ドキュメント・OSS検索
    ├─→ [Explore]     — 高速codebase grep
    └─→ [Multimodal-Looker] — 画像・PDF解析
```

**3層アーキテクチャ:**
1. **計画層（Planning）:** Prometheus → Metis → Momus のパイプライン。インタビュー → ギャップ分析 → 品質レビュー → `.sisyphus/plans/*.md`にプラン出力
2. **指揮層（Execution）:** Atlas がプランを読み込み、タスクを専門エージェントに配分。Wisdom Accumulation（学習蓄積）で後続タスクに知見を伝搬
3. **実行層（Workers）:** Sisyphus-Juniorが実コード変更を担当。カテゴリシステムで自動モデル選択

#### カテゴリシステム（モデルルーティング）

エージェントがタスクを委任する際、モデル名ではなく「カテゴリ」を指定。カテゴリが最適なモデルに自動マッピングされる:

| カテゴリ | デフォルトモデル | 用途 |
|----------|-----------------|------|
| `visual-engineering` | Gemini 3 Pro | フロントエンド、UI/UX |
| `ultrabrain` | GPT-5.3 Codex (xhigh) | 深い論理推論、アーキテクチャ判断 |
| `deep` | GPT-5.3 Codex (medium) | 自律的問題解決 |
| `quick` | Claude Haiku 4.5 | 単純修正、タイポ |
| `writing` | Kimi K2P5 | ドキュメント、散文 |
| `artistry` | Gemini 3 Pro (max) | 創造的タスク |

#### Hooks設計

44個のフックが5つのイベントタイプに分類:

| イベント | タイミング | 機能 |
|----------|-----------|------|
| `PreToolUse` | ツール実行前 | ブロック、入力修正、コンテキスト注入 |
| `PostToolUse` | ツール実行後 | 警告追加、出力修正 |
| `Message` | メッセージ処理中 | キーワード検出、モード切替 |
| `Event` | セッションライフサイクル | リカバリ、フォールバック |
| `Transform` | コンテキスト変換 | システムプロンプト注入 |
| `Params` | APIパラメータ設定 | モデル設定調整 |

各フックは個別に無効化可能（`disabled_hooks`配列）。

#### Claude Code互換性

Claude Codeのエコシステムとの完全互換レイヤーを提供:
- **Hooks:** `~/.claude/settings.json`のフック定義をそのまま実行（`claude-code-hooks`フック）
- **Commands:** `.claude/commands/*.md`を読み込み
- **Skills:** `.claude/skills/*/SKILL.md`を読み込み
- **Agents:** `.claude/agents/*.md`を読み込み
- **MCPs:** `.mcp.json`、`.claude/.mcp.json`を読み込み
- **Plugins:** Claude Codeマーケットプレイスのプラグインを読み込み

`src/features/`配下に専用ローダーが存在:
- `claude-code-agent-loader/`
- `claude-code-command-loader/`
- `claude-code-mcp-loader/`
- `claude-code-plugin-loader/`
- `claude-code-session-state/`

#### ベンダーロックイン回避の設計

- **プロバイダフォールバックチェーン:** 各エージェントに優先順位付きのモデルチェーンを定義。主モデルが不可用でも自動切替（`runtime-fallback`フック + `model-fallback`フック）
- **カテゴリの抽象化:** タスク委任時にモデル名を直接指定しない → プロバイダ変更時にコード変更不要
- **OpenCode基盤:** OpenCode自体が75+プロバイダ対応のオープンソースCLI

### 機能一覧

#### Core（中核機能）

| 機能 | 説明 | コード位置 |
|------|------|-----------|
| **Sisyphusオーケストレーター** | メインの計画・委任・実行エージェント。Todo駆動ワークフロー、32kトークンのextended thinking | `src/agents/sisyphus.ts` |
| **カテゴリベース委任** | タスクの意図に基づくモデル自動選択。8つの組み込みカテゴリ | `src/tools/delegate-task/` |
| **Intent Gate** | ユーザーの真意を分類してから行動。リテラルな誤解を防止 | `src/hooks/keyword-detector/` |
| **Hash-Anchored Edit（Hashline）** | `LINE#ID`コンテンツハッシュで編集の整合性を検証。stale-line errorゼロ | `src/tools/hashline-edit/` |
| **バックグラウンドエージェント** | 5+の専門エージェントを並列実行。コンテキストを汚さず結果を取得 | `src/features/background-agent/`, `src/tools/background-task/` |
| **44ライフサイクルフック** | エージェントの動作をあらゆるポイントでインターセプト・修正 | `src/hooks/` (40+サブディレクトリ) |
| **プロバイダフォールバック** | APIエラー（429, 503等）時の自動モデル切替、クールダウン制御 | `src/hooks/runtime-fallback/`, `src/hooks/model-fallback/` |

#### Differentiator（差別化機能）

| 機能 | 説明 | コード位置 |
|------|------|-----------|
| **Prometheus計画システム** | インタビューモード → Metisギャップ分析 → Momusレビュー → `.sisyphus/plans/`出力 | `src/agents/prometheus/`, `src/agents/metis.ts`, `src/agents/momus.ts` |
| **Atlas実行コンダクター** | プランの体系的実行、Wisdom Accumulation、Notepadシステム | `src/agents/atlas/`, `src/hooks/atlas/` |
| **Hephaestus自律ワーカー** | GPT-5.3 Codex専用の自律型ディープワーカー。AmpCodeのdeep modeに触発 | `src/agents/hephaestus.ts` |
| **Ralph Loop** | 自己参照的開発ループ。タスク完了まで自動継続（最大100イテレーション） | `src/hooks/ralph-loop/`, `src/features/builtin-commands/` |
| **Todo Enforcer** | エージェントがアイドル化したらシステムリマインダーで作業に引き戻す | `src/hooks/todo-continuation-enforcer/` |
| **Skill-Embedded MCPs** | スキルが自前のMCPサーバーを持ち込み、タスク完了後に破棄。コンテキスト肥大化を防止 | `src/features/skill-mcp-manager/`, `src/tools/skill-mcp/` |
| **LSP統合** | `lsp_rename`, `lsp_goto_definition`, `lsp_find_references`, `lsp_diagnostics`。IDE精度の操作をエージェントに提供 | `src/tools/lsp/` |
| **AST-Grep** | 25言語対応のAST-aware検索・置換 | `src/tools/ast-grep/` |
| **`/init-deep`** | プロジェクト全体に階層的`AGENTS.md`を自動生成。エージェントが自動的にコンテキストを取得 | `src/features/builtin-commands/` |
| **Claude Code完全互換** | Hooks, Commands, Skills, MCPs, Pluginsの全てが互換 | `src/features/claude-code-*-loader/` |
| **Tmux統合** | バックグラウンドエージェントをtmuxペインでリアルタイム可視化 | `src/features/tmux-subagent/` |
| **MCP OAuth 2.1** | スキルMCPのOAuth認証（RFC 9728, 8414, 8707, 7591準拠、PKCE必須） | `src/features/mcp-oauth/` |
| **Task依存システム** | `blockedBy`/`blocks`による依存関係管理、並列実行最適化 | `src/features/claude-tasks/` |

#### Utility（ユーティリティ）

| 機能 | 説明 | コード位置 |
|------|------|-----------|
| **Comment Checker** | AIが生成する冗長コメントを検出・警告 | `src/hooks/comment-checker/` |
| **Think Mode** | 「think deeply」「ultrathink」を検出しextended thinkingを自動有効化 | `src/hooks/think-mode/` |
| **セッションツール** | セッション一覧、読み取り、検索、統計 | `src/tools/session-manager/` |
| **Tool Output Truncator** | コンテキストウィンドウに応じたツール出力の動的切り詰め | `src/hooks/tool-output-truncator/` |
| **Preemptive Compaction** | トークン制限到達前の先制的セッション圧縮 | `src/hooks/preemptive-compaction.ts` |
| **Edit Error Recovery** | editツール失敗からの自動リカバリ | `src/hooks/edit-error-recovery/` |
| **Session Recovery** | セッションエラー（ツール結果欠損、空メッセージ等）からの回復 | `src/hooks/session-recovery/` |
| **Auto-Update Checker** | 新バージョン通知 | `src/hooks/auto-update-checker/` |
| **OS Notification** | エージェントのアイドル時にOS通知（macOS/Linux/Windows） | `src/hooks/session-notification.ts` |
| **`/handoff`** | セッション引き継ぎ用の構造化コンテキストサマリー生成 | `src/features/builtin-commands/` |
| **look_at** | PDF・画像をMultimodal-Lookerエージェント経由で分析 | `src/tools/look-at/` |
| **interactive_bash** | tmuxベースの対話型ターミナル（vim, htop等のTUIアプリ対応） | `src/tools/interactive-bash/` |

#### 組み込みMCPサーバー

| MCP | 説明 |
|-----|------|
| **websearch (Exa)** | リアルタイムWeb検索 |
| **context7** | 任意のライブラリ/フレームワークの公式ドキュメント検索 |
| **grep_app** | 公開GitHubリポジトリ横断のコード検索 |

#### 組み込みスキル

| スキル | トリガー | 機能 |
|--------|---------|------|
| **git-master** | commit, rebase, squash等 | アトミックコミット、リベース手術、履歴考古学。直近30コミットからスタイル自動検出 |
| **playwright** | ブラウザ操作 | Playwright MCPによるブラウザ自動化 |
| **frontend-ui-ux** | UI/UXタスク | デザイナー視点のUI構築（ボールドな美的方向性、独自タイポグラフィ） |

### 特徴的な点・注目ポイント

#### 1. Hash-Anchored Edit（Hashline）— editツールの革新

[The Harness Problem](https://blog.can.ac/2026/02/12/the-harness-problem/)（[oh-my-pi](https://github.com/can1357/oh-my-pi)着想）を解決する中核技術。ファイル読み取り時に各行にコンテンツハッシュを付与:

```
11#VK| function hello() {
22#XJ|   return "world";
33#MB| }
```

エージェントはこのハッシュタグを参照して編集を指定。ファイルが変更されていたらハッシュ不一致で即リジェクト。結果: Grok Code Fast 1のedit成功率が **6.7% → 68.3%** に向上。

コード: `src/tools/hashline-edit/`, `src/hooks/hashline-read-enhancer/`, `src/hooks/hashline-edit-diff-enhancer/`

#### 2. Wisdom Accumulation — 累積学習メカニズム

Atlasがタスク完了後に学習を抽出・分類し、後続全タスクに伝搬:

```
.sisyphus/notepads/{plan-name}/
├── learnings.md      # パターン、規約、成功アプローチ
├── decisions.md      # アーキテクチャ判断と根拠
├── issues.md         # 問題、ブロッカー、注意点
├── verification.md   # テスト結果、検証成果
└── problems.md       # 未解決問題、技術的負債
```

タスク1で発見した規約がタスク5に自動的に反映される。ミスの繰り返しを防止。

#### 3. カテゴリ + スキルのコンボ戦略

カテゴリ（モデル選択）とスキル（知識+ツール注入）を組み合わせることで、特化型エージェントをオンデマンド生成:

- **The Designer:** `visual-engineering` + `["frontend-ui-ux", "playwright"]` → UIを実装し、ブラウザで描画結果を検証
- **The Architect:** `ultrabrain` + `[]` → GPT-5.3 Codexの論理推論をフル活用した設計分析
- **The Maintainer:** `quick` + `["git-master"]` → 低コストモデルで高速修正 + クリーンなコミット

#### 4. 「規律」の設計思想

プロジェクト名のSisyphus（シーシュポス）が象徴するように、「止まらない・怠けない・最後までやる」を設計原則としている:
- **Todo Enforcer:** エージェントが応答しようとした時に未完了todoがあれば、システムリマインダーで引き戻す
- **Ralph Loop:** 完了（`DONE`検出）まで自動的にループ継続（最大100イテレーション）
- **Boulder State:** `.sisyphus/boulder.json`でセッション間の作業状態を永続化。セッション再開時に中断箇所から継続

### 使い方・典型的なワークフロー

#### インストール

```shell
# LLMエージェントに貼り付ける（推奨）
curl -s https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/refs/heads/dev/docs/guide/installation.md
```

OpenCodeの設定ファイル（`~/.config/opencode/opencode.json`）の`plugin`配列に`"oh-my-opencode"`を追加。

#### ワークフロー1: ultrawork（最も簡単）

```
> ultrawork fix the failing tests
```

Sisyphusが自動的に全てを処理: コードベース探索 → パターン研究 → 実装 → 診断検証 → 完了まで継続。

#### ワークフロー2: Prometheus計画 → Atlas実行（精密モード）

```
# 1. Tabキーで Prometheus エージェントに切替、または:
> @plan "認証システムをリファクタリングしたい"

# 2. Prometheusがインタビュー形式で質問
# 3. 回答を繰り返し、プランが .sisyphus/plans/ に生成

# 4. 実行開始
> /start-work

# 5. Atlasがプランに基づきタスクを専門エージェントに配分・実行
# 6. セッションが途切れても /start-work で中断箇所から再開
```

#### ワークフロー3: Hephaestus（ディープワーク）

```
# Tabキーで Hephaestus エージェントに切替
> Design a new plugin system for extensibility
```

GPT-5.3 Codex駆動の自律型ワーカーが、コードベースを探索し、パターンを研究し、end-to-endで実行。

#### 設定例

```jsonc
// .opencode/oh-my-opencode.jsonc
{
  "$schema": "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/dev/assets/oh-my-opencode.schema.json",
  "agents": {
    "sisyphus": { "model": "kimi-for-coding/k2p5" },
    "oracle": { "model": "openai/gpt-5.2", "variant": "high" }
  },
  "categories": {
    "visual-engineering": { "model": "google/gemini-3-pro" },
    "quick": { "model": "anthropic/claude-haiku-4-5" }
  },
  "disabled_hooks": ["auto-update-checker"]
}
```

#### 推奨サブスクリプション構成（作者推奨）

| サービス | 月額 | 用途 |
|---------|------|------|
| ChatGPT | $20 | GPTモデル（Hephaestus, Oracle等） |
| Kimi Code | $0.99 | Kimi K2.5（Sisyphusオーケストレーション） |
| GLM Coding Plan | $10 | GLM 5（汎用タスク） |

### エコシステム・実利用状況

#### 採用事例

- **[Indent](https://indentcorp.com):** インフルエンサーマーケティング、越境EC、AIコマースレビューソリューション開発に使用
- **Google, Microsoft:** READMEに「Loved by professionals at」として記載（個人利用の可能性が高い。企業公式採用かは不明）
- **[ELESTYLE](https://elestyle.jp):** マルチモバイル決済ゲートウェイ・キャッシュレスSaaS開発
- **個人ユーザー:** 8,000 ESLint警告を1日で修正、45k行のTauriアプリをSaaS Webアプリに一晩で変換等の報告あり（[ソース](https://x.com/jacobferrari_/status/2003258761952289061)、[ソース](https://x.com/hargabyte/status/2007299688261882202)）

#### 盛り上がりの文脈

- **AnthropicによるOpenCodeブロック事件:** AnthropicがOmOの存在を理由にOpenCodeのAPI利用を制限。これが話題を呼び、「We don't do lock-in here」のメッセージと共にプロジェクトの知名度が急上昇（[ソース](https://x.com/thdxr/status/2010149530486911014)）
- **OpenCodeの急成長:** OpenCode自体が1年足らずで60k+ starsに到達し、OpenAI・GitHub公式パートナーシップを獲得。その最大のプラグインとしてOmOも成長
- **マルチモデル時代の到来:** Kimi K2.5、GLM 5等の安価で高品質なモデルが登場し、マルチモデルオーケストレーションの実用性が向上

#### コミュニティ

- **Discord:** 活発なコミュニティ（[招待リンク](https://discord.gg/PUwSMR9XNk)）
- **GitHub Issues:** 2,100+（活発）。バグ報告、機能要望、設定相談が日常的に投稿
- **多言語対応:** README は英語、韓国語、日本語、ロシア語、簡体字中国語に翻訳済み
- **X（旧Twitter）:** 作者のアカウント停止後、[@justsisyphus](https://x.com/justsisyphus)が更新を配信

#### 周辺ツール

- **[sisyphuslabs.ai](https://sisyphuslabs.ai):** Sisyphusエージェントの商用版を開発中（ウェイトリスト受付中）
- **agent-browser（Vercel）:** Playwright MCP代替のブラウザ自動化エンジン
- **ohmyopencode.com:** **警告: 公式ではない。** プロジェクトは明確に非関連を表明。ペイウォール付きサイトで、配布物の安全性は未検証

#### 評判

**肯定的:**
- 「Cursorのサブスクリプションをキャンセルした」（[Arthur Guiot](https://x.com/arthur_guiot/status/2008736347092382053)）
- 「Claude Codeが7日でやることをSisyphusは1時間でやる」— クオンツリサーチャー
- 「開発体験が完全に別次元に到達した」（[苔硯:こけすずり](https://x.com/kokesuzuri/status/2008532913961529372)）
- 「Anthropicはこれを本体に取り込むべき」— Henning Kilset

**否定的/課題:**
- サブエージェントのプロンプトが24kトークンを超え、ローカルモデル（16kコンテキスト等）で破綻する（[Issue #951](https://github.com/code-yeongyu/oh-my-opencode/issues/951)）
- ハードコードされた`anthropic/`プロバイダデフォルトにより、Anthropicを使わない設定でエラーが発生（[Issue #946](https://github.com/code-yeongyu/oh-my-opencode/issues/946)）
- バックグラウンドエージェントが出力なしで即座に完了するレースコンディション（[Issue #480](https://github.com/code-yeongyu/oh-my-opencode/issues/480)）
- `call_omo_agent`のUnauthorizedエラー（[Issue #786](https://github.com/code-yeongyu/oh-my-opencode/issues/786)）

### 他ツールとの比較・ポジショニング

#### vs oh-my-claudecode（Yeachan-Heo）

| 項目 | oh-my-opencode | oh-my-claudecode |
|------|---------------|-----------------|
| **Stars** | 35,626 | 5,886 |
| **対象プラットフォーム** | OpenCode（オープンソースCLI） | Claude Code（Anthropic製） |
| **モデル対応** | マルチベンダー（75+プロバイダ） | Claude中心（一部Codex/Gemini対応） |
| **エージェント数** | 11 | 30+ |
| **主要コンセプト** | 規律（Discipline）+ マルチモデル | チーム（Teams-first）+ 並列化 |
| **ライセンス** | SUL-1.0（商用制限あり） | MIT |
| **editツール** | Hash-Anchored（LINE#ID） | 標準 |
| **差別化** | ベンダーロックイン回避、カテゴリシステム | 自然言語インターフェース、ゼロ設定 |

**関係性:** 両プロジェクトは独立。oh-my-opencodeはOpenCode専用、oh-my-claudecodeはClaude Code専用。概念的類似性（Sisyphusエージェント等）はあるが、コードベースは別物。

#### vs oh-my-claude-code（zephyrpersonal）/ o-m-cc（kok1eee）

| 項目 | oh-my-opencode | oh-my-claude-code / o-m-cc |
|------|---------------|---------------------------|
| **規模** | 35,626 stars | 数十〜数百 stars |
| **成熟度** | v3.9.0、3,391テスト、133k行 | 小規模、概念実証レベル |
| **プラットフォーム** | OpenCode | Claude Code |
| **アプローチ** | 包括的プラグインエコシステム | 軽量なプロンプト+設定ベース |

oh-my-opencodeとは規模・成熟度で桁違いの差がある。

#### vs Agent Orchestrator（Composio）

| 項目 | oh-my-opencode | Agent Orchestrator |
|------|---------------|-------------------|
| **Stars** | 35,626 | 2,728 |
| **アプローチ** | 単一CLI内でのマルチエージェント | 複数CLIプロセスの外部オーケストレーション |
| **並列化** | バックグラウンドエージェント（同一プロセス内） | 独立worktree + 独立プロセス（tmux/Docker/K8s） |
| **CI統合** | なし（エージェントがbash実行） | 自律的CI失敗検出・修正 |
| **用途** | 1人の開発者が1つのタスクを深く実行 | 複数のエージェントが複数PRを同時並行 |
| **差別化** | プラグインとしての深い統合 | インフラレベルの分離・並列化 |

解決する問題が根本的に異なる。OmOは「1つのタスクを賢くやる」、Agent Orchestratorは「複数タスクを同時にやる」。

### 制約・注意点

1. **ライセンス（SUL-1.0）:** MITではない。商用利用に制限あり — 「内部業務目的または非商用・個人利用のみ」。無償配布のみ許可。商用利用したい場合はライセンス確認が必要
2. **OpenCode依存:** OpenCodeのプラグインAPIに完全依存。OpenCodeの仕様変更に追従が必要
3. **トークン消費:** マルチエージェントオーケストレーションはトークン消費が大きい。作者自身が「$24K使った」と発言。サブエージェントのプロンプトが24kトークン超になるケースも報告あり
4. **ローカルモデル非対応:** 小さなコンテキストウィンドウのローカルモデル（16k等）ではサブエージェントプロンプトが破綻する（[Issue #951](https://github.com/code-yeongyu/oh-my-opencode/issues/951)）
5. **Anthropicハードコード問題:** プロバイダ設定を変更してもAnthropicモデルへのハードコードされたフォールバックが残る問題が報告されている（[Issue #946](https://github.com/code-yeongyu/oh-my-opencode/issues/946)）
6. **偽サイト問題:** `ohmyopencode.com`が公式を装って有料配布。プロジェクト側が明確に警告を出している
7. **急速な変化:** v3.9.0で187ファイル変更、+7,046/-1,891行。開発速度は非常に速いが、破壊的変更のリスクも伴う
8. **複雑性:** 44フック、11エージェント、26ツール、8カテゴリ — 問題発生時のデバッグは容易ではない

### 深掘り候補（コードリーディング対象）

| 対象 | ファイルパス | 深掘りの理由 |
|------|------------|-------------|
| **Hashline editの実装** | `src/tools/hashline-edit/` | ハッシュ生成・検証の具体的アルゴリズム、[oh-my-pi](https://github.com/can1357/oh-my-pi)との差分 |
| **カテゴリ→モデル解決** | `src/tools/delegate-task/` | カテゴリからモデルへのマッピング、フォールバックチェーンの具体的実装 |
| **Prometheus計画パイプライン** | `src/agents/prometheus/`, `src/agents/metis.ts`, `src/agents/momus.ts` | インタビュー→ギャップ分析→レビューの具体的プロンプト設計 |
| **Sisyphusプロンプト** | `src/agents/sisyphus.ts`, `sisyphus-prompt.md` | オーケストレーターのシステムプロンプト設計 |
| **dynamic-agent-prompt-builder** | `src/agents/dynamic-agent-prompt-builder.ts` | エージェントプロンプトの動的生成ロジック |
| **Plugin Interface** | `src/plugin-interface.ts`, `src/plugin/` | OpenCode Plugin APIとの統合パターン |
| **runtime-fallbackフック** | `src/hooks/runtime-fallback/` | APIエラー時の自動切替、クールダウン、リトライロジック |
| **Boulder State** | `src/features/boulder-state/` | セッション間の作業状態永続化の実装 |
| **Skill MCP Manager** | `src/features/skill-mcp-manager/` | スキルが独自MCPを持ち込むオンデマンド起動・破棄の仕組み |
| **Claude Code Plugin Loader** | `src/features/claude-code-plugin-loader/` | Claude Codeプラグインの互換ロード実装 |
| **agent-builder** | `src/agents/agent-builder.ts` | エージェント生成のファクトリパターン、ツール制限の付与方法 |
