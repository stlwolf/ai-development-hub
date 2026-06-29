---
id: "01KW94DF3TYQC7GR73NR4Z1BTN"
title: "#206 増分2 plan — oe-activity --timeline（B・viewer-only・additive）"
date: 2026-06-29
type: plan
status: draft
related:
  - type: derived_from
    ref: ../discussions/2026-06-29-discussion-206-increment2-timeline.md
    reason: "本プランのスコープ確定元（設計探索・DJ-i2-1）"
  - type: implements
    ref: "#206"
  - type: design_context
    ref: ../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md
    reason: "増分1 の決定境界（DJ-206-1/2/3）。本増分はこれを additive 拡張する前提"
tags: [orchestration, activity-log, timeline, cockpit, read-only, increment2]
---

# #206 増分2 plan — oe-activity --timeline（B・viewer-only・additive）

## Context / 前提

増分1（PR #213）で event-bus + 自己完結ログ（`oe-events.jsonl`）+ read-only viewer（`bin/oe-activity` の overview / `--inbox`）が landed 済み。本増分は **(B) turn 粒度 timeline** を、event-bus を additive 拡張する形で実装する。設計判断・スコープ根拠は discussion（`../discussions/2026-06-29-discussion-206-increment2-timeline.md`）に確定済み。

核となる確定事項:

- **DJ-i2-1**: turn index は **read 時導出**（関係内 `ts` ソート位置）。スキーマに turn フィールドを足さない。
- viewer-only・**スキーマ変更ゼロ**・増分1 の既存 jsonl と後方互換。
- DJ-206-1/2/3・#188 を再オープンしない（stall 推論・engine session_id 統合・report_received は対象外）。

## スコープ

### IN

- `bin/oe-activity` に `--timeline` モードを追加（関係内の各 `message_sent` を時系列 1 行で表示）。
- `tests/test_oe_activity.sh` に timeline 投影のテスト追加。
- `bin/README.md` / `projects/orchestration-engine/README.md` に `--timeline` を追記。

### OUT（discussion の defer に同じ）

- `report_received`（A・actor トリガ設計を伴う）。
- engine session_id 統合 / stall・lifecycle 推論 / server-pid キー化 / log rotation。
- `lib/event-bus.sh` / `schemas/oe-events.schema.json` の変更（**触らない** = スキーマ不変の担保）。

## 成果物

- `bin/oe-activity`（`--timeline` モード追加・既存 overview / `--inbox` は不変）。
- `tests/test_oe_activity.sh`（timeline テストケース追加）。
- README 2 ファイルの追記。
- episode（実装記録）。

## ステップ（TODO + Gate interleaved）

- [ ] **S1. `--timeline` 引数パース追加**: `bin/oe-activity:48-56` の case に `--timeline` を追加（`MODE="timeline"`）。help（`usage`）にも 1 行追記。
- [ ] **S2. timeline 投影を `project()` に追加**: `bin/oe-activity:95-133` の jq で、timeline モードのとき関係ごとの `$g`（`sort_by(.ts)`・既存 line 120）を畳まず**各メッセージを 1 行**に展開する。行フィールド = `child_pane / parent_pane / child_label / parent_label / turn_index / ts / dir(report|kick|→) / delivery / miss / preview`。turn_index は `$g` 内 1-based 位置（read 時導出）。
  - 全体の並びは既定で**時系列（古→新）**で読み下せる順とする（overview の `newest-first` とは別モード・実装時に最終確認）。
- [ ] **S3. timeline レンダリング追加**: `bin/oe-activity:148-167` に timeline 用の header / 行整形を追加（列案: `TS / TURN / DIR / DELIVERY / RELATION / PREVIEW`）。既存 overview / inbox の出力は不変に保つ。
- [ ] **Gate G1（自己検証）**: `shellcheck bin/oe-activity` rc=0。手動で `OE_EVENT_DIR=<tmp>` に複数往復のダミー jsonl を置き `--timeline` の出力（turn 連番・順序・空入力・壊れ行 skip）を目視確認。
- [ ] **S4. テスト追加**: `tests/test_oe_activity.sh` に — (a) 単一関係で turn が 1..N に振られる、(b) 複数関係の時系列インターリーブ、(c) 空入力で `(no ...)`、(d) 壊れ JSONL 行の skip（既存 degrade と整合）、(e) `--inbox` / overview の既存挙動が不変（回帰）。
- [ ] **Gate G2（テスト・bash 両系）**: `bash tests/test_oe_activity.sh`（既存 24 + 追加）を **bash 5.2.x と bash 3.2.57 の両方**で green。**#193 の bash 3.2 footgun（空配列の `set -u` 展開・`declare -A`）を新テストで踏まないこと**を明示確認。
- [ ] **S5. README 追記**: `bin/README.md` と `projects/orchestration-engine/README.md` に `--timeline` の用途を 1〜数行で追記（overview=サマリ / timeline=往復の時系列、を対比）。
- [ ] **Gate G3（実装SO・必須）**: `oe-review`（codex+cursor・欠陥/到達可能性レンズ）を reviewed diff にバインドして実行。**verdict=refuted なら PR を保留**し 1 ラウンド自律対応（real は採用・false positive は一次照合で却下）。
- [ ] **S6. episode 締め**: `episode-retrospective`（消費者明示・routing・status・tier 判定）。リアルタイム追記が崩れた場合は冒頭 `reconstructed` を明示。
- [ ] **S7. PR 作成**: `pr-conventions`・**squash**・本文に Refs #206。Copilot レビュー依頼は既存フローどおり。

## 検証 / 完了条件

- `shellcheck bin/oe-activity` rc=0。
- `tests/test_oe_activity.sh` が bash 5.2.x / 3.2.57 の両方で green（既存 + 追加ケース）。
- overview / `--inbox` の既存出力が不変（回帰テストで担保）。
- `lib/event-bus.sh` / `schemas/oe-events.schema.json` に diff が無い（スキーマ不変の担保）。
- 実装SO（`oe-review`）1 ラウンド対応完了（refuted の real 指摘を反映 or 反証）。

## doc flow（4層パイプライン・明示）

- **discussion**〔済〕: `../discussions/2026-06-29-discussion-206-increment2-timeline.md` — 設計探索・スコープ確定。
- **plan**〔本ファイル〕: 実行可能プラン。
- **設計SO**〔省略・理由記録〕: timeline 単体は viewer-only・スキーマ変更ゼロで低リスク。重い設計判断（report_received のトリガ）は defer したため heavy 設計SO は当てない。判断は episode に残す。
- **実装SO（`oe-review`）**〔Gate G3・必須〕: コード変更があるため PR 前に実行。
- **decision/ADR**〔状況次第・原則 episode 止まり〕: DJ-i2-1 は DJ-206 の小精緻化。昇格価値が出た場合のみ decision card 化。
- **episode**〔実装着手時に作成・リアルタイム追記 / 締めで必須〕: closure で `episode-retrospective`。
- **branch / PR**: `feature/#206_increment2_timeline`（作成済）・PR は squash・pr-conventions。

## リスク・未確認事項

- **timeline の並び順**（全体 古→新 vs 新→古）: 既定は時系列読み下し（古→新）。実装時に overview との一貫性も含め最終確認（軽微）。
- **列幅・情報密度**: timeline は行数が増える。preview 切り詰め（既存 ~100 字）と列整形で可読性を保つ。新モードとして分離し overview は汚さない。
- **%N 再利用の混線**: 増分1 の既知制約（server-pid 非保持）をそのまま継承。本増分で新たに悪化させない（解消は別 follow-up）。
- **report_received を defer したことで (A) の「人間が見た」可視化は本増分では未達**: discussion に defer 理由を明記済み。別増分でトリガ設計から扱う。

## 参照

- discussion: `../discussions/2026-06-29-discussion-206-increment2-timeline.md`
- 増分1 ADR: `../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md`
- 増分1 episode: `../episodes/2026-06-22-episode-206-activity-log.md`
- 実装対象: `bin/oe-activity` / `tests/test_oe_activity.sh`
- Issue: [#206](https://github.com/stlwolf/ai-development-hub/issues/206)
