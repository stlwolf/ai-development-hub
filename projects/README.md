# Projects

独立した研究開発成果物・ツールキットの保管場所。

## インデックス

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

### cursor-thread-tools

Cursorスレッド会話のMarkdownエクスポートとライフサイクル管理を行うVS Code拡張。

- `state.vscdb`（SQLite）からの会話データ読み取り
- スレッド完了報告の定型化（git diff + GitHub Issue投稿）
- 4層モデルの「層3: 生ログ抽出パイプライン」の実装

詳細は [cursor-thread-tools/README.md](cursor-thread-tools/README.md) を参照。

### second-opinion-verification（アーカイブ）

セカンドオピニオン（反証レビュー）の検証プロジェクト。**検証フェーズ完了、以降の知見は `agent-verification-flow` に統合。**

- タイムアウト付き Claude CLI ラッパー（watchdog パターン）
- episodes / decisions / plans の三層ドキュメント構造
- [ドキュメント規約 v0](second-opinion-verification/docs/DOCUMENT_CONVENTION.md)
- [ドキュメント関連マップ](second-opinion-verification/docs/INDEX.md)

詳細は [second-opinion-verification/README.md](second-opinion-verification/README.md) を参照。

---

## アーカイブ (`_archived/`)

役割を終えた・代替手段が確立されたプロジェクトの保管場所。

### cursor-devtools-inspector

Playwrightでheadless Chromiumを起動し、ネットワーク・コンソール・DOM情報をJSON出力するCLIツール。Playwright MCP（`cursor-ide-browser`）の導入により同等機能がCursorにネイティブ統合されたためアーカイブ。

詳細は [_archived/cursor-devtools-inspector/README.md](_archived/cursor-devtools-inspector/README.md) を参照。
