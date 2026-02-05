# AI Agent CLI連携 - アイデア・検証ドキュメント

作成日: 2026-02-04

## 概要

Claude Code / Cursor Agent / Gemini などのAIエージェントをCLI経由で連携させる「マルチエージェントオーケストレーション」の検証と実験記録。

## このディレクトリの内容

| ファイル | 説明 |
|----------|------|
| `ai-agent-orchestration.md` | 全体像: CLI連携の可能性、フレームワークとの比較、各エージェントの視点 |
| `claude-safe.md` | claude-safeラッパーの詳細ドキュメント |
| `claude-safe` | Cursor統合ターミナル用Claude CLIラッパースクリプト |

## 検証で確認できたこと

1. **双方向CLI通信**: Claude Code ↔ Cursor Agent の非インタラクティブ連携が動作する
2. **プロセス分離による安定化**: `nohup`ラッパーでCursor統合ターミナルからの実行が可能に
3. **異種サービス横断**: フレームワークなしでも複数AIエージェントを組み合わせられる

## 今後の発展方向

### 短期（実験継続）

- [ ] コンテキスト・エンベロープ（JSON構造）の実装
- [ ] `jq`を使った中間状態の検証スクリプト
- [ ] タイムアウト・リトライ機構の追加

### 中期（ユースケース特化）

- [ ] `ai-review` - 複数視点コードレビュー
- [ ] `ai-refactor` - リファクタ提案の比較検討
- [ ] `ai-debug` - 複数エージェントでの原因特定

### 長期（フレームワーク統合検討）

- [ ] 複雑な状態管理が必要になった場合にLangGraph等を検討
- [ ] MCP経由での連携強化

## 関連

- dotfiles: `bin/claude-safe`, `docs/claude-safe.md`, `docs/AI_AGENT_ORCHESTRATION.md`
- [GitHub Issue #11707](https://github.com/anthropics/claude-code/issues/11707) - VS Code terminal interrupts

## ステータス

🧪 **検証段階** - 基本動作確認済み、実用化に向けて改善中
