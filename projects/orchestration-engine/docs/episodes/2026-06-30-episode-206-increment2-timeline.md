---
id: "01KW9ZS54TRJNCA8KMKQ8SFTS9"
title: "#206 増分2 = oe-activity --timeline（B・viewer-only）実装エピソード"
date: 2026-06-30
type: episode
status: draft
related:
  - type: implements
    ref: "#206"
  - type: derived_from
    ref: ../plans/2026-06-29-plan-206-increment2-timeline.md
    reason: "本エピソードの実行プラン（S1–S7・Gate）"
  - type: design_context
    ref: ../discussions/2026-06-29-discussion-206-increment2-timeline.md
    reason: "スコープ確定・DJ-i2-1（turn=read 時導出）"
  - type: depends_on
    ref: "#188"
---

# #206 増分2 = oe-activity --timeline（B・viewer-only）実装エピソード

> リアルタイム追記（作業中に逐次記録）。

## コンテキスト / なぜ

増分1（PR #213）で event-bus + 自己完結ログ + read-only viewer（overview / `--inbox`）が landed した。本増分は #206 (B) の **turn 粒度 timeline** を、event-bus を additive 拡張（実質 viewer のみ）で実装する。設計上 turn はスキーマに焼かず **read 時導出**（関係内 `ts` ソート位置）とした（DJ-i2-1）。`report_received`(A) / engine session_id 統合 / stall 推論は defer（未収束 SO 領域・DJ-206-2 を再オープンしないため）。

## 進行ログ

### 実装着手（S1–S3）

- branch `feature/#206_increment2_timeline`・viewer-only。`lib/event-bus.sh` / `schemas/oe-events.schema.json` は触らない（スキーマ不変の担保）。
- `bin/oe-activity` に変更を集約:
  - 引数 `--timeline`（`MODE="timeline"`）+ usage / help 追記。
  - `project()` jq: `$msgs` に `dir`（`report`=子→親 / `kick`=親→子・recipient で判定）を追加。末尾を `if $mode=="timeline" then … else <既存サマリ> end` で分岐。timeline は `group_by(.c)`（関係＝子）→ 各群 `sort_by(.ts)|to_entries` で **turn を read 時導出**（1-based 位置）→ `add` で平坦化 → 全体 `sort_by(.ts)`（古→新）→ 1 送信 1 行の TSV。
  - レンダリング: timeline 専用 header / 行（`TURN / TS / DIR / DELIVERY / RELATION / PREVIEW`・LIVE 列は出さない）。空入力は `case "$MODE"` で `(no messages …)` を出す。
- **DJ-i2-1 の実装的帰結**: turn は emit 時に振らない（event-bus の「過去ログを read しない / atomic append」不変条件を壊さない）。viewer が `ts` 順位置として read 時に算出するだけ ＝ スキーマ変更ゼロ・増分1 既存 jsonl と後方互換。

### 検証（G1 / G2）

- **G1**: `shellcheck bin/oe-activity` rc=0。ダミー jsonl（2 関係・往復・kick・suspected_miss・壊れ行）で `--timeline` を目視 → 関係内 turn 連番（%66=1,2,3 / %70=1）・全体時系列・`dir`・`delivery`・壊れ行 skip を確認。overview / `--inbox` の既存出力は不変。TS 列が ISO 25 桁で `%-20s` を超えたため `%-26s` に微調整。
- **S4**: `tests/test_oe_activity.sh` に [12]–[14] 追加（turn 連番 / dir / 時系列順 / kick 可視 / spawn-only→no messages / 壊れ行 skip）。bash 3.2 footgun（`declare -A`・空配列）は新規追加で踏まない。多バイト grep 回避のため kick マーカは ASCII `increment1`。
- **G2**: `test_oe_activity.sh` を **bash 5.2.37 / 3.2.57 両系で 39/39 green・rc=0**。`shellcheck` test ファイル rc=0。`git diff` は `bin/oe-activity`（+66/-19）と test（+34）のみ ＝ **event-bus / schema 無変更**（viewer-only 担保）。無回帰: `test_event_bus.sh` 36/36（bash 3.2.57）。
- **S5**: `bin/README.md`（oe-activity 節に `--timeline` + モード対比 + スキーマ不変を明記）/ `projects/orchestration-engine/README.md`（ツリー行）に追記。
