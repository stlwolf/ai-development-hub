---
id: "01KVJ5ZJ04Q4D7HSADFQ2SNBHR"
title: "oe-refute / oe-review の VERDICT 抽出/集約を共有 lib 化（#196・実装SO=oe-review 初の実運用）"
date: 2026-06-20
type: episode
status: in-development
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

（oe-review --lanes 2 の verdict / dissent / 所感をここに転記）

## closure

（episode-retrospective で締める）
