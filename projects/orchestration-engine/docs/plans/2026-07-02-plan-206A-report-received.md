---
id: "01KWGX449JKWWX0FCT2E9YF2YF"
title: "#206/A plan — report_received（oe-ack primitive + frontier snapshot・受領可視化）"
date: 2026-07-02
type: plan
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/206"
    reason: "(A) report_received — 子の報告の「受領」可視化。(B) timeline は増分2（PR #214）で済"
  - type: design_context
    ref: ../decisions/2026-06-22-decision-206-activity-log-self-contained-events.md
    reason: "決定境界 DJ-206-1/2/3。本増分は DJ-206-3 が明示予約した additive 追加"
tags: [orchestration, activity-log, report-received, ack, event-bus, cockpit, increment-a]
so:
  design: weak
  impl: weak
  reason: "kickoff-206A の指定どおり。設計SO=oe-refute --rubric exploration（実施済・3周）、実装SO=oe-review。可逆な additive 増分（既存行不変・viewer read-only 維持）のため弱 SO で足りる"
---

# #206/A plan — report_received（oe-ack primitive + frontier snapshot・受領可視化）

> 駆動層: kickoff（.oe/kickoff-206A.md）→ ゼロベース設計（predecision-exploration・済）→ 設計SO（oe-refute exploration・3周・済）→ **本プラン** → ユーザー承認（このペイン）→ 実装 → 実装SO（oe-review）→ PR → episode closure。

## Context / 前提（kickoff 忠実転記 + 設計確定事項）

- 親（統括）から委譲された子セッション。**設計・実装は人間とこのペインで直接**、完了確認のみ親へ。**マージ・worktree 掃除はしない**（人間/親）。
- 増分1（PR #213）で event-bus（`lib/event-bus.sh`）+ 自己完結ログ（`~/.claude/state/oe-events.jsonl`）+ viewer `oe-activity`（overview / `--inbox`）が landed。増分2（PR #214）で `--timeline`（B・時系列）。
- 決定境界（ADR）: DJ-206-1 自己完結イベント（emit 時 snapshot）/ DJ-206-2 lifecycle-end・stall は推論しない / DJ-206-3 vocab は additive（`report_received` / turn は非破壊追加できる＝本タスクは ADR が明示的に予約済みの追加）。
- 本タスク = (A) report_received: 「子の報告が親に届いた／読まれた」を可視化し #206 の (A) を閉じる。現状は `message_sent`（送った）+ `delivery_signal`（suspected_miss|none）まで。
- **viewer（oe-activity）は read-only 維持** → emit は viewer でなく actor 側の明示トリガ。「誰がいつ受領印を付けるか」が設計判断（DJ-206A-1・確定済み・下記）。
- ※増分2（viewer-only）と違い、本タスクは **event-bus + schema を触る＝新しい write path の設計**を含む。ここが慎重どころ。

設計確定事項（探索木 v3・`tmp/dj-206A-tree.md` — kickoff 同様 gitignore 対象の揮発 artifact のため frontmatter 参照にせず、S2 で episode へ蒸留する。ユーザー承認待ち）:

- **DJ-206A-1**: トリガ = 親側アクター（AI/人間）が明示的に打つ ack verb **`bin/oe-ack`**（primitive）。応答連動 sugar（`oe-send --ack`）/ ハーネス受信フック自動 emit は additive defer。
- **DJ-206A-2**: 意味論 = **frontier snapshot**。event に `covers_last_ts`（frontier）+ `covers_count`（同秒 cap）を焼込。viewer 投影は 方向フィルタ（sender=to.pane ∧ recipient=from.pane の message_sent のみ）→ (ts,idx) 順で K = min(covers_count, |ts ≤ covers_last_ts|) の先頭 K 件が received。複数 ack は max K（単調・巻き戻りなし）。covers_count==0 は emit しない（no-op）。
- **DJ-206A-3**: from=受領者（ack した側）/ to=報告元（actor=from の既存規則に整合）。covers_* は report_received のみ必須（既存 allOf イディオム）。既存行不変。
- **DJ-206A-4**: viewer は `--inbox` PENDING 列 + `--timeline` ack 行 interleave。overview はスコープ外。
- **DJ-206A-5**: legacy `oe-report` の emit 漏れ（inbox/ack ループの盲点）はユーザー承認ゲートでスコープ判断（同 PR / 別 PR / #142 defer）。
- **DJ-206A-6**: 層分離 — lib 層 `oe_event_report_received <from> <to> <covers_count> <covers_last_ts>` は引数のみの純 emit（ログ read なし・best-effort・常に return 0）。ログ read + covers 計算 + echo は verb 層 `oe-ack`。
- 受入残余リスク: (1) ack 直前着弾の未読報告が frontier に入るレース → `oe-ack` の stderr echo「acked N 件 / 最終: <ts> <preview>」で開示 (2) 誤 ack の訂正手段なし → 訂正 event は additive で将来可能・影響は表示限定 (3) rotation 増分側へ「ack/frontier 整合の保存」を申し送り。

## スコープ

### IN

- `schemas/oe-events.schema.json`: type enum に `report_received` を additive 追加 + `covers_count` / `covers_last_ts`（DJ-206-3 準拠・既存行不変）。
- `lib/event-bus.sh`: `oe_event_report_received`（self-contained・best-effort・常に return 0）。
- `bin/oe-ack`（新規 verb）: target 解決・covers 計算・no-op 判定・echo・`--all`。
- `bin/oe-activity`: `--inbox` / `--timeline` で「受領済み」を表示（`message_sent` → `report_received` のループを閉じる）。
- テスト（`tests/test_event_bus.sh` / `tests/test_oe_activity.sh` + oe-ack 新規テスト）・README 追記・episode。

### OUT（defer・explicit）

- 応答連動 sugar（`oe-send --ack`）/ ハーネス受信フック自動 emit（案C）/ oe-capture 結線（案B）。
- 誤 ack 訂正（retraction）event / per-message id / provenance `via` フィールド。
- overview への受領表示 / server-pid キー化 / log rotation（ADR defer に同じ。frontier 整合の申し送りのみ）。
- `oe-report` 載せ替え（**条件付き**: ユーザーが「同 PR」を選んだ場合のみ S9 で IN に昇格）。

## 成果物

- 上記 IN の 5 点（schema / lib / oe-ack / viewer / テスト+README）。
- episode（実装記録・リアルタイム追記）+ closure（episode-retrospective）。
- ADR 昇格判断（条件付き: トリガ設計が決定級なら #114/#92 の粒度に倣う・内容次第）。
- 親への完了 1 行報告。

## ステップ（TODO + Gate interleaved）

- [x] **S0. ゼロベース設計 + 設計SO**（進め方 1–2・実施済み）
  - [x] DJ-GATE: DJ-206A 確定前に `predecision-exploration`（ゼロベース代替 ≥1 = 案C ハーネス受信フック等）を実施し、探索木 + SO 出力パス + 採否を確定前 artifact（`tmp/dj-206A-tree.md`）に記録
  - [x] REVIEW: 設計SO — `oe-refute --rubric exploration` を 3 周（v1/v2/v3）。verdict は 3 周とも refuted（conservative 集約）だが SO#3 は新カテゴリゼロ → `predecision-exploration` の暫定停止条件充足で打切り（打切りは人間判断へ委ねる）。audit_id: 20260702072958…/20260702073615…/20260702074310…
- [x] **STOP: このペインでユーザー承認** — (1) 設計 v3（refuted×3 だが round3 新カテゴリゼロ、という判断ごと）(2) 本プラン (3) DJ-206A-5 の oe-report スコープ（同 PR / 別 PR / #142 defer）。**承認済み（2026-07-02・このペイン）: 設計+プラン承認 / oe-report は「同 PR」選択 → S9 発動**。
- [ ] **S1. ブランチ/worktree 作成**: `wt switch --create feature/#206A_report_received`（`branch-naming` / `worktrunk-worktrees` 準拠・issue 起点）。
- [ ] **S2. episode 作成・リアルタイム追記開始**: `docs/episodes/2026-07-02-episode-206A-report-received.md`（spec-card frontmatter）。以後 S3〜PR まで随時追記（後追い再構成にしない）。制約（kickoff「エピソード精度」）: SO/レビュー/ツール挙動の主張は fact 断定前に一次照合（実測）・最弱の妥当表現を採る / テスト数・行番号など事実の記述は成果物に当てて正確に（stale を残さない）/ 訂正は belief・反証の誤り=additive 注釈、事実ドリフト=in-place 修正。tmp/dj-206A-tree.md の探索木 + SO 証跡をここへ蒸留。
- [ ] **S3. schema 追加**: `schemas/oe-events.schema.json` — type enum に `report_received` を additive 追加 + `covers_count`（integer・minimum 1）/ `covers_last_ts`（date-time）を定義し、allOf 条件付き必須（`message_sent` の preview/delivery_signal と同じイディオム）で report_received のみに要求。既存行（child_spawned / message_sent）の検証結果が不変であることを確認。
- [ ] **S4. emit primitive 追加**: `lib/event-bus.sh` に `oe_event_report_received <from_pane> <to_pane> <covers_count> <covers_last_ts>` — 引数のみの純 emit（ログ read なし・DJ-206A-6）。`_oe_event_ident` で from/to の role/label を焼込。self-contained・best-effort・常に return 0（既存 emit 規約維持）。covers_count の非数値/0 は emit せず return 0（ノイズ event 防止）。
- [ ] **S5. `bin/oe-ack` 新規作成**: usage=`oe-ack [--all] [--] <target>`。target は `oe_reg_resolve`（%N 素通し・ラベル union 解決、oe-send と同じ）。`$TMUX_PANE` 必須（inbox と同じ制約）。ログを read-only で読み、sender=target ∧ recipient=self の `message_sent` を (ts,idx) 順に数えて covers_count / covers_last_ts を計算 → 0 件なら「nothing to ack」で no-op（emit しない）→ 1 件以上なら primitive を呼び stderr に「acked N 件 / 最終: <ts> <preview>」を echo（レース開示 affordance）。`--all` は自分宛て pending のある相手すべてへ per-relation に emit。
- [ ] **GATE G1（自己検証）**: `shellcheck` を変更ファイル全部（`bin/oe-ack` / `lib/event-bus.sh` / `bin/oe-activity`）に対し rc=0。`OE_EVENT_DIR=<tmp>` 隔離でダミー jsonl を置き、oe-ack の emit 行が schema 通り + no-op / --all / echo を目視確認。
- [ ] **S6. viewer 投影追加**: `bin/oe-activity` — `--inbox` に PENDING 列（未受領 report 数。厳密規則: 方向フィルタ → K = min(covers_count, |ts ≤ covers_last_ts|) → 先頭 K 件 received・複数 ack は max K・received 分を差引き）/ `--timeline` に `report_received` 行を interleave（dir=ack・covers N 表示・turn は "-"）。overview と既存列は不変。壊れ行 skip 等の既存 degrade 方針を維持。
- [ ] **S7. テスト追加**: `tests/test_event_bus.sh`（emit: 正常 / covers 0・非数値 no-op / jq 不在 degrade / 常に rc=0）+ `tests/test_oe_activity.sh`（PENDING 計算: 未 ack / 部分 ack / 全 ack / ack 後の新着 / 同秒割込み count cap / 複数 ack max / 方向フィルタ=kick を数えない / timeline の ack 行 / 既存 overview・inbox 回帰）+ oe-ack の verb テスト（target 解決・no-op・--all・TMUX_PANE 無し）。
- [ ] **GATE G2（テスト・bash 両系）**: 追加含む関連テストを **bash 5.2.x と bash 3.2.57 の両方**で green（#193 の bash 3.2 footgun — 空配列の `set -u` 展開・`declare -A` — を新コードで踏まない）。
- [ ] **S8. README 追記 + 残余リスク開示**: `projects/orchestration-engine/README.md`（oe-ack verb・受領ループ・inbox PENDING）。開示: 誤 ack 訂正なし（additive で将来）/ echo によるレース開示 / oe-* 外の生 send-keys 報告は観測不能 / rotation 増分への frontier 整合申し送り。
- [ ] **S9. oe-report 載せ替え**（**条件: STOP でユーザーが「同 PR」を選択した場合のみ**）: `bin/oe-report` の生 `tmux send-keys` 2 連を `oe_send_line` へ差替え（`delegate-send.sh` の設計済み受け皿。message_sent + finalize が自動で付く）。別 PR / #142 defer 選択時は本ステップをスキップし S8 の開示に盲点として明記。
- [ ] **REVIEW: 実装SO = `oe-review`**（実装後・PR 前。設計SOとは別レンズ=コード欠陥/到達可能性。reviewed diff にバインド）。**verdict=refuted なら PR を保留**し指摘を処置してから再実行。
- [ ] **ADR: トリガ設計の昇格判断**（条件: 決定級なら。#114/#92 の粒度に倣う・内容次第）: DJ-206A-1/2/6（actor 明示トリガ・frontier snapshot・純 emit 層分離）は増分1 ADR の DJ-206-3 予約を具体化した決定なので、昇格 or 増分1 ADR への追記かを判断し episode に理由を残す。
- [ ] **PR 作成**: `pr-conventions` 準拠・**1 PR = 1 論理変更**・test plan は実行してから PR（実行済み結果を記載）。報告契約は `implementer-contract`（status enum・self-review・スコープ外は surface のみ＝実装しない）。
- [ ] **episode closure**: PR レビュー対応後・**マージ前**に `episode-retrospective`（消費者明示・routing・status 確定・tier 判定・Decision 昇格検討）。リアルタイム追記できなかった部分があれば冒頭 `reconstructed` 明示。
- [ ] **戻し（親への完了確認のみ）**: 完了時に親ペインへ 1 行 — `/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub/projects/orchestration-engine/bin/oe-send "$PARENT_TMUX_PANE" "#206A 完了。status=... / PR #..."`。途中の設計相談・承認依頼は親に送らずこのペインでユーザーと直接。マージ・worktree 掃除はしない。

## 最終検証（ループが閉じたことの確認）

- [ ] `message_sent` → `report_received` のループが `--inbox`（PENDING 0/N）と `--timeline`（ack 行）で見える（kickoff「設計の核」viewer 項の充足）。
- [ ] 既存行・既存ビュー（overview / 既存列・既存テスト）が不変（DJ-206-3 additive の担保）。
- [ ] emit 失敗が本体を壊さない（best-effort・常に return 0）の実測確認。

## スコープ外（Post-Completion・注記のみ）

- `oe-send --ack` sugar / UserPromptSubmit 受信フック / retraction event / overview 受領表示 / server-pid キー化 / rotation — いずれも同一 vocab への additive 増分として follow-up（必要なら issue 化は親/人間の判断）。
