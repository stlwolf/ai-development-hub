---
title: Harness Engineering 現状評価・ギャップ分析
date: 2026-04-01
status: living
last_reviewed: 2026-04-12
depends:
  - projects/orchestration-research/synthesis/harness-engineering-mapping.md
  - projects/orchestration-research/synthesis/architecture-sketch.md
refs:
  - https://blog.fltech.dev/entry/2026/04/07/swebench
  - https://caddi.tech/start-harness-engineering-with-framework
---

# Harness Engineering 現状評価・ギャップ分析

> Epic #10 の Tier 1・1.5 完了、リサーチ記事 category-1（7本）・category-2（12本）+ NLAH 論文 + 富士通 SWE-bench ハーネス実証 + CADDi 枠組みファースト記事の読了を踏まえた、自設計の現在地と次の一手の整理。

## 1. 評価の観点

19本の記事群 + NLAH 論文（arXiv:2603.25723）+ 富士通 SWE-bench 記事（Kozuchi mini-swe-agent, 2026-04）+ CADDi 枠組み記事（2026-04）から抽出されるハーネスの構成要素に対し、canonical 資産の充足度を3段階（充足 / 部分的 / 未着手）で評価する。

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
| **Contracts（NLAH）** | implementer-contract のステータス enum | 停止ルールが人間依存 | NLAH 論文, 富士通 SWE-bench（`WORKFLOW: COMPLETE/GIVEUP` + 実行系の事後検証 + `required_assets` 検査が機械的な停止ルール実装例） |
| **Failure Taxonomy（NLAH）** | BLOCKED + エスカレーション | 分類が粗い（3値） | NLAH 論文, 富士通 SWE-bench（`turn_handover_threshold` 32〜192ターン + `hard_gate_giveup_threshold=3` がリカバリパス付き閾値制御の実例） |
| **Initializer Agent** | #24 H-4（セッション初期化）が部分対応 | タスク固有コンテキスト自動選択は未定義 | Anthropic #4 |
| **Custom linter** | shellcheck 自動実行（#24 H-1）が1例 | 「エラーメッセージ = 修復プロンプト」の汎用パターン未整理 | OpenAI #1 |

## 4. 未着手の領域

| ハーネス構成要素 | 意味 | 既存 Issue | 典拠 |
|---|---|---|---|
| **Generator + Evaluator 自動ループ** | 評価 → 再生成の自動サイクル | [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 4-3 | Anthropic #3 |
| **Ralph Loop（制御ループ）** | 失敗 → 再投入 → エスカレーション | [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 全体 | arch-sketch §7 |
| **多周制御（ループ終了条件）** | 宣言的な終了条件定義 | [#36](https://github.com/stlwolf/ai-development-hub/issues/36)（CLOSED: 仕様整理完了、実装は #19 依存） | rigg review.yaml |
| **Pre-completion verification** | 完了宣言前の最終チェック | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-7 | implementation-principles |
| **監査ログ** | 全イベントの事後分析基盤 | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-8 | Observability 文献 |
| **Negative Knowledge ledger** | 失敗の構造化蓄積・自動注入 | **Issue なし** | Hashimoto #5, ideas/20260329 |
| **Knowledge freshness** | コンテキスト陳腐化検出 | **Issue なし** | Doc-gardening の前提 |
| **State Semantics（NLAH）** | スキル/コマンドの永続化宣言 | **Issue なし** | NLAH 論文, 富士通 SWE-bench（`/_share/` 共有領域の読み取り専用固定・回収対象許可リストが具体実装例） |
| **Time budgeting** | サブエージェントへの時間意識注入 | **Issue なし** | mapping #3, 富士通 SWE-bench（tokenizer-aware 予算管理 + `turn_handover_threshold` が具体実装例） |
| **Orchestra（1ターン内の役割分離）** | conductor（探索・判断）+ tool-specialist（コマンド整形）の分離 | **Issue なし** | 富士通 SWE-bench（同一モデルの温度差で探索と整形を分離。arena/SO の並列比較とは異なる軸） |

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
| ゲート健全性チェック | [#22](https://github.com/stlwolf/ai-development-hub/issues/22) CLOSED | exit code 分離（0/1/2）+ 部分成功検知 + タイムアウトリトライ 実装済み（`scripts/so-compare.sh`） |
| 多周制御 | [#36](https://github.com/stlwolf/ai-development-hub/issues/36) CLOSED | 終了条件・ループ不変条件の仕様文書化完了（`docs/specs/2026-04-06-discussion-multi-round-control-loop.md`）。実装は #19 依存 |

### 未カバー（Issue 化されていない）

| # | 施策 | 接続先 | 備考 |
|---|---|---|---|
| G1 | **Negative Knowledge ledger** | [#62](https://github.com/stlwolf/ai-development-hub/issues/62), #19 エンベロープ, ideas/20260329 Decision Ledger | 失敗蓄積 → 次サイクル注入 |
| G2 | **Knowledge freshness** | Doc-gardening パイプライン | 規模が小さいうちは手動で十分 |
| G3 | **State Semantics（NLAH）** | [#61](https://github.com/stlwolf/ai-development-hub/issues/61), #26 メタデータ基盤, frontmatter 拡張 | `outputs:` フィールド追加。#58 の3ツール比較でコンテキスト寿命差（Claude コンパクト後の再注入、Codex 32KiB 制限）が設計入力として整理済み |
| G4 | **Failure Taxonomy（NLAH）** | [#60](https://github.com/stlwolf/ai-development-hub/issues/60), implementer-contract 拡張 | リカバリパス付き失敗分類 |
| G5 | **Time budgeting** | implementer-contract 拡張 | `deadline:` フィールド追加 |
| G6 | **Initializer Agent 完全版** | #24 H-4 拡張 or #19 ディスパッチャ | CATALOG.md → 関連リソース自動選択。`question-driven-design` スキルは Plan 手前の質問整理であり自動選択とは別軸 |
| G7 | **Orchestra（1ターン内の役割分離）** | #19 ディスパッチャ or サブエージェント戦略拡張 | conductor + specialist の分離。arena/SO とは異なる軸 |

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

## 7. SWE-bench ハーネス実証と枠組みファーストの位置づけ

### 富士通 Kozuchi mini-swe-agent（2026-04）

> [ハーネスエンジニアリングのすすめ: 27BモデルでSWE-bench VerifiedのSLM SOTAを達成](https://blog.fltech.dev/entry/2026/04/07/swebench)

`Qwen3.5-27B` を追加学習なしで使い、TTS@8 で 74.8%（229B未満 SOTA）を達成。モデル規模ではなくハーネス設計が性能を決めることを定量的に実証。

canonical との関係:

- **フェーズ × ワークフロー二段制御**: 8フェーズ（ISSUE_REPRODUCT → FINAL_REPORT）+ 各フェーズ内 W0..Wn の明示遷移。`#19` のディスパッチャ設計に具体的な参照実装を提供
- **ファイルシステム共有領域** (`/_share/`): 会話履歴の外に状態を永続化し、フェーズ間で引き継ぎ。NLAH の State Semantics の具体実装に相当
- **フェーズベースのスキル挿入**: `if phase in skill.phases and tools ⊆ agent.tools` で必要なスキルだけをプロンプトに注入。Cursor の conditional rules（`.mdc` の `paths:`）と同型の設計
- **エージェント間相互テスト**: 各 run が生成したテスト資産を他 run のパッチに相互適用して比較証拠に。`#49`（テスト戦略コンポーネント）への入力となる手法
- **事後検証 + required_assets**: 成果物の存在 + 検証コマンドの終了コードでフェーズ遷移を機械的に制御。`#24` H-7（pre-completion verification）の具体ゲート実装例

### CADDi「枠組みから始めよう」（2026-04）

> [ハーネスエンジニアリングは枠組みから始めよう](https://caddi.tech/start-harness-engineering-with-framework)

ハーネス整備の心理的ハードルを下げるアプローチ: 内容より構造（空の枠組み）を先に作り、日常開発の中で育てる。

canonical との関係:

- **枠組みファースト = canonical の既存構造**: `canonical/` の `rules/` `skills/` `agents/` `commands/` `hooks/` というディレクトリ構造自体が「ここに追加すればいい」という枠組みとして機能している。CADDi 記事はこの方針の外部検証事例
- **更新しやすさ > 完成度**: ルールやスキルの初期品質より「誰でも更新できる状態」が重要というメタ原則。Issue #37 の「Issue化は必要性に応じて段階的に」方針と一致
- **`/update-coding-rule` スキル**: Claude Code のスラッシュコマンドで実装中の気づきを即座にルール化。人間が明示的に起動する設計でスキルロード信頼性の問題を回避。Cursor では `.cursor/commands/` やフック（task-complete 時のナッジ）で類似体験を構築可能

## 8. 全体評価サマリ

**現状の強み**: 記事群で語られるハーネス構成要素の約 6 割を canonical 資産としてカバー済み。特に認知協調（arena/SO/peer-review）は業界記事に登場しない独自の強み。canonical のディレクトリ構造自体が CADDi の言う「枠組みファースト」として機能しており、増分改善の土台がある。

**最大のギャップ**: **制御ループの不在**。検証は存在するが自動ループしない。[#19](https://github.com/stlwolf/ai-development-hub/issues/19)（オーケストレーション MVP）が直接的な解。富士通のフェーズ × ワークフロー二段制御 + ファイルシステム共有領域は #19 の設計に参照実装を提供する。

**NLAH からの新規ギャップ**: State Semantics と Failure Taxonomy。前者は #26（メタデータ基盤）、後者は implementer-contract 拡張で対応可能。富士通の `/_share/` 設計と閾値制御が両者の具体実装例として参照可能になった。

**新規ギャップ**: Orchestra（1ターン内の役割分離）。conductor + tool-specialist の温度差分離パターンは既存の並列モデル比較（arena/SO）とは異なる軸であり、G7 として追跡。

## 9. 2026-04-12 再評価

### 前回評価（2026-04-10）からの変化

**Issue 完了**:

- [#22](https://github.com/stlwolf/ai-development-hub/issues/22) CLOSED（2026-04-06）: `so-compare.sh` に exit code 分離（0/1/2）・部分成功検知・タイムアウトリトライを実装
- [#36](https://github.com/stlwolf/ai-development-hub/issues/36) CLOSED（2026-04-06）: 多周制御の終了条件・ループ不変条件を仕様文書化（`docs/specs/2026-04-06-discussion-multi-round-control-loop.md`）。実装は #19 依存
- [#58](https://github.com/stlwolf/ai-development-hub/issues/58) CLOSED（2026-04-11）: Cursor / Claude Code / Codex の3ツール比較調査完了（`docs/research/2026-04-12-cross-agent-rules-skills-config-survey.md`）。canonical 展開時のツール間差異（コンテキスト寿命・スキルロード・トークン制限）が整理された

**canonical 資産の増分**（#37 起票後）:

- スキル追加: `spec-card`、`worktrunk-worktrees`、`branch-finish`、`question-driven-design`
- ルール追加: `careful-operations-rule`、`workflow-awareness-rule`
- フック追加: `commit-gate`（Claude Code TaskCompleted 時の advisory 通知）
- コマンド追加: `research-intake`

### G1-G7 ギャップの現状

全ギャップが引き続き Issue 未作成。ただし以下の文脈変化あり:

- **G3（State Semantics）**: #58 の3ツール比較で、ツール間のコンテキスト寿命差（Claude のコンパクト後の再注入挙動、Codex の 32KiB 制限等）が明確化。frontmatter `outputs:` の設計時に考慮すべき制約が具体化された
- **G6（Initializer Agent）**: `question-driven-design` スキルが追加されたが、これは Plan mode 手前の質問フェーズであり、CATALOG からの自動コンテキスト選択（G6 の本質）とは別軸

### 評価更新

§2 充足領域は canonical 資産の増分（4スキル・2ルール・1フック・1コマンド）により強化されているが、カテゴリ移動が必要なレベルの変化ではない。§3 部分的領域・§4 未着手領域の構造は前回評価から変化なし。

最大のギャップ（制御ループの不在）は依然として [#19](https://github.com/stlwolf/ai-development-hub/issues/19) に依存。#22/#36 の完了により、制御ループの「入力層」（exit code 契約・終了条件仕様）は整備されたが、ループ本体は未着手。

#38 Phase 0（#58）の成果はハーネス評価の G3 に直接的な設計入力を提供する。#38 Phase 1（Core Canonical 診断）が進めば、canonical の品質向上を通じてハーネス全体の基盤が強化される。

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
- [Epic #38](https://github.com/stlwolf/ai-development-hub/issues/38) — canonical cross-agent optimization
- [#58](https://github.com/stlwolf/ai-development-hub/issues/58) — 3ツール比較調査（`docs/research/2026-04-12-cross-agent-rules-skills-config-survey.md`）
- [NLAH 論文](https://arxiv.org/abs/2603.25723) — Natural-Language Agent Harnesses
- [富士通 SWE-bench](https://blog.fltech.dev/entry/2026/04/07/swebench) — 27Bモデルでハーネス設計のみで SWE-bench Verified 74.8%（2026-04）
- [CADDi 枠組みから始めよう](https://caddi.tech/start-harness-engineering-with-framework) — 枠組みファーストによるハーネス整備ハードル低減（2026-04）
