---
id: "01KRXRDENZAE4X8FJ3E4B1WAD8"
title: "Phase 5 / 本実装移行の方向感 KickOff (現時点の方向感メモ、Phase 5 着手時に正式 confirmed 化)"
date: 2026-05-18
type: kickoff
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP の完了直後に Phase 5 方向感を捕捉するための前段 doc"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md"
    reason: "Step 4-5 Discussion Q9 で本 KickOff の作成方針が確定"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md"
    reason: "Step 4-5 KickOff DI-5 で本 KickOff の構造 (5 項目) が確定"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "Phase 4 最終 Step (Step 4-4) Episode (現状認識の素材)"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20"
    reason: "Path γ 候補: wezterm-ai-mode (PoC → プロジェクト昇格 Epic)"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "Path γ 候補: フック拡充エピック"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/37"
    reason: "Path γ 候補: Harness Engineering 基盤整備 Epic"
  - type: superseded_by
    ref: "https://github.com/stlwolf/ai-development-hub/issues/105"
    reason: "Phase 5 方針は Epic #105 (パイプライン駆動 + ECS target case) で再構成、本 KickOff は履歴アーカイブ"
  - type: superseded_by
    ref: "projects/orchestration-engine/docs/discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md"
    reason: "Phase 5 方針の正本 Discussion (本 KickOff の Path α'/β/γ 軸からの離脱を明示、target case 中心に転換)"
tags: [orchestration, post-phase-4, kickoff, direction-memo, draft, phase-5-prep, archived]
---

# Phase 5 / 本実装移行の方向感 KickOff (現時点の方向感メモ)

> **文書ステータス (2026-05-19 更新): 履歴アーカイブ**
>
> 本 KickOff (`status: draft`) は Phase 4 完了直後 (2026-05-18) のスナップショット。その後の議論 (2026-05-19) で方針が ECS target case 中心に再構成されたため、本 KickOff は **履歴アーカイブとして据え置き**、確定方針は以下を正本とする:
>
> - **Epic [#105](https://github.com/stlwolf/ai-development-hub/issues/105)**: 自前オーケストレーション Phase 5 — パイプライン駆動 + ECS target case
> - **Discussion** ([`2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md`](../discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md)): Phase 5 方針の正本 (status: draft、QDD 9 open questions あり)
>
> 本 KickOff の §6 (ゴール / 用途の具体化、想定ゴール候補 5 案) は新 Discussion §2 (根本的な方向転換) と §5 (Target case) で具体化された target case (= EC2 → ECS + IaC 化) に統合済み。Path α'/β/γ の 3 軸枠組みは新 Discussion §2.1 で「ツール完成度を軸にしていた」と明示的に離脱された。

> **本 KickOff のステータス**: `status: draft` — Phase 5 着手時に正式 `confirmed` 化する前提の **方向感スナップショット**。Phase 4 完了直後 (2026-05-18) の現時点認識を捕捉し、後の Phase 5 正式 KickOff 起草時の入力資料として再利用する。本 doc は Step 4-5 [PR #104](https://github.com/stlwolf/ai-development-hub/pull/104) で merge され、orchestration-engine の Phase 5 着手判断の起点として機能する。
>
> ※ 上記「文書ステータス (2026-05-19 更新)」のとおり、本 KickOff は履歴アーカイブとして据え置きとなりました。以降は新 Discussion + Epic #105 を参照してください。

## 1. 背景・現状認識 (Phase 4 完了時点の engine 到達点と限界)

### Phase 4 で組み上がった orchestration-engine の実用範囲

- **engine**: Bash + jq + WezTerm + wez CLI で構築、`bin/oe` がエントリポイント
- **1 サイクル E2E**: target (cursor-agent / composer-2) + reviewer (claude / sonnet-4-6) で 1 サイクル完走を実機実証 ([PR #97](https://github.com/stlwolf/ai-development-hub/pull/97))
- **検証ゲート v1**: Compliance Review only、`@@OE_VERIFY:(pass\|fail\|warn)` marker、pane-keyed verification map、circuit breaker
- **観測層**: audit JSONL (failure-taxonomy 拡張)、KVS state schema、ULID session id、structural assertions (`check_cycle_complete.sh` 4 + 2 点)
- **駆動層 doc**: Discussion (QDD) → KickOff (DI 確定) → Plan (Phase / Step) → Episode (経緯) → ADR (設計判断) のサイクルが Step 4-1〜4-5 で 5 回連続成立
- **テスト**: mock 306 assertions (8 suite)、実機 smoke 1 サイクル完走実証

### Phase 4 完了時点の限界 (派生 Issue / 改善候補)

- **派生 Issue 7 件 (open)**:
  - [#92](https://github.com/stlwolf/ai-development-hub/issues/92): KVS outputs[] 拡張 + 完了報告内容の充実
  - [#93](https://github.com/stlwolf/ai-development-hub/issues/93): reviewer 一時ファイル掃除 (前半は Phase 4 で対応済) + nonce marker (後半 = MVP 後拡張)
  - [#98](https://github.com/stlwolf/ai-development-hub/issues/98): target ペイン出力を file redirect 経路に統一 (現状 reviewer のみ)
  - [#99](https://github.com/stlwolf/ai-development-hub/issues/99): `bin/oe --task-file` の異常系 (空 / 不在 / 不正パス) の仕様明示
  - [#100](https://github.com/stlwolf/ai-development-hub/issues/100): `_oe_verify_scan_log_file` の単体テスト追加
  - [#101](https://github.com/stlwolf/ai-development-hub/issues/101): reviewer marker の false-positive 抑制 (markdown 引用との偶然一致)
  - [#102](https://github.com/stlwolf/ai-development-hub/issues/102): `_oe_strip_ansi` 共通関数化
- **未実装機能**: Plan Review (kickoff-to-plan 段階)、複数 reviewer 並走、検証ゲート v2 (per-pane 変更ファイル検出 / 完了報告充実)、Negative Knowledge 昇格、ダッシュボード / 可視化
- **運用上の課題**: 単一プロジェクト内 dogfood (= 自己改修) のみで実証、他プロジェクトでの利用実績なし、配布形態未定 (現状は repo 内 `projects/orchestration-engine/` ローカル実行)

## 2. Path 候補 (3 案) + 各主要 DI 候補

### Path α: MVP 継続改良 (現プロジェクト内で機能拡張)

**スコープ**: 既存 orchestration-engine を継続改良し、機能拡張・品質向上を進める。

**主要 DI 候補**:
- α-DI-1: 派生 Issue 7 件の優先度仕分け + 順次消化 (1〜2 件着手 → 残り backlog 化、もしくは全消化)
- α-DI-2: 検証ゲート v2 着手 ([#92](https://github.com/stlwolf/ai-development-hub/issues/92)): KVS outputs[] 拡張 + per-pane 変更ファイル検出 + 完了報告充実
- α-DI-3: Plan Review 追加 (現状は Compliance Review only、kickoff-to-plan 段階の品質チェック追加)
- α-DI-4: 複数 reviewer 並走 (現状単一 reviewer、多視点レビューの構造化)
- α-DI-5: Negative Knowledge 昇格 ([#62](https://github.com/stlwolf/ai-development-hub/issues/62) との連動): 失敗の構造化蓄積 + 次サイクル注入

**前提**: orchestration-engine の utility が今後も中核と判断 (本実装移行は当面しない)。

### Path β: 本実装移行 (production 用途化)

**スコープ**: MVP の機能足りに加え、production 用途として配布・運用形態を整える。

**主要 DI 候補**:
- β-DI-1: 配布形態の選択 (CLI package 化 / Docker / standalone binary / Homebrew tap など)
- β-DI-2: 他プロジェクトでの dogfood 着手 (本リポジトリ以外の repo に組み込み、運用実績を積む)
- β-DI-3: ドキュメント整備 (現状の `README.md` + `tests/e2e_real_agent/README.md` に加え、ユーザーガイド / quickstart / トラブルシュート / API リファレンス)
- β-DI-4: production 品質の補強 (派生 Issue 7 件のうち #99 / #100 / #101 / #102 は production では必須レベル)
- β-DI-5: バージョニング戦略 (semver 採用、breaking change のポリシー)

**前提**: orchestration-engine が他プロジェクトでも価値を発揮できると判断。

### Path γ: MVP を停止し別 Epic に注力

**スコープ**: orchestration-engine の機能拡張は派生 Issue 起票止まりとし、別 Epic で得られる利益を優先する。

**主要 DI 候補 (別 Epic 案)**:
- γ-DI-1: [#20 wezterm-ai-mode](https://github.com/stlwolf/ai-development-hub/issues/20) — PoC → プロジェクト昇格、wez CLI ツールキット拡充 (orchestration-engine が依存する CLI 自体の充実)
- γ-DI-2: [#24 フック拡充エピック](https://github.com/stlwolf/ai-development-hub/issues/24) — ルール → フック移行 + 新規フック追加 (canonical/hooks の体系化)
- γ-DI-3: [#37 Harness Engineering 基盤整備](https://github.com/stlwolf/ai-development-hub/issues/37) — 自設計のギャップ解消と体系化 (orchestration-engine の上位概念に該当)
- γ-DI-4: [#62 失敗の構造化蓄積](https://github.com/stlwolf/ai-development-hub/issues/62) — Negative Knowledge 昇格 (orchestration-engine と関連あり、独立 Epic としても進められる)

**前提**: orchestration-engine の utility は現状 MVP のままで十分、他領域への投資の方が利益が大きいと判断。

## 3. 各 Path の利益 / リスク / 必要工数の見積もり (user 確定、2026-05-18 時点)

> ⚠️ **本セクションは現時点の主観**。確定値ではなく、Phase 5 正式 KickOff 起草時に再評価する。Copilot レビュー反映で「pending 表」を削除し確定リストに一本化 (2026-05-18)。

- Path α 利益: 派生 Issue 消化で engine 自体が成熟、Phase 4 の dogfood サイクルを継続できる
- Path α リスク: MVP の延命のみで対外価値 (= 他プロジェクトでの利用) を生み出さない、内向きの作業に閉じる可能性。**ゴール未確定の状態では純粋なブラッシュアップは空振りに終わる懸念**
- Path α 工数: 派生 Issue 1 件あたり **~0.5〜2 日** (本質性で仕分けて優先順位高いものから)、7 件全消化なら **~1〜2 週 (週末 + α レベル)**
- Path β 利益: orchestration-engine の対外価値を顕在化、production 用途で得られるフィードバックがエンジン改良に還流
- Path β リスク: ゴール (= 真の用途) が見えていない現状で本実装移行は時期尚早、production 品質に到達するまでの工数が大きい、配布形態の選択判断が必要
- Path β 工数: production 品質補強 **~1 ヶ月**、配布形態 + ドキュメント追加で **~+1 ヶ月**、他プロジェクトでの dogfood 含めても **総計 1 ヶ月程度** (β に振り切らないため抑制可)
- Path γ 利益: 別 Epic で得られる利益を即座に取れる、orchestration-engine は派生 Issue で必要時のみ touch
- Path γ リスク: orchestration-engine の改良が停滞、Phase 4 で得た学びが冷凍される。**現時点では orchestration-engine をまだ深めたい意向のため γ は時期尚早**
- Path γ 工数: 別 Epic 1 件あたり **~1〜数ヶ月** (Epic ごとに異なる、本 KickOff 起草時点では選択肢外)

**主な制約 (Path に関わらず共通)**:
- **セッション / コスト**: claude / cursor の月次 usage 制限、so-compare のコストが頭打ち要因になり得る
- **時間軸全体感**: 3 ヶ月単位ではなく、実質的に **1 ヶ月以内 + 短期は 1 日単位** で進む想定 (Phase 4 dogfood の体感)

## 4. 現時点の傾き (user 確定、2026-05-18 時点)

> 確定ではなく、Phase 5 着手判断時に再評価する暫定意向のスナップショット。

### 大前提: ゴール / 用途が未確定

orchestration-engine の **真の用途・ゴールがまだ見えていない**。本実装移行先 (Path β) も別 Epic 注力 (Path γ) も、この前提が解消されないと判断材料が揃わない。**この未確定状態でブラッシュアップだけしても空振りに終わる** という認識 (項目 6 で論点として独立化)。

### user の暫定意向: **Path α 寄り + β 視点 (= 「実運用を見越した MVP 拡張」)**

- **Path α (MVP 継続改良) を基本路線とする** — orchestration-engine をまだ深めたい意向
- ただし純粋な α (内向き改良) ではなく、**β 視点 (実運用を見越した観点)** を加味して MVP 機能を拡張する方向
- 形式としては **「Phase 5」として継続するか、新規 MVP 拡張 (= 別 MVP 段階) として位置づけるか** は検討余地あり
- **Path γ (別 Epic 注力) は時期尚早** — 現時点では選択肢外

### 傾きの主な要因

- **Phase 4 dogfood の体感**: 駆動層 doc サイクル (Discussion → KickOff → Plan → Episode → ADR) で 5 Step 連続完走、engine 自体の utility はある程度実証された
- **派生 Issue 7 件の重要度認識**: 「本質的に MVP の課題か / それ以外か」で仕分け、本質的なものから着手する方針 (項目 6 §2 で詳述)。本質でないものへの投資は控えめに
- **別 Epic (#20 / #24 / #37 / #62) の優先度認識**: 現状は orchestration-engine を引き続き深める優先度の方が高い、別 Epic は Phase 5 着手判断時に再評価
- **利用可能なリソース**: セッション / コストが頭打ち要因、3 ヶ月単位の長期スパンは想定しない

## 5. 判断時期 / 判断のトリガー + 次アクション

### 判断のトリガー (どれかが成立したら Phase 5 着手判断を起動)

- **トリガー A (派生 Issue 着手の動機)**: 派生 Issue 7 件のうち 1 件以上を「自分で着手したい」と感じる事象が発生 (例: #98 が他プロジェクト dogfood で blocker になる、#101 が実運用で偽陽性を出す)
- **トリガー B (別 Epic の動機)**: 別 Epic (#20 / #24 / #37 / #62) の作業要因が顕在化 (例: wezterm-ai-mode の PoC を完成させたい、Negative Knowledge 昇格を始めたい)
- **トリガー C (時間経過)**: 本 KickOff 起草から **N 週間後** (具体は user 主観項目) に強制レビュー、その時点での意向で Path を選択
- **トリガー D (外部要因)**: 他プロジェクトで orchestration-engine の使用検討が始まる / production 用途の要望が発生

### 次アクション (Phase 5 着手判断時にやること)

1. **Phase 5 Discussion 起草**: 本 KickOff (draft) を入力資料として、Path α / β / γ の最終選択を QDD で確定
2. **Phase 5 KickOff 確定**: 本ファイルを `status: confirmed` に変更、選んだ Path の DI を確定形に書き換え
3. **Phase 5 Plan 起草**: 確定 DI を Phase / Step に展開
4. **派生 Issue 7 件の優先度仕分け** (Path α 採用時): backlog ordering を確定
5. **別 Epic 着手** (Path γ 採用時): 該当 Epic の Discussion / KickOff / Plan に移行

### 判断時期 (user 確定、2026-05-18 時点)

- **短期 (1 日以内)**: 派生 Issue 1 件着手で本質性を試す or **ゴール / 用途定義の Discussion 起草** (項目 6)
- **中期 (1 週間以内)**: Path α' (MVP 拡張) のスコープ決定 + 派生 Issue の本質性仕分け
- **長期 (1 ヶ月以内)**: orchestration-engine の真のゴール確定 (= 何のためにあるか、どこで使うか、Phase 5 にするか新規 MVP 拡張にするか)

**注記**: 3 ヶ月単位の長期スパンは想定しない。Phase 4 dogfood の体感で「1 ヶ月単位、短期は 1 日単位」で進むのが現実的。**セッション / コストが頭打ち要因**になる可能性のみが時間軸を伸ばす要因。

## 6. 次の最重要論点: ゴール / 用途の具体化 (user 確定、2026-05-18 時点)

> 項目 4 の「大前提」を独立論点として明示。Phase 5 着手 (Path α' / Phase 5 / 新規 MVP 拡張 のいずれを採るにせよ) の前に解決すべき最重要事項。

### 1. ゴール未確定の現状認識

- orchestration-engine の Phase 4 MVP は **「dogfood で実装し、自身を改修する 1 サイクル」を実機実証** できた段階。次に何のために engine を進化させるかが定まっていない
- **想定し得るゴール候補** (現時点で未選択):
  - (a) 本リポジトリ内の継続的な自己改修ループ (= 現状の延長、内向き)
  - (b) 他プロジェクトでの利用 (= 外向き、Path β に近い)
  - (c) Harness Engineering 体系化への寄与 (= #37 と関連)
  - (d) Negative Knowledge 蓄積基盤 (= #62 と関連)
  - (e) その他 (未明確化)

### 2. 派生 Issue の本質性仕分けポリシー

派生 Issue 7 件 (#92 / #93 / #98〜#102) は「ゴール未確定」と直交した品質改善が多い。優先順位の付け方:

- **本質的課題** (= MVP の中核仕様 / 安全性に関わる): 優先着手
- **本質的でない課題** (= 内向きブラッシュアップ、対外価値に直結しない): 後回し or 不着手
- 「本質的かどうか」の判断は、項目 6 §1 のゴール候補が定まらない現状では完全に決まらない。**現状ボトルネックになっているもの** から仕分け開始

**現時点の暫定仕分け候補** (Phase 5 Discussion で再確定する想定):
- 本質寄り: #92 (KVS outputs[] 拡張、検証ゲート v2)、#101 (false-positive marker 抑制、実運用で発生し得る)
- 中間: #98 (target file redirect 統一、長文化対応)、#99 (--task-file 異常系仕様化)
- 後回し寄り: #100 (scan_log_file 単体テスト、E2E で間接検証済み)、#102 (_oe_strip_ansi 共通化、保守性のみ)、#93 後半 (nonce marker、MVP 後)

### 3. ゴール定義に向けた次アクション

- **Phase 5 着手前**に **「orchestration-engine の真のゴール / 用途」を絞り込む Discussion** を起草することを推奨
- そのインプット候補: Phase 4 で得た学び (Episode 5 件 + ADR 5 件)、現状の自己改修サイクルでの体感、他プロジェクトでの想定利用パターン、Harness Engineering / Negative Knowledge との関連
- Discussion の出力 = Path α' を「Phase 5」として継続するか「新規 MVP 拡張」として独立 Epic 化するかの判断材料

### 4. ゴール未確定のまま着手しないものリスト (本 KickOff 起草時点の合意)

- 派生 Issue のうち「本質的でない」と判断したもの (内向きブラッシュアップ)
- Path β (本実装移行) の本格着手 (配布形態の選択、production 品質補強の専門投資)
- Path γ (別 Epic 注力) の着手 (#20 / #24 / #37 / #62 のいずれも本 KickOff 起草時点では時期尚早)

## 関連

- 本 KickOff の作成方針: Step 4-5 Discussion Q9 + KickOff DI-5
- Phase 4 完了報告: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md) §11 (Step 4-5 PR で追加)
- Phase 4 経緯: [`docs/episodes/`](../episodes/) 配下の Step 4-1〜4-5 Episode
- Phase 4 ADR: [`docs/decisions/`](../decisions/) 配下の 5 件
- 派生 Issue: #92 / #93 / #98 / #99 / #100 / #101 / #102
- 別 Epic 候補: #20 / #24 / #37 / #62
