---
title: "Happy Coder × Cursor Agent: リモートモニタリング実現可能性調査"
date: 2026-02-23
status: research-complete
tags: [happy-coder, cursor-agent, remote-monitoring, fork-analysis]
next_step: フォーク作成 → Cursor対応の実装検証
---

# Happy Coder × Cursor Agent: リモートモニタリング実現可能性調査

## 動機

Cursorで指示を出して外出した後、スマホからエージェントの進捗を確認したい。Happy Coder（slopus/happy）はClaude Code向けにこれを実現しているが、Cursorでも同様のことが可能か。

## Happy Coder 概要

- **リポジトリ:** https://github.com/slopus/happy
- **Stars:** 13.1k / Forks: 999 / MIT
- **技術スタック:** TypeScript モノレポ（Yarn Workspaces）
- **対応CLIバックエンド:** Claude Code, Codex, Gemini, OpenCode

Happy CoderはAIコーディングエージェントのCLI出力をインターセプトし、E2E暗号化されたリレーサーバー経由でモバイル/Webクライアントに中継する。Local/Remoteモードの即時切替、プッシュ通知、音声コーディングなどを提供する。

### アーキテクチャ

```
CLI (cursor agent) → stdin/stdout capture → SessionProtocol変換 → E2E暗号化 → Relay Server → Mobile/Web App
```

### パッケージ構成

| パッケージ | 役割 |
|---|---|
| `happy-cli` | CLIラッパー。プロセス起動・ストリームキャプチャ・暗号化・サーバー送信 |
| `happy-app` | モバイル/Web UI（Expo + React Native）|
| `happy-server` | バックエンドリレーサーバー（Fastify + Socket.IO + Prisma） |
| `happy-agent` | リモートエージェント制御CLI |
| `happy-wire` | 共有プロトコル定義（Zodスキーマ） |

## Cursor Agent CLI の調査

### 発見: `cursor agent` サブコマンド

Cursor 2.5.20 に `cursor agent` サブコマンドが存在し、Claude Code CLIとほぼ同等のインターフェースを持つ。

```bash
cursor agent [prompt...]    # ターミナルでエージェント起動
cursor agent --print        # 非対話モード（stdout出力）
cursor agent --output-format stream-json  # JSON ストリーミング
cursor agent --resume [chatId]  # セッション再開
cursor agent --continue     # 前回セッション継続
cursor agent --cloud        # クラウドモード
cursor agent --model <model>  # モデル指定
cursor agent --mode <plan|ask>  # プラン/質問モード
cursor agent --workspace <path>  # ワークスペース指定
```

### 検証: stream-json 出力フォーマットの互換性

実際に `cursor agent --print --output-format stream-json` を実行して出力を取得した。

**出力例（NDJSON: 1行1JSON）:**

```json
{"type":"system","subtype":"init","apiKeySource":"login","cwd":"...","session_id":"...","model":"Claude 4.6 Opus (Thinking)","permissionMode":"default"}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"..."}]},"session_id":"..."}
{"type":"thinking","subtype":"delta","text":"The user","session_id":"...","timestamp_ms":...}
{"type":"thinking","subtype":"completed","session_id":"...","timestamp_ms":...}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"..."}]},"session_id":"..."}
{"type":"result","subtype":"success","duration_ms":46642,"is_error":false,"result":"...","session_id":"..."}
```

### フォーマット比較

| イベント | Claude Code | Cursor Agent | 互換性 |
|---|---|---|---|
| `type: "system"` + `subtype: "init"` | あり | あり | **同一** |
| `type: "user"` + `message.role/content` | あり | あり | **同一** |
| `type: "thinking"` + `subtype: "delta/completed"` | あり | あり | **同一** |
| `type: "assistant"` + `message.role/content` | あり | あり | **同一** |
| `type: "result"` + `subtype: "success"` | あり | あり | **同一** |

Cursor Agent CLIのstream-json出力はClaude CodeのJSON出力と**同一スキーマ**を使用している。

## Happy Coder コードベース調査（vendor-inspector）

### stdin/stdout キャプチャの仕組み

Happy Coderには2つのモードがあり、キャプチャ方式が異なる。

**ローカルモード (`claudeLocal.ts`):**
- stdio は `['inherit', 'inherit', 'inherit', 'pipe']`（stdoutはターミナル直通）
- セッションデータは `~/.claude/projects/.../<session-id>.jsonl` をファイルウォッチャーで監視
- fd 3 でthinking状態トラッキング（fetchモンキーパッチ）

**リモートモード (`claudeRemote.ts` → `sdk/query.ts`):**
- stdio は `['pipe', 'pipe', 'pipe']`（全パイプ）
- stdoutをreadlineで行単位に読み、JSONパース
- `--output-format stream-json --verbose` で起動

Cursor対応ではリモートモードのパターンをそのまま適用できる。

### Claude Code SDK への依存度

**SDKをライブラリとしてはimportしていない。** CLIバイナリを `spawn` で起動し、stdout JSONをパースしているだけ。SDK的な機能（プロセス管理、ストリーム処理、メッセージパース）はすべて `sdk/query.ts`, `sdk/stream.ts`, `sdk/types.ts` で自前実装。

### SessionProtocol（happy-wire）

9つのイベント型を持つプロバイダー非依存のプロトコル：

| イベント (`t`) | 用途 |
|---|---|
| `text` | テキスト出力（`thinking` フラグでreasoning区別） |
| `service` | サービスメッセージ |
| `tool-call-start` | ツール呼び出し開始 |
| `tool-call-end` | ツール呼び出し終了 |
| `file` | ファイル参照 |
| `turn-start` | ターン開始 |
| `turn-end` | ターン終了（`completed` / `failed` / `cancelled`） |
| `start` | サブエージェント開始 |
| `stop` | サブエージェント停止 |

既に Claude / Codex / Gemini / OpenCode の4プロバイダーが実装されており、各プロバイダーは固有の `sessionProtocolMapper` でCLI出力 → SessionEnvelopeへの変換を行う。

### 暗号化

- 送信直前に `enqueueMessage` で暗号化
- 2方式: Legacy（TweetNaCl XSalsa20-Poly1305）/ DataKey（AES-256-GCM）
- サーバーは暗号化blobを中継するのみ（Zero-Trust）

## 実現方針: フォーク + 最小改変

### フォークが最適な理由

1. E2E暗号化、リレーサーバー、モバイルアプリ（iOS/Android/Web）がそのまま使える
2. Local/Remoteモード切替、daemon、プッシュ通知がタダで付いてくる
3. Cursor Agent の stream-json が Claude Code と同一スキーマのため、Mapper差替えすらほぼ不要
4. 新規で同等のものを作ると数千行規模

### 必要な改変

| ファイル | 変更内容 | 工数 |
|---|---|---|
| `sdk/query.ts` | spawn引数を `cursor agent --print --output-format stream-json` に変更 | 小 |
| `sdk/utils.ts` | CLIパス検出を `cursor` コマンドに変更 | 小 |
| `ACPProvider` 型 | `'cursor'` を追加 | 極小 |
| `runCursor.ts` 新規 | Cursorプロセス起動+ストリーム接続（`runClaude.ts`ベース） | 中 |

### 改変不要なファイル

- `sdk/stream.ts` — 汎用ストリーム実装
- `session.ts` — サーバー連携用セッション管理
- `sessionProtocolMapper.ts` — 出力フォーマットが同一のため流用可能
- 暗号化層、サーバー、モバイルアプリ全体

## 未確認事項（次のステップで検証）

| 項目 | 確認方法 |
|---|---|
| `--cloud` モードの挙動 | `cursor agent -c --print --output-format stream-json` で実行 |
| ツール呼び出し時のJSON構造 | ファイル編集・シェル実行を含むプロンプトで stream-json を取得 |
| `--resume` / `--continue` のプロトコル | セッション再開時の出力を比較 |
| stdinからの `control_response` 受付 | ツール承認待ち状態でstdinにJSON書き込みテスト |
| `cursor tunnel` との併用可能性 | tunnel起動中にagent CLIが並行動作するか |

## 関連リンク

- Happy Coder: https://github.com/slopus/happy
- Cursor Agent CLI: `cursor agent --help`（Cursor 2.5.20+）
- ローカルクローン: `.vendor-inspect/happy-coder/`（調査用、gitignore推奨）

---

## Appendix A: OSS Researcher 出力（初回調査 — アーキテクチャ重視）

> 調査指示: 「アーキテクチャ」「設計パターン」「実装の特徴」「開発状況」「注目ポイント」を指定

### Happy Coder (slopus/happy) 深層調査レポート

#### 基本情報
- **リポジトリ:** https://github.com/slopus/happy
- **言語:** TypeScript（100%）
- **最終更新:** 2026年2月時点でアクティブ
- **規模:** 13,061 stars / 999 forks
- **CLIバージョン:** v0.14.0（npm: `happy-coder`）
- **ライセンス:** MIT
- **主要開発者:** Kirill Dubovitskiy, Steve Korshakov
- **一言で:** Claude CodeとCodexをモバイル/Webからリモート操作するためのE2E暗号化クライアント

#### 1. プロジェクト概要：何を目的としたプロジェクトか

Happy Coderは、デスクトップで動作するClaude CodeやCodex（OpenAI）などのAIコーディングエージェントを、**スマートフォンやWebブラウザからリモート操作**するためのオープンソースツール。

**解決する課題:** AIコーディングエージェントはターミナルで実行されるが、長時間タスクの進捗確認、パーミッション承認、エラー対応のためにPCの前に座り続ける必要がある。Happy Coderはこの制約を取り除き、「ランチ中にスマホからAIの進捗を確認し、必要な承認を出す」というワークフローを実現する。

**ターゲットユーザー:** Claude CodeやCodexを日常的に使う開発者。特に、長時間のAIコーディングタスクを走らせつつ離席する必要があるケース。

#### 2. アーキテクチャ：主要コンポーネント、技術スタック、パッケージ構成

Yarn Workspacesによるモノレポ構成で、5つのパッケージから成る。

```
slopus/happy/
├── packages/
│   ├── happy-cli/      # CLIラッパー（npm: happy-coder）
│   ├── happy-app/      # モバイル/Web UI（Expo + React Native）
│   ├── happy-server/   # バックエンドリレーサーバー
│   ├── happy-agent/    # リモートエージェント制御CLI
│   └── happy-wire/     # 共有プロトコル定義（Zodスキーマ）
├── Dockerfile          # スタンドアロンサーバー（PGlite内蔵）
├── Dockerfile.server   # 本番サーバー
└── Dockerfile.webapp   # WebアプリUI
```

##### 各パッケージの技術スタック

**happy-cli** (CLIラッパー)
- TypeScript + Node.js
- **ink** (React ベースのCLI UI)
- **tweetnacl** (E2E暗号化)
- **socket.io-client** (リアルタイム通信)
- **@modelcontextprotocol/sdk** (MCP統合)
- **@agentclientprotocol/sdk** (ACP統合)
- **fastify** (ローカルMCPサーバー/hookサーバー)
- Codex統合: MCP STDIO bridgeパターン

**happy-app** (モバイル/Web)
- **Expo 54** + **React Native 0.81**
- **react-native-unistyles** (スタイリング)
- **zustand** (状態管理)
- **libsodium-wrappers** / **@more-tech/react-native-libsodium** (暗号化)
- **livekit-client** + **@livekit/react-native** (WebRTC音声)
- **@elevenlabs/react-native** (TTS/STT)
- **@shopify/react-native-skia** (グラフィックス)
- **@tauri-apps/cli** (macOSデスクトップ版 via Tauri)
- **posthog-react-native** (アナリティクス)
- **RevenueCat** (課金)
- **socket.io-client** (リアルタイム通信)

**happy-server** (バックエンド)
- **Fastify** + TypeScript
- **Prisma** + PostgreSQL（本番）/ **PGlite** (スタンドアロン)
- **Socket.IO** (双方向リアルタイム通信)
- **Redis** + **@socket.io/redis-streams-adapter** (スケーリング)
- **MinIO** (S3互換オブジェクトストレージ)
- **privacy-kit** (サーバー側暗号化)
- **tweetnacl** (E2E暗号化)
- **ElevenLabs SDK** (音声合成)
- **prom-client** (Prometheusメトリクス)
- **sharp** (画像処理)

**happy-wire** (共有プロトコル)
- **Zod 3.25** でメッセージスキーマを定義
- セッションプロトコル: `SessionEnvelope` + 9種類のイベント型
- discriminated union による型安全なメッセージルーティング

#### 3. 設計パターン：特筆すべき設計判断

##### 3-1. Zero-Trust リレーアーキテクチャ

最も重要な設計判断。サーバーは**暗号化されたblob**のみを中継し、平文データに一切アクセスできない。

- クライアント側: **tweetnacl** (CLI) + **libsodium** (モバイル) でE2E暗号化
- サーバー側: **privacy-kit** の KeyTree で**サーバー自身の秘密**のみを管理（認証トークン、ユーザーメタデータの暗号化）
- 鍵交換: QRコード読み取りによるワンタイム鍵交換
- 暗号化対象: セッションメッセージ、メタデータ、daemon状態、Artifact、KVストア — ほぼすべてのユーザーデータが暗号化されてDBに保存される

Prismaスキーマで `Bytes` 型が多用されている（`dataEncryptionKey`, `body`, `header`, `token` など）のが、このE2E設計の証左。

##### 3-2. Local/Remote モード切替

CLIは2つのモードを持つ：
- **Local モード**: デスクトップターミナルで直接Claude Codeを操作
- **Remote モード**: モバイル/Webからリレー経由で操作

「キーボードの任意のキーを押す」だけでLocal/Remote間を即座に切替可能。これは `session.sendSessionEvent({ type: 'switch', mode: newMode })` で通知され、`agentState.controlledByUser` フラグで管理される。

##### 3-3. Daemon アーキテクチャ

CLIのバックグラウンドプロセスとして常駐するdaemonが、以下を管理：
- 複数セッションのライフサイクル管理
- モバイルからのリモートセッション起動（RPC経由）
- 自動バージョンアップデート検出（heartbeat中にpackage.json比較）
- プロセス死活監視とクリーンアップ
- macOS launchd統合（`daemon/mac/` ディレクトリ）

daemonはローカルHTTPサーバーとWebSocket（サーバー向け）の二重通信を持ち、ローカルCLIインスタンスとリモートモバイルの両方から制御可能。

##### 3-4. Offline-First / Pub-Sub メッセージング

ネットワーク接続が不安定でもセッションが死なない設計。`startOfflineReconnection` パターンにより：
1. サーバー到達不能時 → ローカルモードで即座にClaude Code起動
2. バックグラウンドで再接続を試行
3. 復帰時にセッションをサーバーに同期

##### 3-5. SessionProtocol（happy-wire）

Zodのdiscriminated unionで9種類のイベントを定義：
- `text`, `service`, `tool-call-start`, `tool-call-end`, `file`, `turn-start`, `turn-end`, `start`, `stop`
- 各イベントは `SessionEnvelope` でラップ（id, time, role, turn, subagent）
- `role` による制約バリデーション（`service`/`start`/`stop` は `agent` ロールのみ）

これにより、CLI・アプリ・サーバー間で型安全なメッセージングが実現されている。

#### 4. 実装の特徴

##### 4-1. E2E暗号化の実装

**アプリ側** (`happy-app/sources/encryption/`):
- `aes.ts` — AES暗号化（プラットフォーム共通）
- `deriveKey.ts` — 鍵導出
- `hmac_sha512.ts` — HMAC-SHA512
- `libsodium.ts` / `libsodium.lib.web.ts` — libsodium のネイティブ/Web切替
- `base64.native.ts` / `base64.ts` — ネイティブ/Web Base64実装分離

**CLI側**: `tweetnacl` を直接使用。

**サーバー側** (`happy-server/sources/modules/encrypt.ts`):
`privacy-kit` の `KeyTree` による階層的対称暗号化。`HANDY_MASTER_SECRET` から鍵ツリーを生成し、パス（配列）単位で暗号化/復号。サーバーが読むのは自身の管理データのみで、ユーザーコンテンツは常にE2Eの暗号化blobとして扱われる。

##### 4-2. リアルタイム通信

**Socket.IO** ベースの双方向通信：
- CLI ↔ サーバー: セッションイベント、メッセージ同期、daemon状態更新
- アプリ ↔ サーバー: セッション購読、リアルタイム更新受信
- Redis Streams Adapterによる水平スケーリング対応

**アプリ側のRealtime層** (`happy-app/sources/realtime/`):
- `RealtimeProvider.tsx` / `.web.tsx` — ネイティブ/Web別のProvider実装
- `RealtimeSession.ts` — セッション接続管理
- `RealtimeVoiceSession.tsx` — LiveKit WebRTC経由の音声セッション
- `realtimeClientTools.ts` — クライアント側のリアルタイムツール定義

##### 4-3. マルチプラットフォーム対応

- **iOS**: Expo + React Native（App Store公開済み）
- **Android**: Expo + React Native（Google Play公開済み）
- **Web**: Expo Web（app.happy.engineering）
- **macOS デスクトップ**: Tauri 2.x でのネイティブアプリ（`src-tauri/` 設定あり）
- **CLI**: Node.js（npm global install）

`.web.tsx` / `.native.ts` のサフィックスによるプラットフォーム別実装分離パターンが暗号化・リアルタイム・Base64などで徹底されている。

##### 4-4. 音声コーディング

**ElevenLabs** のTTS/STTと **LiveKit** WebRTCを組み合わせた音声入力機能：
- アプリ側: `@elevenlabs/react-native` + `livekit-client`
- サーバー側: `elevenlabs` SDK
- Claude Sonnet 4がエージェントとして「ラバーダック思考」→「具体的なClaude Code指示」への変換が担当

##### 4-5. Claude Code / Codex / Gemini マルチエージェント対応

CLIの `src/` ディレクトリが示す通り、3つのAIバックエンドに対応：
- `claude/` — Claude Code SDK統合（ローカル/リモート起動、セッション管理）
- `codex/` — Codex統合（MCP STDIO bridge, execution policy）
- `gemini/` — Gemini CLI統合

各バックエンドは `runClaude.ts`, `runCodex.ts`, `runGemini.ts` のエントリポイントを持つ。

##### 4-6. スタンドアロン/セルフホスト対応

`Dockerfile` で **PGlite**（組み込みPostgreSQL）を使い、外部依存なしの単一コンテナデプロイが可能：

```bash
docker run -v /data:/data -e HANDY_MASTER_SECRET=... -p 3005:3005 happy-server
```

`standalone.ts` が独自のマイグレーションランナーを実装しており、Prisma CLIに依存せずPGliteに直接SQLを適用する。

#### 5. 開発状況

- **Stars:** 13,061（急成長中）
- **Forks:** 999
- **主要開発者:** 2名（Kirill Dubovitskiy = CLI/Agent担当、Steve Korshakov = Server担当）
- **CLIバージョン:** v0.14.0（npmにて `happy-coder` で公開）
- **アプリ:** iOS/Android/Web すべて公開済み
- **ライセンス:** MIT
- **マネタイズ:** RevenueCat経由のアプリ内課金（Pro版機能）

コミュニティの声（Reddit r/ClaudeCode）:
- SSH + tmux + Termius と比較されることが多い
- 競合として claude-relay, Paseo, Myrlin-workbook が挙がるが、Happy Coderはネイティブアプリとして最も完成度が高い
- E2E暗号化・プッシュ通知・音声コーディングの3点が差別化要因

#### 6. 注目ポイント：参考になりそうな実装や学べる点

##### 学べる設計パターン
1. **Zero-Trust リレーパターン**: サーバーが平文データに一切触れないE2E暗号化設計。プライバシーが求められるSaaSアーキテクチャの参考になる
2. **happy-wire パッケージ**: Zodのdiscriminated unionでプロトコル定義を共有する手法。クライアント/サーバー間の型安全性を保証する実践的パターン
3. **Daemon + Local/Remoteモード切替**: CLIプロセスの永続化・リモート制御・自動更新のライフサイクル管理は、CLIツール設計のリファレンスとして秀逸
4. **PGlite によるスタンドアロンデプロイ**: 組み込みPostgreSQLで「外部依存ゼロの単一コンテナ」を実現する手法
5. **Expo + Tauri マルチプラットフォーム**: React Nativeアプリに Tauri を組み合わせてデスクトップ版も提供する実践例

##### 深掘り候補（コードリーディング対象）
- `packages/happy-cli/src/claude/loop.ts` — Local/Remoteモード切替のメインループ
- `packages/happy-cli/src/daemon/run.ts` — Daemon起動・heartbeat・セッション管理の全体像
- `packages/happy-cli/src/claude/claudeRemote.ts` — リモートモードでのClaude Code制御実装
- `packages/happy-app/sources/sync/sync.ts` — アプリ側の同期エンジン
- `packages/happy-app/sources/encryption/` — E2E暗号化のクロスプラットフォーム実装
- `packages/happy-server/sources/app/session/` — サーバー側セッション管理API
- `packages/happy-cli/src/codex/happyMcpStdioBridge.ts` — Codex統合のMCP bridgeパターン

##### 制約・注意点
- daemon.state.jsonの管理に課題あり（開発者自身が `CLAUDE.md` で改善案を記述）
- caffeinate プロセスの追跡が不完全（runawayプロセスのリスク）
- ローカルHTTPポートの認証保護が未実装（現時点ではlocalhost限定で緩和）
- コントリビューター数が少なく（2名が主要）、バス因子のリスク
- RevenueCat統合があるため、完全なセルフホストでは一部機能が制限される可能性

---

## Appendix B: OSS Researcher 出力（再調査 — 自律判断・使い方含む）

> 調査指示: URL のみ渡し、調査観点はoss-researcherの自律判断に委ねた

### claude-code-prompt-improver 調査結果

> 注: 本 appendix は oss-researcher サブエージェントの出力精度検証も兼ねている。指示の与え方による出力品質の差異を比較するため、同一リポジトリに対して「観点を列挙した場合」と「URLのみ渡した場合」の両方を実施した。

#### 基本情報
- **リポジトリ:** https://github.com/severity1/claude-code-prompt-improver
- **言語:** Python（hookスクリプト ~70行） + Markdown（Skill定義・リファレンス）
- **最終更新:** 2026年2月14日（v0.5.1）
- **規模:** 1,135 stars / 96 forks / v0.5.1
- **ライセンス:** MIT
- **作者:** severity1
- **一言で:** Claude Code の曖昧なプロンプトを自動検出し、リサーチベースの質問で明確化してから実行するフックプラグイン

#### これは何か・何を解決するのか

Claude Code CLIで `"fix the bug"` のような曖昧なプロンプトを投げたとき、**そのまま実行すると的外れな結果になる問題**を解決するプラグイン。

`UserPromptSubmit` hookとして動作し、ユーザーのプロンプトを**送信時にインターセプト**して明瞭性を評価する。明確なプロンプトはそのまま通過（ゼロオーバーヘッド）、曖昧なプロンプトの場合はコードベースのリサーチを行い、1〜6個の選択肢つき質問をユーザーに提示してから実行する。

**ターゲットユーザー:** Claude Code を日常的に使う開発者。特に「雑にプロンプトを投げたいが、精度は落としたくない」というニーズを持つ人。

**要件:** Claude Code 2.0.22+（`AskUserQuestion` ツール対応が必須）

#### 設計思想・アーキテクチャ

##### コア設計思想

- **Rarely intervene** — 大多数のプロンプトは変更せずスルー
- **Trust user intent** — 本当に不明確な場合のみ介入
- **Use conversation history** — 既存の会話文脈を活用し、冗長な探索を回避
- **Progressive Disclosure** — 必要な場合のみスキル・リファレンスファイルをロード

##### 二層アーキテクチャ（v0.4.0〜）

**Hook層 (`scripts/improve-prompt.py`)**
- ~70行のPythonスクリプト。stdin/stdout JSONで通信
- バイパスプレフィックス処理（`*` = スキップ、`/` = スラッシュコマンド、`#` = メモライズ）
- プロンプトを評価用ラッパー（~189トークン）で包んで出力
- Claude自身が会話履歴を使って明瞭度を判定

**Skill層 (`skills/prompt-improver/`)**
- `SKILL.md`: 4フェーズワークフロー定義（Research → Questions → Clarify → Execute）
- `references/`: オンデマンドで読み込まれる詳細ガイド
  - `question-patterns.md`: 質問テンプレート・AskUserQuestionのフォーマット
  - `research-strategies.md`: コンテキスト収集戦略
  - `examples.md`: 実際のプロンプト変換例

##### 注目すべき設計判断

1. **サブエージェントではなくメインセッションで実行** — 会話履歴にアクセスでき、冗長な探索を避けられる。透明性も高い
2. **Hook自体は評価のみ、リサーチ・質問生成はSkillに分離** — v0.4.0で導入。明確なプロンプトではSkillをロードしないため31%のトークン削減を実現
3. **Pythonのみ・外部依存なし** — `json`, `sys` のみ。ネットワーク呼び出しも重い処理もフックには入れない
4. **Claude Code Plugin仕様に準拠** — `.claude-plugin/plugin.json` でメタデータ、`hooks/hooks.json` で自動検出

#### 機能一覧

| カテゴリ | 機能 | 概要 | 場所 |
|---------|------|------|------|
| **Core** | プロンプト明瞭度評価 | 会話履歴を使い、~189トークンの評価プロンプトで判定 | `scripts/improve-prompt.py` |
| **Core** | リサーチベース質問生成 | コードベース・ドキュメント・Web検索を行い、根拠のある選択肢を提示 | `skills/prompt-improver/SKILL.md` |
| **Core** | AskUserQuestion統合 | 選択式UI（2-4選択肢 × 1-6質問）で効率的にユーザー回答を取得 | Skill Phase 3 |
| **Differentiator** | Progressive Disclosure | 明確なプロンプト→スキル未ロード、曖昧→スキル+必要なリファレンスのみロード | アーキテクチャ全体 |
| **Differentiator** | バイパスプレフィックス | `*`（スキップ）、`/`（スラッシュコマンド）、`#`（メモライズ）で任意に回避 | `scripts/improve-prompt.py` |
| **Utility** | 手動スキル呼び出し | フック経由なしで `Use the prompt-improver skill to...` で直接呼び出し可能 | `skills/prompt-improver/` |
| **Utility** | マーケットプレイス配布 | `claude plugin install prompt-improver@severity1-marketplace` でワンコマンドインストール | `.claude-plugin/` |
| **Utility** | テストスイート | 24テスト（Hook 8 + Skill 9 + Integration 7）、pytest互換 | `tests/` |
| **Utility** | Windows互換 | `python3 || python` フォールバックでWindows対応（v0.5.1） | `hooks/hooks.json` |

#### 特徴的な点・注目ポイント

**1. 「Claudeが自分自身のプロンプトを評価する」パターン**

フックはプロンプトを評価ラッパーで包むだけで、実際の判定はClaude自身が行う。外部LLM呼び出しや分類器は一切使わない。会話履歴全体をコンテキストにして判定するため、「3ターン前にバグの話をしていた」という文脈も考慮される。

**2. トークンオーバーヘッドの極小化**

明確なプロンプトでのオーバーヘッドは~189トークン/プロンプト。30メッセージのセッションで約5.7kトークン（200kコンテキストの2.8%）。v0.3.x比で31%削減。

**3. 質問の「根拠付け」への徹底的なこだわり**

`question-patterns.md`（300行超）で「すべての選択肢はリサーチ結果に基づく」「仮定に基づく選択肢は禁止」を繰り返し強調。選択肢にはコードベースのファイルパスや行番号を含む具体性が求められる。

**4. Plugin/Marketplace エコシステムへの先行対応**

Claude Code のプラグインシステム（2025年後半〜）に早期から対応。`severity1-marketplace` 経由でのインストールを正式にサポート。

#### 使い方・典型的なワークフロー

**インストール（推奨: マーケットプレイス経由）:**

```bash
claude plugin marketplace add severity1/severity1-marketplace
claude plugin install prompt-improver@severity1-marketplace
# Claude Codeを再起動
```

**通常利用:**

```bash
claude "fix the bug"      # フックが評価 → 曖昧なら質問
claude "add tests"        # フックが評価 → 曖昧なら質問
```

**バイパス:**

```bash
claude "* add dark mode"  # * で評価スキップ
claude "/help"            # スラッシュコマンドは自動バイパス
```

**典型フロー（曖昧プロンプト）:**

1. `claude "fix the error"` と入力
2. フックが「曖昧」と判定、フレンドリーな通知: "Hey! The Prompt Improver Hook flagged your prompt as a bit vague because..."
3. Claudeがコードベースをリサーチ（git log、grep、テスト結果など）
4. 選択式質問を提示:
   - `TypeError in src/components/Map.tsx (recent change)`
   - `API timeout in src/services/osmService.ts`
   - `Other (paste error message)`
5. ユーザーが選択 → 文脈充実した状態でタスク実行

#### エコシステム・実利用状況

- **採用規模:** 1,135 stars / 96 forks（2026年2月時点）。Claude Code プラグインとしてはトップクラスの人気
- **メディア:** DevGenius/Reading.sh の記事（2026年1月）で「Every Serious Claude Code User Needs」と紹介
- **コミュニティ:** GitHub Issues 3件Open（すべて作者自身がfiling、ロードマップ的）
- **周辺ツール:** severity1-marketplace（プラグイン配布）、agent-skills.md に掲載
- **日本語コミュニティ:** 直接的な言及は未確認

#### 他ツールとの比較・ポジショニング

| 比較軸 | severity1/claude-code-prompt-improver | GaZmagik/claude-prompt-improver |
|--------|--------------------------------------|--------------------------------|
| **Stars** | 1,135 | 2 |
| **言語** | Python（~70行） | TypeScript（大規模） |
| **ランタイム** | Python3（標準ライブラリのみ） | Bun必須 |
| **テスト** | 24テスト | 619+テスト |
| **アプローチ** | Claude自身が会話文脈で判定 | 外部LLM呼び出しでプロンプト書き換え |
| **デフォルト動作** | 全プロンプトを評価（バイパスで回避） | opt-in（`#improve` タグ必須） |
| **レイテンシ** | 明確なプロンプト: ほぼゼロ追加 | 30-90秒のLLM呼び出し |
| **コンテキスト注入** | リサーチベースの質問で間接的に | Git/LSP/spec/memory を直接注入 |
| **設定** | 設定不要（CLAUDE.mdで適応） | YAML frontmatter で詳細設定可能 |

#### 制約・注意点

1. **Claude Code 2.0.22+ 必須:** `AskUserQuestion` ツールがないバージョンでは動作しない
2. **プラグインシステムへの依存:** Claude Code のプラグイン仕様は発展途上。仕様変更リスクあり
3. **評価の精度はClaude次第:** フック自体には判定ロジックがなく、Claudeの判断品質に完全に依存
4. **トークンオーバーヘッド:** 明確なプロンプトでも毎回~189トークンの評価プロンプトが付加される
5. **個人プロジェクト:** 開発は severity1 一人。バス因子のリスク。ただしコード量が極めて少ない（フックは70行）ため、フォークして維持するのは容易
6. **日本語プロンプトでの動作:** テスト・ドキュメントはすべて英語。日本語プロンプトの明瞭度評価の精度は未検証

#### 深掘り候補（コードリーディング対象）

| 場所 | 調査の目的 |
|------|----------|
| `scripts/improve-prompt.py` | 評価ラッパーの正確な文面と、バイパスロジックの実装詳細 |
| `skills/prompt-improver/references/research-strategies.md` | リサーチフェーズで具体的にどんな探索戦略を指示しているか |
| `skills/prompt-improver/references/examples.md` | 実際のプロンプト変換例（効果の具体性を確認） |
| `tests/test_integration.py` | エンドツーエンドフローの検証方法とトークンオーバーヘッド計測 |
| `.claude-plugin/` + `hooks/hooks.json` | プラグイン配布構造の参考パターン |
