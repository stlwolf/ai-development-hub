---
name: TAKT
repo: nrslib/takt
last_reviewed: 2026-02-22
category: orchestrator
---

## TAKT (nrslib/takt) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/nrslib/takt
- **言語:** TypeScript (strict mode, ES2022, Node.js >= 18)
- **最終更新:** 2026-02-22 (v0.22.0)
- **規模:** 424 stars, 24 forks, npm パッケージとして公開 (`npm install -g takt`)
- **ライセンス:** MIT
- **作者:** nrslib (成瀬氏 / @nrslib) — 日本の開発者。Qiitaで11,000+コントリビューション、Clean Architecture / DDDの分野で知名度あり
- **一言で:** AIコーディングエージェント（Claude Code / Codex / OpenCode）を YAML定義のワークフローで「強制的に」plan → implement → review → fix ループさせるCLIオーケストレーター

### これは何か・何を解決するのか

AIコーディングエージェントを使った開発における「見張り番問題」を解決するツール。

作者の問題意識は明確で、[発表記事](https://zenn.dev/nrs/articles/c6842288a526d7)で次のように語っている:

> 「AIエージェントにサブエージェントを呼び出させるアプローチも試したが、使ってくれるときもあれば完全に無視するときもある。結局、人間が見張り番をしている」

TAKTの解決策は「**強制力**」。AIに「お願い」するのではなく、ワークフロー定義（piece）としてレビュー→修正のループを**仕組みとして強制**する。エージェントがスキップできない。遷移判定はAIの自由意志ではなくpieceに定義されたルールに基づく。

ターゲットユーザーは、Claude Code / Codex / OpenCode を日常的に使っている個人開発者〜小規模チーム。特に「AIエージェントの出力品質を上げたいが、人間がレビューし続けるのは疲れる」という層。

### 設計思想・アーキテクチャ

#### 音楽メタファ
全体を通じて音楽メタファで用語統一:
- **Piece** = ワークフロー定義 (YAML)
- **Movement** = ワークフロー内の1ステップ
- **Persona** = エージェントの役割定義
- **Arpeggio** = データ駆動バッチ処理
- **Repertoire** = 共有可能なパッケージ

#### Faceted Prompting（関心の分離パターン）
TAKT最大の設計的特徴。モノリシックなプロンプトを5つの独立ファセットに分解:

| ファセット | 問い | 配置 |
|---|---|---|
| **Persona** | 誰として振る舞うか | System Prompt |
| **Policy** | 何を守るか | User Message (末尾 = 再現性効果) |
| **Instruction** | 何をするか | User Message |
| **Knowledge** | 何を参照するか | User Message |
| **Output Contract** | どう出力するか | User Message |

各ファセットは独立したMarkdownファイルで管理され、piece YAMLで宣言的に組み合わせる。Policyを末尾に配置するのは意図的で、LLMのrecency effectを活用した設計判断。

#### 3フェーズ実行モデル
各movementは3フェーズで実行される:
1. **Phase 1** — メインワーク (コーディング、レビュー等)
2. **Phase 2** — レポート出力
3. **Phase 3** — ステータス判定 (構造化出力 + AI judge)

#### ソースコード構造 (`src/`)

```
src/
├── agents/           # エージェント抽象化
├── app/cli/          # CLIエントリポイント (commander.js)
├── commands/         # コマンド実装 (repertoire等)
├── core/
│   ├── models/       # ドメインモデル
│   ├── piece/        # ピースエンジン (中核)
│   │   ├── arpeggio/ # データ駆動バッチ処理
│   │   ├── engine/   # PieceEngine
│   │   ├── evaluation/ # ルール評価
│   │   ├── instruction/ # InstructionBuilder
│   │   └── run/      # ランタイム
│   └── runtime/      # ランタイムプリセット (gradle, node)
├── faceted-prompting/ # Faceted Promptingライブラリ (TAKT非依存)
├── features/
│   ├── analytics/    # レビュー品質メトリクス
│   ├── catalog/      # ファセットカタログ
│   ├── interactive/  # 対話モード
│   ├── pieceSelection/ # ピース選択UI
│   ├── pipeline/     # CI/CDパイプラインモード
│   ├── repertoire/   # パッケージ管理
│   └── tasks/        # タスク管理
├── infra/
│   ├── claude/       # Claude Code SDK統合
│   ├── codex/        # Codex SDK統合
│   ├── opencode/     # OpenCode SDK統合
│   ├── mock/         # テスト用モック
│   ├── github/       # GitHub CLI統合
│   └── task/         # Git操作 (clone, branch)
└── shared/           # i18n, プロンプト, ユーティリティ
```

### 機能一覧

#### Core（中核機能）

| 機能 | 概要 | 場所 |
|---|---|---|
| **PieceEngine** | YAML定義のワークフロー実行エンジン。movement間遷移、ルール評価、ループ制御 | `src/core/piece/engine/` |
| **Faceted Prompting** | プロンプトの5関心事分離・宣言的合成。TAKT非依存のスタンドアロンライブラリ | `src/faceted-prompting/` |
| **ルール評価** | Tag-based / AI judge / Aggregate (`all()`, `any()`) の3種類の条件判定 | `src/core/piece/evaluation/` |
| **Parallel Movements** | 複数レビュアーの並列実行 + 集約評価 | `src/core/piece/engine/` |
| **Structured Output** | JSON Schema ベースの構造化出力（タスク分解、ルール評価、ステータス判定） | `builtins/schemas/` |
| **マルチプロバイダー** | Claude Code / Codex / OpenCode の3プロバイダー対応。APIキー直接指定も可 | `src/infra/claude/`, `codex/`, `opencode/` |
| **Persona Providers** | ペルソナ単位でプロバイダー/モデルを切り替え（coderはCodex、reviewerはClaude等） | 設定のみ |
| **Provider Profiles** | プロバイダー別のパーミッションプロファイル（5段階優先度解決） | `src/core/piece/permission-profile-resolution.ts` |

#### Differentiator（差別化機能）

| 機能 | 概要 | 場所 |
|---|---|---|
| **Interactive Mode** | `takt`起動で対話的にタスク要件をAIと詰め、`/go`で実行。4モード | `src/features/interactive/` |
| **Team Leader Movement** | エージェントがタスクを動的にサブタスク分解し、複数partエージェントを並列実行 | `src/core/piece/engine/` |
| **Arpeggio Movement** | CSV等のデータソースからバッチ分割→テンプレート展開→並列LLM呼び出し→結果マージ | `src/core/piece/arpeggio/` |
| **Repertoire Package System** | GitHubリポジトリからTAKTパッケージをインストール・共有。`@scope`参照構文 | `src/features/repertoire/` |
| **Loop Monitor / Cycle Detection** | 無限ループ検出と仲裁ステップの自動挿入 | `src/core/piece/engine/` |
| **Worktree Isolation** | `git clone --shared`による完全分離実行 | `src/infra/task/` |
| **Task Queue + Batch Execution** | `takt add` → `takt run` でキューイング→バッチ実行。並列ワーカープール (1-10) | `src/features/tasks/` |
| **Instruct/Retry Mode** | 完了/失敗タスクに対して追加指示→再実行 | `src/features/tasks/` |
| **Analytics Module** | レビュー品質メトリクス（REJECT率、ラウンドトリップ率等）のローカル収集 | `src/features/analytics/` |
| **MAGI Piece** | エヴァンゲリオン着想の3者合議システム | `builtins/*/pieces/` |

#### Utility（ユーティリティ機能）

| 機能 | 概要 | 場所 |
|---|---|---|
| **ビルトインピース** | 22+種のプリセットワークフロー | `builtins/*/pieces/` |
| **ビルトインペルソナ** | 18+種のプリセットペルソナ | `builtins/*/facets/personas/` |
| **GitHub Issue統合** | `takt #N` でIssueをタスクとして実行 | `src/infra/github/` |
| **GitHub Actions統合** | `nrslib/takt-action` でCI/CD連携 | 別リポジトリ |
| **Pipeline Mode** | `--pipeline` で非対話実行。CI向けオプション | `src/features/pipeline/` |
| **i18n (en/ja)** | UI・ビルトインリソースが英語/日本語に完全対応 | `builtins/en/`, `builtins/ja/` |
| **Eject** | ビルトインをユーザーディレクトリにコピーしてカスタマイズ | CLI |
| **NDJSON Session Logs** | 全実行ステップのリアルタイムログ | `.takt/runs/` |
| **Slack Webhook** | piece完了時のSlack通知 | `src/infra/` |
| **Prevent Sleep** | macOSの`caffeinate`でスリープ防止 | 設定のみ |
| **Branch Name Strategy** | `romaji`または`ai`でブランチ名自動生成 | 設定のみ |
| **takt export-cc** | Claude Code Skillとしてエクスポート | CLI |
| **takt catalog** | 利用可能なファセット一覧表示 | `src/features/catalog/` |
| **takt watch** | タスク監視デーモン | CLI |
| **PR Duplicate Prevention** | 既存PRがある場合はpush+コメント | `src/features/tasks/` |

### 特徴的な点・注目ポイント

1. **「強制力」の設計哲学**: ワークフローエンジンが確定的にレビュー→修正ループを回す。AIがスキップできない。これがTAKTの核心的価値。

2. **Faceted Prompting**: Separation of Concernsをプロンプト設計に適用した独自パターン。`src/faceted-prompting/`としてTAKT非依存ライブラリとして切り出されている。

3. **Dogfooding**: TAKTはTAKT自身で開発されている。v0.12.0のOpenCode対応も「taktにタスクを積んで夜回したら朝PRができていた」と[作者が報告](https://zenn.dev/nrs/articles/5f549e7fe0ff75)。

4. **異常なリリース速度**: 約4週間で22メジャーバージョン。CHANGELOGは1,050行。

5. **Persona Providers**: 1つのpieceの中で「coderはCodex、reviewerはClaude」とプロバイダーを混在可能。

6. **Repertoire System (v0.22.0)**: GitHubからTAKTパッケージをインストール・共有できるエコシステム基盤。

### 使い方・典型的なワークフロー

```bash
npm install -g takt
takt  # 対話モード起動

# ピース選択 → AIと要件を詰める → /go で実行
> JWTトークン検証をユーザー認証モジュールに追加して
> /go

# タスクキューイング
takt add "認証モジュールのリファクタリング"
takt add #28
takt run

# GitHub Actions統合
# Issueコメント「@takt run」でトリガー
```

設定例 (`~/.takt/config.yaml`):

```yaml
provider: claude
model: sonnet
language: ja
concurrency: 3
persona_providers:
  coder:
    provider: codex
    model: o3-mini
  ai-antipattern-reviewer:
    provider: claude
```

### エコシステム・実利用状況

- **採用事例:** 作者自身がフルdogfooding。第三者のプロダクション事例は未確認だが、[ito氏のZenn記事](https://zenn.dev/ito/articles/472d6f11023eed)で「圧倒的な堅牢さ」「3並列レビューが高い完遂能力を生んでいる」と高評価。
- **盛り上がりの文脈:**
  - 2026年2月の「AIエージェント・オーケストレーション」トレンドのど真ん中
  - OpenCode対応で「無料でオーケストレーションを試せる」参入障壁低下
  - 作者Zenn記事「[AIの見張り番をやめよう](https://zenn.dev/nrs/articles/c6842288a526d7)」が日本語コミュニティでの認知を獲得
- **コミュニティ:** Discord, GitHub Issues/PR活発、作者がZennで精力的に記事執筆。日本語コミュニティ中心。
- **周辺ツール:** takt-action (GitHub Actions), Repertoire System, takt export-cc, デバッグビューア
- **評判:**
  - 肯定的: 確実性、Faceted Promptingの設計思想
  - 懸念: APIコスト、OpenCodeモデルでの収束困難

### 他ツールとの比較・ポジショニング

| 観点 | TAKT | Composio agent-orchestrator | multi-agent-shogun | Claude Code Agent Teams | TaskSmith |
|---|---|---|---|---|---|
| 中核思想 | 確定的ワークフロー強制 | 並列Agent + CI自動化 | 武士階層型の並列実行 | ネイティブサブエージェント | バリデーション駆動 |
| プロバイダー | Claude/Codex/OpenCode | Claude/Codex/Aider | Claude/Codex/Copilot/Kimi | Claude のみ | Claude のみ |
| レビュー強制 | ピースで強制 | CI連動 | Gunshi(軍師)による | AIの判断次第 | テストバリデーション |
| 独自性 | Faceted Prompting / Persona Providers | ダッシュボード / CI自動修復 | tmux直接制御 | ネイティブ統合 | 3階層メモリ |

TAKTの最も明確なポジショニングは「**確定性**」。他のツールがAIの自律性を前提にしているのに対し、TAKTはステップ遷移を確定的に制御する。

### 制約・注意点

1. **成熟度:** v0.22.0、約1ヶ月。BREAKING CHANGEが頻発。安定版には至っていない。
2. **開発体制:** 事実上の個人プロジェクト。バス因子は1。
3. **APIコスト:** マルチステージレビューはトークン消費が大きい。
4. **モデル依存性:** レビューループの収束はモデル品質に依存。
5. **英語圏認知:** 日本語コミュニティが先行。英語圏での採用事例は未確認。
6. **セキュリティ:** エージェントの自律性拡大に伴うリスクは利用者側で管理が必要。

### 深掘り候補（コードリーディング対象）

| 対象 | パス | 理由 |
|------|------|------|
| PieceEngine | `src/core/piece/engine/` | ステート管理と遷移ロジック。「強制力」の実装 |
| ルール評価 | `src/core/piece/evaluation/` | tag-based / AI judge / aggregate の実装 |
| Status Judgment Phase | `src/core/piece/status-judgment-phase.ts` | Phase 3のStructured Output統合 |
| Faceted Prompting | `src/faceted-prompting/` | 合成・解決ロジック。TAKT非依存設計 |
| Arpeggio | `src/core/piece/arpeggio/` | データ駆動バッチ処理の実装 |
| プロバイダー統合 | `src/infra/claude/`, `codex/`, `opencode/` | 3 SDK統合の抽象化パターン |
| Repertoire | `src/features/repertoire/` | パッケージシステムの実装 |
| ビルトインポリシー | `builtins/en/facets/policies/coding.md` | AIアンチパターン検出基準の具体例 |
