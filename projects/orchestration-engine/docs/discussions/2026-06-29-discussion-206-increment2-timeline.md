---
id: "01KW94DF3TDNADEF2E0BTXF6ZP"
title: "#206 増分2 = 親子活動 timeline（B）の設計探索 — turn は read 時導出 / report_received(A) は defer"
date: 2026-06-29
type: discussion
status: stable
related:
  - type: implements
    ref: "#206"
  - type: depends_on
    ref: "#188"
  - type: design_context
    ref: ../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md
    reason: "増分1 の決定境界（DJ-206-1/2/3）。本増分はこれを additive 拡張する前提"
  - type: parent
    ref: "#169"
---

# #206 増分2 = 親子活動 timeline（B）の設計探索

## 文脈

`#206`（HITL クロスセッション活動フロー観測 + 報告可視化）は 2 軸ある:

- **(A) 報告の確実な可視化** — 子→親報告の可視 inbox（pending / 未読）。
- **(B) クロスセッション活動フロー観測** — セッション × ターン × 往復の時系列 timeline（read-only）。

増分1（PR #213・merged 2026-06-23）で event-bus（`lib/event-bus.sh`）+ 自己完結ログ（`oe-events.jsonl`）+ read-only viewer（`bin/oe-activity` の overview / `--inbox`）が landed した。本増分（増分2）は **(B) の turn 粒度 timeline** を、増分1 の event-bus を **additive 拡張**する形で実装する範囲を確定する。

## 増分1 が引いた決定境界（本増分の制約）

増分1 ADR（`../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md`）の確定事項。本増分はこれを**再オープンしない**:

- **DJ-206-1 — 自己完結イベント（write 時 snapshot）**: 各イベントが `from`/`to` の `{pane,role,label}` を emit 時に焼き込む。read 時は live registry に依存しない。[verified] ADR:46
- **DJ-206-2 — lifecycle-end / stall は推論しない**: viewer が出すのは 往復 / 配送 / preview / 送信元生存（`alive`|`gone`|`?`）の 4 つのみ。「終了 vs stall」分類はしない（DJ-188-2 の category error 回避を観測側へ徹底）。[verified] ADR:47
- **DJ-206-3 — vocab は additive**: `report_received` / turn 粒度は非破壊追加できる設計。engine 側（`audit-log.schema.json`）とは別系統に保つ。[verified] ADR:48

加えて event-bus の不変条件（`lib/event-bus.sh:11-16`）: **emit は過去ログを read しない / 1 行 = atomic append（O_APPEND, < PIPE_BUF） / best-effort（常に return 0）**。[verified]

## 探索した選択肢（増分2 項目のトリアージ）

ADR の defer リストには増分2 候補が複数ある。それを「クリーン additive か / 決定境界をまたぐか」で仕分けた:

- **turn 粒度 timeline（B）** → クリーン additive。下記 DJ-i2-1 で read 時導出に確定。**本増分の核**。
- **report_received（A）** → スキーマ enum 追加自体は additive だが、emit に **actor 側の新しい write path とトリガ設計**が要る（viewer は read-only 維持のため書かせない）。→ **本増分では defer**。
- **engine session_id 統合** → #188 の D-vs-F（pane 層 vs session 層統一）と 2-world topology（engine=wez-split は tmux 外・delegate=tmux-split は wez 外で相互不可視・DJ-188-1）を再オープンする。**対象外**。
- **stall / lifecycle 推論** → DJ-206-2 を覆す（category error 回避を意図的に選んだ箇所）。**対象外**。
- **server-pid キー化 / log rotation** → 増分1 の既知制約。本増分のスコープ外（別 follow-up）。

### turn の表現: read 時導出 vs スキーマ焼込

- **案 turn-stored（棄却）**: `message_sent` に turn 連番を焼き込む。→ 連番を振るには emit 時に「その関係の既存件数」を read する必要があり、**emit は過去ログを read しない**不変条件（`lib/event-bus.sh:14-16`）と同時 emit のレース耐性を壊す。
- **案 turn-readtime（採用 = DJ-i2-1）**: イベントは既に `ts` を持つ。viewer が関係内で `ts` ソートした**位置がそのまま turn 順**。現に `bin/oe-activity` の `project()` は関係ごとに `sort_by(.ts)`（`bin/oe-activity:120`）して直近 1 件へ畳んでいる。timeline は同じ `$g` を畳まず各メッセージを行にするだけ。**スキーマ変更ゼロ・増分1 の既存 jsonl と後方互換・#188 DJ-188-3「read 時投影」と整合**。[verified] `bin/oe-activity:95-133`

## 未収束 SO の文脈（session_id / stall を外す根拠）

「増分前に SO が収束しなかった」案件 = **#188（2基盤 identity 統一）**。設計SO（`tmp/so-188-design/`・codex+cursor）は構造的な答え（query-side fusion）には収束したが、**「そもそも #188 を解くべきか / F(session 層統一) を入れるか / #114 を先にすべきか」という framing で割れた**（cursor は F 保留・#114 先行を主張）。[verified] `tmp/so-188-design/cursor-stdout.txt`・ADR `2026-06-19-decision-188-identity-unification.md:78`

increment-1 の自己完結イベントは、この F-vs-session の対立を **「永続化の鍵」でなく「write 時の投影」で満たす**ことで orthogonal にした（`../episodes/2026-06-22-episode-206-activity-log.md:31`）。よって増分2 で **engine session_id 統合 / stall 推論を入れると、その未収束領域に戻る**。本増分はそこへ踏み込まず、event-bus の additive 拡張に閉じる。

（補足: #206 自身の設計SO も v1–v3 で 3 連続 refuted を経て v4 に確定した経緯がある — `../episodes/2026-06-22-episode-206-activity-log.md:25`。[verified]）

## 決めたこと

- **DJ-i2-1 — turn index は read 時導出**（スキーマに turn フィールドを足さない）。viewer に `--timeline` モードを追加し、関係内 `ts` ソート位置を turn 番号とする。
- **スコープ = `oe-activity --timeline`（B）のみ・viewer-only・スキーマ不変**。
- **report_received（A）は defer**（actor トリガ設計を含むため別増分）。
- DJ-206-1/2/3・#188 を再オープンしない（stall 推論・engine session_id 統合は対象外）。

## やらない / defer

- **report_received（A）**: viewer read-only を保つため actor 側 emit が要る → トリガ設計（明示コマンド等）を伴うので別増分。
- **engine session_id 統合**: #188 D-vs-F / 2-world topology の再オープン。
- **stall / lifecycle 推論**: DJ-206-2 を覆す。
- **server-pid キー化 / log rotation**: 増分1 の既知制約・別 follow-up。

## doc flow（本増分・明示）

- **discussion**（本ファイル）: 設計探索・スコープ確定。
- **plan**: `../plans/2026-06-29-plan-206-increment2-timeline.md`（実行可能プラン）。
- **設計SO**: timeline 単体は viewer-only・スキーマ変更ゼロで低リスク → heavy 設計SO は省略（report_received を defer したことで設計判断の重い部分が外れた）。判断は episode に残す。
- **実装SO（`oe-review`）**: コード変更があるため **PR 前に必須**（codex+cursor・欠陥/到達可能性レンズ・verdict refuted なら PR 保留）。
- **decision/ADR**: DJ-i2-1 は DJ-206 の小精緻化のため、原則 episode 記録に留める。昇格価値が出たら decision card 化を検討。
- **episode**: 実装着手時に作成しリアルタイム追記。締めで `episode-retrospective`（消費者明示・routing・status・tier）。後追い執筆になる場合は冒頭 `reconstructed` を明示。

## 参照

- 増分1 ADR: `../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md`（DJ-206-1/2/3）
- 増分1 episode: `../episodes/2026-06-22-episode-206-activity-log.md`
- #188 ADR: `../decisions/2026-06-19-decision-188-identity-unification.md`（DJ-188-1/2/3・D vs F）
- 設計SO 生出力（#188）: `tmp/so-188-design/`（worktree・gitignore）
- Issue: [#206](https://github.com/stlwolf/ai-development-hub/issues/206) / [#188](https://github.com/stlwolf/ai-development-hub/issues/188) / [#169](https://github.com/stlwolf/ai-development-hub/issues/169)
