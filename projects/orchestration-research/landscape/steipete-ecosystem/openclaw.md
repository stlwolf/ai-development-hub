---
name: OpenClaw
repo: openclaw/openclaw
last_reviewed: 2026-02-25
category: personal-ai-assistant-platform
---

## OpenClaw 調査結果

### 基本情報

- **リポジトリ:** <https://github.com/openclaw/openclaw>
- **言語:** TypeScript 85.4%, Swift (macOS/iOS app)
- **Stars:** 224,553 (2026-02-25時点)
- **Forks:** 42,900+
- **Contributors:** 370+ (900+との記述もあり)
- **最終更新:** v2026.2.23 (2026-02-24リリース) / daily commit
- **ライセンス:** MIT
- **一言で:** 自前デバイスで動くマルチチャネル対応のパーソナルAIアシスタント基盤

### これは何か・何を解決するのか

OpenClawは、Peter Steinberger（steipete）が2025年11月に個人プロジェクトとして開始した、**ローカルファーストのパーソナルAIアシスタント**。

**解決する問題:**

- ChatGPTやClaude.aiは「聞いたことに答える」受動的チャットボット。OpenClawは「実際にタスクを実行する」能動的エージェント
- メッセージングプラットフォームは分散しており、統一的なAIインターフェースがない
- クラウドAIサービスにデータを預けたくないが、AIの利便性は欲しい
- 24/7稼働するパーソナルAIが欲しいが、セルフホストの設定が難しい

**ターゲットユーザー:**

- 技術力があり、自分のデバイスでAIアシスタントを運用したい個人開発者・パワーユーザー
- 複数のメッセージングプラットフォームを統一的にAI処理したいユーザー
- データプライバシーを重視するユーザー

**注意:** 作者自身が「コマンドラインを理解できない人には危険すぎるプロジェクト」と述べている。非技術者向けではない。

**歴史:** Clawd → Clawdbot → Moltbot（Anthropicの商標要求で改名）→ OpenClaw（2026-01-30〜）。2026年1月下旬にMoltbook（AIエージェント専用SNS）の爆発的流行と連動し、3日間で60,000 Starsを獲得。Wikipedia記事あり。

**現在の状況:** 2026-02-14にSteipete本人がOpenAIへの参画を発表。OpenClawはオープンソース財団に移管予定。OpenAIがスポンサーに。

### 設計思想・アーキテクチャ

#### 核となる設計判断

VISION.mdから読み取れる明確な設計哲学:

1. **ローカルファースト:** Gateway（制御プレーン）は`ws://127.0.0.1:18789`にバインド。データは`~/.openclaw/`にローカル保存
2. **シングルユーザー信頼モデル:** マルチテナントではなく「1人のオペレーター + 複数エージェント」モデル。Gateway認証を通過したクライアントは信頼済みオペレーター扱い
3. **チャネル非依存:** プロダクトは「アシスタント」であり、Gatewayは「制御プレーン」。メッセージングチャネルは入出力サーフェスにすぎない
4. **コアはリーン:** オプション機能はプラグイン/スキル/拡張で提供。コアへの追加は意図的に高いバー
5. **ターミナルファースト:** セットアップは明示的。セキュリティ判断をユーザーから隠す利便性ラッパーは拒否

#### アーキテクチャ概要

```
WhatsApp / Telegram / Slack / Discord / Google Chat / Signal / iMessage / ...
│
▼
┌───────────────────────────────┐
│            Gateway            │
│       (WS制御プレーン)         │
│     ws://127.0.0.1:18789      │
└──────────────┬────────────────┘
               │
├─ Pi agent (RPC) ← @mariozechner/pi-agent-core
├─ CLI (openclaw …)
├─ WebChat UI / Control UI
├─ macOS app (メニューバー)
└─ iOS / Android nodes (デバイスアクション)
```

#### ディレクトリ構造（深度2レベル）

```
openclaw/
├── src/                    # メインソースコード
│   ├── gateway/            # WS制御プレーン
│   ├── agents/             # エージェントランタイム
│   ├── sessions/           # セッション管理
│   ├── channels/           # チャネル共通ロジック
│   ├── routing/            # メッセージルーティング
│   ├── plugins/            # プラグインランタイム
│   ├── plugin-sdk/         # プラグインSDK（npm公開）
│   ├── config/             # 設定スキーマ（TypeBox）
│   ├── security/           # セキュリティポリシー
│   ├── memory/             # メモリ機能
│   ├── browser/            # ブラウザ制御（Playwright/CDP）
│   ├── canvas-host/        # Canvas + A2UI
│   ├── media/              # メディアパイプライン
│   ├── telegram/discord/slack/signal/whatsapp/imessage/  # 個別チャネル
│   ├── cli/commands/wizard/ # CLI/ウィザード
│   ├── tui/                # TUI（pi-tui使用）
│   ├── tts/                # テキスト読み上げ
│   ├── hooks/              # フック機構
│   ├── cron/               # cron/スケジュール実行
│   ├── pairing/            # デバイスペアリング
│   └── infra/              # インフラ基盤（HTTP, WS, net等）
├── extensions/             # プラグイン（ワークスペースパッケージ）
│   ├── msteams/matrix/zalo/zalouser/  # 拡張チャネル
│   ├── memory-core/        # デフォルトメモリプラグイン
│   ├── memory-lancedb/     # ベクトルDB版メモリ
│   ├── voice-call/         # 音声通話
│   ├── copilot-proxy/      # Copilotプロキシ
│   ├── diagnostics-otel/   # OpenTelemetry診断
│   ├── llm-task/           # LLMタスク分岐
│   ├── feishu/line/irc/nostr/twitch/synology-chat/ # 追加チャネル
│   └── ...                 # 38以上のextension
├── skills/                 # バンドルスキル（53個）
│   ├── mcporter/           # MCP統合
│   ├── coding-agent/       # コーディングエージェント
│   ├── github/             # GitHub操作
│   ├── obsidian/notion/    # ノートアプリ連携
│   ├── weather/            # 天気
│   └── ...                 # 53以上のスキル
├── apps/                   # コンパニオンアプリ
│   ├── macos/              # macOSメニューバーアプリ（Swift）
│   ├── ios/                # iOS node（Swift）
│   ├── android/            # Android node（Kotlin）
│   └── shared/OpenClawKit/ # 共有Swiftライブラリ
├── ui/                     # Web UI（Control UI + WebChat）
├── packages/               # 内部パッケージ
├── vendor/a2ui/            # A2UI vendored
└── docs/                   # Mintlifyドキュメント
```

#### プラグインアーキテクチャ（npmパッケージ + ローカル拡張）

Plugin SDKは`openclaw/plugin-sdk`としてnpmから配布。`src/plugin-sdk/index.ts`は非常に大きなexport surfaceを持ち、チャネル実装に必要な型・ユーティリティを一式提供:

- **ChannelPlugin:** チャネル実装の中心インターフェース。各アダプタ（Messaging, Setup, Auth, Config, Status, Pairing, Security等）をコンポーズ
- **プラグインHTTPルート:** `registerPluginHttpRoute`で独自HTTPエンドポイント追加可
- **Webhookターゲット:** `registerWebhookTarget`で外部Webhook受信
- **ランタイム:** `PluginRuntime`インターフェースで`log/error/exit`を抽象化

**配布方法:** extensions/配下のプラグインは各自`package.json`を持つワークスペースパッケージ。ランタイムdepsは`dependencies`に、`openclaw`は`devDependencies`か`peerDependencies`に配置。jiti aliasで`openclaw/plugin-sdk`を解決。

#### メモリプラグインスロット設計

メモリは**排他的シングルスロット**設計。`plugins.slots.memory`で切り替え:

- `memory-core`（デフォルト）: ファイルベースのMarkdown記憶検索
- `memory-lancedb`: LanceDBベクトルDBによるセマンティック検索。OllamaローカルまたはOpenAI埋め込みに対応
- `"none"`: 無効化

VISION.mdの記述: "Today we ship multiple memory options; over time we plan to converge on one recommended default path."

`sqlite-vec`は`package.json`のdependenciesに`"sqlite-vec": "0.1.7-alpha.2"`として含まれており、core側でも軽量ベクトル検索基盤として使用されている模様。

#### MCP統合（mcporter経由）

VISION.mdで**意図的にMCPランタイムをコアに組み込まない**と宣言:

> OpenClaw supports MCP through `mcporter`: https://github.com/steipete/mcporter
> This keeps MCP integration flexible and decoupled from core runtime

- ブリッジモデルでGateway再起動なしにMCPサーバー追加/変更可能
- コアのツール/コンテキストサーフェスをリーンに保つ
- MCPのchurn（破壊的変更）がコアの安定性・セキュリティに波及しない

mcporterはOpenClawのスキル（`skills/mcporter/`）として統合。CLI経由でMCPサーバーの検出・呼び出し・OAuth認証・TypeScript生成が可能。

#### チャネル対応

**ビルトイン（src/内）:** WhatsApp (Baileys), Telegram (grammY), Slack (Bolt), Discord (discord.js), Signal (signal-cli), iMessage (legacy), LINE

**拡張（extensions/）:** BlueBubbles (iMessage推奨), Microsoft Teams, Matrix, Google Chat, Zalo, Zalo Personal, Feishu, IRC, Nostr, Twitch, Mattermost, Nextcloud Talk, Synology Chat, Tlon, WebChat

**合計:** 20以上のメッセージングプラットフォーム対応。

#### セキュリティ設計

SECURITY.mdは非常に詳細（約300行）で、明確なトラストモデルを定義:

- **デフォルト安全:** DMはpairing制（未知の送信者にはペアリングコード表示、`openclaw pairing approve`で許可）
- **明示的knob:** `dmPolicy="open"`、`dangerouslyAllowPrivateNetwork`等のリスク設定は接頭辞で明示
- **サンドボックス:** 非mainセッション用にDocker sandboxモード（`agents.defaults.sandbox.mode: "non-main"`）
- **exec制御:** ホスト上exec、obfuscated command検出、allowlist判定
- **Gateway保護:** デフォルトloopbackバインド、Tailscale Serve/Funnelでの安全な外部公開
- **セキュリティ監査CLI:** `openclaw security audit --deep --fix`
- **detect-secrets:** CI/CDで自動シークレット検出

### 機能一覧

#### Core

| 機能 | 概要 | 場所 |
|------|------|------|
| Gateway WS制御プレーン | セッション、プレゼンス、設定、cron、Webhook、Control UI、Canvas hostを統合するWebSocket制御プレーン | `src/gateway/` |
| Pi agentランタイム | RPCモードのエージェント実行エンジン（ツールストリーミング、ブロックストリーミング） | `src/agents/`, pi-agent-core依存 |
| セッションモデル | main（DM）/group分離、activation mode、queue mode、reply-back | `src/sessions/` |
| マルチエージェントルーティング | チャネル/アカウント/ピアをワークスペース+セッション隔離されたエージェントにルーティング | `src/routing/` |
| メディアパイプライン | 画像/音声/動画、文字起こし、サイズ制限、一時ファイルライフサイクル | `src/media/`, `src/media-understanding/` |
| 設定システム | TypeBoxスキーマベース、`openclaw.json`（JSON5対応）、CLI config set/get/unset | `src/config/` |
| プラグインSDK | npmパッケージ配布のPlugin SDK。チャネル・ツール・webhook等のAPIを提供 | `src/plugin-sdk/` |
| CLIサーフェス | gateway, agent, send, wizard, doctor, onboard, channels, config, pairing等 | `src/cli/`, `src/commands/` |
| TUI | ターミナルUI（pi-tuiベース） | `src/tui/` |

#### Differentiator

| 機能 | 概要 | 場所 |
|------|------|------|
| マルチチャネルInbox | 20+メッセージングプラットフォーム統合（WhatsApp, Telegram, Slack, Discord, Signal, iMessage, Teams, Matrix, LINE, IRC等） | `src/*/`, `extensions/*/` |
| メモリプラグインスロット | 排他的シングルスロット設計。core(ファイル)またはLanceDB(ベクトル)から選択 | `extensions/memory-core/`, `extensions/memory-lancedb/` |
| Voice Wake + Talk Mode | macOS/iOS/AndroidでElevenLabs連携の常時音声認識・会話 | `extensions/talk-voice/`, `extensions/voice-call/` |
| Live Canvas + A2UI | エージェント駆動のビジュアルワークスペース | `src/canvas-host/`, `vendor/a2ui/` |
| ブラウザ制御 | Playwright/CDP経由の専用Chrome/Chromiumインスタンス制御 | `src/browser/` |
| セッション間通信 | sessions_list/sessions_history/sessions_sendツールでエージェント間協調 | `src/sessions/` |
| スキルプラットフォーム（ClawHub） | 5,700+のコミュニティスキル。バンドル/マネージド/ワークスペーススキル | `skills/`, ClawHub |
| MCP統合（mcporter） | MCPブリッジモデルでGateway再起動不要のMCPサーバー統合 | `skills/mcporter/` |
| DMペアリング | 未知送信者のDMにペアリングコードを要求するデフォルトセキュリティ | `src/pairing/` |
| Dockerサンドボックス | 非mainセッション用のper-session Dockerサンドボックス | `Dockerfile.sandbox*` |
| コンパニオンアプリ | macOSメニューバー + iOS/Android node | `apps/` |
| Nodeプロトコル | デバイスローカルアクション（camera, screen recording, system.run, location.get）のリモート実行 | `src/node-host/` |
| オンボーディングWizard | ステップバイステップのセットアップウィザード | `src/wizard/` |

#### Utility

| 機能 | 概要 | 場所 |
|------|------|------|
| Cron + Wakeups | スケジュール実行 | `src/cron/` |
| Webhook受信 | 外部トリガー受信 | `src/hooks/` |
| Gmail Pub/Sub | Gmailトリガー | ドキュメントのみ |
| Doctor | 設定検証・マイグレーション・セキュリティ監査 | `src/commands/` |
| プレゼンス/タイピングインジケータ | チャネルごとのオンラインステータス・入力中表示 | `src/channels/` |
| モデルフェイルオーバー | OAuth vs APIキーのプロファイルローテーション + フォールバックチェーン | `src/providers/` |
| セッションプルーニング/コンパクション | コンテキスト長管理の自動要約 | `src/agents/` |
| 使用量トラッキング | モデルごとのトークン/コスト追跡 | ランタイム内蔵 |
| チャットコマンド | `/status`, `/new`, `/think`, `/verbose`等のインライン制御 | 各チャネル |
| Tailscale統合 | Serve/Funnelでの安全なリモートアクセス | `src/gateway/` |
| ロギング + 診断 | tslog, OpenTelemetry extension, redact機能 | `src/logging/`, `extensions/diagnostics-otel/` |
| i18n (zh-CN) | AI生成中国語翻訳パイプライン | `docs/.i18n/` |
| ポーリング/投票 | グループ内投票機能 | `src/polls.ts` |

### 特徴的な点・注目ポイント

1. **マルチチャネル統合の規模:** 20+プラットフォームは他のパーソナルAIプロジェクトで類を見ない。WhatsApp（Baileys）、Telegram（grammY）、Slack（Bolt）、Discord（discord.js）等、各プラットフォーム固有のSDKを直接使用し、公式API制約内で最大限の機能を引き出している

2. **「強いデフォルト + 明示的knob」セキュリティモデル:** SECURITY.mdの質と詳細度は個人プロジェクトとして異例。`dangerously*`接頭辞による明示的リスク受容パターン、信頼モデルの明文化（「マルチテナントではない」宣言）、`openclaw doctor`によるセキュリティ監査CLIなど、セキュリティを利便性と引き換えにしない哲学が一貫

3. **Gateway + Node分離アーキテクチャ:** 「Gateway（制御プレーン）」と「Node（デバイスアクション実行）」を明確に分離。LinuxサーバーでGatewayを24/7稼働させつつ、macOS/iOS/AndroidのNodeからデバイス固有アクション（カメラ、スクリーンレコード、通知等）を実行する構成。TCC permissionもNodeプロトコル経由で正しくハンドリング

4. **プラグインスロット設計:** メモリは排他スロット。「1つだけアクティブ」制約で複数実装の衝突を防止。将来的に1つのデフォルトに収束予定（VISION.md）

5. **MCPブリッジ戦略:** 他のプロジェクトがMCPをコアに組み込む中、OpenClawは意図的に`mcporter`外部ブリッジ経由。「MCPのchurn（破壊的変更）からコアを守る」という明示的理由。スキルとしてインストールするため、使わないユーザーへの影響ゼロ

6. **pi-agent-core依存:** エージェントランタイムは`@mariozechner/pi-agent-core`（外部パッケージ）に依存。Mario Zechnerとの協業で、Pi agent runtimeはRPCモードで動作

### 使い方・典型的なワークフロー

#### インストール

```bash
# Node >= 22 が必要
npm install -g openclaw@latest

# オンボーディングウィザード（推奨パス）
openclaw onboard --install-daemon

# Gateway起動
openclaw gateway --port 18789 --verbose
```

#### 基本構成（`~/.openclaw/openclaw.json`）

```jsonc
{
  "agent": {
    "model": "anthropic/claude-opus-4-6"
  },
  "channels": {
    "telegram": {
      "botToken": "123456:ABCDEF"
    },
    "discord": {
      "token": "1234abcd"
    }
  }
}
```

#### 典型的なワークフロー

1. `openclaw onboard`でウィザードに従い、モデルプロバイダー認証 → チャネル設定 → スキルインストール
2. `openclaw gateway --install-daemon`でlaunchd/systemdサービスとしてバックグラウンド稼働
3. WhatsApp/Telegram等からメッセージを送ると、Gatewayがエージェントを呼び出して応答
4. `openclaw agent --message "Ship checklist" --thinking high`でCLIから直接エージェント呼び出し
5. `openclaw doctor`で設定の健全性チェック・マイグレーション

#### スキル管理

```bash
# ClawHubからスキルインストール
openclaw skill add steipete/mcporter

# ワークスペーススキル
# ~/.openclaw/workspace/skills/<name>/SKILL.md にMarkdownファイルを配置
```

### エコシステム・実利用状況

#### 採用事例

- GitHub上224K+ Stars、42K+ Forks（2026-02-25時点）
- Cisco AI研究チームが検証・セキュリティレポート公開
- シリコンバレー企業・中国企業での利用報告（Wikipedia引用）
- DeepSeekモデル + 中国国内メッセージアプリ（Zalo等）への適応
- IBM Think、WIRED、The Verge、TechCrunch、CNBC等の主要メディアで取り上げ

**出典:**
- [IBM Think (2026-01-29)](https://www.ibm.com/think/news/clawdbot-ai-agent-testing-limits-vertical-integration)
- [WIRED (2026-02-03)](https://www.wired.com/story/i-infiltrated-moltbook-ai-only-social-network/)
- [TechCrunch (2026-01-28)](https://techcrunch.com/2026/01/27/everything-you-need-to-know-about-viral-personal-ai-assistant-clawdbot-now-moltbot/)

#### 盛り上がりの文脈

- **2025-11:** 個人プロジェクトとしてGitHubに公開
- **2026-01-27:** Moltbook（AIエージェントSNS）の爆発的流行と連動し急上昇
- **2026-01-30:** OpenClawに改名。3日間で60,000 Stars獲得
- **2026-02-02:** 140K Stars到達。ClawCon（SF）開催
- **2026-02-14:** Steinberger氏がOpenAI参画を発表
- **2026-02-24:** 224K Stars。Wikipedia記事あり

#### コミュニティ

- **Discordサーバー:** <https://discord.gg/clawd>（活発）
- **GitHub Issues:** 7,435 open（活発すぎる）
- **Reddit:** r/openclaw、r/LocalLLaMA等で活発な議論
- **ClawHub:** 5,700+コミュニティスキル（日40-60個新規追加）
- **リリース頻度:** ほぼ毎日。CalVer（`YYYY.M.D`）採用

#### 周辺ツール

- **ClawHub:** 公式スキルレジストリ（<https://clawhub.com>）
- **mcporter:** MCP統合CLI（<https://mcporter.dev>）
- **nix-openclaw:** Nix宣言的設定（<https://github.com/openclaw/nix-openclaw>）
- **openclaw-ansible:** 自動デプロイ
- **ComposioHQ/composio-openclaw:** Composioプラグイン統合フォーク
- **ComposioHQ/secure-openclaw:** セキュリティ強化版

#### 評判

**ポジティブ:**
- 「マルチチャネル統合の完成度が高い」（多数のReddit報告）
- 「設定を理解すれば非常に強力」（[Reddit r/openclaw](https://www.reddit.com/r/openclaw/comments/1r71you/))
- Platformerレビュー: 柔軟性とオープンソースライセンスが強み

**ネガティブ:**
- [Ciscoブログ (2026-01-28)](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare): 「セキュリティ上は悪夢」
- メモリ管理の複雑さ（2層メモリシステムの手動構築が必要、state loss問題）
- 月額コスト$50-80（APIコスト最適化必要）
- 設定の学習コストが高い（初期セットアップでの挫折報告多数）
- MoltMatch事件（AIエージェントが無断でデーティングプロフィール作成）[Wikipedia]

### 他ツールとの比較・ポジショニング

#### vs Agent Orchestrator（Composio）

| 観点 | OpenClaw | Composio |
|------|----------|----------|
| カテゴリ | パーソナルAIアシスタント | ツール統合プラットフォーム（SaaS） |
| MCP対応 | mcporter経由のブリッジ | ネイティブ統合 |
| 認証管理 | ローカル設定ファイル | マネージドOAuth（500+ツール） |
| 運用モデル | セルフホスト | SaaS + セルフホスト |
| 統合形態 | ComposioがOpenClawのフォーク（`composio-openclaw`）を提供 | OpenClawのプラグインとして統合可能 |
| 強み | チャネル統合、エンドユーザー体験 | 認証の簡素化、ツール数 |

Composioは**OpenClawを補完するツール統合レイヤー**として位置づけ。競合ではなく共生関係。

#### vs Mastra

| 観点 | OpenClaw | Mastra |
|------|----------|--------|
| カテゴリ | パーソナルAIアシスタント | AIアプリケーション開発フレームワーク |
| ターゲット | エンドユーザー（パワーユーザー） | 開発者 |
| 出発点 | 「自分のAIアシスタントが欲しい」 | 「AIアプリを構築したい」 |
| ランタイム | 完成されたGateway + チャネル統合 | フレームワーク（自分で組み立て） |
| メモリ | プラグインスロット（LanceDB等） | フレームワーク提供のメモリAPI |
| MCP | mcporterブリッジ | ネイティブサポート |

OpenClawは**完成品のアシスタント**、Mastraは**アシスタントを作るためのフレームワーク**。レイヤーが異なる。

#### vs Claude Code

DataCamp、AIFreeAPI等の比較記事多数。OpenClawは「ライフオートメーション」、Claude Codeは「コーディングエージェント」。直接競合ではなく、併用推奨。

### 制約・注意点

1. **セキュリティリスク:** Ciscoが「セキュリティ上は悪夢」と評価。スキルレジストリの審査不足、prompt injection脆弱性。設定ミスによるデータ漏洩リスク
2. **設定の複雑さ:** 初期セットアップの学習コストが高い。非技術者には不適
3. **コスト:** 無料だがAPIコスト（月$50-80が一般的）。モデルルーティング最適化が必要
4. **メンテナンス体制の変化:** Steinberger氏がOpenAI参画。財団移管予定だが、メンテナンス体制の安定性は未確定
5. **急成長に伴う品質課題:** 7,435 openのIssues。急速な機能追加でテスト・安定性に課題
6. **WhatsApp等のグレーゾーン:** Baileys（非公式WhatsApp API）使用。公式APIではないため、アカウントBANリスク
7. **メモリの手動管理:** メモリシステムは強力だが、手動メンテナンス（週次cleanup等）が必要
8. **RAM消費:** 常時稼働で約1GB RAM消費（[DataCamp比較記事](https://datacamp.com/blog/openclaw-vs-claude-code)）

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 注目理由 |
|------|------|----------|
| Gatewayサーバー実装 | `src/gateway/` | WS制御プレーンの設計パターン |
| エージェントランタイム統合 | `src/agents/` | Pi agent core との統合パターン |
| プラグインローダー | `src/plugins/` | プラグイン検出・ロード・ライフサイクル |
| チャネルプラグイン型定義 | `src/channels/plugins/types.ts`, `types.plugin.ts` | チャネル抽象化の全貌 |
| メモリスロット実装 | `extensions/memory-core/`, `extensions/memory-lancedb/` | 排他スロット設計パターン |
| 設定スキーマ | `src/config/config.ts` | TypeBoxベースの設定定義 |
| セキュリティモジュール | `src/security/` | DM policy、exec制御の実装 |
| セッション管理 | `src/sessions/` | multi-agent routing、session pruning |
| ルーティング | `src/routing/` | チャネル→エージェントのルーティングロジック |
| Canvas + A2UI | `src/canvas-host/`, `vendor/a2ui/` | エージェント駆動ビジュアルUIの仕組み |
