---
researched_at: "2026-05-26"
topic: "Hermes Agent — Nous Research製の自己改善AIエージェント"
primary_url: "https://github.com/NousResearch/hermes-agent"
agent: oss-researcher
skill: oss-research-session
---

## Hermes Agent 調査結果

### 基本情報

- **リポジトリ:** [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- **言語:** Python 88.7%, TypeScript 8.3%, Shell 0.5% 他
- **最終更新:** 2026-05-26（直近pushは当日）
- **規模:** Stars 168k / Contributors 390名 / Forks 27.7k / v0.14.0 (2026-05-16) / 全13リリース / 9,568コミット
- **ライセンス:** MIT
- **開発元:** [Nous Research](https://nousresearch.com)（2023年設立、$65-70M調達、Paradigm主導Series Aで$1B評価）
- **一言で:** 使うほど賢くなる自己改善型AIエージェント — スキル自動生成・クロスセッション記憶・マルチプラットフォーム対応

### これは何か・何を解決するのか

Hermes Agentは、Nous Researchが開発したオープンソースの自律AIエージェントフレームワーク。2026年2月25日にリリースされ、7週間でGitHub Stars 95kを超えた。

**解決する問題:** 従来のAIエージェント（Claude Code、Cursor等）はセッション間で学習を保持できず、毎回同じコンテキストを再説明する必要がある。Hermes Agentは「閉じた学習ループ（closed learning loop）」を核に設計され、以下の問題を構造的に解決する：

1. **セッション間の記憶喪失** — SQLite/FTS5ベースのセッション検索、MEMORY.md/USER.mdによる永続メモリ、Honcho dialecticユーザーモデリングの3層構造で記憶を保持
2. **経験の蓄積不能** — 5つ以上のツール呼び出しを含むタスク完了後、エージェントが自律的にSKILL.mdを生成し、次回以降の類似タスクで再利用
3. **ラップトップ依存** — VPS・Docker・サーバーレスで常駐実行し、Telegram/Discord/Slack等からリモートアクセス可能
4. **モデルロックイン** — OpenRouter経由で200+モデル対応、`hermes model`コマンド一つで切り替え

**ターゲットユーザー:** ソロ開発者、インディーハッカー、研究者。定常的にAIエージェントを使い、セッション横断の文脈蓄積に価値を見出すユーザー。IDE内のコーディング支援ではなく、長期稼働するパーソナルオートメーションとして位置付けられる。

出典: [README](https://github.com/NousResearch/hermes-agent/blob/main/README.md), [Medium - Krzysztof Słomka](https://kisztof.medium.com/hermes-agent-review-nous-researchs-self-improving-ai-agent-e72bc244435a)

### 設計思想・アーキテクチャ

#### コア設計判断

1. **学習ループファースト:** エージェントの全アーキテクチャが「自己評価と自己改善」を軸に設計されている。タスク完了→スキル生成→メモリ永続化→次回参照のサイクルが組み込み（[Turing Post](https://www.turingpost.com/p/hermes)）
2. **実行環境とインターフェースの分離:** エージェントのコンピュート（VPS/Docker/Modal等）とユーザーインターフェース（CLI/Telegram/Discord等）が完全分離。ラップトップを閉じても動作し続ける
3. **モデル非依存:** OpenAI互換APIなら何でも動作。プロバイダ解決はinit時に一度だけ行い、実行時のモデル切り替えはゼロコスト
4. **サプライチェーンセキュリティ:** 2026年5月12日のMistral AI PyPI汚染事件（Mini Shai-Hulud worm）を受け、全依存を`==`で完全ピン止め。レンジ指定は書面による正当化なしに禁止（`pyproject.toml`コメントに経緯記載）
5. **遅延依存インストール:** コア依存を最小化し、プロバイダ固有パッケージは`tools/lazy_deps.py`で初回使用時にインストール。攻撃対象面の縮小が目的

#### プロジェクト構造（CONTRIBUTING.mdより）

```
hermes-agent/
├── run_agent.py              # AIAgent class — コア会話ループ、ツールディスパッチ
├── cli.py                    # HermesCLI — prompt_toolkit TUI
├── model_tools.py            # ツールオーケストレーション
├── toolsets.py               # ツールグルーピング・プリセット
├── hermes_state.py           # SQLiteセッションDB（FTS5全文検索）
├── agent/                    # エージェント内部モジュール
│   ├── prompt_builder.py     # システムプロンプト組立
│   ├── context_compressor.py # コンテキスト自動圧縮
│   └── model_metadata.py     # モデル仕様・トークン推定
├── hermes_cli/               # CLIコマンド実装
├── tools/                    # 自己登録型ツール実装
│   ├── registry.py           # 中央ツールレジストリ
│   ├── terminal_tool.py      # 7ターミナルバックエンド
│   ├── delegate_tool.py      # サブエージェント生成
│   └── environments/         # 実行バックエンドABC
├── gateway/                  # メッセージングゲートウェイ
├── acp_adapter/              # Agent Client Protocol対応
├── plugins/                  # メモリプロバイダ等プラグイン
├── skills/                   # バンドルスキル（96個+）
├── optional-skills/          # オプショナルスキル（20個+）
└── cron/                     # スケジューラ
```

#### コアループ

```
User message → AIAgent._run_agent_loop()
  ├── Build system prompt (prompt_builder.py)
  ├── Call LLM (OpenAI-compatible API)
  ├── If tool_calls → Execute via registry → Loop back
  ├── If text response → Persist session → Return
  └── Context compression if approaching token limit
```

#### 用語集

| 用語 | 意味 |
|------|------|
| **Learning Loop** | タスク完了→スキル生成→メモリ永続化→次回参照の閉じたサイクル |
| **Skill** | エージェントが自律生成するSKILL.md形式の手続き的知識 |
| **Toolset** | ツールの論理的グルーピング（web, terminal, file等） |
| **Profile** | `~/.hermes/profiles/<name>/` 下の隔離環境 |
| **Gateway** | メッセージングプラットフォームへの統一インターフェース |
| **Terminal Backend** | コマンド実行環境（local/Docker/SSH/Modal等） |
| **Trajectory** | エージェントの行動履歴（訓練データ生成用） |

### 機能一覧

#### コア機能

| 機能 | 概要 | 場所 |
|------|------|------|
| **学習ループ** | タスク完了後にスキルを自動生成・改善。5+ツール呼び出しで発火 | `agent/`, `tools/skill_tools.py` |
| **永続メモリ** | MEMORY.md + USER.md + FTS5セッション検索の3層構造 | `hermes_state.py`, `~/.hermes/memories/` |
| **会話ループ** | OpenAI互換APIへのリクエスト→ツール実行→レスポンスの再帰ループ | `run_agent.py` |
| **コンテキスト圧縮** | トークンリミット接近時に自動要約 | `agent/context_compressor.py` |
| **ツールレジストリ** | 自己登録型ツールシステム。40+ツール | `tools/registry.py` |
| **プロバイダ抽象化** | OpenAI互換API準拠。Nous Portal/OpenRouter/直接接続 | `providers/` |

#### 差別化機能

| 機能 | 概要 | 場所 |
|------|------|------|
| **スキル自動生成** | 経験からSKILL.mdを生成・インデクス。agentskills.io互換 | `skills/`, `tools/skill_tools.py` |
| **Honcho dialectic** | 弁証法的ユーザーモデリング。通信スタイル・嗜好・目標を推論 | `plugins/memory/honcho/` |
| **マルチプラットフォーム** | Telegram, Discord, Slack, WhatsApp, Signal, Email, Matrix | `gateway/platforms/` |
| **7ターミナルバックエンド** | local, Docker, SSH, Singularity, Modal, Daytona, Vercel Sandbox | `tools/environments/` |
| **サブエージェント** | 孤立したサブエージェントを生成し並列実行 | `tools/delegate_tool.py` |
| **cronスケジューラ** | 自然言語でスケジュール定義、任意プラットフォームへ配信 | `cron/` |
| **ACP対応** | Agent Client Protocol（Zed策定）でVS Code/JetBrains/Zed統合 | `acp_adapter/` |
| **MCP対応** | MCPサーバーとして外部エディタからアクセス可能 | `mcp_serve.py` |
| **OpenClawマイグレーション** | `hermes claw migrate` でペルソナ・メモリ・スキル・APIキーを移行 | `hermes_cli/` |
| **プロファイル分離** | 複数人格・環境をプロファイルとして隔離 | `hermes_constants.py` |
| **Nous Portal統合** | 1サブスクリプションで300+モデル + ツールゲートウェイ | `hermes_cli/auth.py` |
| **トラジェクトリ生成** | バッチ実行でツール呼び出しモデルの訓練データを生成 | `batch_runner.py`, `trajectory_compressor.py` |

#### ユーティリティ機能

| 機能 | 概要 | 場所 |
|------|------|------|
| **TUI** | prompt_toolkit製フルTUI（マルチライン編集・補完・履歴） | `cli.py`, `ui-tui/` |
| **Web Dashboard** | FastAPI + SPA（`hermes dashboard`） | `hermes_cli/web_server.py` |
| **音声入力/TTS** | faster-whisper STT + Edge-TTS/ElevenLabs/OpenAI TTS | `tools/transcription_tools.py`, `tools/tts_tool.py` |
| **スキンエンジン** | データ駆動型CLIテーマカスタマイズ | `hermes_cli/skin_engine.py` |
| **Computer Use** | macOSデスクトップ制御（cua-driver MCP経由） | extras `computer-use` |
| **Doctor診断** | `hermes doctor` で環境診断 | `hermes_cli/doctor.py` |

### 特徴的な点・注目ポイント

#### 1. 閉じた学習ループ — 唯一の構造的自己改善

Hermes最大の差別化要因。タスク完了後にエージェントが自律的にスキルドキュメント（SKILL.md）を生成し、`~/.hermes/skills/`に保存する。次回類似タスクではこのスキルが自動ロードされ、品質と速度が向上する。

重要な点は、スキル名と概要のみがシステムプロンプトにロードされ、全文は必要時にオンデマンドで読み込まれること。200+スキルでもコンテキストバジェットを圧迫しない設計。

出典: [DEV.to - 30 Days With Hermes](https://dev.to/uuhi_reddy_841b6e27138dcc/30-days-with-hermes-agent-the-only-ai-that-learned-from-my-mistakes-16i3), [Zenn - 自己改善するAIエージェント](https://zenn.dev/neurestx/articles/83ed7b10f7ff62)

#### 2. 3+1層メモリアーキテクチャ

- **Layer 1: Working Memory** — セッション中の会話コンテキスト
- **Layer 2: Persistent Memory** — MEMORY.md（エージェント管理メモ）+ USER.md（ユーザープロファイル）
- **Layer 3: Session Search** — SQLite FTS5全文検索。「先週のRaftの議論は？」といったクロスセッション想起
- **Layer 3.5: Honcho dialectic** — オプション。弁証法的推論でユーザーの行動パターン・思考傾向を自律モデリング

8つのメモリプロバイダが存在（Honcho, Mem0, Hindsight, Holographic, OpenViking, ByteRover, RetainDB, Supermemory）。新規プロバイダはプラグインとして外部リポジトリで開発する方針（CONTRIBUTING.md）。

出典: [Zenn - Hermes Agentの記憶システム](https://zenn.dev/lumichy/articles/hermes-agent-memory-system-2026), [Vectorize.io - Memory Providers Compared](https://vectorize.io/articles/hermes-agent-memory-providers-compared)

#### 3. サプライチェーン防御設計

2026年5月12日のMistral AI PyPIワーム事件を契機に、全依存を`==`完全ピン止めに移行。コア依存を最小化し、プロバイダ固有パッケージは`LAZY_DEPS`辞書で遅延インストールする設計。`[all]`エクストラからも大部分のバックエンドを除外し、一つの汚染リリースが全インストールを破壊するリスクを排除。

```python
# pyproject.toml より抜粋
# Scope rule: only packages used by EVERY hermes session belong here.
# Anything that's provider-specific belongs in an extra and gets
# lazy-installed via tools/lazy_deps.py when the user picks that backend.
# Smaller dependencies = smaller blast radius for the next supply-chain attack.
```

#### 4. ACP (Agent Client Protocol) 統合

Zed Industries策定のACP（LSPのAIエージェント版）に対応。`hermes acp`コマンドでstdio JSON-RPCサーバーを起動し、VS Code、Zed、JetBrains、Neovim等のACP対応エディタからHermesを利用可能。IDE・メッセージング・CLIの3インターフェースモードが並立する設計。

`acp_adapter/server.py` に `HermesACPAgent(acp.Agent)` として実装。セッション管理、ストリーミング、ツール呼び出し、パーミッションリクエストをACP規格に準拠してエクスポーズ。

出典: [Issue #569](https://github.com/NousResearch/hermes-agent/issues/569), [ACP Docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/acp)

#### 5. OpenClawからの移行パス

Hermes AgentはOpenClaw（旧称ClawdBot/MoltBot、2025年後半ローンチ）の「次世代」として位置付けられ、Day 1からマイグレーションツールを同梱：

- `hermes claw migrate` — ペルソナ（SOUL.md）、メモリ、スキル、APIキー、メッセージング設定を一括移行
- OpenClawのMarkdownメモリを自動的にSQLiteに変換
- セットアップウィザードが`~/.openclaw`を検出し移行を提案

**OpenClawとの設計上の違い:** OpenClawのスキルは人間が手動作成しClawHubで配布。Hermesのスキルはエージェントが経験から自動生成。OpenClawは「マニュアルに従う助手」、Hermesは「自分でマニュアルを書く助手」。

出典: [Medium - I Switched from OpenClaw](https://medium.com/@sathishkraju/i-switched-from-openclaw-to-hermes-agent-heres-what-nobody-told-me-5f33a746b6ca), [Turing Post](https://www.turingpost.com/p/hermes)

### 使い方・典型的なワークフロー

#### インストール

```bash
# Linux/macOS/WSL2/Termux
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
source ~/.bashrc

# Windows (PowerShell, Early Beta)
iex (irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1)
```

#### 初回セットアップ

```bash
hermes setup              # 対話型セットアップウィザード
hermes setup --portal     # Nous PortalでOAuth + プロバイダ + ツールゲートウェイ一括設定
hermes model              # LLMプロバイダ・モデル選択
hermes tools              # 有効ツール設定
```

#### 日常的なワークフロー

```bash
hermes                    # CLI起動（TUI）
hermes gateway start      # メッセージングゲートウェイ起動（Telegram等）
hermes cron list          # スケジュールジョブ確認
hermes doctor             # 環境診断
hermes update             # アップデート
```

#### 設定ファイル（`~/.hermes/config.yaml`）

```yaml
model:
  provider: nous              # or openrouter, openai, anthropic, etc.
  name: anthropic/claude-sonnet-4.6
  reasoning: medium

terminal:
  backend: local               # local, docker, ssh, modal, daytona, etc.

memory:
  provider: builtin            # or honcho, mem0, hindsight, etc.

skills:
  auto_create: true            # タスク後にスキル自動生成
  auto_improve: true           # 使用中にスキル自動改善

cron:
  enabled: true
```

#### コントリビューター向けセットアップ

```bash
git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git
cd hermes-agent
./setup-hermes.sh              # uv + venv + .[all] + symlink
scripts/run_tests.sh           # テスト（CI準拠、4 xdist workers）
```

### エコシステム・実利用状況

#### 採用事例

- OpenRouterのアプリランキングでOpenClawに並ぶ上位（[Zenn - 1時間触ってみた](https://zenn.dev/flinters_blog/articles/e3bf5fafce3ed7)）
- v0.13 "Tenacity"リリース（2026年5月）で日次トークン消費量がOpenRouter上のOSS全エージェント中トップに（[Towards AI比較記事](https://pub.towardsai.net/i-tested-hermes-agent-vs-claude-code-vs-openclaw-on-18-real-tasks-the-10-week-old-one-cheats-by-0f2881a10213)）
- [Petronella Technology Group](https://petronellatech.com/blog/hermes-agent-ai-guide/)がマネージドデプロイメントを提供（Starter $5K-$10K / Production $15K-$40K / Enterprise $40K+）

#### 盛り上がりの文脈

- 2026年2月25日ローンチ → 7週間でStars 95k → 本稿時点168k
- OpenClawからの移行需要がカタリスト。Day 1マイグレーションツール同梱がシグナルとなり話題化
- 「自己改善型」という明確な差別化軸がバイラル。初日の性能ではなく「90日後にどう成長したか」で評価される新パラダイム
- ICLR 2026 Oral論文（MIT）でHermesの学習ループの測定可能な改善効果が示された（[Medium記事](https://kisztof.medium.com/hermes-agent-review-nous-researchs-self-improving-ai-agent-e72bc244435a)で言及）

#### コミュニティ

- **Discord:** [Nous Research Discord](https://discord.gg/NousResearch) — 主要コミュニティハブ
- **GitHub Issues:** 13,795件オープン（活発）
- **Contributors:** 390名（トップ: teknium1, OutThisLife, kshitijk4poor）
- **日本語圏:** Zennで複数の詳細解説記事が存在：
  - [Hermes Agentの記憶システムを完全図解](https://zenn.dev/lumichy/articles/hermes-agent-memory-system-2026)
  - [使用を通じて成長するAIエージェントフレームワークの設計思想](https://zenn.dev/evolink/articles/971638504819ee)
  - [1時間触ってみた](https://zenn.dev/flinters_blog/articles/e3bf5fafce3ed7)
  - [ローカル環境で検証してみた](https://zenn.dev/neurestx/articles/83ed7b10f7ff62)
  - [メモリーを試す](https://zenn.dev/kun432/scraps/dc58a0fdfc1ba7)

#### 周辺ツール

- **[agentskills.io](https://agentskills.io)** — スキルのオープンスタンダード仕様
- **[HermesHub](https://hermeshub.xyz)** — コミュニティスキルレジストリ・マーケットプレイス（セキュリティスキャン65+ルール、x402クリプト決済対応）
- **[computer-use-linux](https://github.com/avifenesh/computer-use-linux)** — LinuxデスクトップMCPサーバー（AT-SPIアクセシビリティツリー、Wayland/X11対応）
- **[HermesClaw](https://github.com/AaronWong1999/hermesclaw)** — WeChat Bridge
- **Nous Portal** — Nous Research統合サブスクリプション（300+モデル + Tool Gateway）

#### 評判

**肯定的:**
- 「30日使って体験が明確に変わった。2週目にはリサーチの好みを学習し、1週目の論文を新しい発見と結びつけ始めた」（[DEV.to 30日体験記](https://dev.to/uuhi_reddy_841b6e27138dcc/30-days-with-hermes-agent-the-only-ai-that-learned-from-my-mistakes-16i3)）
- 「18タスク中14でHermesが勝利。Claude Codeに負けた4タスクは純粋なコーディング能力。勝った14は先週のセッションを記憶していたから」（[Towards AI](https://pub.towardsai.net/i-tested-hermes-agent-vs-claude-code-vs-openclaw-on-18-real-tasks-the-10-week-old-one-cheats-by-0f2881a10213)）
- 「学習ループは本物。クロスセッションメモリは動く。Profile Distributionsによるチーム知識共有はIDEエージェントにはない」（[DEV.to](https://dev.to/uuhi_reddy_841b6e27138dcc/30-days-with-hermes-agent-the-only-ai-that-learned-from-my-mistakes-16i3)）

**否定的・懸念:**
- 「短時間では良さが分からない。30分のデモで体感できる類のものではない」（[Zenn](https://zenn.dev/flinters_blog/articles/e3bf5fafce3ed7)）
- 「規制環境にはまだ適さない。スキル署名、承認ワークフロー、監査証跡が未整備」（[Medium](https://kisztof.medium.com/hermes-agent-review-nous-researchs-self-improving-ai-agent-e72bc244435a)）
- 「スキルポイズニング、MCPサプライチェーン、ホスト上のクレデンシャル露出は未解決の脅威」（[Medium](https://kisztof.medium.com/hermes-agent-review-nous-researchs-self-improving-ai-agent-e72bc244435a)）
- 「エンタープライズフォークは不可避。署名付きスキル、監査ログ、ロールベース承認、コントロールプレーン付きの商用版が出る」（[Medium](https://kisztof.medium.com/hermes-agent-review-nous-researchs-self-improving-ai-agent-e72bc244435a)）
- 「Nous ResearchはWeb3出身でクリプト投資家から資金調達。公式トークン未発表だがコミュニティで憶測。技術評価と金融話題は分離推奨」（[Zenn](https://zenn.dev/evolink/articles/971638504819ee)）

### 他ツールとの比較・ポジショニング

#### Hermes Agent vs Claude Code vs Cursor vs OpenClaw

| 観点 | Hermes Agent | Claude Code | Cursor | OpenClaw |
|------|-------------|-------------|--------|----------|
| **カテゴリ** | パーソナル自律エージェント | コーディングエージェント | AI IDE | パーソナル自律エージェント |
| **主用途** | 長期稼働オートメーション | ソフトウェアエンジニアリング | IDE内コーディング | セルフホスト型エージェント |
| **メモリ** | 自動3+1層（MEMORY/USER/FTS5/Honcho） | CLAUDE.md（手動） | なし | MEMORY.md（ファイルベース） |
| **スキル** | エージェントが自動生成・改善 | なし | Skills（手動） | 人間が手動作成、ClawHub配布 |
| **モデル柔軟性** | 200+ via OpenRouter | Claude固定 | マルチモデル | マルチモデル |
| **常駐実行** | VPS/Docker/サーバーレス | ターミナルセッション中のみ | IDE起動中のみ | VPS/Docker |
| **メッセージング** | 7+プラットフォーム | なし | なし | 24+プラットフォーム |
| **cronジョブ** | ネイティブ対応 | なし | なし | あり |
| **コーディング能力** | 汎用（SWE-bench非特化） | 高い（SWE-bench 70-75%） | 高い（Tab補完優秀） | 汎用 |
| **初日の価値** | 低い（セットアップコスト） | 高い（即効性） | 高い（即効性） | 中 |
| **90日後の価値** | 高い（蓄積効果） | 変わらず | 変わらず | 中 |

**ポジショニングの要約:**
- Hermes Agent vs Claude Code は「エージェントプラットフォーム vs コーディングエージェント」。カテゴリが異なる（[SyntaxDispatch](https://www.syntaxdispatch.com/blog/hermes-agent-vs-claude-code)）
- 多くの開発者はClaude Code（コーディング）+ Hermes Agent（常駐オーケストレーション）を併用し、MCPでブリッジする構成を取り始めている（[BrowserAct比較](https://www.browseract.com/blog/hermes-agent-vs-claude-code-cursor)）
- OpenClawとは直接競合。メモリアーキテクチャとスキル自動生成が主要な差別化軸。OpenClawのエコシステム規模（345k Stars, 13k+スキル）vs Hermesの技術的深さ

#### コスト比較

- Claude Code（Sonnet 4.6）: ~$21.60/月（900タスク×3k input / 1k output tokens）
- Hermes Agent（DeepSeek-V3 via OpenRouter）: ~$1.72/月（同条件、92%削減）
- Hermes Agent（Sonnet 4.6 via OpenRouter）: Claude Codeと同等

出典: [NivaaLabs](https://nivaalabs.com/hermes-agent-vs-claude-code-2026/)

### 制約・注意点

1. **初日の生産性は低い:** セットアップと設定に時間がかかり、学習ループの効果が出るまで数週間〜数ヶ月。即効性を求めるならClaude Code/Cursorが適する
2. **コーディング特化ではない:** SWE-benchスコアでClaude Codeに劣る。純粋なコーディングエージェントとしては二線級
3. **セキュリティ未成熟:** スキル署名なし、承認ワークフロー未整備、監査証跡不十分。規制環境での利用は推奨されない
4. **Honchoメモリのライセンス:** Honcho OSSはAGPL v3.0。セルフホスト時にネットワークアプリケーションのソースコード公開義務が生じる可能性。マネージドクラウドならこの制約なし
5. **Windows対応はEarly Beta:** PowerShellインストーラーは動作するが、ダッシュボードのチャットペイン（POSIX PTY依存）はWSL2が必要
6. **Nous Researchのクリプト関連性:** Paradigm主導$50M調達、$1Bトークン評価。公式トークン未発表だが憶測あり。技術判断と投資判断の分離を推奨
7. **Mistral AI プロバイダ一時停止:** PyPI汚染により`mistralai`パッケージが削除中。復旧まで直接Mistralプロバイダは利用不可
8. **Issue数の多さ:** 13,795件オープン。急成長プロジェクト特有の課題が蓄積中
9. **モデルルーティングの運用負荷:** モデル非依存の柔軟性は「どのモデルをどのタスクに使うか」の判断コストを生む。自動ルーティングはない

### 深掘り候補（コードリーディング対象）

| 場所 | 関心 |
|------|------|
| `run_agent.py` | コア会話ループ、ツールディスパッチ、スキル生成トリガーの実装 |
| `agent/prompt_builder.py` | システムプロンプト組立の詳細（スキル・メモリ・コンテキストファイルの注入方法） |
| `tools/skill_tools.py` | スキル自動生成・改善のロジック |
| `hermes_state.py` | SQLite FTS5セッションDBの設計、セッション検索の実装 |
| `tools/delegate_tool.py` | サブエージェント生成・並列実行のアーキテクチャ |
| `acp_adapter/server.py` | ACP実装の詳細（JSON-RPC、セッション管理、パーミッション） |
| `plugins/memory/honcho/` | Honcho dialecticの統合実装 |
| `tools/lazy_deps.py` | 遅延依存インストールの仕組み |
| `agent/context_compressor.py` | コンテキスト自動圧縮のアルゴリズム |
| `tools/approval.py` | 危険コマンド検出・承認フロー |
| `gateway/run.py` | GatewayRunnerのプラットフォームライフサイクル管理 |
| `toolsets.py` + `toolset_distributions.py` | ツールグルーピングとプラットフォーム別プリセット |
