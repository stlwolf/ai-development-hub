# Projects

独立した研究開発成果物・ツールキットの保管場所。

## インデックス

### agent-verification-flow

AIエージェントとの協調でAPI動作検証を行うツールキット。

- 認証自動化（JWT/Session）
- 検証レポートテンプレート
- マルチエージェントオーケストレーション研究

詳細は [agent-verification-flow/README.md](agent-verification-flow/README.md) を参照。

### claude-safe

Cursor/VS Code 統合ターミナルから Claude CLI を安全に実行するためのラッパースクリプト。

- `nohup` + 出力リダイレクトで TTY 競合を回避
- 疑似マルチエージェントオーケストレーションの基盤
- [Zenn記事](https://zenn.dev/stlwolf/articles/1a269f1e865e94)

詳細は [claude-safe/README.md](claude-safe/README.md) を参照。

### second-opinion-verification

claude-safe を使ったセカンドオピニオン（反証レビュー）と意図的圧縮（昇格フロー）の検証プロジェクト。

- タイムアウト付き Claude CLI ラッパー（watchdog パターン）
- episodes / decisions / plans の三層ドキュメント構造で検証プロセスを記録
- [ドキュメント規約 v0](second-opinion-verification/docs/DOCUMENT_CONVENTION.md)（YAML Frontmatter + use_when）

詳細は [second-opinion-verification/README.md](second-opinion-verification/README.md) を参照。
