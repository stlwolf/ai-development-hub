---
name: SWE-agent
repo: SWE-agent/SWE-agent
last_reviewed: 2026-02-22
category: agent-runtime
---

## SWE-agent (Princeton NLP) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/SWE-agent/SWE-agent（元: princeton-nlp/SWE-agent）
- **言語:** Python (3.11+)
- **最終更新:** 2026-02-17
- **規模:** 18,528 stars / 1,994 forks / 106 contributors / MIT
- **論文:** NeurIPS 2024採択
- **一言で:** LLMに「Agent-Computer Interface（ACI）」を介してGitHub Issueを自律解決させる研究プロジェクト

### これは何か・何を解決するのか

GitHub Issueの記述を入力としてLLMがDockerサンドボックス内でコードを自律的に探索・編集・テストしパッチを生成するシステム。最大の学術的貢献は**ACI（Agent-Computer Interface）**の概念提唱。

### 設計思想・アーキテクチャ

#### 核心概念: Agent-Computer Interface (ACI)

HCIがGUI/IDEで人間の生産性を高めたように、ACIはLMエージェント専用のインターフェースを設計することでエージェント性能を劇的向上させるという主張。

**ACI設計で発見された4つの原則:**
1. **空出力の明示処理:** コマンド成功だが出力なしの場合、明示メッセージを返す（エラー誤解防止）
2. **簡潔なファイル検索:** マッチファイルリストのみ返す（コンテキスト表示は混乱の元）
3. **100行ウィンドウ付きファイルビューア:** `cat`ではなくスクロール・検索付き専用ビューア
4. **編集時リンティング:** `edit`実行時にリンターで構文エラーチェック、エラーなら編集拒否

#### アーキテクチャ

```
sweagent CLI
├── SWEEnv (environment)
│   └── SWE-ReX Deployment (Docker / Modal / AWS)
│       └── FastAPI Server + Shell Session + ACI Tools
├── Agent
│   ├── action_sampler.py (LLM呼び出し)
│   ├── models.py (litellm統合)
│   ├── history_processors.py (コンテキスト圧縮)
│   ├── reviewer.py (submit前レビュー)
│   └── problem_statement.py (Issue解析)
└── Run Module
    ├── run.py / run_batch.py / run_replay.py
    └── inspector_cli.py (結果分析TUI)
```

**エージェントループ (Agent.forward()):**
1. 観察 → 2. 履歴構築（HistoryProcessor圧縮）→ 3. LLM推論 → 4. パース（function_calling/regex）→ 5. SWE-ReX経由でDocker実行 → 6. submit or 繰り返し

### 機能一覧

#### コア機能

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **ACI** | LM専用設計のツール群（ビューア、検索、エディタ、リンター） | `tools/` | コア |
| **YAML設定駆動** | テンプレート、ツール、パーサー、履歴処理を全てYAMLで設定 | `config/*.yaml` | コア |
| **マルチLLMバックエンド** | litellm経由 | `agent/models.py` | コア |
| **Dockerサンドボックス** | SWE-ReX経由 | `environment/swe_env.py` | コア |
| **バッチ実行** | SWE-bench等の並列評価 | `run/run_batch.py` | コア |
| **Submit前レビュー** | パッチ提出前の自己レビュー | `agent/reviewer.py` | コア |

#### ツールバンドル

| バンドル | 概要 | 分類 |
|---|---|---|
| `registry` | コアコマンド（filemap, search, submit等） | コア |
| `edit_anthropic` | Anthropic Computer Use風ファイル編集 | コア |
| `windowed` | 100行ウィンドウ付きビューア+エディタ | コア |
| `windowed_edit_linting` | 編集時リンター付き | コア |
| `review_on_submit_m` | submit時にdiff表示し自己レビュー促す | 差別化 |
| `image_tools` | 画像処理（マルチモーダル） | 拡張 |
| `web_browser` | Webブラウザ | 拡張 |

#### 差別化機能

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **HistoryProcessor** | LLMコンテキスト窓を最大活用する履歴圧縮 | `agent/history_processors.py` | 差別化 |
| **Trajectory Inspector** | Textual TUIで実行結果を対話分析 | `run/inspector_cli.py` | 差別化 |
| **Trajectory Replay** | 過去の軌跡を再生して環境状態再現 | `run/run_replay.py` | 差別化 |
| **Run Comparison** | 複数ラン結果の比較分析 | `run/compare_runs.py` | 差別化 |
| **EnIGMA** | CTF問題を解くサイバーセキュリティモード | 別論文 | 差別化 |
| **マルチモーダル** | Issue画像をVisionモデルで処理 | `config/default_mm_*.yaml` | 差別化 |
| **クラウドデプロイ** | Modal / AWSでリモート実行 | SWE-ReX経由 | 差別化 |

### 特徴的な点

1. **ACI設計の学術的貢献**: 単なるツール提供ではなく、「LMエージェント専用インターフェース設計が性能に支配的影響」という知見。NeurIPS 2024採択

2. **YAML一枚で全制御**: プロンプト、ツール、パーサー、履歴処理を1ファイルで管理。研究者がACI設計のA/Bテストを容易に実施可能

3. **SWE-ReXによる環境抽象化**: Local/Docker/Modal/AWSをコード変更なしで切り替え。100+エージェントの並列実行もサポート

4. **後継プロジェクト: mini-SWE-agent**: 100行Pythonで65-74%の性能。Meta, NVIDIA, IBM等が採用。READMEに「いずれSWE-agentを置き換える」と明記

### 使い方・典型的なワークフロー

```bash
pip install sweagent

sweagent run \
  --agent.model.name=claude-sonnet-4-20250514 \
  --agent.model.per_instance_cost_limit=2.00 \
  --env.repo.github_url=https://github.com/owner/repo \
  --problem_statement.github_url=https://github.com/owner/repo/issues/123

sweagent inspector  # Textual TUIで結果閲覧
```

### エコシステム・実利用状況

- **採用事例:** 主に研究・ベンチマーク文脈。mini-SWE-agentがMeta, NVIDIA, IBM, Princeton, Stanfordで採用
- **盛り上がりの文脈:**
  - 2024年4月: 初リリース + NeurIPS 2024採択
  - 2025年2月: v1.0 + Claude 3.7でSWE-bench全ベンチマークSoTA
  - 2025年5月: SWE-smith（50k学習インスタンス生成）
  - 2025年7月: mini-SWE-agent（100行で65%の衝撃）
- **周辺:** SWE-ReX, SWE-bench, SWE-smith, mini-SWE-agent, sb-cli
- **評判:**
  - 肯定: 「OSS SWE-benchのSoTA」「最もハック可能」「YAML一枚で実験設計」
  - 否定: 「Python前提でプロンプトが他言語に弱い」「Docker必須で敷居」「プロダクション機能不足」「mini-SWE-agentで本体の複雑さに疑問符」

### 他ツールとの比較

| 観点 | SWE-agent | OpenHands | Aider |
|---|---|---|---|
| 設計思想 | 研究用・ACI実験基盤 | エンタープライズAIプラットフォーム | Gitネイティブコーディングアシスタント |
| SWE-bench | ~74%（mini版） | ~72% | 非公開 |
| サンドボックス | Docker（SWE-ReX） | Docker | なし |
| カスタマイズ性 | YAML設定で高度 | ランタイムプラグイン | 限定的 |
| 最適用途 | 研究、ベンチマーク | プロダクション、チーム | 日常コーディング |

### 制約

1. **開発主力がmini-SWE-agentに移行中**
2. デフォルトプロンプトがPython前提
3. Docker必須
4. プロダクション向け機能不足（UI, RBAC等なし）
5. EnIGMAのv1.0未対応

### 深掘り候補

| ファイル | 理由 |
|---|---|
| `agent/agents.py` (55KB) | forward()ループ、ACI統合の核心 |
| `agent/history_processors.py` (15KB) | コンテキスト圧縮戦略 |
| `agent/reviewer.py` (26KB) | submit前レビュー機構 |
| `tools/parsing.py` (25KB) | function_calling/regexパーサー |
| `tools/edit_anthropic/` | Anthropic Computer Use風エディタ |
| `config/default.yaml` | 設定バリエーションとプロンプトエンジニアリング |
