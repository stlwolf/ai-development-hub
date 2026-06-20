---
id: "01KVJ5ZJ04Q4D7HSADFQ2SNBHR"
title: "oe-refute / oe-review の VERDICT 抽出/集約を共有 lib 化（#196・実装SO=oe-review 初の実運用）"
date: 2026-06-20
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/196"
    reason: "本サイクルの Issue（共有 lib 化・純リファクタ）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/194"
    reason: "oe-review 追加時に重複させた経緯（oe-refute 非変更ガード）"
  - type: prior_work
    ref: "https://github.com/stlwolf/ai-development-hub/pull/195"
    reason: "oe-review が oe-refute の VERDICT ロジックを thin 複製した PR"
tags: [orchestration, oe-refute, oe-review, refactor, so-verdict, lib, episode]
---

# oe-refute / oe-review の VERDICT 抽出/集約を共有 lib 化（#196）

> PR #195（#194）で oe-review が oe-refute の VERDICT 抽出/集約/dissent/exit code を thin に複製（#194 の「oe-refute 非変更」ガードのため）。重複＝drift risk（#184 の VERDICT 部分一致 fix のような修正が2箇所必要・片方取りこぼし）。本サイクルは共有 lib `lib/so-verdict.sh` 化で解消する**純リファクタ（両 verb 挙動不変・回帰ゼロ）**。**実装SO に新 verb `oe-review` を自分の diff へ適用する初の実運用ケース**でもある。

## Context / なぜ

- 重複実体は4つ: extract_verdict/extract_reason（#184 Fix 1 の token 切り出し含む）/ per-lane 集約ループ（並行配列＋count）/ conservative 集約 / dissent JSON 組立。
- 観測した verb 差（保持必須）: conservative 集約の **REASON 文言のみ** が verb で異なる（refuted 句・survived 句）。error 句・verdict 判定・exit code・dissent 構造・抽出は完全同一。

## 設計（DJ-1）と設計SO のスキップ判断

確定前証跡を `tmp/dj-1-so-verdict-lib.md` に外部化（predecision-exploration 手順4・確定前 artifact）。

- 採用 = **案A: global-return lib**（関数が文書化グローバル `SO_VERDICT_*` を populate）。根拠 = `lib/envelope.sh` が既に global-return（「戻り値: OE_ENVELOPE_PATH に設定」）を採用済の既存パターン（behavioral-rule §6）。bash 3.2 で関数から配列を返す現実解（nameref 禁止）。
- 棄却 = 案B stdout-serialization（dissent 二重エンコード・既存慣習逸脱）/ 案C leaf 関数のみ抽出（issue 受け入れ条件「集約が単一 lib に一元化」を満たさず過少デリバリ）。
- REASON 差は **phrase 引数** で受け、文言を完全一致で保持。
- **設計SO（別途 oe-refute）はスキップ（記録された skip・黙った skip ではない）**: 制約された純リファクタの責務分界で incumbent パターンが強く後戻りコスト低い。かつ下流の**必須 実装SO（oe-review）が lib 分解のコード品質・到達可能性・bash 堅牢性を敵対的にレビューする**＝この判断への敵対的チェックを兼ねる。predecision-exploration「いつ使わないか（低リスク・過剰適用回避）」に該当。

## 実装と検証

- 新規 `lib/so-verdict.sh`（source 専用・`# shellcheck disable=SC2034` は envelope.sh と同じ global-return 規約）に6関数を切り出し:
  `so_verdict_extract_verdict` / `so_verdict_extract_reason` / `so_verdict_collect_lanes`（並行配列＋count を populate）/ `so_verdict_aggregate <refuted_phrase> <survived_phrase>`（conservative 集約・error 句は固定）/ `so_verdict_dissent_json`（stdout）/ `so_verdict_exit`（refuted→3 / else→0）。
- `bin/oe-refute` / `bin/oe-review` は lib を source し、複製していた抽出2関数＋レーンループ＋集約＋dissent 組立＋exit を lib 呼び出しに置換。出力/audit jq 組立を不変に保つため lib の global-return を verb ローカル名（`VERDICT`/`REASON`/`total_lanes`/`dissent_json`）に束ねた＝verb 固有の出力アセンブリ（oe-review の reviewed_sha 等）は無改変。
- verb 差は集約 REASON の文言のみ。phrase 引数で完全一致保持:
  - oe-refute: refuted=「material に反証」/ survived=「反証を試みたが claim は持ちこたえた」
  - oe-review: refuted=「material なコード欠陥を検出」/ survived=「レビューしたが material な欠陥は見つからなかった」
- oe-review の冒頭 NOTE（旧: 複製は意図的で lib 化は follow-up）を「#196 で共有・解消」へ更新。
- **検証（回帰ゼロ）**:
  - shellcheck: `lib/so-verdict.sh` `bin/oe-refute` `bin/oe-review` 全 CLEAN。
  - 既存ユニット: `test_oe_refute` 63/0・`test_oe_review` 64/0。**bash 5.2.37 と system bash 3.2.57 の両方**で green（lib 抽出前の baseline と同数＝回帰ゼロ）。
  - **負のコントロール（lib 抽出前後で同一挙動）**: master(旧) verb と worktree(新) verb の出力 JSON を、`output_dir`/`audit_id`（run 毎の ULID）のみ正規化して byte 比較。refuted/survived/error/mixed・rubric exploration|consensus・lanes 3 を網羅して **fail=0**＝ユニットが検証しない `reason` 文言まで含め完全一致を確認。

## 実装SO（oe-review・初の実運用）

`oe-review --lanes 2 --base master --context tmp/oe-review-context-196.md` を自分の diff（`478a75f`）に実行。output_dir は非永続のため verdict/dissent の内容を転記する。

- **verdict: survived**（exit 0）。reason=「全 2 レーンがレビューしたが material な欠陥は見つからなかった」。lens=impl / diff_base=master / reviewed_sha=478a75f / diff_hash=022f93e / changed_files_count=4 / audit_id=20260620094339FYHNGGY46DF1。
- dissent:
  - `[codex] survived`: 共有 lib 化による correctness / 到達可能性 / Bash 堅牢性 / セキュリティ上の material な欠陥なし。
  - `[cursor] survived`: master との突合・REASON 文言・set -e/IFS/jq/exit/global-return の各経路を反証的に検証し、純リファクタとして挙動不変を確認。
- audit: `audit/oe-review.jsonl` に event_type=oe_review・lens=impl・diff バインド付きで記録（設計SO の oe-refute.jsonl とは別 stream＝構造的に識別可能）。

### oe-review を実 impl-SO に使った所感（初の実運用）

- end-to-end で機能: base=master 自動突合 → diff バインド（reviewed_sha/diff_hash/changed_files_count）→ 2 レーン → conservative 集約 → JSON + audit emit まで一気通貫。
- **impl-SO レンズが「正しい関心」に当たった**: 純リファクタで本当に効くのは「旧実装との突合」で、cursor レーンが明示的に master cross-check を行った。設計SO（breadth/grounding）では出ない観点で、設計SO ≠ 実装SO の分離（episode-flow-discipline）が実地で機能した。
- lens=impl が別 audit stream（oe-review.jsonl）に落ちる＝#192 の false-pass（設計SO を回して実装SO 代替とみなす）を構造的に防ぐことを実運用で確認。
- **out-of-scope finding（verb への follow-up 候補・本 PR では実装しない）**: changed_files_count=4 に episode doc（非コード）が含まれた。コミット後に diff バインドする運用だと doc も対象に入る。レビュー品質には無害だが、将来 doc 除外 or コミット前 diff レビューの選択肢は verb 側の検討余地（routing のみ）。

## closure（episode-retrospective・tier=heavy）

tier=heavy（意図的に oe-review=so-compare wrap を品質ゲートとして起動・DJ-1 で選択肢比較棄却あり）。

### closure gate

- **Context / なぜ**: 冒頭ブロック引用に自己完結（#195 で複製した VERDICT ロジックの drift risk を共有 lib で解消する純リファクタ）。
- **次の消費者**: (1) #196 PR レビュアー（親 %3 が oe-refute/oe-review 契約の文脈でレビュー）。(2) 今後 VERDICT 抽出/集約ロジックを触る者（単一 source = lib/so-verdict.sh）。(3) cockpit/探索クラスタ — oe-review の**実運用初ケースの記録**として。
- **follow-up routing**:
  - oe-review の changed_files_count に episode doc（非コード）が混じる件 → **verb への follow-up 候補（本 PR では実装しない・routing のみ）**。再発・摩擦が顕在化したら Issue 化、しなければ追わない。
  - 設計SO（別途 oe-refute）スキップ → 記録済み・follow-up なし（実装SO=oe-review が分解の敵対的チェックを兼ねた）。
  - その他の残課題なし。
- **status 確定**: in-development → **stable**。達成度: **達成**（受け入れ条件3つ全充足・回帰ゼロ）。
- **evidence anchor（揮発パス転記）**: oe-review output_dir / DJ-1 artifact / 負のコントロール script は tmp・scratchpad（揮発）。verdict/dissent・採否理由・neg-control 手法と結果（fail=0）・shellcheck/test 結果は本文へ転記済。audit は `audit/oe-review.jsonl`（永続）に残存。
- **SO 証跡リンク**: 実装SO セクションに verdict/reason/audit_id/output_dir を転記。

### 内容（出力型 × 消費チャネル）

- **決定と根拠**: DJ-1 で案A（global-return lib）採用、案B（stdout-serialization）/案C（leaf 関数のみ抽出）を理由付きで棄却（上記「設計」節）。
- **わかったこと（W）**: oe-review は実 diff に対し end-to-end で機能。impl-SO レンズが純リファクタで効く「旧実装との突合」観点に当たった（cursor が master cross-check 実施）。
- **原則（Pattern）**: 設計SO ≠ 実装SO の分離（別レンズ・別 audit stream）が実地で機能＝#192 false-pass の構造的予防を実運用確認。global-return lib は envelope.sh の既存パターン転用で bash 3.2 制約下の現実解。
- **蒸留シグナル**: 昇格候補 **なし**（lib は実装詳細・Decision/skill/rule 昇格不要）。oe-review 実運用初ケースの知見は本 episode に保全し cockpit 側が参照すれば足りる。
- **残課題**: 上記 routing の oe-review doc 混じり 1 件のみ（行き先付与済）。

### Step4（外部チェック）辞退

```
Step4 辞退: 本 episode は実行ログに失敗・撤回・指摘が無い純リファクタ（test 初回 green・neg-control fail=0・oe-review survived）で、Step4 が主に守る「失敗の選択的省略」が構造的に該当しない。
既存チェックで覆った観点: routing（残課題1件に行き先付与済）/ evidence anchor（揮発パスの要点を本文転記済）/ back-propagation（欠陥を見つけた他文書なし）
未実施観点と判断: 「失敗の選択的省略」チェック=該当する失敗が存在しないため不要（低リスク・非該当）
```
