---
name: Oracle
repo: steipete/oracle
last_reviewed: 2026-02-24
category: multi-model-review-tool
---

## Oracle 調査結果

### 基本情報

- **リポジトリ:** <https://github.com/steipete/oracle>
- **公式サイト:** <https://askoracle.dev/>
- **言語:** TypeScript (Node 22+)
- **パッケージ:** `@steipete/oracle` (npm) / `brew install steipete/tap/oracle`
- **Stars:** 1,521 / Forks: 129
- **最終更新:** 2026-02-20 (v0.8.6)
- **リリース数:** 31
- **ライセンス:** MIT
- **作者:** Peter Steinberger (steipete) — PSPDFKit創業者、iOS/macOS開発者として著名
- **一言で:** プロンプト＋ファイルをバンドルし、GPT-5 Pro等の複数モデルに「セカンドオピニオン」を求めるCLIツール

### これは何か・何を解決するのか

**目的:** AIコーディングエージェント（Claude Code, Cursor等）で開発中に「行き詰まった」とき、別のAIモデルにコードレビュー・デバッグ・設計検証を依頼するための「セカンドオピニオン」ツール。

**解決する問題:**

1. **コンテキスト組み立ての手間:** コードファイル＋プロンプトをMarkdownバンドルにまとめ、一発で別モデルに投げられる
2. **マルチモデル比較の煩雑さ:** `--models gpt-5.1-pro,gemini-3-pro,claude-4.5-sonnet` のように一度のコマンドで複数モデルに並列投入し、回答を比較できる
3. **GPT-5 Pro等の長時間実行管理:** バックグラウンドdetach→reattachのセッション管理で、10分〜1時間かかるPro実行を手放しで待てる
4. **APIキー不要のフォールバック:** ブラウザ自動操作でChatGPT/Gemini Webを直接操作でき、APIキーなしでも利用可能

**ターゲットユーザー:** Claude Code/Cursor等のAIエージェントをメインで使い、GPT-5 ProやGemini等の別モデルでクロスチェックしたい開発者。特にsteipete自身のワークフロー（Ghostty + Claude Code主体、GPT-5 Proでレビュー）が原型。

### 設計思想・アーキテクチャ

#### コアコンセプト: "Bundle once, reuse anywhere"

Oracle の設計哲学は「プロンプト＋ファイル群を1つのバンドルにまとめ、どのエンジン（API/ブラウザ/クリップボード）でも再利用できる」こと。ワンショット問い合わせに特化しており、会話の継続は想定しない。

#### ディレクトリ構造

```
src/
├── oracle/          # コアエンジン（モデル実行、トークン計算、バンドル組立）
│   ├── run.ts           # 単一モデル実行のメインループ
│   ├── multiModelRunner.ts  # 複数モデル並列実行
│   ├── background.ts    # バックグラウンドAPI実行（poll/retrieve）
│   ├── client.ts        # クライアントファクトリ（OpenAI/Gemini/Claude/OpenRouter）
│   ├── modelResolver.ts # モデル名解決＋OpenRouterカタログ統合
│   ├── config.ts        # モデル定義（pricing、inputLimit、tokenizer等）
│   ├── files.ts         # ファイル読み込み＋glob展開
│   ├── request.ts       # Responses APIリクエストボディ構築
│   ├── tokenEstimate.ts # トークン事前推定
│   └── tokenStats.ts    # per-fileトークンレポート
├── browser/         # ブラウザ自動操作エンジン（ChatGPT/Gemini Web）
│   ├── index.ts         # runBrowserMode メインフロー（2000行超の巨大ファイル）
│   ├── chromeLifecycle.ts   # Chrome起動/接続管理
│   ├── cookies.ts       # Chrome cookie同期
│   ├── pageActions.ts   # DOM操作（ログイン確認、プロンプト入力、回答取得）
│   ├── reattach.ts      # タイムアウト後の再接続
│   └── modelStrategy.ts # ChatGPTモデルピッカー制御
├── gemini-web/      # Gemini Web専用ブラウザクライアント
├── cli/             # CLIコマンド・TUI・オプション解析
│   ├── sessionRunner.ts # セッション実行制御
│   ├── sessionCommand.ts    # status/session/restartコマンド
│   ├── tui/             # インタラクティブTUI
│   └── bridge/          # Windows-Linux ブリッジ
├── mcp/             # MCP (Model Context Protocol) サーバー
│   ├── server.ts        # stdio MCPサーバー
│   └── tools/           # consult, sessions, sessionResources
├── remote/          # リモートブラウザサービス（oracle serve）
├── bridge/          # クロスプラットフォームブリッジ
├── sessionManager.ts    # セッションメタデータ管理
├── sessionStore.ts      # ファイルベースのセッションストア
├── config.ts            # ユーザー設定読み込み（~/.oracle/config.json）
└── heartbeat.ts         # 長時間実行のハートビート
```

#### マルチモデル並列実行の仕組み

`src/oracle/multiModelRunner.ts` が核。設計は以下:

1. `--models` で指定された各モデルに対し、`startModelExecution()` で個別の `RunOracleOptions` を生成
2. 全モデルの Promise を `Promise.allSettled()` で並列実行
3. 各モデルの結果は個別のログファイル（`~/.oracle/sessions/<id>/log-<model>.txt`）に書き込み
4. 完了時に `onModelDone` コールバックで逐次通知、最終的に fulfilled/rejected の集計結果を返す
5. コスト・トークン使用量はモデルごとに集計し、合算表示

**ポイント:** 各モデルの実行は完全に独立しており、1つが失敗しても他は継続する。`suppressHeader: true` でモデルごとのバナーを抑制し、集約ランナーが共通ヘッダーを1回だけ出力する設計。

#### セッション管理（status, session再接続）

- **ストレージ:** `~/.oracle/sessions/<session-id>/` にメタデータJSON、ログ、リクエストボディを永続化
- **SessionStore:** `FileSessionStore` クラスでファイルシステムに直接読み書き（DB不使用）
- **detach/reattach:** GPT-5 Pro等の長時間モデルはデフォルトでバックグラウンド実行。`oracle status --hours 72` でセッション一覧、`oracle session <id> --render` で結果取得
- **zombie検出:** `--zombie-timeout` でstale session判定。`--zombie-last-activity` でログの最終更新時刻基準の判定も可能
- **セッションプルーニング:** `oracle status --clear --hours 168` で古いセッションを自動削除

#### --dry-run + --files-report のトークンプレビュー

`run.ts` 内で `estimateRequestTokens()` → `resolvePreviewMode()` の流れ:

- `--dry-run summary`: 推定トークン数のサマリーのみ
- `--dry-run json`: リクエストボディJSON全文を表示
- `--dry-run full`: JSON + 組み立て済みプロンプト全文
- `--files-report`: ファイルごとのトークン数・割合をテーブル表示（`getFileTokenStats()`）
- 各モデルに対応する正確なtokenizerを使用（`gpt-tokenizer` for GPT、`@anthropic-ai/tokenizer` for Claude）

#### API vs ブラウザ自動操作のデュアルエンジン

**エンジン自動選択:** `OPENAI_API_KEY` があればAPI、なければブラウザ。`--engine` で明示も可能。

**APIエンジン** (`src/oracle/`):
- OpenAI Responses API（ストリーミング or バックグラウンド）
- Gemini API (`@google/genai` SDK)
- Anthropic API（Claude用アダプター）
- OpenRouter経由の任意モデル（Chat Completions APIへのアダプター）
- Azure OpenAI対応

**ブラウザエンジン** (`src/browser/`):
- Chrome DevTools Protocol (CDP) で実際のChromeを操作
- `chrome-launcher` でChrome起動、`chrome-remote-interface` でCDP接続
- `@steipete/sweet-cookie` でChromeのCookieを同期（APIキー不要でログイン済みセッション利用）
- ChatGPTのDOMを直接操作: プロンプト入力→送信→レスポンス取得
- Gemini Web (`src/gemini-web/`): gemini.google.comに対する同様のブラウザ自動操作
- 自動再接続: タイムアウト後もポーリングで回答を待つ (`--browser-auto-reattach-*`)
- リモートブラウザ: `oracle serve` でホストマシンのChromeをネットワーク越しに利用可能

#### MCP対応（mcporter経由）

`src/mcp/server.ts` で `@modelcontextprotocol/sdk` を使った stdio MCPサーバーを実装:

- **`consult` ツール:** プロンプト＋ファイルを受け取り、セッション実行して結果を返す
- **`sessions` ツール:** セッション一覧・詳細取得（`oracle status` / `oracle session` のMCP版）
- **`oracle-session://` リソース:** セッションのメタデータ・ログ・リクエストをMCPリソースとして公開
- Cursor の `.cursor/mcp.json` に `{ "oracle": { "command": "oracle-mcp" } }` で統合可能

### 機能一覧

#### Core（コア機能）

| 機能 | 説明 | 場所 |
|------|------|------|
| プロンプト＋ファイルバンドル | glob/除外パターンでファイル選択、Markdownバンドルに組立 | `src/oracle/files.ts`, `request.ts` |
| APIモデル実行 | OpenAI Responses API経由のストリーミング実行 | `src/oracle/run.ts` |
| マルチモデル並列実行 | `--models` で複数モデルに並列投入、結果集約 | `src/oracle/multiModelRunner.ts` |
| バックグラウンド実行 | Pro系モデルのdetach→poll→retrieve | `src/oracle/background.ts` |
| セッション管理 | 全実行をファイルベースで永続化、status/session/restart | `src/sessionManager.ts`, `sessionStore.ts` |
| トークン推定＋コスト計算 | モデル別tokenizer、`tokentally` でUSDコスト算出 | `src/oracle/tokenEstimate.ts`, `config.ts` |

#### Differentiator（差別化機能）

| 機能 | 説明 | 場所 |
|------|------|------|
| ブラウザ自動操作エンジン | CDP経由でChatGPT/Gemini Webを直接操作（APIキー不要） | `src/browser/` (2000行超) |
| Cookie同期 | Chrome Cookieを自動取得してブラウザ操作に利用 | `src/browser/cookies.ts` |
| 自動再接続 | タイムアウト後もポーリングで回答を待機 | `src/browser/reattach.ts` |
| リモートブラウザサービス | `oracle serve` でネットワーク越しにChrome操作を委譲 | `src/remote/` |
| Gemini Web画像生成 | `--generate-image` / `--edit-image` でGeminiブラウザ経由の画像生成 | `src/gemini-web/` |
| MCP統合 | stdio MCPサーバーでCursor等から直接呼び出し | `src/mcp/` |
| OpenRouter統合 | 任意のOpenRouterモデルIDに対応、カタログ自動取得 | `src/oracle/modelResolver.ts` |
| Codex Skill同梱 | Claude Code/Codex用のスキル定義がリポジトリに同梱 | `skills/oracle/SKILL.md` |
| `--dry-run` + `--files-report` | トークン消費の事前プレビュー（summary/json/full） | `src/cli/dryRun.ts`, `src/oracle/tokenStats.ts` |

#### Utility（ユーティリティ機能）

| 機能 | 説明 | 場所 |
|------|------|------|
| `--render` / `--copy` | バンドルをMarkdown出力/クリップボードコピー | `src/cli/markdownBundle.ts`, `clipboard.ts` |
| TUI | インタラクティブなターミナルUI | `src/cli/tui/` |
| Azure OpenAI対応 | `--azure-endpoint` 等でAzure専用エンドポイント利用 | `src/oracle/client.ts` |
| macOS通知 | 長時間実行完了時のネイティブ通知 | `vendor/oracle-notifier/` (Swift) |
| ハートビート | 長時間実行中の接続維持ログ | `src/heartbeat.ts` |
| OSC Progress | ターミナルのプログレスバー表示 | `src/oracle/oscProgress.ts` |
| Markdown ANSI描画 | ターミナルでMarkdownをリッチ表示 | `src/cli/markdownRenderer.ts` (shiki利用) |
| 重複プロンプト検出 | 同一プロンプトの再送信ガード | `src/cli/duplicatePromptGuard.ts` |
| Windows-Linux ブリッジ | WSL環境でのクロスプラットフォームサポート | `src/cli/bridge/`, `src/bridge/` |
| YouTube解析 | Geminiブラウザモードで動画URL解析 | `--youtube` フラグ |
| カスタムクライアントファクトリ | `ORACLE_CLIENT_FACTORY` 環境変数でクライアント差し替え | `src/oracle/client.ts` |

### 特徴的な点・注目ポイント

#### 1. APIとブラウザ自動操作のシームレスな切り替え

最大の特徴。APIキーがあればAPI、なければ実際のChrome上のChatGPT/Geminiを自動操作する。これにより:
- APIキーを持たない／課金を避けたいケースでもGPT-5 Proを利用可能
- ChatGPT Pro（$200/月プラン）のGPT-5 Pro無制限アクセスを活用できる
- ブラウザモードでは `--browser-thinking-time` でChatGPTのThinking強度も制御可能

#### 2. ファイルバンドル＋トークン予算管理の緻密さ

単にファイルを結合するだけでなく:
- モデルごとに正確なtokenizerで事前推定（GPT-5用/Claude用/Gemini用）
- `--files-report` でファイルごとの消費割合を可視化
- 196k tokenの予算上限でのガードレール
- 1MB超ファイルの自動拒否
- `.gitignore` の自動適用

#### 3. バックグラウンドdetach→reattachパターン

GPT-5 Proの応答は10分〜1時間かかることがある。この現実に対応:
- デフォルトでdetach、`oracle session <id>` で後から取得
- ハートビートで接続維持
- ブラウザモードでは自動再接続（ポーリング）
- セッションメタデータにChrome PID/ポートを記録し、後からDOM検査も可能

#### 4. OpenRouterとの深い統合

`modelResolver.ts` が OpenRouter APIカタログを自動取得し:
- 任意のモデルID（`minimax/minimax-m2` 等）をそのまま `--model` に指定可能
- OpenAI Responses API → Chat Completions APIへの自動アダプテーション
- pricing情報もカタログから自動取得してコスト表示

#### 5. 実践から生まれた「泥臭い」機能群

- Cloudflare WAFブロック対策（Cookie同期、inline-cookies、manual-login）
- プロファイルロック（並列ブラウザ実行の排他制御）
- ゾンビセッション検出
- 重複プロンプト送信ガード
- AGENTS.mdにChatGPTの "Answer now" ボタンを絶対にクリックしない指示が書かれるほど、実運用で踏んだ地雷からの学びが反映されている

### 使い方・典型的なワークフロー

#### インストール

```bash
npm install -g @steipete/oracle
# or
brew install steipete/tap/oracle
# or
npx -y @steipete/oracle --help
```

#### 基本フロー

```bash
# 1. ファイル＋プロンプトをプレビュー（トークン消費なし）
oracle --dry-run summary --files-report \
  -p "Review the auth module for security issues" \
  --file "src/auth/**" --file "!**/*.test.ts"

# 2. APIで単一モデルに投げる
oracle -p "Review the auth module for security issues" \
  --file "src/auth/**" --model gpt-5.1-pro

# 3. 複数モデルに並列投入
oracle -p "Cross-check the data layer" \
  --models gpt-5.1-pro,gemini-3-pro,claude-4.5-sonnet \
  --file "src/**/*.ts"

# 4. ブラウザモード（APIキー不要）
oracle --engine browser \
  -p "Walk through this refactoring plan" \
  --file "src/**"

# 5. セッション管理
oracle status --hours 72          # 最近のセッション一覧
oracle session <id> --render      # 結果取得
oracle restart <id>               # 再実行
```

#### 設定例（`~/.oracle/config.json`）

```json5
{
  model: "gpt-5.1-pro",
  engine: "api",
  filesReport: true,
  browser: {
    chatgptUrl: "https://chatgpt.com/g/g-p-.../project"
  }
}
```

#### MCP統合（Cursor）

`.cursor/mcp.json`:

```json
{
  "oracle": {
    "command": "oracle-mcp",
    "args": []
  }
}
```

### エコシステム・実利用状況

#### 採用事例

- **steipete自身:** 主開発者兼ヘビーユーザー。Claude Code + Ghosttyでメイン開発、Oracle経由でGPT-5 Proにレビュー依頼するワークフローを [ブログ記事](https://steipete.me/posts/2025/optimal-ai-development-workflow) で公開
- **1,500+ Stars:** npm公開パッケージとして広く利用される
- 企業での採用事例は未確認（個人開発者中心の利用層と推測）

#### 盛り上がりの文脈

- GPT-5 Pro/GPT-5.1 Pro登場時期に「APIキーなしでPro活用」のニーズで注目
- steipete（PSPDFKit創業者）の知名度によるiOS/macOS開発者コミュニティでの拡散
- AI開発ワークフローの「セカンドオピニオン」パターンの実践ツールとして注目

#### コミュニティ

- GitHub Issues/Discussionsは活発。ブラウザモードの安定性に関するIssueが多い
- agent-skills.md や playbooks.com にスキル定義が掲載されている
- 日本語コミュニティ（Zenn/Qiita）での言及は確認できず（2026-02時点）

#### 周辺ツール（steipeteエコシステム）

- **[MCPorter](https://mcporter.dev):** MCP サーバー管理ツール（Oracle MCPの設定にも利用）
- **[Trimmy](https://trimmy.app):** マルチラインシェルスニペットのフラット化ツール
- **[CodexBar](https://codexbar.app):** Codexトークン使用量のmacOSメニューバー表示
- **[sweet-cookie](https://github.com/steipete/sweet-cookie):** Chrome Cookie同期ライブラリ（Oracleの依存関係）
- **arena:** steipete開発の別のマルチモデル比較ツール（ブログ記事で言及）

### 他ツールとの比較・ポジショニング

#### vs arena-compare（自作のマルチモデル比較）

| 観点 | Oracle | arena-compare（自作想定） |
|------|--------|--------------------------|
| **アプローチ** | CLIワンショット、ファイルバンドル | ？（構成による） |
| **モデル対応** | GPT-5系/Gemini/Claude/OpenRouter/xAI | 任意（実装次第） |
| **エンジン** | API＋ブラウザ自動操作の二刀流 | 通常APIのみ |
| **セッション管理** | ファイルベースで永続化、detach/reattach | ？ |
| **MCP対応** | あり（stdio） | ？ |
| **トークン管理** | モデル別tokenizerで精密推定 | ？ |

Oracle の強み: ブラウザエンジンによるAPIキー不要の実行、堅牢なセッション管理、実践的な「泥臭い」機能。

#### vs セカンドオピニオン検証（claude-safe）

| 観点 | Oracle | second-opinion-verification |
|------|--------|-----------------------------|
| **実装** | TypeScript CLI (npm) | Bash (claude-safe wrapper) |
| **モデル** | マルチモデル（GPT/Gemini/Claude/OpenRouter） | Claude Code のみ |
| **ファイル管理** | glob/除外パターン、トークン推定 | 手動パイプ |
| **セッション** | ファイルベースの永続管理 | なし（ワンショット） |
| **統合** | MCP, Codex Skill, CLI | Cursor Agent統合のみ |
| **ブラウザ** | CDP経由のChatGPT/Gemini自動操作 | なし |
| **コスト管理** | dry-run、files-report、pricing表示 | なし |

Oracle はフルスペックの統合ツール。claude-safeは軽量・最小限のBashラッパー。目的は同じ「セカンドオピニオン」だが、Oracle は「プロダクションレベルのCLIツール」、claude-safeは「最小限の安全ラッパー」と位置付けが異なる。

#### vs Claude Code / Cursor Agent 直接利用

Oracle は既存のAIエージェントの**代替ではなく補完**。メインのコーディングはClaude Code/Cursorで行い、Oracleで「別の視点」を得るワークフロー。steipete自身もこの使い方を推奨している。

### 制約・注意点

- **Node 22+必須:** 比較的新しいNode.jsが必要
- **ブラウザモードの不安定性:** README/AGENTS.mdで "experimental" と明記。Cloudflare WAF、ChatGPT UI変更、Cookie同期の問題が頻繁に発生する
- **ChatGPT依存:** ブラウザモードはChatGPTのDOM構造に依存しており、OpenAI側のUI変更で壊れるリスクがある
- **コスト管理:** GPT-5 Proは$21/M input、$168/M output と非常に高価。dry-runでの事前確認が重要
- **ワンショット設計:** 会話の継続はできない。前回の実行結果を踏まえた追加質問はプロンプトに含める必要がある
- **設定の複雑さ:** ブラウザ関連のフラグが30以上あり、設定オプションが非常に多い
- **成熟度:** v0.8.6でまだメジャーバージョン前。APIの破壊的変更の可能性がある
- **メンテナンス:** 実質steipete個人のプロジェクト。バス係数が1

### 深掘り候補（コードリーディング対象）

| ファイル/ディレクトリ | 注目ポイント |
|----------------------|-------------|
| `src/browser/index.ts` (2000行超) | ブラウザ自動操作の全フロー。CDP操作、Cookie同期、プロンプト入力、回答取得、再接続の実装詳細 |
| `src/browser/pageActions.ts` | ChatGPTのDOM操作セレクタ群。UI変更への追従方法がわかる |
| `src/browser/reattach.ts` | タイムアウト後の自動再接続アルゴリズム |
| `src/oracle/multiModelRunner.ts` | マルチモデル並列実行のPromise.allSettled設計 |
| `src/oracle/client.ts` | OpenAI/Gemini/Claude/OpenRouterのプロバイダーアダプター実装 |
| `src/oracle/modelResolver.ts` | OpenRouterカタログ統合、モデルID解決、pricing自動取得 |
| `src/sessionManager.ts` | ファイルベースのセッション永続化設計 |
| `src/mcp/tools/consult.ts` | MCP toolとしてのOracle実行の橋渡し |
| `src/gemini-web/` | Gemini Webのブラウザ自動操作（画像生成含む） |
| `src/remote/server.ts` | リモートブラウザサービスのHTTPサーバー実装 |
| `vendor/oracle-notifier/` | macOSネイティブ通知のSwift実装 |
