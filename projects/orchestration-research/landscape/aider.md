---
name: Aider
repo: Aider-AI/aider
last_reviewed: 2026-02-22
category: agent-runtime
---

## Aider 調査結果

### 基本情報
- **リポジトリ:** https://github.com/Aider-AI/aider
- **言語:** Python (3.10-3.12)
- **規模:** 40,835 stars / 3,900+ forks / 490万インストール / 約30,000行
- **ライセンス:** Apache 2.0
- **作者:** Paul Gauthier（Inktomi創業者、元Groupon CTO）
- **一言で:** ターミナルベースのgit統合型AIペアプログラミングツール

### これは何か・何を解決するのか

ターミナルから直接LLMとペアプログラミング。既存gitリポジトリ内でLLMにコード変更を指示し、自動gitコミット。

**解決する問題:**
- 大規模コードベースの文脈をLLMに効率的に伝える（Repository Map）
- AI生成コードの変更管理・取り消し（git auto-commit + /undo）
- LLMのコード編集精度ばらつき（モデルごと最適edit format）
- IDE依存からの解放（ターミナルネイティブ）

### 設計思想・アーキテクチャ

#### コア: Coder パターン（Strategyパターン）

```
aider/
├── coders/           # Coder階層（edit format × chat mode マトリクス）
│   ├── base_coder.py       # 基底（LLM対話ライフサイクル）
│   ├── architect_coder.py  # architect/editor 2段階パイプライン
│   ├── ask_coder.py        # Q&Aモード
│   ├── editblock_coder.py  # search/replace format
│   ├── udiff_coder.py      # unified diff format
│   ├── wholefile_coder.py  # whole file format
│   ├── search_replace.py   # diff適用ファジーマッチング
│   └── chat_chunks.py      # プロンプト組み立て
├── repomap.py        # Repository Map（tree-sitter + PageRank）
├── repo.py           # GitRepo抽象（auto-commit, dirty file管理）
├── models.py         # LLMモデル設定・メタデータ
├── commands.py       # /add, /drop, /undo 等30+コマンド
├── linter.py         # tree-sitter基盤lint
├── watch.py          # AI comment監視（IDE連携）
├── voice.py          # Whisper音声入力
├── scrape.py         # Webスクレイピング
└── sendchat.py       # LLM API呼び出し（litellm経由）
```

**設計上の重要判断:**
- litellmでLLM統一抽象化。モデル固有挙動は`models.py`メタデータで管理
- **型ヒントなし方針**（CONTRIBUTING.md明記）
- `pip-tools`ベースの依存管理

### 機能一覧

#### コア

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **Repository Map** | tree-sitter + PageRankでコードベース構造マップ生成。トークン予算内で動的選択 | `repomap.py` | コア |
| **Edit Formats** | 6種類（diff, diff-fenced, udiff, whole, editor-diff, editor-whole）をモデル毎に最適選択 | `coders/*_coder.py` | コア |
| **Chat Modes** | code / ask / architect / help の4モード | `coders/` | コア |
| **Git Auto-Commit** | 変更ごと自動コミット。dirty file事前別コミット。Conventional Commits準拠メッセージ自動生成 | `repo.py` | コア |
| **100+ 言語サポート** | tree-sitter-language-pack | `queries/` | コア |

#### 差別化

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **Architect Mode** | architect（計画）→ editor（実装）の2段階LLMパイプライン | `coders/architect_coder.py` | 差別化 |
| **Watch Mode** | ファイル監視。`AI!`/`AI?`コメントで任意IDEから指示 | `watch.py` | 差別化 |
| **Copy/Paste Web Chat** | `/copy-context`→ブラウザLLM→`/paste`でAPI不要利用 | `copypaste.py` | 差別化 |
| **Auto Lint & Fix** | 編集後自動lint + tree-sitter構文エラー検出 + カスタムlinter | `linter.py` | 差別化 |
| **Voice-to-Code** | Whisper音声入力 | `voice.py` | 差別化 |
| **LLM Leaderboard** | 独自polyglotベンチマーク（225問、6言語） | `benchmark/` | 差別化 |

#### ユーティリティ

| 機能 | 概要 | 分類 |
|------|------|------|
| Web Scraping | `/web <url>`でMarkdown化 | ユーティリティ |
| Image Support | マルチモーダル画像入力 | ユーティリティ |
| Scripting/Headless | `--message`ワンショット、`--yes`自動確認。CI/CD連携 | ユーティリティ |
| 30+ In-chat Commands | `/add`, `/drop`, `/undo`, `/diff`, `/git`, `/run`, `/test`, `/lint` | ユーティリティ |
| Commit Attribution | `(aider)`メタデータ + `Co-authored-by` | ユーティリティ |
| Browser UI | Streamlitベース | ユーティリティ |

### 特徴的な点

**1. Repository Map — PageRank + tree-sitter**

最も独自性の高い機能:
1. tree-sitter AST解析 → 定義(def)と参照(ref)タグ抽出
2. `networkx.MultiDiGraph` で依存グラフ構築
3. `nx.pagerank()` でファイル重要度算出
4. `max_map_tokens`内に二分探索で切り詰め
5. `TreeContext`（grep_ast）で省略記号付きコンテキスト表示

重み付けヒューリスティクス:
- snake_case/camelCase 8文字以上 → 10倍
- ユーザー言及識別子 → 10倍
- チャット中ファイルからの参照 → 50倍
- `_`始まりプライベート → 0.1倍
- 定義が5ファイル超の汎用名 → 0.1倍

**2. Edit Format アーキテクチャ**

6種類のedit formatをモデルごとに最適選択。`search_replace.py`がファジーマッチングでLLM出力ブレを吸収。

**3. Architect Mode — 2段階LLMパイプライン**

architect（推論モデル: o1/o3）→ editor（編集モデル: GPT-4o/Sonnet）。同一モデルでも2回分けで精度向上報告あり。

**4. Git統合**

dirty file事前コミット（人間/AI変更分離）、Conventional Commitsメッセージ自動生成（weak-model）、`/undo`即時取り消し、`(aider)`メタデータ、pre-commitフックデフォルトスキップ。

### 使い方

```bash
python -m pip install aider-install && aider-install
cd /your/project
aider --model sonnet --api-key anthropic=sk-...
```

推奨ワークフロー: `ask`で議論 → `code`で実装

```
ask> このリポジトリの認証フローは？
ask> JWTをセッションベースに変更したい。影響範囲は？
> go ahead  # code modeに切り替わり、編集+auto-commit
```

設定: `.aider.conf.yml`

```yaml
model: sonnet
auto-commits: true
map-tokens: 2048
lint-cmd: flake8
test-cmd: pytest
```

### エコシステム

- **採用:** Paul Gauthier自身が「各リリース新コードの約70%はAI」。ESRが「人生が変わった」
- **SWE-bench**: Lite/Main両方でSOTA達成実績
- **周辺:** nvim-aider, Aider Smart Context (VS Code), aider-script, aider-lint-fixer
- **評判:**
  - 肯定: 「既存コードベースでの実作業に最強」「精密なLLMコード生成ツール」「開発者をコントロール下に置く」
  - 否定: 長い会話でコンテキスト劣化、手動`/add`が必要、MCP未対応、litellm依存リスク

### 他ツールとの比較

| 観点 | Aider | Cursor | OpenHands | SWE-agent |
|------|-------|--------|-----------|-----------|
| 形態 | CLIツール | IDE | Webプラットフォーム | 研究CLI |
| コードベース理解 | Repository Map（PageRank） | IDE内蔵インデックス | コンテナ内探索 | ACI |
| git統合 | ネイティブ（auto-commit, undo） | IDE内蔵 | 限定的 | 限定的 |
| 自律性 | 低〜中（対話的） | 中 | 高 | 高 |
| コスト | API料金のみ（月$50-100目安） | $20-40/月 + API | セルフホスト | セルフホスト |

**ポジショニング:** 「開発者がコントロールを保持する対話型ペアプログラマー」

### 制約

1. 長い会話でコンテキスト劣化（定期`/clear`推奨）
2. 大規模コードベースでは手動`/add`が必要
3. MCP未対応
4. Python 3.10-3.12限定
5. litellm依存リスク（unhandled exceptionでハング）
6. IDE Watch ModeのJetBrains問題
7. 型ヒントなし方針

### 深掘り候補

| 対象 | パス | 理由 |
|------|------|------|
| Repository Map PageRank | `repomap.py:365-575` | networkxグラフ構築、重み付けヒューリスティクス |
| Search/Replace ファジーマッチング | `coders/search_replace.py` | LLM出力ブレの吸収 |
| Architect パイプライン | `coders/architect_coder.py` | 2段階呼び出しフロー |
| Base Coder ライフサイクル | `coders/base_coder.py` | LLM対話→編集→lint→commit |
| GitRepo抽象 | `repo.py` | auto-commit, undo, attribution |
| Watch Mode | `watch.py` | ファイル監視→AIコメント検出 |
| Model メタデータ | `models.py` | モデルごとedit format, トークン上限 |
