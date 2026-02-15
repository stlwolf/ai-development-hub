# ドキュメント関連マップ

このプロジェクト配下の全ドキュメントの関連性を示す。

## 全体の流れ

```
2/9  claude-safe タイムアウト実装
      │
      ├── [plan] verification-plan ─── 検証計画
      ├── [episode] timeout-design ─── タイムアウト設計の議論
      ├── [episode] timeout-implementation-review ─── 実装レビュー
      ├── [episode] summary ─── 2/9 のまとめ
      └── [decision] ADR-001 ─── shell タイムアウトパターンの確定
                │
2/10  claude-safe 疑似オーケストレーション検証
      │
      └── [report] claude-safe-orchestration-verification
          │   実プロダクトのdeprecation修正で Cursor+Claude Code の協調を検証
          │   → ハング問題発見、スラッシュコマンドの知見
          │
2/14  Codex CLI 検証
      │
      ├── [plan] codex-cli-verification-prompt ─── 検証プロンプト（Step 1-4）
      │       │
      ├── [report] codex-cursor-integration-verification
      │       │   Step 1/4: 基本動作・AGENTS.md認識・セッション管理
      │       │
      └── [report] sentry-fix-codex-second-opinion
              │   Step 2/3: Sentry修正で Claude×Codex 並行比較
              │   → Codex が Claude の floor() 誤判定を検出
              │   → CLAUDE.md/AGENTS.md 生成パターンを確立
              │
2/15  3エージェント深掘り検証
      │
      ├── [plan/kickoff] deep-dive-verification-kickoff
      │       │   深度レベル L1-L5、ロール設計案B、facts.md テンプレート
      │       │
      ├── [report] deep-dive-error-reproduction
      │       │   L4到達。ロール分担で再現経路を自律特定
      │       │   Playwright MCP でステージング発火/非発火を確認
      │       │
      └── [episode] session-synthesis
                  セッション全体の統合記録。次スレッドへの引き継ぎ文書
```

## ドキュメント一覧

### plans/ — 計画・キックオフ

| ファイル | 一言 |
|---|---|
| [2026-02-09-verification-plan](plans/2026-02-09-verification-plan.md) | claude-safe タイムアウトの検証計画 |
| [2026-02-14-codex-cli-verification-prompt](plans/2026-02-14-codex-cli-verification-prompt.md) | Codex CLI の基本検証プロンプト（Step 1-4） |
| [2026-02-14-deep-dive-verification-kickoff](plans/2026-02-14-deep-dive-verification-kickoff.md) | 3エージェント深掘りのキックオフ。深度レベル・ロール設計・プロンプトテンプレート |

### episodes/ — 作業記録・レポート

| ファイル | 種別 | 一言 |
|---|---|---|
| [2026-02-09-timeout-design](episodes/2026-02-09-timeout-design.md) | episode | タイムアウト設計の議論（watchdog vs timeout コマンド） |
| [2026-02-09-timeout-implementation-review](episodes/2026-02-09-timeout-implementation-review.md) | episode | 実装のセカンドオピニオンレビュー |
| [2026-02-09-summary](episodes/2026-02-09-summary.md) | episode | 2/9 作業のまとめ |
| [2026-02-10-claude-safe-orchestration-verification](episodes/2026-02-10-claude-safe-orchestration-verification.md) | report | claude-safe 単体での疑似オーケストレーション検証 |
| [2026-02-14-codex-cursor-integration-verification](episodes/2026-02-14-codex-cursor-integration-verification.md) | report | Codex CLI × Cursor 連携の基本動作検証 |
| [2026-02-14-sentry-fix-codex-second-opinion](episodes/2026-02-14-sentry-fix-codex-second-opinion.md) | report | Sentry修正で Claude×Codex 並行セカンドオピニオン比較 |
| [2026-02-15-deep-dive-error-reproduction](episodes/2026-02-15-deep-dive-error-reproduction.md) | report | 3エージェント深掘り。L4到達、ステージング発火確認 |
| [2026-02-15-session-synthesis](episodes/2026-02-15-session-synthesis-codex-verification-to-autonomous-flow.md) | episode | セッション統合記録。スレッド引き継ぎ用 |

### decisions/ — 確定した判断

| ファイル | 一言 |
|---|---|
| [ADR-001-shell-timeout-pattern](decisions/ADR-001-shell-timeout-pattern.md) | watchdog パターンの採用（bash 3.2 互換） |

## 他プロジェクトの関連成果物

| ファイル | 配置先 | 内容 |
|---|---|---|
| [FACTS_TEMPLATE.md](../../agent-verification-flow/docs/templates/FACTS_TEMPLATE.md) | agent-verification-flow | facts.md 汎用テンプレート |
| [DESIGN_PRINCIPLES.md](../../agent-verification-flow/docs/DESIGN_PRINCIPLES.md) | agent-verification-flow | ロール設計パターン（案B）追記 |
| [peer-ai-review.md](../../cursor/command/verification/peer-ai-review.md) | cursor/command | ピアレビュー Cursor コマンド |
| [so-compare.sh](../../scripts/so-compare.sh) | scripts | Claude/Codex 並行比較スクリプト |

## 規約

| ファイル | 内容 |
|---|---|
| [DOCUMENT_CONVENTION.md](DOCUMENT_CONVENTION.md) | ドキュメント規約 v0（Frontmatter、命名、運用ルール） |
