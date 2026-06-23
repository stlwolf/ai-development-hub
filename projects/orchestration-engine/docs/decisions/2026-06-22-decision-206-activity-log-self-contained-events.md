---
id: "01KVQPVHWZTRGV46B94JVRQ7SR"
title: "#206 親子活動ログは session_id 主キーでなく自己完結イベント（write 時 snapshot）の append-only ログにする — #188 DJ-188-4 の精緻化"
date: 2026-06-22
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/206"
    reason: "本 ADR の主スコープ（report inbox / 親子活動ログ 増分1 の鍵戦略）"
  - type: refines
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "DJ-188-4（Stage-B の event bus は session_id 主キー）を、delegate に session_id が無い現実へ精緻化（部分 supersede・DJ-188-4 の範囲のみ）"
  - type: source_material
    ref: "projects/orchestration-engine/lib/event-bus.sh"
    reason: "本決定の実装（emit プリミティブ・自己完結レコード）"
  - type: source_material
    ref: "projects/orchestration-engine/schemas/oe-events.schema.json"
    reason: "レコードスキーマ（audit-log とは別系統・additive）"
  - type: episode
    ref: ../episodes/2026-06-22-episode-206-activity-log.md
    reason: "本 ADR を生んだ実装エピソード（探索・実装SO・経緯）"
tags: [orchestration, activity-log, event-bus, identity, cockpit, report-inbox, decision, read-only]
---

# #206 親子活動ログは session_id 主キーでなく自己完結イベント（write 時 snapshot）の append-only ログにする — #188 DJ-188-4 の精緻化

## コンテキスト

`#206`（report inbox）の増分1 として、親子委譲の相互作用（spawn・送信）を永続記録し read 時に投影する活動ログを実装する。動機は親子委譲の「中身を回収できない／配送が見えない／子が消えると追えない」問題（departed children も後から見たい）。

[#188 ADR](2026-06-19-decision-188-identity-unification.md) は、永続横断観測が必要になった場合の本線を **DJ-188-4 = `session_id` 主キーの typed append-only event/activity bus** と申し送っていた（deferred）。本 ADR はその deferred 方針を増分1 として実装するにあたり、**鍵戦略を 1 点だけ精緻化**する。DJ-188-1/2/3/5 は不変・本 ADR の対象外。

## 確定した事実（決定の前提）

| 項目 | 内容 | 根拠 | status |
|---|---|---|---|
| delegate 子は session_id を持たない | registry は `{pane,label,workspace,parent_pane,role}` のみ。session_id/state/audit を持たない | `lib/delegate-registry.sh:56`・[#188 ADR 前提表](2026-06-19-decision-188-identity-unification.md) | verified |
| pane は寿命が短く再利用される | tmux `%N` は pane 破棄後に再割当。registry は GC される（`oe_reg_gc`） | `lib/delegate-registry.sh:168` | verified |
| #188 の read-only/read 時相関 | observer は両ソースを read 時投影・永続マップを作らない（DJ-188-3）。read-only は観測者拘束（DJ-188-5） | [#188 ADR](2026-06-19-decision-188-identity-unification.md) | verified |

→ DJ-188-4 の素朴な「`session_id` 主キー」は **delegate の相互作用を 1 件も載せられない**（session_id が無い）。pane 主キーは GC/再利用で read 時に identity が失われる（寿命ミスマッチ）。

## 決定

- **DJ-206-1 — 鍵は session_id でも pane でもなく「自己完結イベント」。** 各イベントが `from`/`to` の `{pane, role, label}` を **emit 時に焼き込む**（write 時 snapshot）。role/label は emit 時に registry/pane-issue を read 時投影して決める。read 時は live registry に一切依存しない＝registry が GC されても・pane が消えても・再利用されてもレコードの意味は保たれる（departed children も可視）。
- **DJ-206-2 — lifecycle-end/stall は推論しない。** viewer（`oe-activity`）が出すのは 往復回数 / 配送（`suspected_miss`|`none`）/ preview / 送信元(子)生存（mux 存在 query = `alive`|`gone`|`?`）の 4 つのみ。「終了 vs stall」の分類はしない。これは **DJ-188-2**（対話 delegate 子の非対称 lifecycle を engine の完了 enum に押し込む category error を避ける）の帰結を観測側へ徹底したもの。
- **DJ-206-3 — vocab は additive。** 増分1 は `child_spawned` / `message_sent` の 2 種。`report_received` / turn 粒度などは非破壊追加できる設計にし、engine session_id 側（audit-log.schema.json）とは**別系統**に保つ（混ぜない）。

これにより [#188 ADR](2026-06-19-decision-188-identity-unification.md) の **DJ-188-4 を部分的に supersede** する（「永続横断観測が要れば event bus」という方針は維持、鍵戦略のみ session_id 主キー → 自己完結 write 時 snapshot へ差し替え）。

## 検討した選択肢と評価

| 案 | 概要 | 評価 |
|---|---|---|
| **session_id 主キー bus**（DJ-188-4 原案） | engine と同じ session_id を主キーに | ❌ delegate 子は session_id を持たない → 親子相互作用を 1 件も載せられない |
| **pane 主キー bus** | tmux `%N` を主キーに | ❌ pane は GC/再利用される → read 時に kind/role 導出が破綻（v1–v3 設計SO が反復指摘した寿命ミスマッチ） |
| **自己完結イベント（write 時 snapshot・採用）** | 各レコードが from/to の identity を emit 時に焼込 | ◎ session_id 不要・寿命ミスマッチ解消・read-only/read 時相関（#188 思想）と整合・departed children 可視 |
| **lifecycle 状態機械（ended/stalled 分類）** | 最終イベント＋無音時間で推論 | △ 増分1 では不採用（DJ-188-2 の category error を観測側へ持ち込む）。liveness の生 fact（alive/gone）のみに留める |

## 帰結（本決定の影響範囲）

- **実装（増分1）**: `lib/event-bus.sh`（best-effort emit）/ `schemas/oe-events.schema.json`（別系統・additive）/ `bin/oe-activity`（read-only 投影・report inbox）。emit は `oe-delegate`（`child_spawned`）と `oe_send_line`（`message_sent`）に best-effort 結線（本体を壊さない）。
- **#188 への back-prop**: [#188 ADR](2026-06-19-decision-188-identity-unification.md) に「DJ-188-4 は本 ADR で部分 supersede」のステータス行を 1 行追記（本文は不可触）。
- **残課題（後続増分へ defer）**:
  - server-pid をレコードに含めない現状では、同一サーバの `%N` 再利用で別関係が混線し得る（viewer の既知制約として明記済）。server-pid キー化は後続で。
  - log rotation / retention（永続＝増加）。`#185` raw-log retention と同様に defer（viewer の既定窓で緩和）。
  - engine session_id 側との統合・turn 粒度 timeline（B）。
- **#144 reliability は再実装しない**（境界）。delivery_signal は #144 の finalize 信号を読むのみ。

## 関連

- 精緻化元: [#188 identity unification ADR](2026-06-19-decision-188-identity-unification.md)（DJ-188-4）
- 実装エピソード（探索・実装SO・経緯）: [#206 activity-log episode](../episodes/2026-06-22-episode-206-activity-log.md)
- Issue: [#206](https://github.com/stlwolf/ai-development-hub/issues/206) / [#188](https://github.com/stlwolf/ai-development-hub/issues/188) / [#177](https://github.com/stlwolf/ai-development-hub/issues/177)
