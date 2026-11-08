# Projects

独立した研究開発成果物・ツールキットの保管場所。

## インデックス

### orchestration-engine

複数の AI コーディングエージェントのセッションを、統括（親）と子に分けて動かすための Bash + jq の CLI 群。

- 本体のエンジン `oe`: wez のペインに agent を起こし、1 サイクル（envelope→spawn→capture→verify→monitor）を自律で回す
- 親子の委譲: `oe-delegate` / `oe-kick` / `oe-send` などで、統括から tmux の子セッションへタスクを渡し、報告を受ける
- cockpit の観測: `oe-tree` / `oe-activity` / `oe-threads` / `oe-status` などの read-only のビューと、`oe-vitals` / `oe-undelivered` / `oe-confirm` などの見張り
- 統括の交代と lease: `oe-handoff` で統括を計画的に交代し、`oe-lease` で統括と子の「誰か」をペインと切り離して記録する
- SO のゲート: `oe-refute`（設計の反証）・`oe-review`（実装のレビュー）

詳細は [orchestration-engine/README.md](orchestration-engine/README.md) を参照。

### arena-compare

Cursor CLI（`agent` コマンド）によるマルチモデル並列比較スクリプト。

- 同一プロンプトを複数モデルに並列投入して結果を比較
- Cursor サブスク内の全モデル（38+）を利用（外部 API 不要）
- `-w` でワークスペースパス参照（`-c` によるファイル添付は非推奨）
- `--resume-from` によるセッション維持でイテレーション可能
- スキル（`canonical/skills/arena-compare/SKILL.md`）とコマンド（`/arena-perspectives`）を通じたサブエージェント委譲対応
- 探索モード: 「不可能」回答時に persistent-exploration の行動制約を注入して自動深掘り
- `~/bin/arena-compare` として PATH 配置済み（`scripts/sync/sync-bin.sh`）

詳細は [arena-compare/README.md](arena-compare/README.md) を参照。

### agent-verification-flow

マルチエージェント検証フレームワーク。API動作検証、ロール設計パターン、検証テンプレートを提供。

- 認証自動化（JWT/Session）
- 検証レポート・検証ケーステンプレート
- facts.md テンプレート（事実/解釈分離）
- ロール設計パターン（案A: 並行比較、案B: 逐次専門化）
- 計画/実行分離パターン
- SO 効果分析・限界の知見

詳細は [agent-verification-flow/README.md](agent-verification-flow/README.md) を参照。

### claude-safe

Cursor/VS Code 統合ターミナルから Claude CLI を安全に実行するためのラッパースクリプト。

- `nohup` + 出力リダイレクトで TTY 競合を回避
- 疑似マルチエージェントオーケストレーションの基盤
- [Zenn記事](https://zenn.dev/stlwolf/articles/1a269f1e865e94)

詳細は [claude-safe/README.md](claude-safe/README.md) を参照。

### wezterm-ai-mode

WezTerm の Human Mode / AI Mode デュアル構成を支える `wez` CLI ツールキット（Bash）。Phase 1（CLI）の完了後に、dotfiles の Lua ハンドラとの統合による toast 通知の開通（#86）と `wez layout` を足した。[Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20) は close 済みで、`wez agent`（Epic の Phase 3 の構想）は実装していない。

- サブコマンド: `discover`（ソケット自動検出）/ `pane`（list/split/activate/send/capture/kill）/ `layout`（preset による盤面の構築）/ `notify`（OSC 1337 user-var 送信）
- Cursor / Claude Code / Codex CLI の3ツールで E2E 検証済み
- `~/bin/wez` として PATH 配置済み（`scripts/sync/sync-bin.sh`）
- [CONVENTIONS.md](wezterm-ai-mode/CONVENTIONS.md)、[VERIFICATION_MATRIX.md](wezterm-ai-mode/docs/VERIFICATION_MATRIX.md)

詳細は [wezterm-ai-mode/README.md](wezterm-ai-mode/README.md) を参照。

### orchestration-research

エージェントオーケストレーション・並列エージェントツール群のランドスケープ調査プロジェクト。

- 既存OSSの設計パターン・概念・実装方式を体系的に調査・抽出
- 抽出した要素と自分の検証知見（認知協調・知識永続化）を合成
- 自前オーケストレーションツール構築の設計基盤

詳細は [orchestration-research/README.md](orchestration-research/README.md) を参照。

### ruler-agent-verification

ルーラーエージェント（判断履歴のナビゲーター）構想の検証プロジェクト。

- SOの前段に「過去の判断履歴から関連コンテキストを自動選定する」エージェントを配置する構想
- Gemini CLI での初期検証完了（技術的適性は高い、アクセスモデルが課題）
- 個別タスクでルーラーを実行し、実績を蓄積して精度・有用性を評価

詳細は [ruler-agent-verification/README.md](ruler-agent-verification/README.md) を参照。

### second-opinion-verification（アーカイブ）

セカンドオピニオン（反証レビュー）の検証プロジェクト。**検証フェーズ完了、以降の知見は `agent-verification-flow` に統合。**

- タイムアウト付き Claude CLI ラッパー（watchdog パターン）
- episodes / decisions / plans の三層ドキュメント構造
- [ドキュメント規約 v0](second-opinion-verification/docs/DOCUMENT_CONVENTION.md)
- [ドキュメント関連マップ](second-opinion-verification/docs/INDEX.md)

詳細は [second-opinion-verification/README.md](second-opinion-verification/README.md) を参照。

### poc/

技術検証（PoC）の凍結スナップショット。

- [`poc/wezterm-ai-mode/`](poc/wezterm-ai-mode/README.md): wezterm-ai-mode の一次根拠の PoC

---

## アーカイブ (`_archived/`)

役割を終えた・代替手段が確立されたプロジェクトの保管場所。

### cursor-thread-tools

Cursor Composer / Agent スレッドの Markdown エクスポート（拡張 + CLI）。

**正本・Release は [stlwolf/cursor-thread-tools](https://github.com/stlwolf/cursor-thread-tools) に移行済み。** hub 側は履歴アーカイブのみ。

詳細は [_archived/cursor-thread-tools/README.md](_archived/cursor-thread-tools/README.md) を参照。

### agent-rule-decomposition

マルチエージェント/サブエージェント環境におけるドキュメントルール分割の検証プロジェクト。議論ドキュメントの段階のまま、検証には進まずにアーカイブ（#594）。

- 集権的ルール（CONVENTIONS.md）のサブエージェント向け分割粒度の検証
- エージェント役割とルールのマッピング（実装/レビュー/ドキュメント）
- スキル/ルール/.mdc の配布メカニズムと優先順位の調査
- ルール衝突時の解決パターン

詳細は [_archived/agent-rule-decomposition/README.md](_archived/agent-rule-decomposition/README.md) を参照。

### cursor-devtools-inspector

Playwrightでheadless Chromiumを起動し、ネットワーク・コンソール・DOM情報をJSON出力するCLIツール。Playwright MCP（`cursor-ide-browser`）の導入により同等機能がCursorにネイティブ統合されたためアーカイブ。

詳細は [_archived/cursor-devtools-inspector/README.md](_archived/cursor-devtools-inspector/README.md) を参照。
