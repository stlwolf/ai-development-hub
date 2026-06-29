---
id: "01KW9ZS54TRJNCA8KMKQ8SFTS9"
title: "#206 増分2 = oe-activity --timeline（B・viewer-only）実装エピソード"
date: 2026-06-30
type: episode
status: stable
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

> 作業中に追記（skeleton → S1–S5 → G3+closure の 3 チャンクで記録。厳密な逐次ではない）。

## コンテキスト / なぜ

増分1（PR #213）で event-bus + 自己完結ログ + read-only viewer（overview / `--inbox`）が landed した。本増分は #206 (B) の **turn 粒度 timeline** を、event-bus を additive 拡張（実質 viewer のみ）で実装する。設計上 turn はスキーマに焼かず **read 時導出**（関係内 `ts` + append `idx` 順の位置）とした（DJ-i2-1）。`report_received`(A) / engine session_id 統合 / stall 推論は defer（未収束 SO 領域・DJ-206-2 を再オープンしないため）。

## 進行ログ

### 実装着手（S1–S3）

- branch `feature/#206_increment2_timeline`・viewer-only。`lib/event-bus.sh` / `schemas/oe-events.schema.json` は触らない（スキーマ不変の担保）。
- `bin/oe-activity` に変更を集約:
  - 引数 `--timeline`（`MODE="timeline"`）+ usage / help 追記。
  - `project()` jq: `$msgs` に `dir`（`report`=子→親 / `kick`=親→子・recipient で判定）を追加。末尾を `if $mode=="timeline" then … else <既存サマリ> end` で分岐。timeline は `group_by(.c)`（関係＝子）→ 各群 `sort_by(.ts)|to_entries` で **turn を read 時導出**（1-based 位置）→ `add` で平坦化 → 全体 `sort_by(.ts)`（古→新）→ 1 送信 1 行の TSV。**※この時点の実装。G3 で区切りを US 化＋ `sort_by(.ts, .idx)` に差し替え（下記）。**
  - レンダリング: timeline 専用 header / 行（`TURN / TS / DIR / DELIVERY / RELATION / PREVIEW`・LIVE 列は出さない）。空入力は `case "$MODE"` で `(no messages …)` を出す。
- **DJ-i2-1 の実装的帰結**: turn は emit 時に振らない（event-bus の「過去ログを read しない / atomic append」不変条件を壊さない）。viewer が `ts` 順位置として read 時に算出するだけ ＝ スキーマ変更ゼロ・増分1 既存 jsonl と後方互換。

### 検証（G1 / G2）

- **G1**: `shellcheck bin/oe-activity` rc=0。ダミー jsonl（2 関係・往復・kick・suspected_miss・壊れ行）で `--timeline` を目視 → 関係内 turn 連番（%66=1,2,3 / %70=1）・全体時系列・`dir`・`delivery`・壊れ行 skip を確認。overview / `--inbox` の既存出力は不変。TS 列が ISO 25 桁で `%-20s` を超えたため `%-26s` に微調整。
- **S4**: `tests/test_oe_activity.sh` に [12]–[14] 追加（turn 連番 / dir / 時系列順 / kick 可視 / spawn-only→no messages / 壊れ行 skip）。bash 3.2 footgun（`declare -A`・空配列）は新規追加で踏まない。多バイト grep 回避のため kick マーカは ASCII `increment1`。
- **G2**: `test_oe_activity.sh` を **bash 5.2.37 / 3.2.57 両系で 39/39 green・rc=0**。`shellcheck` test ファイル rc=0。`git diff` は `bin/oe-activity`（+66/-19）と test（+34）のみ ＝ **event-bus / schema 無変更**（viewer-only 担保）。無回帰: `test_event_bus.sh` 36/36（bash 3.2.57）。
- **S5**: `bin/README.md`（oe-activity 節に `--timeline` + モード対比 + スキーマ不変を明記）/ `projects/orchestration-engine/README.md`（ツリー行）に追記。

### 実装SO（Gate G3・`oe-review` codex+cursor）

- 初回 `oe-review --lanes 2 --base master`（reviewed_sha `f60db94`・audit `202606291538449ZSP19KCNCAN`・出力 `tmp/oe-review-202606291538449ZSP19KCNCAN/`）= **refuted 2/2**（3 指摘）。finding B/C は real。**finding A は当時 real と判断したが、後日の jq 実測で「過大」と判明**（下記で訂正）。1 ラウンド自律対応:
  - **[cursor・real・採用]** `--timeline` の TSV パースが `IFS=$'\t' read` の連続タブ折り畳みで**スキーマ正当な空 label 時に列ズレ**（RELATION/PREVIEW 誤表示）。cursor が adversarial 実行で再現。→ 区切りを **tab→US(`0x1f`)** に変更（jq `join("\u001f")` + `IFS=$'\037' read`。US は非空白 IFS なので空フィールドを保持）。
  - **[codex・real・採用]** preview の制御文字畳み込みが `\t\r\n` だけで **ESC/OSC が `--timeline` 表示へ素通り**（端末注入が到達可能）。→ `gsub("[\t\r\n]")` → `gsub("[[:cntrl:]]")`（C0+DEL を空白化）。
  - **[codex・過大 → 堅牢化として採用]** codex は「秒精度 `ts` の同秒送信で turn 導出が**順序不定**」と指摘。だが**後日実測（jq 1.8.0）では `sort_by`/`group_by` は安定（append 順保持）で、関係内 turn は現行 jq では実際には決定的に正しかった**（cursor の「実装依存」が正確・codex / 初稿の「順序不定」は過大。SO を一次照合せず転記した evidence-verification の漏れ）。残る実問題は (a) jq sort 安定性は仕様保証された契約でない、(b) 全体 `sort_by(.ts)` は group 順を経るため同一秒の**異関係**行が append 順でなく group 順で並ぶ軽微な表示差、の 2 点。→ append 順 `idx` を付与し `sort_by(.ts, .idx)` で**安定性に依存せず決定化**（現行 jq のバグ修正ではなく堅牢化＋異関係表示順の是正）。
- 回帰テスト [15]（空 label 列ズレ）[16]（ESC 畳み込み）[17]（同一秒 turn 決定性）を追加し各指摘を locking。**修正後 50/50 green（bash 5.2.37 / 3.2.57）・shellcheck rc=0**。
- **スコープ判断（back-prop）**: US 区切りへの変更は **既存 overview/inbox の同型潜在バグ（空 label 列ズレ）も同時に解消**した（根本原因が共有の `IFS=$'\t'` 折り畳みのため。timeline だけ直すのは hacky な部分修正）。rendered 出力は不変ゆえ既存テストは透過。これは増分2 スコープの軽微な拡大だが、既知バグを残さない判断（implementation-principles・最小スコープは silent 拡大を禁ずるのみ＝本記録で明示）。

## closure

- **tier: heavy**（意図的 SO 起動 + SO refuted で方針修正 + 非自明な設計判断 DJ-i2-1）。
- **status: stable** / **達成度: 達成**（増分2 = `--timeline`（B）viewer-only・スキーマ不変・実装SO 1 ラウンド対応まで）。
- **次の消費者**: (1) cockpit を見る人間（`oe-activity --timeline` で「見ていない間の往復」を時系列把握）/ (2) **report_received(A) 増分の着手者**（本増分は (B) のみ・(A) は actor トリガ設計を伴うため defer）/ (3) #185 lifecycle 機械制御の検討者（turn は read 時導出で持つ＝engine 結合や stall 推論は依然未着手の地点を確認できる）。
- **決定と根拠（コア・diff から復元しにくい所）**:
  - **DJ-i2-1（turn = read 時導出）**: emit 時に turn を振らない。event-bus の「過去ログを read しない / atomic append / best-effort」不変条件とレース耐性を壊さないため。viewer が関係内 `ts`（+ append `idx`）順の位置として算出 → スキーマ変更ゼロ・増分1 既存 jsonl 後方互換。
  - **US(`0x1f`) 区切り採用**: `@tsv` + `IFS=$'\t'` は tab が IFS 空白で連続折り畳み＝空フィールド消失。非空白の US なら `read` が空フィールドを保持。`[[:cntrl:]]` 畳み込みで preview に US も混入しない。
- **原則（negative knowledge・#62 候補）**:
  - Anti: `IFS=$'\t' read` で TSV を分解（tab は IFS 空白 → 連続 tab が 1 区切りに畳まれ空列消失で列ズレ）/ OK: 非空白区切り（US 0x1f）+ `IFS=$'\037'`、または列数検証。
  - Anti: 秒精度 ts だけで時系列順・連番を導出し、同秒タイの順序を sort 安定性に委ねる（仕様非保証への依存。jq 1.8.0 は実測安定だが契約ではない）/ OK: append-order index を tiebreaker に明示。
  - Anti: 端末出力の制御文字畳み込みを `\t\r\n` 限定（ESC/OSC 素通り＝注入）/ OK: `[[:cntrl:]]` で C0+DEL を畳む。
  - Anti: テスト fixture の preview に制御文字を「バックスラッシュ u + 16進」(JSON エスケープ) で直接書く → エディタ / heredoc がリテラル制御文字へ展開し jq が不正 JSON として行 skip → テスト空振り（実装SO 対応中に数回手戻り）/ OK: `jq -cn` でオブジェクトを組んで出力させる、または perl の hex 指定（`\x5c`=バックスラッシュ）で挿入。
- **follow-up routing**:
  - `report_received`(A) / engine session_id 統合 / stall・lifecycle 推論 → **defer**（#206 ADR defer リスト・DJ-206-2 / #188 未収束領域。discussion に根拠）。別増分。
  - server-pid キー化（`%N` 再利用混線）/ log rotation → **defer**（増分1 既知制約のまま・本増分で悪化させていない）。
  - 既存 overview/inbox の空 label 列ズレ → **本 PR で解消済**（back-prop・上記）。追加 follow-up なし。
- **evidence anchor**: SO audit `202606291538449ZSP19KCNCAN`・reviewed_sha `f60db94`・出力 `tmp/oe-review-202606291538449ZSP19KCNCAN/`（worktree・gitignore＝揮発のため要点を本文へ転記済）。テスト 50/50（bash 5.2.37 / 3.2.57）・shellcheck rc=0・event-bus/schema diff ゼロ。
- **蒸留シグナル**: Decision 昇格は **保留**（DJ-i2-1 は #206 ADR の小精緻化＝本 episode 記録で足りる。新規 ADR は作らない）。negative knowledge 3 件は **#62 注入候補**（今回は本 episode 記録に留める）。
- **Step4 辞退（heavy 外部チェック・advisory）**: closure 4 観点を自己点検し低リスクと判断して辞退。覆った観点= 失敗の選択的省略なし（SO refuted 3 件・fix・back-prop をすべて明記）／ routing 網羅（defer 群すべて行き先付与・overview バグは解消済）／ evidence anchor（SO audit id・出力パス・テスト数を本文転記）／ back-propagation（overview/inbox への波及を明記）。未実施観点と判断= so-compare 再チェックは指定フロー外（実装SO は別レンズ＝コード欠陥で closure 品質を代替しない点は理解の上、上記 4 観点を本文で自己点検済のため不実施）。
  - **※ 後日訂正（自己評価の甘さの実例）**: この辞退は borderline だった。finding A の「順序不定」過大表現（技術的事実誤認）が closure 時点で残存し、ユーザー指摘 → jq 実測ではじめて訂正できた。Step4 外部チェックを回していれば closure 前に拾えた公算が高い。heavy で 3 件の指摘が出た episode の Step4 辞退は今後より慎重に。
