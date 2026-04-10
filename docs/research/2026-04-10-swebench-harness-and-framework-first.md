---
title: "SWE-bench ハーネス実証 + 枠組みファースト: 2記事のクロス分析"
date: 2026-04-10
status: research-complete
tags: [harness-engineering, swe-bench, framework-first, phase-workflow, orchestra, mutual-testing]
sources:
  - https://blog.fltech.dev/entry/2026/04/07/swebench
  - https://caddi.tech/start-harness-engineering-with-framework
related_docs:
  - docs/research/harness-engineering/current-state-assessment.md
  - projects/orchestration-research/synthesis/harness-engineering-mapping.md
  - docs/draft/orchestration-control-loop-challenges.md
related_issues: [19, 24, 37, 49]
---

# SWE-bench ハーネス実証 + 枠組みファースト: 2記事のクロス分析

2026年4月の2記事から、ハーネスエンジニアリングの **定量的実証**（富士通）と **導入戦略**（CADDi）の知見を抽出し、自設計との接続点を整理する。

## 1. 記事の本質

### 記事A: 富士通 — ハーネス設計だけで SLM SOTA

> [ハーネスエンジニアリングのすすめ: 27BモデルでSWE-bench VerifiedのSLM SOTAを達成](https://blog.fltech.dev/entry/2026/04/07/swebench)

`Qwen3.5-27B` を追加学習なしで使い、TTS@8 で 74.8%（229B未満 SOTA）。モデル規模ではなくハーネス設計が性能を決めることの定量証明。

設計パターン8つ:

| # | パターン | 本質 |
|---|---------|------|
| 1 | フェーズ分割 + ワークフロー分割 + 明示遷移 | タスクの二段階構造化（マクロ責務 × ミクロ手順）。`WORKFLOW: Wn` の自己申告 + 実行系の事後検証 |
| 2 | ファイルシステム共有領域 (`/_share/`) | 会話履歴の外に状態を永続化。読み取り専用固定、回収対象許可リストで契約を制御 |
| 3 | ハンドオーバー = コンテキスト圧縮 | tokenizer-aware の予算管理 + `turn_handover_threshold`（32〜192ターン）で圧縮タイミングを制御 |
| 4 | Orchestra (conductor + tool-specialist) | 1ターン内での「探索」と「コマンド整形」の分離。同一モデルの温度差（0.6 vs 0.0）で実現 |
| 5 | 特化ツール (line_trace / caller_trace / coedit_localize / line_edit) | 汎用 grep/pytest より精密な調査・編集ツール |
| 6 | フェーズベースのスキル挿入 | `if phase in skill.phases and tools ⊆ agent.tools` — 必要なスキルだけをプロンプトに注入 |
| 7 | エージェント間相互テスト | 各 run のテスト資産を他 run のパッチに相互適用して比較証拠に。LLM judge より安定 |
| 8 | 運用安定化 (シャーディング + 再試行) | 部分失敗の局所再実行 |

### 記事B: CADDi — 枠組みから始めよう

> [ハーネスエンジニアリングは枠組みから始めよう](https://caddi.tech/start-harness-engineering-with-framework)

知見3つ:

| # | パターン | 本質 |
|---|---------|------|
| 1 | Framework-first | 内容より構造を先に作る。スカスカでも「ここに追加すればいい」が大事 |
| 2 | `/update-coding-rule` スキル | 実装中の不満やPRレビューコメントから即座にルール化。**人間が明示的に起動**する設計 |
| 3 | Rules index パターン | `.claude/rules/` はインデックス（軽量）、本体は別ファイル。conditional rules のトークン節約 |

## 2. クロス分析: 2記事の交差点

2記事は対象が異なる（ベンチマーク vs チーム開発）が、共通する構造がある。

### 「枠組みが更新を促す」

- 富士通: フェーズ定義とワークフロー定義という**枠組み**があるから、特化ツールやスキルを各フェーズに配置できる。枠組みなしに 8 パターンを個別に投入しても噛み合わない
- CADDi: ルールファイルの**枠組み**（ディレクトリ構造 + インデックス）があるから、日常開発の中でルールが育つ。枠組みなしにルール内容を充実させようとしても心理的ハードルが高い
- **共通**: 構成要素の品質より、構成要素を配置する構造の存在が先行する

### 「機械的検証 > プロンプト指示」

- 富士通: `required_assets` の存在検査 + 検証コマンドの終了コード → フェーズ遷移の条件。エージェントの自己申告だけでは通さない
- CADDi: ルール（プロンプト）だけでは遵守率に限界がある前提で、スキルやフックに責務を移す
- **共通**: `harness-engineering-mapping.md` の「ルールで祈る → フックで強制する」と同じ収束方向

### 「コンテキスト節約の設計」

- 富士通: フェーズベースのスキル挿入で今不要なスキルを除外 + ハンドオーバーで会話履歴を圧縮
- CADDi: Rules index パターンで conditional rules のトークン量を最小化
- **共通**: 「知識を増やすほどattentionが散る」問題への構造的対処

## 3. 自設計への接続

`current-state-assessment.md` の §3〜§4, §7 に反映済み。ここでは補足的な接続点を記録する。

### Issue #19（オーケストレーション MVP）への入力

富士通のフェーズ × ワークフロー二段制御は #19 の step 4-1（エンベロープ + ディスパッチャ）に直接的な参照実装を提供する:

- **エンベロープ**: `/_share/*.md` のフェーズメモ + `Kanban.md` + `handover_*.md` が、#19 のコンテキスト・エンベロープの具体例
- **ディスパッチャ**: フェーズ遷移の `on_complete` / `on_giveup` + `required_assets` 検査が、#19 の検証ゲート v1 の具体例
- **状態管理**: JSON ファイルベースの状態管理（#19 step 4-2）に対し、富士通はファイルシステム上の共有資産 + 回収許可リストで実現

### Issue #49（テスト戦略コンポーネント）への入力

富士通のエージェント間相互テストは、テスト資産を「比較証拠」として活用するパターン:

- 各 run が `FAIL_TO_PASS` / `PASS_TO_PASS` テストを自前で生成
- 他 run のパッチにそれらを相互適用し、`weighted pass-rate` で選抜
- LLM judge より安定し、採用理由が監査可能
- #49 の「テスト戦略の宣言」に、この「テスト資産の相互適用」を検討材料として追加できる

### Issue #24（フック拡充）への入力

富士通の `hard_gate_giveup_threshold=3` は、#24 H-7（pre-completion verification）の具体的なゲート実装パターン:

- N回連続で通過条件を満たさない → 強制 GIVEUP → 前段フェーズに戻す
- Cursor / Claude Code のフックでは stop / subagentStop イベントで類似の検出が可能

### canonical の「枠組みファースト」としての位置づけ

CADDi 記事は canonical の既存構造が「枠組みファースト」として機能していることの外部検証。ただし CADDi が Claude Code の `/command` で実現した「気づき → 即座にルール化」のフローは、Cursor 環境では `.cursor/commands/` またはフック（task-complete 時のナッジ）で構築する必要がある。

## 4. 既存記事群での位置づけ

| 記事 | カテゴリ | 追加価値 |
|------|---------|---------|
| 富士通 SWE-bench | category-1 相当（ベンチマーク実証 = 一次データ） | 既存19本にない「ハーネス設計の定量的効果」「フェーズ×ワークフロー二段制御」「エージェント間相互テスト」「Orchestra」 |
| CADDi 枠組み | category-3 相当（日本語実践記事） | 既存33本にない「導入ハードル低減」「ルール更新スキル」「枠組みファースト」の実践知 |

## 参照

- [`current-state-assessment.md`](harness-engineering/current-state-assessment.md) — ギャップ分析（本ノートの知見を §3〜§4, §7 に反映済み）
- [`harness-engineering-mapping.md`](../../../projects/orchestration-research/synthesis/harness-engineering-mapping.md) — ハーネス概念と自設計の対応表
- [`harness-engineering/README.md`](harness-engineering/README.md) — 記事インデックス（番号34・35として追加済み）
- [Issue #19](https://github.com/stlwolf/ai-development-hub/issues/19) — オーケストレーション MVP
- [Issue #37](https://github.com/stlwolf/ai-development-hub/issues/37) — Harness Engineering 基盤整備
- [Issue #49](https://github.com/stlwolf/ai-development-hub/issues/49) — テスト戦略コンポーネント
