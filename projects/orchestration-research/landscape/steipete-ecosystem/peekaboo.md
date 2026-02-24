---
name: Peekaboo
repo: steipete/Peekaboo
last_reviewed: 2026-02-24
category: screen-capture-ai-gui-automation
---

## Peekaboo 調査結果

### 基本情報

- **リポジトリ:** <https://github.com/steipete/Peekaboo>
- **公式サイト:** <https://www.peekaboo.boo/> / <https://www.peekaboo.dev/>
- **言語:** Swift 6.2（コアCLI/アプリ）、JavaScript/Node.js（MCPラッパー）
- **Stars:** 約2,360 / Forks: 約154
- **最終更新:** 2026-01-18（v3.0.0-beta4）
- **ライセンス:** MIT
- **作者:** Peter Steinberger（steipete） — PSPDFKit創業者、iOS/macOS開発の著名エンジニア
- **一言で:** macOS専用のAIエージェント向けスクリーンキャプチャ＋GUI自動化ツールキット

### これは何か・何を解決するのか

**目的:**
AIエージェント（Claude、Cursor、Claude Code等）に「目」と「手」を与えるツール。macOSのスクリーンキャプチャ、AIによるビジュアル分析、そして完全なGUI操作を一つのCLI/MCPサーバに統合する。

**解決する問題:**

1. **エージェントの視覚的盲目:** AIコーディングエージェントはUIの状態を「見る」ことができない。ビルドエラー、UIバグ、ダイアログ等を人間に確認を求める必要がある。Peekabooはスクリーンショット取得 + AI分析で自律的なデバッグループを実現する
2. **macOSネイティブ操作の欠如:** Playwrightはブラウザ内に限定される。macOSネイティブアプリ（メニューバー、Dock、ダイアログ、Spaces）を横断する自動化ツールが不足していた
3. **MCP vs CLI の二律背反:** v2でCLI-first設計に移行し、MCPの常時ロードによるコンテキスト汚染を回避。CLIはオンデマンド呼び出しで済む

**ターゲットユーザー:**
- AIエージェント開発者（Claude Desktop、Cursor、Claude Code利用者）
- macOS上でGUI自動化を行いたい開発者
- E2Eテスト、ワークフロー自動化の構築者

### 設計思想・アーキテクチャ

#### 設計原則（作者ブログより）

1. **"Less is More"**: ツール数を最小限に保ちつつ各ツールを高機能にする。多くのエージェントは40ツール超で混乱するため
2. **Lenient Tool Calling**: パラメータ不正に対して厳格にエラーを返さず、意図を推測して処理する。エージェントはミスをするため、リトライループを避ける設計
3. **Fuzzy Window Matching**: "Chrome"で"Google Chrome - Peekaboo MCP"をマッチさせる。部分一致・大文字小文字無視
4. **CLI-first, MCP-optional**: v2でMCP-onlyからCLI-first設計に転換。「CLIはエージェントにとってMCPより呼びやすい」（Armin Ronacher "Code Is All You Need"の影響）

#### コアアーキテクチャ（v3）

```
┌─────────────────┐
│   Tachikoma     │  AI models + streaming（マルチプロバイダSDK）
└────────┬────────┘
         │
┌────────▼────────┐    ┌────────────────────┐    ┌────────────────────┐
│PeekabooAutomation│◄──►│PeekabooAgentRuntime │◄──►│ PeekabooVisualizer │
│ UI/system services│   │ Agent + MCP runtime │    │ Visual feedback    │
└────────┬────────┘    └──────────┬──────────┘    └──────────┬──────────┘
         │                        │                          │
         └───────────┬────────────┴──────────┬───────────────┘
                     ▼                       ▼
              ┌─────────────┐        ┌──────────────┐
              │ PeekabooCore│        │  Apps / CLI   │
              │ (umbrella)  │        │  consumers    │
              └─────────────┘        └──────────────┘
```

**主要モジュール:**

| モジュール | 役割 | 配置 |
|---|---|---|
| **PeekabooAutomation** | 全自動化コード。Accessibility、ScreenCaptureKit、設定、スナップショット管理 | `Core/PeekabooCore/` |
| **PeekabooAgentRuntime** | MCPツール、ToolRegistry、エージェントサービス、CLI/MCPフォーマッタ | `Core/PeekabooCore/` |
| **PeekabooVisualizer** | オーバーレイUI、ビジュアルフィードバック | `Core/PeekabooVisualizer/` |
| **PeekabooFoundation** | 基礎ユーティリティ | `Core/PeekabooFoundation/` |
| **PeekabooProtocols** | 共通プロトコル定義 | `Core/PeekabooProtocols/` |
| **Tachikoma** | AIプロバイダ統一SDK（OpenAI/Anthropic/Grok/Gemini/Ollama） | `Tachikoma/` (サブモジュール) |
| **AXorcist** | macOS Accessibility API ラッパー | `AXorcist/` (サブモジュール) |
| **Commander** | CLI引数パーサー | `Commander/` (サブモジュール) |
| **TauTUI** | ターミナルUI | `TauTUI/` (サブモジュール) |

#### v3のBridge Architecture

v3 beta2で導入された「Peekaboo Bridge」は、特権的な自動化操作を長寿命の**ブリッジホスト**（Peekaboo.app、またはClawdbot.app等の署名済みホスト）で実行し、CLIはUNIXソケット経由で接続する設計。コード署名TeamIDによるセキュリティ検証も備える。

**ブリッジ探索順序:** Peekaboo.app → Clawdbot.app → ローカルインプロセス

#### v3の自然言語エージェントフロー

`peekaboo agent "..."` または `peekaboo "..."` で自然言語による複数ステップ自動化が可能。内部でネイティブツール（see, click, type等）をチェーンし、AI（デフォルトgpt-5.1）がタスクを解釈・実行する。

```bash
peekaboo "Open Notes and create a TODO list with three items"
```

エージェントループは `DESKTOP_STATE`（フォーカス中アプリ/ウィンドウタイトル、カーソル位置、クリップボードプレビュー）をコンテキストとして注入し、状況認識を改善する。

`--chat` フラグでインタラクティブチャットモードに入り、連続的な会話形式での自動化も可能（v3設計中）。

### 機能一覧

#### Core（中核機能）

| 機能 | コマンド | 概要 |
|---|---|---|
| スクリーンキャプチャ | `image` | ScreenCaptureKit利用。スクリーン/ウィンドウ/メニューバーのピクセル完全キャプチャ。Retina 2x対応 |
| UI要素検出・スナップショット | `see` | アプリのUIをキャプチャし、Accessibility情報と合わせてUI要素マップ（ID付き）を生成 |
| クリック操作 | `click` | 要素ID、ラベル、座標でクリック。スナップショットベースで自動フォーカス |
| テキスト入力 | `type` | テキスト入力。クリア、遅延指定可能 |
| キー操作 | `press`, `hotkey` | キーシーケンスとModifierコンボ（cmd+shift+t等） |
| スクロール | `scroll` | 要素・方向・ティック数指定 |
| 自然言語エージェント | `agent` | マルチステップ自動化。`--model`、`--dry-run`、`--resume`、`--max-steps`対応 |
| MCPサーバ | `mcp serve` | Claude Desktop / Cursor向けMCPサーバとして動作 |

#### Differentiator（差別化機能）

| 機能 | コマンド | 概要 |
|---|---|---|
| メニューバー構造化JSON取得 | `menu`, `menubar` | アプリメニュー全体の列挙、キーボードショートカット発見、メニューエクストラ操作。CGWindow + AXフォールバック |
| Dock操作 | `dock` | Dockアイテムの起動、右クリック、表示/非表示 |
| ダイアログ駆動 | `dialog` | システムダイアログ（Open/Save等）の検出・操作・ファイル選択 |
| ウィンドウ管理 | `window` | リスト/移動/リサイズ/フォーカス/バウンド設定。Spaces間移動対応 |
| Spaces操作 | `space` | macOS Spacesのリスト/切り替え/ウィンドウ移動 |
| アプリ管理 | `app` | 起動/終了/再起動/切り替え/リスト |
| スワイプ・ドラッグ | `swipe`, `drag` | ジェスチャースタイルのドラッグ、Dock/ゴミ箱へのD&D |
| マルチAIプロバイダ | `config` | OpenAI GPT-5.1、Claude 4.x、Grok 4-fast、Gemini 2.5、Ollama（ローカル） |
| ペースト | `paste` | クリップボード設定 → Cmd+V → 元に復元の一連の流れ |
| スクリプト実行 | `run` | `.peekaboo.json`形式の自動化スクリプト再生 |
| ヘッドレスデーモン | `daemon` | start/stop/status。インメモリスナップショット、移動追従のクリック/タイプ調整 |

#### Utility（ユーティリティ）

| 機能 | コマンド | 概要 |
|---|---|---|
| 列挙 | `list` | アプリ/ウィンドウ/スクリーン/メニューバー/パーミッション一覧 |
| ツール検査 | `tools` | Peekabooネイティブツールの詳細表示 |
| 設定管理 | `config` | 資格情報/プロバイダ/設定の管理 |
| パーミッション | `permissions` | Screen Recording / Accessibility権限の確認・付与 |
| スリープ | `sleep` | ステップ間のミリ秒遅延 |
| クリーン | `clean` | スナップショット/キャッシュの整理 |
| カーソル移動 | `move` | クリックなしのカーソル位置決め |

### 特徴的な点・注目ポイント

#### 1. スナップショットベースの自動化パイプライン

`peekaboo see` がUI状態のスナップショットを作成し、後続の `click`, `type`, `scroll` がそのスナップショットIDを参照して要素を特定する。これにより：
- 要素検出結果のキャッシュ（~1.5秒間のAXトラバーサルキャッシュ）
- ウィンドウ移動追従（移動後もスナップショット内の要素座標を再解決）
- エージェントが管理するIDが最小限で済む

スナップショットは `~/.peekaboo/snapshots/<bundleID>/` に保存され、`snapshot.json`（UIマップ+ウィンドウメタデータ）、`raw.png`、`annotated.png` で構成される。

#### 2. メニューバーの構造化取得（CGWindow + AX ハイブリッド）

macOSのメニューバー（メニューエクストラ含む）を構造化JSONで取得できる。CGWindow APIとAccessibility APIのフォールバックを組み合わせ、サードパーティアプリ（Trimmy等）のメニューエクストラも検出。`--verify` でポップオーバーやOCRによる確認も可能。

#### 3. Peekaboo Bridge（UNIX ソケットベースの特権分離）

v3 beta2で導入。Screen Recording / Accessibility権限を持つ署名済みアプリ（Peekaboo.app）がブリッジホストとして動作し、CLIはUNIXソケット経由で接続する。これにより：
- バックグラウンドデーモンからの操作が可能
- コード署名TeamIDによるセキュリティ
- 権限管理の一元化

#### 4. マルチプロバイダAI統合（Tachikoma）

AI機能はサブモジュール `Tachikoma` に分離されている（223 stars）。DI（依存性注入）パターンで、テスト可能かつプロバイダの追加が容易。

```swift
let provider = try AIConfiguration.fromEnvironment()
let model = try provider.getModel("gpt-5.1")
```

対応プロバイダ: OpenAI（GPT-5.1/4.1/4o）、Anthropic（Claude 4.x）、xAI（Grok 4-fast）、Google（Gemini 2.5）、Ollama（ローカル）、Azure OpenAI

#### 5. ScreenCaptureKit によるフォーカス非変更キャプチャ

AppleScriptの `screencapture` はフォーカスを奪うが、ScreenCaptureKit APIはウィンドウマネージャに直接アクセスするため、対象アプリのフォーカスを変更せずにキャプチャ可能。45ms程度で全画面キャプチャが完了する。

#### 6. Visualizer（視覚フィードバック）

クリックやスクロール等の操作時にオーバーレイアニメーションで視覚フィードバックを提供。`VisualizerEvent` を `NSDistributedNotificationCenter` 経由で送信し、Peekaboo.appが稼働中の場合にオーバーレイを表示。非稼働時はサイレントにドロップ。

### 使い方・典型的なワークフロー

#### インストール

```bash
# Homebrew（CLI + macOSアプリ）
brew install steipete/tap/peekaboo

# MCPサーバ（Node 22+）
npx -y @steipete/peekaboo
```

#### ワークフロー1: スクリーンショット + AI分析

```bash
# 全画面Retinaキャプチャ
peekaboo image --mode screen --retina --path ~/Desktop/screen.png

# アプリ指定キャプチャ + AI分析（ワンコマンド）
peekaboo image --app "Safari" --analyze "このページに何が表示されている？"
```

#### ワークフロー2: UI要素の特定とクリック

```bash
# UIスナップショット取得（要素ID付きアノテーション生成）
peekaboo see --app Safari --json-output | jq -r '.data.snapshot_id' | read SNAPSHOT

# ラベルでクリック
peekaboo click --on "Reload this page" --snapshot "$SNAPSHOT"
```

#### ワークフロー3: 自然言語マルチステップ自動化

```bash
# 単発自然言語タスク
peekaboo "Open Notes and create a TODO list with three items"

# モデル指定
peekaboo agent --model claude-opus-4 "Safari で github.com を開いて Peekaboo を検索"

# ドライラン（実際の操作なし）
peekaboo agent --dry-run "デスクトップのファイルを整理"
```

#### ワークフロー4: MCPサーバとしてClaude Desktop/Cursorから利用

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": ["-y", "@steipete/peekaboo"],
      "env": {
        "PEEKABOO_AI_PROVIDERS": "openai/gpt-5.1,anthropic/claude-opus-4"
      }
    }
  }
}
```

#### ワークフロー5: 再現可能な自動化スクリプト

`.peekaboo.json` 形式のスクリプトを `peekaboo run` で実行。CI/CDパイプラインやテスト自動化に利用可能。

### エコシステム・実利用状況

#### 採用事例

- **Clawbot.ai / MoltBot**: steipeteが構築する macOS AI自動化プラットフォーム。Peekabooはそのエコシステムの中核コンポーネント ([source](https://clawbot.ai/ecosystem/peekaboo.html))
- **開発者のCI/CDデバッグ**: UIビルドの視覚確認をエージェントに委任するワークフローが主用途（作者ブログより）

#### 盛り上がりの文脈

- **2025-06**: v1リリース。MCPサーバとしてClaude Desktop向けスクリーンショットツールとして登場
- **2025-07**: v2.0リリース。CLI-first設計への転換。「MCPよりCLI」のコミュニティ潮流に乗る（Armin Ronacher "Code Is All You Need" からの影響を公言）
- **2025-11〜2026-01**: v3 beta。GUI自動化コマンド群の大量追加、自然言語エージェントフロー、Bridge Architecture導入
- **HN投稿**: [HN thread](https://news.ycombinator.com/item?id=44219988) で紹介（反応は限定的）
- **日本語コミュニティ**: Zenn/Qiitaでの言及は確認できず（2026-02時点）

#### コミュニティ

- GitHub Issues: 21件オープン（2026-02時点）
- Contributors: 10名
- リリース頻度: 活発（2025-06〜2026-01で v1→v2→v3-beta4）
- サブモジュール群も活発に更新（AXorcist v0.1.0、Commander v0.2.1、Tachikoma v0.1.0）

#### 周辺ツール（steipeteエコシステム）

| ツール | 役割 |
|---|---|
| **[Tachikoma](https://github.com/steipete/Tachikoma)** | Swift AIプロバイダSDK（223 stars） |
| **[AXorcist](https://github.com/steipete/AXorcist)** | macOS Accessibility APIラッパー（181 stars） |
| **[Terminator](https://github.com/steipete/Terminator)** | エージェント向け外部ターミナルMCP |
| **[macos-automator-mcp](https://github.com/steipete/macos-automator-mcp)** | AppleScript/JXA実行MCP |
| **[claude-code-mcp](https://github.com/steipete/claude-code-mcp)** | Claude CodeをCursorに統合するMCP |
| **[Poltergeist](https://github.com/nicktypson/poltergeist)** | ファイル監視 + 自動ビルドツール（Peekaboo開発で使用） |

#### 評判

- **肯定的**: "AIエージェントに目を与える"というコンセプトが明確。Swift ネイティブによる高速性（45msキャプチャ）。包括的なコマンド群（[Clawbot.ai評価](https://clawbot.ai/ecosystem/peekaboo.html): クリック成功率99.2%、AI要素精度96.8%を主張）
- **懐念的**: 独立したコミュニティフィードバックがほぼ存在しない。steipete自身のエコシステム（Clawbot/MoltBot）内での評価が中心。Reddit/X での実使用レポートは確認できず

### 他ツールとの比較・ポジショニング

#### vs Playwright MCP

| 観点 | Peekaboo | Playwright MCP |
|---|---|---|
| **対象** | macOS全体（ネイティブアプリ、メニューバー、Dock、Spaces） | Webブラウザ内のみ |
| **要素特定** | Accessibility API + AI ビジョン + スナップショット | DOM / ARIA スナップショット |
| **プラットフォーム** | macOS 15+ 専用 | クロスプラットフォーム |
| **フォーカス** | ScreenCaptureKitで非変更 | ブラウザ内で完結 |
| **エージェント統合** | CLI-first + MCP optional | MCP or CLI |
| **トークン効率** | AI分析を別エージェントに委任可能 | MCP:フルAXツリーがコンテキストに流入（CLIの4-10倍） |
| **成熟度** | beta（v3） | stable |

**位置づけ:** 競合ではなく補完関係。PlaywrightはWeb、PeekabooはネイティブmacOS。steipete自身も「Playwright MCPはMCPとして優秀」と評価。

#### vs SWE-agent ACI

| 観点 | Peekaboo | SWE-agent ACI |
|---|---|---|
| **対象** | macOS GUI全般 | コードリポジトリ操作 |
| **インターフェース** | ビジュアル（スクリーンショット + Accessibility） | テキスト（ファイルビューア、編集コマンド） |
| **目的** | GUIの視覚確認と操作 | コード修正のためのファイル操作 |
| **AI活用** | ビジョンモデルでUI理解 | LLMでコード理解 |

**位置づけ:** 完全に異なるレイヤー。SWE-agent ACIはコードレベルの操作に特化し、Peekabooはデスクトップレベルの操作に特化。両者を組み合わせることで、コード修正→UIビルド確認→コード再修正の自律ループが構成可能。

#### vs Anthropic Computer Use

| 観点 | Peekaboo | Anthropic Computer Use |
|---|---|---|
| **方式** | ネイティブAPI（Accessibility + ScreenCaptureKit） | スクリーンショット + 座標指定 |
| **精度** | Accessibility情報で要素を構造的に特定 | ピクセル座標に依存 |
| **プラットフォーム** | macOS専用 | クロスプラットフォーム（Docker推奨） |
| **速度** | 高速（45ms キャプチャ、10-50ms クリック） | スクリーンショット毎にVLM推論 |
| **メニューバー** | 構造化JSON取得可能 | スクリーンショットから推測 |

**位置づけ:** PeekabooはmacOSに特化することでAccessibility API活用の精度・速度を実現。Computer Useは汎用だが精度・速度で劣る。

### 制約・注意点

1. **macOS 15+（Sequoia）専用**: クロスプラットフォームは非対応。Windows/Linuxでは動作しない
2. **v3はベータ**: 3.0.0-beta4。既知のバグあり（CHANGELOGに詳述）。プロダクション用途にはリスク
3. **権限要求が重い**: Screen Recording + Accessibility の両方が必要。デーモン/バックグラウンドプロセスからは権限取得不可（macOSの制約。[Issue #940](https://github.com/clawdbot/clawdbot/issues/940)）
4. **ビルド環境の要求**: macOS 15+、Xcode 16+、Swift 6.2。Node 22+（MCPサーバ使用時）
5. **サブモジュール依存**: AXorcist、Commander、Tachikoma、TauTUI の4つのgitサブモジュールに依存。各々別リポジトリで管理される
6. **作者エコシステムへの依存度**: Tachikoma（AIプロバイダ）、AXorcist（Accessibility）、Commander（CLIパーサー）がすべてsteipete製。コミュニティが小さく、メンテナンスリスクがある
7. **独立コミュニティの薄さ**: 2,300+ starsだがReddit/X/Zenn/Qiitaでの実使用報告がほぼない。Clawbot/MoltBot内での利用が主
8. **AI APIキーが必要**: ビジョン分析・エージェント機能にはOpenAI/Anthropic等のAPIキーが必要（ローカルOllamaで回避可能）
9. **パフォーマンス**: 要素検出に200-800ms（AI分析含む）。大量の要素を持つアプリではAXトラバーサルのタイムアウトリスクあり（保守的制限を導入済み）

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 着目点 |
|---|---|---|
| スナップショットマネージャ | `Core/PeekabooCore/Sources/.../SnapshotManager.swift` | スナップショットの永続化・復元ロジック、UIマップ構造 |
| UIAutomationService | `Core/PeekabooCore/Sources/.../UIAutomationService.swift` | サービスオーケストレーションパターン、各Serviceへの委譲 |
| PeekabooAgentService | `Core/PeekabooCore/Sources/.../PeekabooAgentService.swift` | 自然言語→ツールチェーン変換、DESKTOP_STATE注入 |
| ScreenCaptureService | `Core/PeekabooCore/Sources/.../ScreenCaptureService.swift` | ScreenCaptureKit統合、フレームストリーム管理 |
| MenuService | `Core/PeekabooCore/Sources/.../MenuService.swift` | CGWindow + AX ハイブリッド検出、メニューエクストラ |
| Bridge通信 | `Core/PeekabooCore/Sources/.../Bridge/` | UNIXソケット通信、TeamID検証 |
| AXorcist | `AXorcist/Sources/` | Accessibility APIラッパー、チェーンクエリ、ファジーマッチ |
| Tachikoma | `Tachikoma/Sources/` | マルチプロバイダ統一インターフェース、DI設計 |
| MCPラッパー | `peekaboo-mcp.js` | クラッシュ復帰ロジック（指数バックオフ再起動） |
| CLIコマンド定義 | `Apps/CLI/Sources/PeekabooCLI/` | Commander統合、各コマンドの引数バインディング |
| poltergeist設定 | `poltergeist.config.json` | ファイル監視ベースの自動ビルド/テスト構成（steipete開発ワークフローの参考） |
