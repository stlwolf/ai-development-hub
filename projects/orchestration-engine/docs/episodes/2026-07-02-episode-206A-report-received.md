---
id: "01KWH80EP7X26S62YZJ9F1H16M"
title: "#206/A episode — report_received（oe-ack primitive + frontier snapshot）実装記録"
date: 2026-07-02
type: episode
status: draft
related:
  - type: derived_from
    ref: ../plans/2026-07-02-plan-206A-report-received.md
    reason: "本 episode の実行対象プラン（kickoff-206A の忠実変換 + 設計確定事項 v3）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/206"
    reason: "(A) report_received — 子の報告の「受領」可視化"
  - type: design_context
    ref: ../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md
    reason: "決定境界 DJ-206-1/2/3（本増分は DJ-206-3 予約済みの additive 追加）"
tags: [orchestration, activity-log, report-received, ack, event-bus, cockpit, episode]
---

# #206/A episode — report_received（oe-ack primitive + frontier snapshot）実装記録

親（統括）からの委譲子セッションとして、#206 (A)「子の報告の受領可視化」を実装する。現状の活動ログは `message_sent`（送った）+ `delivery_signal`（suspected_miss|none）までで「親が実際に受領／確認した」信号が無く、`message_sent` → `report_received` のループが閉じていない — それを閉じるのが本作業。viewer read-only 規律により emit は actor 側の明示トリガが必要で、「誰がいつ受領印を打つか」が核の設計判断だった。

## 設計フェーズ（2026-07-02・実装前）

- kickoff（`.oe/kickoff-206A.md`・揮発）読了 → issue #206 原文・増分1 ADR・`lib/event-bus.sh`・`schemas/oe-events.schema.json`・`bin/oe-activity`・`lib/delegate-send.sh`・`bin/oe-send`・`bin/oe-report` を読了してから設計に入った。
- **ゼロベース設計**（`predecision-exploration`）: 探索木を `tmp/dj-206A-tree.md`（gitignore・揮発）に外部化。トリガ候補 = 明示 ack verb（A）/ 応答連動バンドル（A'）/ oe-capture 結線（B）/ UserPromptSubmit ハーネス受信フック（C・ゼロベース発見）/ read 時推論（D・棄却=DJ-206-2 と同じ category error）/ 子側 scrape（E・棄却=検出禁止）/ viewer 表示時自動 ack（棄却=read-only 違反）。
- **設計SO**（`oe-refute --rubric exploration`・弱SO・2レーン）を 3 周実行。verdict は 3 周とも refuted（conservative 集約 = 1 レーン refuted で全体 refuted）:
  - SO#1（audit_id 20260702072958R02QXBD79T1R）: 実質的発見 — legacy `oe-report` の emit 漏れ（この経路は `message_sent` すら emit しない盲点）/ 素の位置 watermark の非安全レース・rotation 脆弱性 / 未探索の応答連動カテゴリ → v2 改訂。
  - SO#2（audit_id 20260702073615X1ATZJBMHKP1）: 実質的発見 — covers_count 単独は rotation で false-ack（v1 執筆者の「縮退安全」主張は誤りだった）/ emit がログを read するのは「emit primitive は小さな state file しか読まない」既存規約と衝突 / frontier/snapshot 型が未探索 → v3 改訂（frontier snapshot + count cap・層分離）。
  - SO#3（audit_id 20260702074310YMBYRSHM9QD8）: **新カテゴリゼロ**（未実装で ADR defer 済みの rotation を前提とする複合エッジ・既定置項目の再言・訂正 event の additive defer のみ）→ `predecision-exploration` の暫定停止条件を充足と判断し打切り。
- **打切りとゲート**: exploration rubric + conservative 集約の下では残余リスク列挙が尽きず「survived」は構造的に出にくい。「refuted×3 だが round 3 は新カテゴリゼロ」の状態を隠さずそのままユーザー承認ゲートに提示し、打切り判断ごと承認を得た（このペイン・2026-07-02）。
- **確定した設計**（詳細はプラン Context / 探索木は本 episode 執筆時点で tmp に現存・要旨をここへ蒸留）:
  - DJ-206A-1: トリガ = 明示 ack verb `bin/oe-ack`（primitive）。sugar（`oe-send --ack`）/ ハーネスフックは additive defer。
  - DJ-206A-2: 意味論 = frontier snapshot（`covers_last_ts` 主 + `covers_count` の同秒 cap）。viewer 投影 = 方向フィルタ → K = min(covers_count, |ts ≤ covers_last_ts|) の先頭 K 件 received・複数 ack は max K。
  - DJ-206A-3: from=受領者 / to=報告元（actor=from 規則）。covers_* は report_received のみ必須。
  - DJ-206A-4: `--inbox` PENDING 列 / `--timeline` ack 行。overview 不変。
  - DJ-206A-5: `oe-report` の emit 漏れ → ユーザー選択「同 PR」で `oe_send_line` へ載せ替え（S9 発動）。
  - DJ-206A-6: 層分離 — lib 層は引数のみの純 emit・ログ read/covers 計算/echo は verb 層。
  - 受入残余リスク: ack 直前着弾レース（echo で開示）/ 誤 ack 訂正なし（additive で将来）/ rotation 増分への frontier 整合申し送り。
- 併走の学び（プロセス）: kickoff→設計に直行し **plan 変換（`kickoff-to-plan`）を飛ばしてユーザー承認を求めた → 指摘で是正**。また plan frontmatter が spec（#218 で `so` 強/弱が追加された直後）と 3 点ズレて再指摘: gitignore 対象（`.oe/` / `tmp/`）を `related[]` 参照にしない（本文言及が慣行）/ `implements` でなく §6 語彙の `parent_issue` / `so` はテンプレート順で最後。

## 実装フェーズ

（S3 schema → S4 emit → S5 oe-ack → G1 → S6 viewer → S7 tests → G2 → S8 README → S9 oe-report 載せ替え、の順で随時追記する）

- S1/S2: worktree `feature/#206A_report_received` 作成（cwd 非追従は既知仕様 → 以後絶対パス操作）。プランを worktree へ移動し本 episode を開始。
- S3（schema）: type enum に `report_received` 追加 + `covers_count`（minimum 1）/ `covers_last_ts`（date-time）を allOf 条件付き必須で追加。`jq -e` で構文と enum/minimum を確認。ファイル冒頭 description の「増分2 で report_received を追加可能」は実装済みの事実に合わせ in-place 修正（事実ドリフト扱い）。
- S4（emit）: `oe_event_report_received <from> <to> <covers_count> <covers_last_ts>` を追加。引数のみの純 emit（DJ-206A-6）。covers 0/非数値/frontier 空は「schema 違反行を作らない」ため emit せず return 0。role の関係上書き（直接親子リンク優先）は `oe_event_message_sent` と同イディオム。
- S5（oe-ack）: verb 層でログを read-only 走査（壊れ行 skip は viewer と同じ `fromjson? // empty`）。covers = 累計数 + 最終 ts、pending = 累計 − 既存 ack の covers_count 最大値。pending 0 は emit しない。emit 後に「acked N 件（累計 M）/ 最終: ts + preview」を stderr echo（レース開示 affordance）。`--all` は自分宛て送信元を列挙し per-relation に同処理。書き味の注意: Write ツールが jq の `join("")` を literal US に展開したため、oe-activity と同じエスケープ表記へ置換した。
- G1: shellcheck PASS（oe-ack / event-bus.sh）。隔離スモーク（OE_EVENT_DIR ほか 3 dir を mktemp に向ける）で 5 シナリオ確認 — (1) 初回 ack=累計2件・emit 行の形状正 (2) 再 ack no-op・行数不変 (3) 新着後 `--all` で pending 1 件のみ ack（累計3）(4) TMUX_PANE 無し exit 2 (5) 純 emit の引数バリデーション（0/非数値/ts 空 → emit されず rc=0）。**kick（親→子）が covers に数えられていない**（方向フィルタ有効）ことも (1) で確認（メッセージ3件中 report 2件のみカウント）。python jsonschema は環境に無く、schema 適合は jq 構造チェックで代替（S7 のテストでも固定）。
- S6（viewer）: `project()` に received_of（frontier + count cap・複数 ack max）を def として追加、idx を message-local → **イベント全体の global 位置**に一般化（ack 行と同軸で interleave するため。既存 turn/表示順は単調写像なので不変）。inbox に PENDING 列、timeline に ack 行（turn="-"・dir=ack・preview に covers と frontier）。スモークで PENDING 0→新着→1、ack 行 interleave、overview 列構成不変を確認。
- S7→G2 初回 red で**増分1 由来の潜在バグを検出**: `_oe_event_ident` の内部プロトコルが TAB 区切りだが、TAB は bash read の IFS 空白扱いのため**先頭 TAB（=role 空）が剥がれて label が role 位置にシフト**し、schema の role enum に違反する行を焼く。発火条件は「role 空 + label あり」= registry GC 後の departed pane — **#206A の主要ユースケース（子が去った後に親が ack）が直撃**。テスト suite では [10]（oe-delegate 実行）の registry GC が偶然この状態を作り [13] が red になって発見（単体再現では registry が残っていて green だった）。修正 = プロトコル区切りを US (\037) へ変更（oe-activity の列区切りが同じ理由で US を選んだ前例に整合）・emit 側 6 read サイト追随・label の US 畳み込み追加・GC 状態の回帰テスト [16] を追加。`oe_event_message_sent` にも同経路が存在したため同時に治っている（増分1 の既存 fixture/テストは全て green のまま＝表示互換）。
- もう 1 件のテスト red は fixture marker 衝突（`grep "ACK-R1"` が `NOACK-R1` にもマッチ）→ marker 改名で解消（プロダクトコードのバグではない）。
- G2: 3 スイート（event_bus 59 / oe_activity 66 / oe_ack 33）+ 隣接回帰 4 スイート（delegate_send 36 / oe_delegate 20 / oe_ident 11 / delegate_registry 20）を bash 5.2.37 と 3.2.57 の両方で green。shellcheck も全変更ファイル PASS。
- S9（oe-report 載せ替え・承認済み「同 PR」）: 生 `tmux send-keys` 2 連を `oe_send_line` へ差替え（`delegate-send.sh` ヘッダが明記していた設計済み受け皿）。`test_oe_report.sh` 新設（11 checks・両系 green）— emit される message_sent / --review prefix / 改行 fail-fast / 死ペイン非0 / 親未解決 exit 1。
- S8（README）: 本体 README（bin ツリー・委譲 CLI 節に oe-ack / oe-report 追記）+ bin/README.md（oe-ack 新セクション・oe-activity を増分1+2+A へ・出す情報 4→5・受領印の残余リスク開示・oe-report 載せ替え注記・OE_EVENT_DIR 行）。
- ADR 昇格判断: DJ-206A-1（actor 明示 verb）/ DJ-206A-2（frontier snapshot）/ DJ-206A-6（層分離）は増分1 ADR の DJ-206-3 予約を具体化する決定級と判断し `docs/decisions/2026-07-02-decision-206A-report-received-ack.md` へ昇格。探索木（tmp・揮発）の蒸留先もこの ADR の選択肢表 + 本 episode で恒久化。
