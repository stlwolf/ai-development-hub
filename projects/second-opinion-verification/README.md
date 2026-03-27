# Second Opinion Verification Project

AIによるセカンドオピニオン（反証）と、マルチエージェント協調による検証フローの実験場。

## 検証の歩み

| 日付 | テーマ | 成果 |
|------|--------|------|
| 2026-02-09 | claude-safe タイムアウト実装 | セカンドオピニオンでゾンビプロセス・Ctrl+C問題を事前検出 |
| 2026-02-10 | claude-safe 疑似オーケストレーション | 実プロダクトのdeprecation修正で Cursor + Claude Code の協調を検証 |
| 2026-02-14 | Codex CLI 基本検証 | Cursor統合ターミナルからの安定動作・AGENTS.md認識・セッション管理を確認 |
| 2026-02-14 | Codex × Claude セカンドオピニオン比較 | Sentry修正で並行実行。Codex が Claude の誤判定を検出 |
| 2026-02-15 | 3エージェント深掘り検証 | ロール分担（案B: 逐次専門化）で再現経路を自律特定。Playwright MCP でステージング発火確認 |

## ディレクトリ構成

```
projects/second-opinion-verification/
├── src/
│   └── claude-safe-with-timeout     # タイムアウト付きスクリプト
├── docs/
│   ├── DOCUMENT_CONVENTION.md       # ドキュメント規約 (v0)
│   ├── plans/                       # 検証計画・キックオフ計画
│   ├── episodes/                    # 作業記録・検証レポート・セッション統合記録
│   └── decisions/                   # 確定した判断 (ADR)
```

## 確立されたツール・テンプレート

| 成果物 | 配置先 | 内容 |
|--------|--------|------|
| `/second-opinion` コマンド | `canonical/commands/verification/` | セカンドオピニオン取得コマンド |
| `so-compare.sh` | `scripts/` | Claude / Codex 並行比較スクリプト |
| facts.md テンプレート | `agent-verification-flow/docs/templates/` | 事実/解釈分離の構造化テンプレート |
| ロール設計パターン（案B） | `agent-verification-flow/docs/DESIGN_PRINCIPLES.md` | 逐次専門化の設計ガイド |

## 関連

- `projects/claude-safe/` — Claude CLI ラッパー
- `projects/agent-verification-flow/` — API検証ツールキット・テンプレート
- `ideas/20260208/hypothesis-second-opinion-review-flow.md` — 元アイデア
