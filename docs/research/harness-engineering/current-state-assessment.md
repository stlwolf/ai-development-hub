---
title: Harness Engineering 現状評価・ギャップ分析
date: 2026-04-01
status: snapshot
depends:
  - projects/orchestration-research/synthesis/harness-engineering-mapping.md
  - projects/orchestration-research/synthesis/architecture-sketch.md
---

# Harness Engineering 現状評価・ギャップ分析

> Epic #10 の Tier 1・1.5 完了、リサーチ記事 category-1（7本）・category-2（12本）+ NLAH 論文の読了を踏まえた、自設計の現在地と次の一手の整理。

## 1. 評価の観点

19本の記事群 + NLAH 論文（arXiv:2603.25723）から抽出されるハーネスの構成要素に対し、canonical 資産の充足度を3段階（充足 / 部分的 / 未着手）で評価する。

詳細な概念マッピングは [`harness-engineering-mapping.md`](../../projects/orchestration-research/synthesis/harness-engineering-mapping.md) を参照。

## 2. 充足している領域

| ハーネス構成要素 | 対応資産 | 典拠 |
|---|---|---|
| **AGENTS.md = 目次** | CLAUDE.md ~100行 + canonical/ 分離 | OpenAI #1, HumanLayer #10 |
| **Progressive Disclosure** | canonical/ 階層（rules → skills → commands） | Anthropic #4, Charlie Guo #6 |
| **Self-verification loop** | adversarial-review + so-compare + peer-ai-review | Anthropic #3, LangChain #7 |
| **サブエージェント契約** | implementer-contract（ステータス enum, self-review） | OpenAI #1（Epic #10 A-5） |
| **機械的ガードレール** | hooks/（block-destructive, block-force-push） | OpenAI #1, Hashimoto #5（Epic #10 H-0） |
| **コードレビュー = 修復プロンプト** | pr-review-checklist（各項目に修正指針） | OpenAI #1（Epic #10 A-1） |
| **Build to Delete** | 薄いシェル方針 + canonical sync | Bouchard #2, Charlie Guo #6 |
| **認知協調** | arena-compare（発散）+ so-compare/peer-ai-review（収束） | OSS にない独自レイヤー |
| **Roles（NLAH）** | agents/（oss-researcher, vendor-inspector 等） | NLAH 論文 |
| **Stage Structure（NLAH）** | commands/（issue-debug, peer-ai-review 等の手順） | NLAH 論文 |
| **Adapters & Scripts（NLAH）** | hooks/scripts/、so-compare.sh 等 | NLAH 論文 |

## 3. 部分的にカバーされている領域

| ハーネス構成要素 | 現状 | ギャップ | 典拠 |
|---|---|---|---|
| **Loop detection** | #24 H-5 として計画済み | フック未実装 | Hashimoto #5, LangChain #7 |
| **検証ゲートの実行証跡** | #24 H-6 として計画済み | 人間の目視依存 | arch-sketch §8 |
| **Contracts（NLAH）** | implementer-contract のステータス enum | 停止ルールが人間依存 | NLAH 論文 |
| **Failure Taxonomy（NLAH）** | BLOCKED + エスカレーション | 分類が粗い（3値） | NLAH 論文 |
| **Initializer Agent** | #24 H-4（セッション初期化）が部分対応 | タスク固有コンテキスト自動選択は未定義 | Anthropic #4 |
| **Custom linter** | shellcheck 自動実行（#24 H-1）が1例 | 「エラーメッセージ = 修復プロンプト」の汎用パターン未整理 | OpenAI #1 |

## 4. 未着手の領域

| ハーネス構成要素 | 意味 | 既存 Issue | 典拠 |
|---|---|---|---|
| **Generator + Evaluator 自動ループ** | 評価 → 再生成の自動サイクル | [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 4-3 | Anthropic #3 |
| **Ralph Loop（制御ループ）** | 失敗 → 再投入 → エスカレーション | [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 全体 | arch-sketch §7 |
| **多周制御（ループ終了条件）** | 宣言的な終了条件定義 | [#36](https://github.com/stlwolf/ai-development-hub/issues/36) | rigg review.yaml |
| **Pre-completion verification** | 完了宣言前の最終チェック | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-7 | implementation-principles |
| **監査ログ** | 全イベントの事後分析基盤 | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-8 | Observability 文献 |
| **Negative Knowledge ledger** | 失敗の構造化蓄積・自動注入 | **Issue なし** | Hashimoto #5, ideas/20260329 |
| **Knowledge freshness** | コンテキスト陳腐化検出 | **Issue なし** | Doc-gardening の前提 |
| **State Semantics（NLAH）** | スキル/コマンドの永続化宣言 | **Issue なし** | NLAH 論文 |
| **Time budgeting** | サブエージェントへの時間意識注入 | **Issue なし** | mapping #3 |

## 5. Issue カバレッジマップ

前回評価で挙げた未着手/不足分が既存 Issue でどこまでカバーされているかの一覧。

### カバー済み（Issue 内に計画あり）

| 施策 | Issue | カバー内容 |
|---|---|---|
| Pre-completion verification | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-7 | `stop` フックで機械化 |
| Loop detection | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-5 | `postToolUseFailure` + `stop` で検出 |
| 検証ゲート実行証跡 | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-6 | `stop`/`subagentStop` で検証 |
| 監査ログ | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-8 | 全イベント記録 |
| Generator + Evaluator ループ | [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 4-3 | 検証ゲート v1 |
| Ralph Loop | [#19](https://github.com/stlwolf/ai-development-hub/issues/19) | MVP 全体構成 |
| ゲート健全性チェック | [#22](https://github.com/stlwolf/ai-development-hub/issues/22) | exit code 分離 + 部分成功検知 |
| 多周制御 | [#36](https://github.com/stlwolf/ai-development-hub/issues/36) | ループ終了条件の仕様整理 |

### 未カバー（Issue 化されていない）

| # | 施策 | 接続先 | 備考 |
|---|---|---|---|
| G1 | **Negative Knowledge ledger** | #19 エンベロープ, ideas/20260329 Decision Ledger | 失敗蓄積 → 次サイクル注入 |
| G2 | **Knowledge freshness** | Doc-gardening パイプライン | 規模が小さいうちは手動で十分 |
| G3 | **State Semantics（NLAH）** | #26 メタデータ基盤, frontmatter 拡張 | `outputs:` フィールド追加 |
| G4 | **Failure Taxonomy（NLAH）** | implementer-contract 拡張 | リカバリパス付き失敗分類 |
| G5 | **Time budgeting** | implementer-contract 拡張 | `deadline:` フィールド追加 |
| G6 | **Initializer Agent 完全版** | #24 H-4 拡張 or #19 ディスパッチャ | CATALOG.md → 関連リソース自動選択 |

## 6. NLAH 論文の位置づけ

> 清華大学・ハルビン工業大学 (arXiv:2603.25723, 2026-03)
> [Zenn 解説記事](https://zenn.dev/knowledgesense/articles/22eac0ba8cada3) / [arXiv 論文](https://arxiv.org/abs/2603.25723)

### 核心

ハーネスの制御ロジックをコードではなく**自然言語の統一フォーマット**で記述する。コードベースのハーネスを NLAH に移行しただけで OSWorld 30.4 → 47.2（+16.8pt）。

### canonical との関係

canonical の「Markdown ドキュメント駆動」アプローチは NLAH と方向性が一致する。ただし NLAH が明示的に定義する 6 要素のうち **State Semantics**（永続化宣言）と **Failure Taxonomy**（失敗分類）が canonical に不在。

詳細マッピングは [`harness-engineering-mapping.md` §NLAH](../../projects/orchestration-research/synthesis/harness-engineering-mapping.md) を参照。

### オーケストレーションツールへの示唆

- **エンベロープに `negative_knowledge` フィールド**: 前回の失敗事例を次サイクルに渡す（Hashimoto #5「ミスしたら環境改善」のオーケストレーション層実装）
- **ディスパッチャに Initializer ステップ**: CATALOG.md → 関連 skills/rules の自動選択（Anthropic #4 の簡易版）
- **検証ゲートが最重要構成要素**: 「出力の品質を決めるのはモデルではなくハーネス」（LangChain #7: ハーネス改善だけで Top 30 → Top 5）

## 7. 全体評価サマリ

**現状の強み**: 記事群で語られるハーネス構成要素の約 6 割を canonical 資産としてカバー済み。特に認知協調（arena/SO/peer-review）は業界記事に登場しない独自の強み。

**最大のギャップ**: **制御ループの不在**。検証は存在するが自動ループしない。[#19](https://github.com/stlwolf/ai-development-hub/issues/19)（オーケストレーション MVP）が直接的な解。

**NLAH からの新規ギャップ**: State Semantics と Failure Taxonomy。前者は #26（メタデータ基盤）、後者は implementer-contract 拡張で対応可能。

## 参照

- [`harness-engineering-mapping.md`](../../projects/orchestration-research/synthesis/harness-engineering-mapping.md) — ハーネス概念と自設計の対応表（本文書の基盤）
- [`architecture-sketch.md`](../../projects/orchestration-research/synthesis/architecture-sketch.md) — オーケストレーションツール全体設計
- [`docs/research/harness-engineering/README.md`](./README.md) — 全33本の記事インデックス
- [`docs/draft/orchestration-control-loop-challenges.md`](../../../docs/draft/orchestration-control-loop-challenges.md) — 制御ループ課題
- [Epic #10](https://github.com/stlwolf/ai-development-hub/issues/10) — OSS パターン取り込み
- [#19](https://github.com/stlwolf/ai-development-hub/issues/19) — オーケストレーションツール MVP
- [#24](https://github.com/stlwolf/ai-development-hub/issues/24) — フック拡充エピック
- [#22](https://github.com/stlwolf/ai-development-hub/issues/22) / [#35](https://github.com/stlwolf/ai-development-hub/issues/35) / [#36](https://github.com/stlwolf/ai-development-hub/issues/36) — so-compare 改善系
- [Epic #37](https://github.com/stlwolf/ai-development-hub/issues/37) — Harness Engineering 基盤整備（本文書のギャップ追跡先）
- [NLAH 論文](https://arxiv.org/abs/2603.25723) — Natural-Language Agent Harnesses
