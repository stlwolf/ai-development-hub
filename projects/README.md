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
- [Zenn記事](https://zenn.dev/stlwolf/articles/cursor-agent-claude-cli-nohup-wrapper)

詳細は [claude-safe/README.md](claude-safe/README.md) を参照。
