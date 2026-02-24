---
name: mcporter
repo: steipete/mcporter
last_reviewed: 2026-02-25
category: mcp-bridge-tool
---

## mcporter 調査結果

### 基本情報

- **リポジトリ:** <https://github.com/steipete/mcporter>
- **公式サイト:** <https://mcporter.dev>
- **言語:** TypeScript (Node.js ≥ 20, Bun対応)
- **Stars:** ~2,100
- **フォーク:** ~150
- **最終更新:** 2026年2月（v0.7.4、517+ commits）
- **ライセンス:** MIT
- **パッケージ:** npm `mcporter` / Homebrew `steipete/tap/mcporter`
- **作者:** Peter Steinberger (steipete) — iOS/macOS開発で著名、PSPDFKit創業者
- **一言で:** MCPサーバーをTypeScript APIやCLIとして呼び出すランタイム＋コード生成ツールキット

### これは何か・何を解決するのか

MCPorterは、Model Context Protocol (MCP) サーバーとの通信を統一的に扱うTypeScriptランタイム・CLI・コード生成ツールキット。

**解決する問題:**

- MCPサーバーの設定がCursor、Claude Desktop、Claude Code、Codex、Windsurf、OpenCode、VS Codeなど各ツールに分散しており、統一的に管理・呼び出す手段がない
- MCPサーバーをコードから呼び出すにはboilerplateが多く、スキーマの手動解析が必要
- MCPで提供されるツールをCLIとして再パッケージ化する標準的な方法がない
- OAuth認証やstdio/HTTPトランスポートの違いをアプリケーション側で吸収する負担

**ターゲットユーザー:**

- AIエージェントのワークフローを構築する開発者
- 複数のMCPサーバーを横断的に利用するチーム
- MCPツールをスタンドアロンCLIに変換して配布したい開発者
- Anthropicの「Code Execution with MCP」ワークフローを実践する開発者

### 設計思想・アーキテクチャ

#### 核となる設計判断

1. **Zero-config Discovery（設定不要の自動検出）:** `createRuntime()` がホーム設定 (`~/.mcporter/mcporter.json[c]`) → プロジェクト設定 (`config/mcporter.json`) → 各エディタインポート（Cursor/Claude/Codex等）の順でMCPサーバー定義をマージする。ユーザーは既存のエディタ設定をそのまま流用でき、追加設定なしで即座にツール呼び出しが可能
2. **MCP → CLI変換パイプライン:** steipeteの「MCPよりCLI」思想を体現。`generate-cli` で任意のMCPサーバーをスタンドアロンCLIに変換し、エージェントがオンデマンドで呼び出せる形にする。MCPの利点（スキーマ、認証）を活かしつつ、CLIの利点（composability、on-demand loading）を得る
3. **Proxy-based TypeScript API:** `createServerProxy()` がProxyオブジェクトを返し、`chrome.takeSnapshot()` のようなcamelCaseメソッド呼び出しを `take_snapshot` ツール呼び出しに自動変換。スキーマからのデフォルト値適用、必須引数バリデーション、`CallResult` ラッパーによる `.text()/.json()/.markdown()` アクセスまで自動化
4. **Daemon/Keep-alive アーキテクチャ:** chrome-devtools等のステートフルサーバーはデーモンプロセスで永続化し、エージェント間でセッションを共有。UNIXソケット経由のJSONプロトコルで通信

#### steipeteの「MCPよりCLI」思想との関係

steipeteは2025年7月のブログ記事「Peekaboo 2.0 – Free the CLI from its MCP shackles」で明確に表明:

> "Agents are really, really good at calling CLIs (actually much better than calling MCPs)."

MCPorterはこの思想の**実装基盤**:
- MCPサーバーの価値（スキーマ定義、認証フロー、ツール発見）は維持
- `generate-cli` でMCPサーバーをCLIに変換 → エージェントはCLIとして呼び出す
- MCPは「スキーマの定義と配布のプロトコル」、CLIは「実行のインターフェース」という分離

ソース: <https://steipete.me/posts/2025/peekaboo-2-freeing-the-cli-from-its-mcp-shackles>

#### ディレクトリ構造

```
src/
├── cli.ts                    # CLIエントリポイント（コマンドディスパッチ）
├── index.ts                  # パブリックAPI exports
├── runtime.ts                # McpRuntime クラス（接続プール、ツール呼び出し）
├── server-proxy.ts           # Proxy-based ergonomic API
├── config.ts                 # 設定レイヤー読み込み・マージ
├── config-schema.ts          # Zod スキーマ定義（ServerDefinition等）
├── config-imports.ts          # エディタ設定インポート
├── config-normalize.ts        # 設定正規化
├── generate-cli.ts           # CLI生成エンジン
├── oauth.ts                  # OAuthフロー（ローカルコールバックサーバー）
├── oauth-persistence.ts      # OAuthトークン永続化
├── oauth-vault.ts            # OAuthシークレット管理
├── schema-cache.ts           # スキーマキャッシュ（ディスク永続化）
├── lifecycle.ts              # Keep-alive / ephemeral ライフサイクル管理
├── result-utils.ts           # CallResult ラッパー
├── error-classifier.ts       # 接続エラー分類
├── sdk-patches.ts            # MCP SDK へのパッチ
├── cli/                      # CLIサブコマンド群
│   ├── call-command.ts       # `mcporter call` 実装
│   ├── list-command.ts       # `mcporter list` 実装
│   ├── config-command.ts     # `mcporter config` 実装
│   ├── daemon-command.ts     # `mcporter daemon` 実装
│   ├── emit-ts-command.ts    # `mcporter emit-ts` 実装
│   ├── generate-cli-runner.ts # `mcporter generate-cli` 実装
│   ├── call-expression-parser.ts # 関数呼び出し構文パーサー
│   ├── command-inference.ts  # コマンド自動推論
│   ├── adhoc-server.ts       # アドホックサーバー定義
│   ├── generate/             # CLI生成サブモジュール
│   └── config/               # config サブコマンド
├── config/imports/           # エディタ別インポートパス定義
│   ├── paths.ts              # 各エディタの設定ファイルパス
│   ├── external.ts           # 外部設定読み込み
│   └── shared.ts             # 共通ユーティリティ
├── daemon/                   # デーモンプロセス
│   ├── host.ts               # デーモンホスト（UNIXソケットサーバー）
│   ├── client.ts             # デーモンクライアント
│   ├── protocol.ts           # JSON-RPCプロトコル定義
│   ├── launch.ts             # デーモン起動
│   ├── paths.ts              # ソケットパス解決
│   └── runtime-wrapper.ts    # Keep-alive対応ランタイムラッパー
└── runtime/                  # ランタイムサブモジュール
    ├── transport.ts          # トランスポート生成
    ├── oauth.ts              # OAuth設定解決
    ├── errors.ts             # エラーリセット判定
    └── utils.ts              # タイムアウトユーティリティ
```

#### MCP設定の自動検出メカニズム（config/imports/paths.ts）

`pathsForImport()` が各エディタの設定ファイルパスを網羅的にスキャン:

| ImportKind | 読み込み先パス |
|---|---|
| `cursor` | `.cursor/mcp.json` (project/home) + User/mcp.json |
| `claude-code` | `.claude/settings.local.json`, `.claude/settings.json`, `.claude/mcp.json`, `~/.claude.json` |
| `claude-desktop` | `~/Library/Application Support/Claude/settings.json` |
| `codex` | `.codex/config.toml` (TOML対応) |
| `windsurf` | `.codeium/windsurf/mcp_config.json` 他 |
| `opencode` | `opencode.jsonc`, `.openai/config.json` 他 |
| `vscode` | `.vscode/mcp.json` + User/mcp.json |

マージ優先順位: ホーム設定 → プロジェクト設定 → インポート（imports配列順）。ローカル定義が常に優先。

#### OAuth認証フロー（oauth.ts）

`PersistentOAuthClientProvider` が以下を実装:
- ローカルHTTPサーバー起動（`127.0.0.1` 上の動的ポート）でOAuthコールバック受信
- PKCE (code_verifier) サポート
- ファイルベースのトークン永続化 (`~/.mcporter/<server>/`)
- ブラウザ自動オープン（macOS: `open`, Linux: `xdg-open`, Windows: `cmd /c start`）
- OAuth state検証によるCSRF対策
- サーバーが途中でOAuth要求を出した場合の自動昇格（auto-promotion）

#### デーモンモード（daemon/host.ts）

- UNIXドメインソケット経由のJSON-RPCプロトコル
- `callTool`, `listTools`, `listResources`, `closeServer`, `status`, `stop` メソッド
- アイドルタイムアウトによる自動eviction（30秒間隔チェック）
- デフォルトkeep-alive対象: `chrome-devtools`, `mobile-mcp`, `playwright`
- 環境変数 `MCPORTER_KEEPALIVE` / `MCPORTER_DISABLE_KEEPALIVE` でオーバーライド可
- per-serverログ制御

### 機能一覧

#### Core

| 機能 | 概要 | コードベース位置 |
|---|---|---|
| **MCPサーバー発見・一覧表示** | 設定済みサーバーのライブ発見、ツール一覧のTypeScript風シグネチャ表示 | `src/cli/list-command.ts` |
| **ツール呼び出し** | `server.tool` セレクタまたはHTTP URL指定でツール実行、自動補正付き | `src/cli/call-command.ts` |
| **Runtime API** | `createRuntime()` による接続プール管理、トランスポート再利用 | `src/runtime.ts` |
| **Server Proxy** | camelCase→kebab-case自動変換、スキーマベースのバリデーション・デフォルト値適用 | `src/server-proxy.ts` |
| **設定管理** | 階層的設定読み込み（home → project → imports）、CLI/APIでのCRUD | `src/config.ts`, `src/cli/config-command.ts` |
| **OAuth認証** | ブラウザフロー、PKCE、トークン永続化、自動昇格 | `src/oauth.ts`, `src/oauth-persistence.ts` |

#### Differentiator

| 機能 | 概要 | コードベース位置 |
|---|---|---|
| **CLI自動生成 (generate-cli)** | MCPサーバーをスタンドアロンCLI/バイナリに変換（Rolldown/Bunバンドル、Bunコンパイル対応） | `src/generate-cli.ts`, `src/cli/generate/` |
| **TypeScript型生成 (emit-ts)** | MCPサーバーから `.d.ts` / クライアントラッパー自動生成 | `src/cli/emit-ts-command.ts` |
| **Zero-config Discovery** | Cursor/Claude/Codex/Windsurf/OpenCode/VS Code設定の自動インポート | `src/config/imports/paths.ts` |
| **デーモンモード** | ステートフルサーバーのkeep-alive管理、UNIXソケット通信 | `src/daemon/` |
| **アドホック接続** | 設定ファイル不要でHTTP URL/stdioコマンドを直接指定、後から永続化可能 | `src/cli/adhoc-server.ts`, `src/cli/ephemeral-target.ts` |
| **関数呼び出し構文** | `'linear.create_issue(title: "Bug", team: "ENG")'` のJS風構文対応 | `src/cli/call-expression-parser.ts` |
| **ツール名自動補正** | typo検出と "Did you mean …?" ヒント | `src/cli/command-inference.ts` |
| **スキーマキャッシュ** | ツールスキーマのディスク永続化で起動高速化 | `src/schema-cache.ts` |

#### Utility

| 機能 | 概要 | コードベース位置 |
|---|---|---|
| **CLI Inspect** | 生成済みCLIの再生成メタデータ表示 | `src/cli/inspect-cli-command.ts` |
| **CallResult ヘルパー** | `.text()`, `.json()`, `.markdown()`, `.content()` でMCPレスポンス抽出 | `src/result-utils.ts` |
| **エラー分類** | 接続エラーをauth/offline/http/runtimeに自動分類 | `src/error-classifier.ts` |
| **SDK パッチ** | `@modelcontextprotocol/sdk` への互換性パッチ | `src/sdk-patches.ts` |
| **ライフサイクル管理** | keep-alive/ephemeral切り替え、動的Chromeポート検出 | `src/lifecycle.ts` |
| **環境変数展開** | `${VAR}`, `${VAR:-fallback}`, `$env:VAR` 補間 | `src/env.ts` |
| **JSON出力** | `--json` フラグで全コマンドの構造化出力 | `src/cli/json-output.ts` |
| **ハング検出デバッグ** | `MCPORTER_DEBUG_HANG=1` でアクティブハンドル診断 | `src/cli/runtime-debug.ts` |
| **callOnce** | 単発ツール呼び出し用ワンショットAPI | `src/runtime.ts` |

### 特徴的な点・注目ポイント

1. **MCPのCLI化パイプライン:** MCPorterの最大の差別化要因。`generate-cli` → Rolldown/Bunバンドル → Bunコンパイルの流れで、任意のMCPサーバーをシングルバイナリに変換できる。生成物には再生成メタデータが埋め込まれ、`inspect-cli` → `generate-cli --from` で最新版から再生成が可能

2. **7エディタ同時インポート:** Cursor, Claude Code, Claude Desktop, Codex, Windsurf, OpenCode, VS Codeの設定ファイルパスを網羅的にサポート。TOML (Codex), JSONC (OpenCode) も含めた多フォーマット対応。既存のMCP設定をそのまま活用できる

3. **関数呼び出し構文パーサー:** `'linear.create_comment(issueId: "ENG-123", body: "Looks good!")'` のようなJavaScript風の構文をacornベースでパースし、ネストしたオブジェクト/配列もサポート。CLIの人間工学を重視した設計

4. **Proxy-based API:** JavaScriptのProxyを活用し、任意のMCPサーバーをあたかもTypeScriptオブジェクトのように扱える。スキーマキャッシュ（ディスク永続化）との組み合わせで、初回以降はオフラインでもバリデーション可能

5. **デーモンのアイドルeviction:** chrome-devtools等のステートフルサーバーを自動管理。接続のアイドルタイムアウトで自動切断し、次回呼び出し時に再接続。Chrome DevToolsのURL動的変更も検出して自動ephemeral化

### 使い方・典型的なワークフロー

#### インストール

```bash
# npxで即座に実行（インストール不要）
npx mcporter list

# プロジェクトに追加
pnpm add mcporter

# Homebrew
brew tap steipete/tap && brew install steipete/tap/mcporter
```

#### 基本ワークフロー

```bash
# 1. 設定済みMCPサーバーを確認
npx mcporter list

# 2. 特定サーバーのツール一覧（TypeScript風シグネチャ）
npx mcporter list linear --schema

# 3. ツールを呼び出す（複数の構文に対応）
npx mcporter call linear.search_documentation query="automations"
npx mcporter call 'linear.create_comment(issueId: "ENG-123", body: "Looks good!")'

# 4. OAuth認証が必要なサーバー
npx mcporter auth vercel

# 5. アドホック接続（設定不要）
npx mcporter list --http-url https://mcp.linear.app/mcp --name linear
npx mcporter call --stdio "bun run ./local-server.ts" --name local
```

#### CLI生成ワークフロー

```bash
# MCPサーバーからCLI生成
npx mcporter generate-cli --command https://mcp.context7.com/mcp

# バンドル + コンパイル（シングルバイナリ）
npx mcporter generate-cli --command "npx -y chrome-devtools-mcp@latest" --bundle --compile

# 生成済みCLIの確認・再生成
npx mcporter inspect-cli dist/context7.js
npx mcporter generate-cli --from dist/context7.js
```

#### TypeScript API

```typescript
import { createRuntime, createServerProxy } from "mcporter";

const runtime = await createRuntime();
const linear = createServerProxy(runtime, "linear");

const docs = await linear.searchDocumentation({ query: "automations" });
console.log(docs.json());

await runtime.close();
```

#### 設定ファイル例 (`config/mcporter.json`)

```json
{
  "mcpServers": {
    "context7": {
      "description": "Context7 docs MCP",
      "baseUrl": "https://mcp.context7.com/mcp"
    },
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"],
      "lifecycle": "keep-alive"
    }
  },
  "imports": ["cursor", "claude-code", "codex"]
}
```

### エコシステム・実利用状況

- **採用事例:**
  - **Oplink:** MCPワークフローオーケストレーションツールがmcporterを全外部MCP通信に使用。トランスポート、発見、認証ハンドオフを委譲（<https://oplink.instructa.ai/advanced/3-mcporter>）
  - **openclaw/skills:** Codex向けスキルとしてmcporterを統合（<https://playbooks.com/skills/openclaw/skills/mcporter>）
  - **steipete自身のツールチェイン:** Oracle (プロンプトバンドラー), CodexBar (AIプロバイダ使用量モニター), Peekaboo (スクリーンショット) と組み合わせて使用

- **盛り上がりの文脈:**
  - Anthropicの「Code Execution with MCP」ガイダンス公開がきっかけ
  - 2025年後半の「MCP vs CLI」論争でsteipeteがCLI派の代表格に。MCPorterの`generate-cli`が「MCPの利点を活かしつつCLIに変換する」実用的解答として注目
  - PulseMCPにクライアントとして掲載（<https://www.pulsemcp.com/clients/steipete-mcporter>）

- **コミュニティ:**
  - GitHub Issues: OAuth関連の問題報告が活発（Figma/Supabase/Vercel等のOAuthスコープ問題）
  - 517+ commits、活発なメンテナンス
  - AGENTS.mdベースのAIエージェント向けドキュメント整備

- **周辺ツール（steipeteエコシステム）:**
  - **Oracle** (steipete/oracle): プロンプトバンドラー/マルチモデルCLI。MCPorterでMCPサーバーと連携
  - **CodexBar** (steipete/CodexBar): macOSメニューバーでAIプロバイダ使用量モニタリング
  - **Peekaboo**: macOSスクリーンショット + AI分析。CLI-first + MCP optional
  - **Trimmy**: クリップボード整形ツール

- **評判:**
  - 正: 「MCPをCLIに変換する唯一の実用的ツール」として評価。Zero-config discoveryの利便性（ソース: PulseMCP, Oplink docs）
  - 負: OAuthスコープのハードコード問題 (`mcp:tools` 固定) でFigma等のサーバーと互換性問題。環境変数のstdioサーバーへの引き渡しバグ。JSONパラメータの型強制問題（GitHub Issues #32, #64等）

### 他ツールとの比較・ポジショニング

| 観点 | MCPorter | MCP SDK直接使用 | gh/curl等のCLI |
|---|---|---|---|
| **セットアップ** | Zero-config (エディタ設定自動インポート) | 手動設定必須 | サーバーごとに個別セットアップ |
| **型安全性** | emit-tsで `.d.ts` 生成、Proxy APIで実行時バリデーション | 手動でスキーマ解析 | なし |
| **CLI変換** | `generate-cli` でワンコマンド | なし | 既にCLI |
| **認証** | OAuth自動フロー、トークン永続化 | 手動実装 | ツールごとに個別 |
| **デーモン** | Keep-alive管理あり | なし | なし |
| **哲学** | MCP → CLI変換ブリッジ | MCPネイティブ | CLI直接 |

MCPorterのポジション: **MCPエコシステムとCLI実行のブリッジ**。MCPの利点（スキーマ定義、ツール発見、標準化された認証）を維持しつつ、最終的な実行インターフェースとしてはCLIを推奨する。

### 制約・注意点

- **成熟度:** v0.7.4 — APIは安定してきたが破壊的変更の可能性あり
- **OAuthスコープ問題:** `mcp:tools` がハードコードされており、Figma (`mcp:connect`) 等のサーバーで認証失敗。Issue #32で議論中
- **Node.jsプロセスハング:** MCP SDK由来のstdioハンドルリーク問題。`MCPORTER_DEBUG_HANG=1` でデバッグ可能だが根本解決はSDK側の修正待ち。`MCPORTER_NO_FORCE_EXIT=1` / `process.exit(0)` での強制終了がデフォルト
- **stdio環境変数:** 設定ファイルで指定した環境変数がstdioサーバーに渡らないバグ（Issue #64）
- **JSONパラメータ型強制:** 数値風文字列が数値に自動変換される問題
- **MCP SDKへの依存:** `@modelcontextprotocol/sdk` のバグ影響を直接受ける。`sdk-patches.ts` でパッチ適用中
- **Windowsサポート:** ドキュメントはあるが、UNIXソケット前提のデーモンモードはWindowsで制約あり
- **macOS daemon:** macOS 26 (Tahoe) でバックグラウンド起動が失敗する問題報告あり

### 深掘り候補（コードリーディング対象）

| 対象 | ファイルパス | 理由 |
|---|---|---|
| **CLI生成テンプレートエンジン** | `src/cli/generate/template.ts`, `src/cli/generate/tools.ts` | generate-cliの核心。どのようにMCPスキーマからCLIコードを生成するか |
| **トランスポート生成・OAuth統合** | `src/runtime/transport.ts` | HTTP/stdio/OAuthの分岐と自動昇格の実装詳細 |
| **関数呼び出し構文パーサー** | `src/cli/call-expression-parser.ts` | acornベースのカスタムパーサー設計 |
| **デーモンプロトコル** | `src/daemon/protocol.ts`, `src/daemon/client.ts` | UNIXソケット上のJSON-RPCプロトコル仕様 |
| **設定正規化** | `src/config-normalize.ts` | snake_case/camelCase両対応、URL正規化の実装 |
| **エディタ設定パーサー** | `src/config/imports/external.ts` | 各エディタのJSON/TOML/JSONC形式の統一パース |
| **SDK パッチ** | `src/sdk-patches.ts` | MCP SDKのどのバグに対してパッチを当てているか |
| **エラー分類器** | `src/error-classifier.ts` | auth/offline/http/runtimeエラーの判別ロジック |
