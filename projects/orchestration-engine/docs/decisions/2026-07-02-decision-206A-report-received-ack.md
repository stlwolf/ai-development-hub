---
id: "01KWH9NEDP82G84P9KHMNQRF2Q"
title: "#206A 受領印は actor 明示 verb（oe-ack）+ frontier snapshot の自己完結イベントにする — DJ-206-3 予約の具体化"
date: 2026-07-02
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/206"
    reason: "(A) report_received — 子の報告の受領可視化（本 ADR のスコープ）"
  - type: derived_from
    ref: 2026-06-22-decision-206-activity-log-self-contained-events.md
    reason: "DJ-206-1（自己完結）/ DJ-206-2（推論しない）/ DJ-206-3（vocab additive・report_received を予約）の具体化"
  - type: source_material
    ref: ../plans/2026-07-02-plan-206A-report-received.md
    reason: "設計確定事項と実装ステップ（kickoff-206A の忠実変換）"
  - type: episode
    ref: ../episodes/2026-07-02-episode-206A-report-received.md
    reason: "本 ADR を生んだ実装エピソード（ゼロベース探索・設計SO 3周・実装・潜在バグ発見）"
tags: [orchestration, activity-log, report-received, ack, event-bus, cockpit, decision]
---

# #206A 受領印は actor 明示 verb（oe-ack）+ frontier snapshot の自己完結イベントにする — DJ-206-3 予約の具体化

## コンテキスト

#206 (A): 子→親報告の「受領（届いた/読まれた）」の可視化。増分1/2 で `message_sent`（送った）+ `delivery_signal`（suspected_miss|none）+ inbox/timeline まで揃ったが、「親が実際に受領/確認した」信号が無く `message_sent` → `report_received` のループが閉じていなかった。viewer（`oe-activity`）は read-only 規律（#188/#206）で emit できない — **「誰がいつ受領印を打つか」**（actor トリガ設計）が核の設計判断。

確定前に `predecision-exploration`（ゼロベース探索木）+ `oe-refute --rubric exploration` を 3 周実施。verdict は 3 周とも refuted（conservative 集約）だが SO#3 は新カテゴリゼロ＝暫定停止条件充足で打切り、その判断ごと人間承認ゲートを通過（2026-07-02）。SO の実質的発見（oe-report の emit 漏れ / 位置 watermark・count 単独の棄却 / frontier 型 / 層分離）は下記決定に反映済み。

## 決定

- **DJ-206A-1 — トリガは actor 明示 verb `bin/oe-ack`（primitive）。** 受領した側のアクター（AI が report 処理時 / 人間が inbox 確認時）が明示的に打つ。打ち忘れは pending 残存側（安全側）に倒れる。応答連動 sugar（`oe-send --ack`）/ ハーネス受信フック（UserPromptSubmit 照合の自動 emit）は同一 vocab への additive 増分として defer。
- **DJ-206A-2 — 意味論は frontier snapshot。** event に `covers_last_ts`（カバーする最終 message の ts）+ `covers_count`（累計数・同秒 cap）を emit 時に焼き込む自己完結レコード（DJ-206-1 整合）。viewer 投影は 方向フィルタ（sender=to.pane ∧ recipient=from.pane の `message_sent`）→ `K = min(covers_count, |ts ≤ covers_last_ts|)` の先頭 K 件が received・複数 ack は max K（単調・巻き戻りなし）。受領は推論しない（DJ-206-2 の徹底）— 打たれた印だけを数える。
- **DJ-206A-6 — 層分離。** lib 層 `oe_event_report_received <from> <to> <covers_count> <covers_last_ts>` は**引数のみの純 emit**（ログを読まない＝hot path 結線可能な emit primitive の既存規約を維持）。ログ read・covers 計算・「acked N 件」echo は verb 層 `oe-ack` の責務（`oe-activity` と同じ read クラス）。
- 付随: from=受領者 / to=報告元（actor=from の既存規則）。covers_* は `report_received` のみ必須（既存 allOf イディオム）。covers 0 件は emit しない（no-op）。legacy `oe-report` は `oe_send_line` へ載せ替え（emit 漏れの盲点解消・#142 部分前倒し・人間承認済み）。

## 検討した選択肢と評価（探索木の蒸留）

| 案 | 概要 | 評価 |
|---|---|---|
| **明示 ack verb（採用）** | 親側アクターが oe-ack で打つ | ◎ 「確認した」を確認した者が打つ（honest）・両アクター対応・ハーネス非依存・失敗が安全側 |
| 応答連動バンドル（oe-send --ack） | 返信 act に opt-in で ack を同乗 | ○ primitive と同じ emit 口に乗る sugar として additive defer。自動バンドルは「kick=読んだ」を含意せず棄却 |
| ハーネス受信フック（SO#1 後のゼロベースで発見） | UserPromptSubmit が prompt を message_sent(preview) と照合し自動 emit | △ 決定論的（(i)届いた の受信側 ground truth）だがハーネス結合 + preview prefix 照合の誤 ack（非安全側）+「人間が見たか」に答えない → additive defer |
| oe-capture 結線 | 既存 consume 経路にフック | ❌ 主経路（TUI 直接着弾）で capture が走らずカバレッジ部分的 |
| read 時推論（報告後の kick=受領） | viewer が導出 | ❌ DJ-206-2 と同じ category error |
| 子側 scrape 検証 / viewer 表示時自動 ack | — | ❌ 検出禁止（issue「やらないこと」）/ read-only 違反 |
| 位置 watermark（v1）→ covers_count 単独（v2） | ack 行より前 / 先頭 N 件 | ❌ SO#1/#2 反証で棄却: 非安全側レース / rotation false-ack / DJ-206-1 不整合 → frontier + count cap（v3）へ |

## 結果

- `message_sent` → `report_received` のループが `--inbox`（PENDING 列・0=受領済み）/ `--timeline`（ack 行 interleave）で閉じ、「親が見たか」が人間に可視になる。
- 受入残余（開示）: (1) ack 直前着弾の未読報告が frontier に入るレース → `oe-ack` の echo（acked N 件 / 最終 preview）で即検証可能に開示 (2) 誤 ack の訂正 event は無し（additive で将来可能・影響は表示限定） (3) log rotation 導入時は ack/frontier 整合の保存が制約（rotation 増分へ申し送り） (4) `oe-*` を通らない生 send-keys 報告は観測不能。
- 副産物: 増分1 の潜在バグ（`_oe_event_ident` の TAB 区切り内部プロトコルが「role 空 + label あり」= registry GC 後に label を role 位置へシフト）を検出・修正（US 区切り化）。departed children の ack（本増分の主要ユースケース）が直撃する経路だった。
