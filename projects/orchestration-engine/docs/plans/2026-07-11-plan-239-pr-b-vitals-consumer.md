---
id: "01KX6F1C8E4FTRRSWCSGFRTG8T"
title: "#239 段階1 PR-B plan — oe-vitals（統括 vital 監視 consumer・閾値/staleness）"
date: 2026-07-11
type: plan
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "watchdog（producer=PR-A・consumer=PR-B）。多段のため keep-open"
  - type: kickoff
    ref: ".oe/kickoff-pr-b-consumer.md"
    reason: "本 plan の入力（委譲 kickoff・machine-local）。verb 名と board 突合の機構を実装子に委ねる指定"
  - type: design_context
    ref: "projects/orchestration-engine/bin/oe-undelivered"
    reason: "段階0 の read-only 観測 family。本 verb が template として踏襲する substrate"
  - type: design_context
    ref: "canonical/claude/statusline/statusline-oe-heartbeat.sh"
    reason: "PR-A producer。本 consumer が read する sidecar 契約（パス + JSON 形）の正本"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md"
    reason: "PR-C board schema。統括スコープ化の board 突合が依拠する declared 層契約"
tags: [orchestration, watchdog, heartbeat, consumer, context-threshold, liveness, cockpit, "issue-239"]
so:
  design: weak
  impl: weak
  reason: "上位アーキ（lean + sidecar・seat defer）は HG 確定・不可逆性が低い。本 plan が確定するのは実装レベルの設計判断（verb 名・board 突合の機構・検知述語・env 設計）で、いずれも read-only 追加＝可逆。設計SO=oe-refute --rubric exploration（本 plan の DJ を対象・1周）、実装SO=oe-review（reviewed diff）。両方を弱 SO で当てる（engine 作業は設計SO+実装SO 両方が規律）"
---

# #239 段階1 PR-B plan — oe-vitals（統括 vital 監視 consumer）

> 駆動層: kickoff（`.oe/kickoff-pr-b-consumer.md`）→ 実装 → **本プラン（設計判断の外部化）** → 設計SO（oe-refute exploration・本ペイン）→ reconcile → 実装SO（oe-review）→ PR → episode closure → 親 %158 へ報告。
> 注: 実装は plan 化に先行して着地済み（下記スコープ）。owner の追加指示「設計も SO 必要」を受け、実装子が新規に下した設計判断を本 plan に外部化し、設計SO で zero-base 反証を受けてから PR にする。設計SO で material 反証が出れば着地済みコードを rework する。

## Context / 前提

- 親 `%158` から委譲された子セッション。**マージ・worktree 掃除はしない**（親/owner の HG）。実装子は worktree 作成 → 実装 → テスト → SO → PR 作成 → 報告まで。
- PR-B = statusLine 拍動 producer（PR-A・master マージ済 `7f741e6`）が session 毎に書く sidecar を **out-of-session cron から読み**、統括の **context% 肥大接近（mode1・#238 中核）** と **プロセス死** を検知して owner に ping する read-only 姉妹 verb。段階0 `oe-undelivered` の観測 family（`liveness_of` / `disp` / `fmt_age` / seen cache dedup / owner ping / exit 0 / `--window`+env+`NOW_EPOCH`）を template として踏襲する（再実装しない）。
- **入力面が段階0 と別**: `oe-undelivered` は oe-events.jsonl の frontier（未ack）を読むが、PR-B は **sidecar dir** を読む。→ frontier read の jq は再コピーしない。
- 上位アーキ（lean + sidecar・seat defer）と Q3-Q8 推奨は HG 確定済（上位アーキ = `projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md`、Q3-Q8 推奨の要約は同 decision の §open questions。#250 で昇格元 working plan `.oe/plan-stage1.md` を (b) 張替）。本 plan の射程は **その下の実装レベル設計判断のみ**。

## sidecar 契約（PR-A が正本・本 consumer が read）

- パス: `${OE_HEARTBEAT_DIR:-${HOME}/.claude/state/oe-heartbeat}/<session_id>.json`
- 内容: `{"ts":<epoch秒>, "context_pct":<0-100>, "pane":"<tmux pane|空>"}`。`pane` は producer 実行 env の `${TMUX_PANE:-}`（伝播しなければ空）。

## 設計判断（DJ・設計SO の反証対象）

### DJ-1 verb 名 = `oe-vitals`

消費側 = 統括の **vital（生体徴候）監視**。拍動鮮度（生きているか）+ context% 負荷（健全か）の 2 vital を読んで owner に警告する。

- **検討した代替（zero-base）**:
  - `oe-heartbeat`: producer（`statusline-oe-heartbeat.sh`）と "heartbeat" namespace が衝突。さらに verb 固有 seen cache dir が `${OE_EVENT_DIR}/oe-heartbeat/` = **producer の sidecar dir `~/.claude/state/oe-heartbeat/` と同一パスで衝突**する（consumer の bookkeeping が producer の data dir に混入）。方向も曖昧（producer が heartbeat を出すのか consumer が出すのか）。
  - `oe-liveness`: #239 タイトル liveness と直結するが、設計が明示的に否定する「hang/liveness 誤検知（alive×stale→hang）」を名前が招く。かつ **中核である context% 検知を過小表現**する（liveness は 2 検知器の弱い方）。
  - `oe-vitals`: 両検知器（拍動鮮度 + context% 負荷）を包摂し、producer と namespace 衝突せず、消費側の意味づけ（読んで判定して ping）に合う。
- **決定**: `oe-vitals`。seen cache は `${OE_EVENT_DIR}/oe-vitals/`（producer の `oe-heartbeat/` と別 namespace）。

### DJ-2 統括スコープ化 = board 突合（MVP・kickoff 推奨）

sidecar dir には statusLine を持つ全 session の beat が入る（統括に限らない）。consumer は統括 session だけを対象化する必要がある。

- **決定**: board（declared 層・PR-C）の `現統括` pane と sidecar の `pane` を突合し、一致する sidecar だけを判定する。board path は `OE_BOARD_FILE` で与える。
- **現統括 pane の抽出**: `現統括` marker 以降の **最初の `%NNN`**。PR-C frontmatter 形（`現統括: "%144"`）と **現行 freeform 行**（`現統括: pane `%158``・前任 pane が後方に併記されうる）の両対応。実 board は PR-C schema 未 migrate（現統括 は freeform 行）ゆえ両対応が必要。
- **検討した代替**: (b) sidecar に `role:"supervisor"` marker を載せる → producer（PR-A）改変が要る＝触ってはいけないファイル。(c) delegate-registry の role 突合 → 新規結合が増え board 突合より重い。→ (a) board 突合が最小で PR-C と地続き。

### DJ-3 2 検知器の述語（真理値表の実装・**設計SO の反証で改訂**）

- **context 検知**（mode1 context 肥大死・#238 中核・確度が高い）: `fresh ∧ ¬gone ∧ context_pct > T` → ping（handoff 促し）。
- **death 検知**（プロセス死・crash / pane 消滅）: **`plive == gone`（tmux 確定 gone）のみ**・beat 鮮度に依存しない → ping（1回・dedup）。
  - **改訂の経緯（設計SO 反証）**: 当初は `stale ∧ ¬alive`（beat-staleness＝プロセス死検知）だったが、3レーンが (a) tmux 不在/socket 不通の `?` を `¬alive` として death 扱いし cron で **偽 crash ping** を出す、(b)「idle でも beat 継続」premise が実機未検証で death の linchpin にできない、と反証。→ death を **確定 gone のみ**に絞った。これで `?` は死にならず、idle-premise は death の前提から外れ、`gone×fresh` も即検知（旧設計の最大 W 遅延を解消）。代償: tmux 不在時は death 検知不可（context のみ degrade）＝偽陽性より安全側。
- **`alive/? × stale` は no-op**: 生存プロセスは `refreshInterval` の fixed timer で beat を撃ち続ける前提（beat が止まるのはプロセス死 / pane 消滅の時だけ）。「alive×stale→hang」は実装しない（未検証 premise + 偽陽性回避）。
- 真理値表（改訂後）:

  | pane      | beat 鮮度  | context% | 解釈                         | 動作                          |
  |-----------|-----------|----------|------------------------------|-------------------------------|
  | alive / ? | fresh     | `> T`    | context 肥大接近（#238 中核）| ping（handoff 促し）           |
  | alive / ? | fresh     | `≤ T`    | 健全                         | なし                          |
  | alive / ? | stale     | —        | 生存/不明×拍動停止（idle 等）| なし（死に化かさない・開示穴）  |
  | gone      | fresh/stale| —       | プロセス終了（crash 疑い）    | ping（1回・board 突合で判別）   |
  | 不在      | —         | —        | producer 未設定 — 死ではない | なし（未設定を検知に化かさない）|

### DJ-4 gone×stale の crash/handoff 判別 = board 突合そのものが解く

orderly handoff 後は board の `現統括` が後任 pane へ進むため、停止した前任の sidecar は現統括と一致せず **scope 外**になる（＝想定内の handoff は ping しない）。board がまだ死んだ pane を `現統括` と declare したままその pane が gone×stale なら **crash 疑い** → ping（declared が observed の ground truth を補完）。succession 状態は death FLAG の human 向け注記に best-effort で併記するが、**logic は succession で分岐しない**（過剰設計を避け、判別は board 突合 + seen cache に委ねる）。

### DJ-5 `OE_BOARD_FILE` は既定なし・欠落は no-op

board は machine-local（gitignored `.oe/`・commit しない）ゆえ普遍的な既定 path を持たない。`OE_BOARD_FILE` 未設定 / 未解決 / 現統括 pane の sidecar 不在 → **no-op**（honest に stdout へ理由を出す）。**「未設定」を「死」に化かさない**（producer 未配備・pane 未伝播を検知に化けさせない）。deployment（cron エントリ）で `OE_BOARD_FILE` を設定する前提。

### DJ-6 GC しない・env ノブ

- **GC 非実装**: 停止 session の sidecar 掃除（削除）は producer data の mutation ゆえ行わない（read-only 観測姿勢を貫く。kickoff は GC 任意・最小で可 → 最小＝やらない）。mutation は verb 固有 seen cache への追記のみ（`oe-undelivered` と同クラス）。
- **env / フラグ**: `--window` + `OE_VITALS_WINDOW_SEC`（既定 1800s・W ≫ beat 間隔 N）/ `--threshold` + `OE_VITALS_CONTEXT_THRESHOLD`（既定 85・単一閾値・二段 warn/critical は入れない）/ `OE_VITALS_NOW_EPOCH`（テスト決定化）/ `OE_HEARTBEAT_DIR`（producer と共有・sidecar dir）/ `OE_BOARD_FILE` / `OE_EVENT_DIR`（seen cache 置き場）。default はインライン宣言・`constants.sh` には足さない。

## 開放している運用前提（disclose・silently drop しない）

- board 突合は sidecar の `pane` が埋まっている前提（producer の `$TMUX_PANE` 伝播依存）。伝播しないと現統括 pane と突合できず scope 不能で no-op に落ちる。
- 実 board は PR-C schema 未 migrate（現統括 は freeform 行）。extraction は両対応だが heuristic（marker 後の最初の `%NNN`）。
- `wez notify` の cron（no TTY / mux socket）到達性は段階0 から未検証 → **stdout が durable signal**。
- ping 経路・stdout・seen cache dedup・exit 0 は `oe-undelivered` と同一クラス（blast radius 低）。主リスクは誤 ping（W/T チューニング + seen cache で抑止）。

## 設計SO ゲート結果（`oe-refute --rubric exploration --lanes 3`・1周・弱SO）

- **verdict: refuted（3/3・conservative 集約）** / audit_id `20260710165558WHKWV6XCJXXA` / lanes 3（codex/claude/cursor 全 success＝full 3レーン返却・partial なし）。出力（揮発）: `tmp/oe-refute-20260710165558WHKWV6XCJXXA/`。
- 1周・iterate せず。material 反証を code + 本 plan に reconcile（de-converge）。上位アーキ（lean+sidecar）は HG 確定ゆえ SO 対象外。
- **material 反証と対応**:

  | # | 反証（レーン） | 妥当性 | 対応 |
  |---|---|---|---|
  | M1 | `?×stale → 偽 death`（`stale∧¬alive` が tmux 不在の `?` を death 扱い・cron で偽 crash ping）(codex/claude/cursor) | 正しい・実バグ | **code fix**: death を `plive==gone` のみに。回帰テスト [20] |
  | M2 | PR-A（session_id 主キー）vs PR-B（pane 突合）契約差: pane 空だと scope 不能で watchdog inert 化 (cursor/codex/claude) | 正しい・構造依存 | **disclose 強化 + code**: 全 sidecar pane 空を warn（[23]）。再設計は follow-up（Alt-A/C）|
  | M3 | `gone×fresh×high` が no-op → 最大 W 遅延 + 汎用 death ラベル (claude/cursor) | 正しい | **code fix**: death=gone は gone×fresh も即検知（[21]）。ctx% は FLAG 行に表示 |
  | M4 | `alive×stale×high` 取りこぼし（best-effort beat 落ちを認めつつ alive=fresh 前提）(cursor/claude) | 妥当 | **accept + disclose**: 未検証 idle-premise ゆえ action しない（偽陽性回避）＝開示穴 |
  | M6 | board 抽出 `grep '現統括'` が見出し `## in-flight（現統括 %OLD の担当）` の **stale pane** を誤 match しうる (cursor・実 board で verified) | 正しい・実バグ | **code fix**: `grep '現統括:'`（colon 宣言のみ）。succession も同様。回帰テスト [22] |
  | M5 | context の one-shot dedup は高 ctx 継続でも再 ping しない (cursor) | 妥当 | **disclose + follow-up**（再 ping/escalation）。MVP は 1回（spam 回避・stdout durable）|
  | M7 | pane 再利用で別 session の beat が最新 ts 勝ちで統括を上書きしうる (cursor) | 妥当・既知同種 | **disclose**（Alt-A で解消可）|
  | M8 | board 更新 lag 中の gone×declared → 一時的 偽 crash ping (cursor) | 妥当 | **disclose**（seen cache 1回で緩和・succession 分岐は入れない判断を維持）|
  | M9 | verb 名 `oe-vitals` は family（状態/対象の名詞）に対し抽象 metaphor (cursor) | 妥当・非致命 | **disclose**（namespace 分離の利得が上回る・PR で提案）|
  | M10 | inert watchdog（設定漏れ/未解決/pane 未伝播）で owner ping 無し・stdout のみ (codex/claude) | 妥当 | **disclose + follow-up**（config-health ping）。kickoff の no-op 方針を尊重し本 PR は stdout 明示に留める |

- **spot-check（独立検証）**: load-bearing な M1/M6 を回帰テストで機械検証（[20] `?×stale`→no death・[22] 見出し除外→%NEW 解決）。73/73 green（bash 5.2/3.2.57・shellcheck clean）。
- **de-converge**: board 突合 MVP の骨格は3レーンとも方向を否定せず維持。偽陽性経路（M1/M6=実バグ）を修正し、構造依存（M2/M7/M8）と運用穴（M4/M5/M10）を開示、再設計案を follow-up に surface。

## 探索した代替（設計SO が surface・follow-up へ defer）

- **Alt-A: board が `session_id`（ULID）を declare → consumer は `<sid>.json` を直 read**（pane 非依存で M2/M7 を解消）。defer 理由: board schema（PR-C・マージ済）変更 + handoff 手順更新が要る＝PR-B scope 外。**最有力の後継**。
- **Alt-C: `oe-events.jsonl` 相関で統括 session を動的解決（board 不要）**。defer 理由: 統括が parent として event 痕跡を持つ前提 + 相関 jq＝重い（別 PR）。
- **Alt: config-health owner ping**（inert watchdog を dedup 付きで 1回 ping）。defer 理由: kickoff の「未設定は no-op」方針。owner が inert 可視化を望むなら additive に足す。

## 実装SO ゲート結果（`oe-review --lanes 3`・reviewed diff・弱SO・別レンズ）

- **verdict: refuted（2/3）** / audit_id `20260711025400M3MK3ZMARMG3` / reviewed_sha `b7f266a` / diff_base master / lanes 3（codex・claude refuted / cursor survived）。出力（揮発）: `tmp/oe-review-20260711025400M3MK3ZMARMG3/`。設計SO と別 audit stream（lens=impl）。
- **material 反証と対応**（いずれも実バグ・fix + 回帰テスト）:

  | # | 反証（レーン） | 対応 |
  |---|---|---|
  | I1 | `resolve_supervisor_pane` 末尾 pipeline が `現統括:` 宣言あり・`%NNN` 無しのとき grep rc1 → pipefail→`SUP="$(...)"`→set -e で script exit 1（exit 0 契約違反・graceful no-op 到達不能）(claude/codex) | 末尾に `\|\| true`。pane 未解決は空返し＝統括未解決 no-op へ。回帰テスト [24] |
  | I2 | `OE_EVENT_DIR="${OE_EVENT_DIR:-${HOME}/.claude/state}"` の裸 `${HOME}` が set -u 下で HOME 未設定時 unbound → 落ちる (codex) | `${HOME:-}` に（producer と同方針）。回帰テスト [25] |

- cursor は survived（真理値表・seen 規律・board 抽出・bash 堅牢性を反証的に確認）。
- fix 後 **77/77 green**（bash 5.2.37 / 3.2.57・shellcheck clean）。**設計SO + 実装SO の両ゲートを通過**（両方 refuted → material 反証を reconcile・弱SO ゆえ各1周）。

## スコープ / 触るファイル

- 新規: `projects/orchestration-engine/bin/oe-vitals`（**着地済み**・read-only observer）。
- 新規: `projects/orchestration-engine/tests/test_oe_vitals.sh`（**着地済み**・19 ケース / 62 assertion）。
- 追記: `projects/orchestration-engine/bin/README.md`（oe-vitals 節 + observation family 索引 + env 表）。
- 新規（本 plan）: `docs/plans/2026-07-11-plan-239-pr-b-vitals-consumer.md`。
- 触らない: `bin/oe-undelivered` / `lib/event-bus.sh` / `oe-activity` / `lib/constants.sh` / `sync-claude.sh` / producer（PR-A）/ validator（PR-C）。

## ステップ（TODO + Gate interleaved）

1. [済] 実装 `bin/oe-vitals` + `tests/test_oe_vitals.sh`。shellcheck clean・bash 5.2.37 / 3.2.57 両系 62/62 green。
2. [済] 本 plan doc に設計判断（DJ-1..6）を外部化。
3. **REVIEW（設計SO）**: `oe-refute --rubric exploration --lanes 3`（claim = DJ-1..6 + 開放前提・self-contained）。material 反証を code + 本 plan へ reconcile。→ status を draft から更新。
4. **REVIEW（実装SO）**: `oe-review --lanes 3`（reviewed diff）。material 反証を reconcile + 回帰テスト追加。
5. `bin/README.md` へ oe-vitals doc 追記（cron 配線は deployment 手順として記載・`OE_BOARD_FILE` 要求を明記）。
6. **GATE**: SO 修正後に shellcheck + bash 両系 green を再確認。
7. episode closure（`docs/episodes/`・standard〜heavy・非自明な接続のみ・後追いなら `reconstructed` 明示）。
8. commit（`feat(oe): ...`）+ PR（verb 名提案 + DJ trace + cron/board 運用前提の disclose・Refs #239・close しない）。
9. **REVIEW（Copilot）**: 依頼 → 未返信スレッドの妥当な指摘に1ラウンド対応 → 返信で停止。
10. 報告: `.oe/report-pr-b.md`（implementer-contract 形式）を正本に、親 `%158` へ `oe-send`（single-quote）で要約 + path 送信。

## 最終検証

- 設計SO / 実装SO の verdict + material 反証の reconcile 内容を確認（弱SO・1周・partial は開示・0 はなし）。
- shellcheck clean + bash 5.2.37 / 3.2.57 両系で `test_oe_vitals.sh` 全 PASS を再確認。
- `oe-vitals` を fixture で直接実行し、真理値表4分岐 + scope化（非統括 sidecar 無視）+ dedup + degrade（tmux/wez/jq 不在）の振る舞いを観測。

## スコープ外（Post-Completion・注記のみ）

- board の PR-C schema への migrate（board 保守側の運用・PR-C 決定 doc §7）。
- cron / launchd エントリの実設置（deployment 手順・doc 記載に留める）。
- sidecar GC（残骸量が実運用で問題化したら follow-up）。
- 低 context の hang（プロセス生存 × context 低 × model 停止）は beat も context% も動かず取りこぼす（段階1 は owner 目視・親 plan §5 の既知の穴）。
