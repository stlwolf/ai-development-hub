---
name: Claude Flow
repo: ruvnet/claude-flow
last_reviewed: 2026-02-22
category: orchestrator
---

## Claude Flow (ruvnet/claude-flow) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/ruvnet/claude-flow
- **言語:** TypeScript (63.5%), JavaScript (23.5%), Python (9.0%)
- **作成日:** 2025-06-02
- **最終更新:** 2026-02-17
- **規模:** 14,337 stars / 1,683 forks / 20 contributors / 494 open issues / v3.1.0-alpha.44
- **npmダウンロード:** 月間約11万DL
- **ライセンス:** MIT
- **一言で:** Claude Code CLIの`child_process.spawn('claude')`ラッパーに、大規模な装飾的コードが付随した「エージェントオーケストレーション」フレームワーク

### ⚠️ 重要: 実態の評価

**独立した複数の監査で、主張される機能の大部分がモック/スタブ実装であることが確認されている。**

### これは何か・何を解決するのか

Claude Code向けのマルチエージェント・スウォーム・オーケストレーションプラットフォームを謳うツール。60以上の特化型エージェント、自己学習、分散合意アルゴリズム、ベクトルメモリ等を主張。

**しかし実際に動作する部分は `child_process.spawn('claude')` — つまりClaude Code CLIをサブプロセスとして起動しプロンプトを渡す、というシンプルな機能のみ。** 269個のJavaScriptファイル、107,000行のコードの大部分はモック/スタブ実装。

### 主張される機能 vs 実態

| 機能 | 主張 | 実態 | 根拠 |
|------|------|------|------|
| **60+ Specialized Agents** | 60以上の特化エージェント | JSON書き込み（`writeFileSync`）のみ。実プロセス未生成 | Medium監査, Issue #653 |
| **Queen-led Coordination** | 女王蜂が部下を統括 | `queen-coordinator.ts` (57KB) 存在するが実行はClaude CLIに委譲 | ソース構造確認 |
| **Anti-drift Mechanism** | トポロジ+チェックポイントで逸脱防止 | 動作確認報告なし | - |
| **AgentDB** | HNSW + SQLite + ONNX Runtime | Issue #1108でsql.js依存欠落によりメモリコマンドが壊れている | Issue #1108 |
| **Trust System** | エージェント信頼スコアリング | 動作確認報告なし | - |
| **WASM Acceleration** | 352x高速コード変換 | Agent Boosterとして存在するが実用性未検証 | README記載のみ |
| **Process Logs/Dashboard** | リアルタイムテレメトリ | **完全にMath.random()**。10個の定型メッセージをランダム選択 | Medium監査 |
| **Monitoring Metrics** | CPU/メモリ/稼働率 | **全てMath.random()**。ソースコメントに「実データがある場合に更新」とあるがコードパス不存在 | Medium監査 |
| **MCP Tools (100+)** | 100以上のMCPツール | **85%がモック/スタブ実装**。成功レスポンスを返すが実処理なし | Issue #653（系統的検証） |
| **Self-Learning** | SONA、ReasoningBank、EWC++ | パッケージ存在するが実運用での効果未検証 | optionalDependencies |
| **SWE-Bench 84.8%** | ベンチマーク成績 | 独立検証なし、根拠不明 | README記載のみ |

### 実際に機能する部分

| 機能 | 説明 | 重要度 |
|------|------|--------|
| `--claude`フラグでのClaude Code起動 | `child_process.spawn('claude')` | **唯一の実動作** |
| プロンプトインジェクション | Claude Codeに良いプロンプトを渡す | Utility |
| MCPサーバー登録 | Claude Codeからコマンドとして呼び出し可能 | Utility |
| APIキー不要 | Claude Codeサブスクリプション経由 | Utility |

### エコシステム・実利用状況

- **採用事例:** 特定企業やプロダクション利用の公開事例は発見できず
- **盛り上がりの文脈:** 2025年6月のClaude Code + MCPブームに乗り、AI Twitter/Xでのデモスクリーンショットが拡散。14k+ starsは「見た目の印象」に大きく依存
- **コミュニティ:** 494 open issues。形式的なIssueが多い
- **日本語コミュニティ:** Zenn/Qiitaでの言及はゼロ

**ポジティブ評判:**
- Derek Ashmore氏のbake-off記事: Claude Flowはネイティブ Agent Teamsと比較して「より深いリサーチ出力」「トークン効率良い」と評価
- **注意:** この結果はclaude-flowの「プロンプトランチャー」性質で説明可能

**ネガティブ評判（決定的）:**
- Jarad DeLorenzo氏の監査記事（2026-02-20頃）: 「テレメトリは乱数生成器」「ダッシュボードは同じゲーム」「エージェントはJSON」— ソースコード引用付き
- GitHub Issue #653（2025-08-14）: 85%のMCPツールがモック/スタブ — 系統的L1〜L4検証結果付き
- Issues #1106〜#1109（2026年2月）: エージェント終了失敗、sql.js欠落、hook-handler未生成、Claudeハードコード

### 他ツールとの比較

| 観点 | Claude Flow | TAKT | Composio Agent-Orchestrator |
|------|-------------|------|---------------------------|
| 実態 | Claude CLIプロンプトラッパー + 大量装飾コード | CLI駆動の透過的ファイルベースオーケストレーション | SaaS型ツール統合 + マルチエージェント管理 |
| コア価値 | 「良いプロンプトを自動構成してClaude Codeに渡す」 | YAMLワークフロー定義、協調制御 | 250+ツール統合、フレームワーク統合 |
| 透明性 | 極めて低い（モック多数、テレメトリ偽装） | 高い（ファイルベースで可視化） | 中程度（SaaS） |
| 信頼性 | 深刻な疑義あり | 小規模だが正直な実装 | 商用プロダクト |

Anthropicネイティブの Claude Code Agent Teams（環境変数1つで有効化）の登場により、外部オーケストレーターの必要性自体が低下している。

### 総合評価

**Claude FlowはClaude Code CLIの精巧なプロンプトラッパーであり、主張される高度な機能の大部分は実装されていないか装飾的なモック実装。** 14.3k starsは見た目の印象（印象的なREADME、ターミナルデモ）に依存しており、実際の技術的品質とは大きく乖離。

### 制約・注意点

1. 独立監査で85%モック/テレメトリ偽装が確認済み。プロダクション利用は推奨不可
2. Star数と実態の乖離。Issue #653は作者が閉じたが実質的修正なし
3. Alpha長期化（v3.0.0-alpha.79, v3.1.0-alpha.44）
4. 依存関係の不安定さ（agentdb, sql.js等で継続的に壊れる）
5. 実用的価値は「200行のスクリプトで実現可能」（監査記事の結論）

### 深掘り候補（実態確認用）

| パス | サイズ | 理由 |
|------|--------|------|
| `v3/@claude-flow/swarm/src/queen-coordinator.ts` | 57KB | Queen協調が本当に機能するか |
| `v3/@claude-flow/swarm/src/consensus/` | dir | Raft/Byzantine/Gossip実装の実態 |
| `v3/@claude-flow/memory/src/` | dir | AgentDB/ベクトル検索の実態 |
| `process.js` 562〜593行 | - | 偽テレメトリの直接確認 |
