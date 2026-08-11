---
id: "01KX3P18XYMDHCKHSKE8RCEYTM"
title: "#238/#239 統括 succession/watchdog の上位アーキは lean — declared + observed + statusline 拍動 producer、seat は defer、producer 表現は sidecar file"
date: 2026-07-09
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/238"
    reason: "統括 succession を第一級概念に（declared 層 / seat defer の本体）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "watchdog（producer / consumer）。多段のため keep-open"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "C1: engine identity は read 時相関・永続マップ不採用（DJ-188-3）、横断観測は新 state でなく typed append-only event bus（DJ-188-4）— seat defer と observed 層の制約"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-05-14-decision-cleanup-strategy.md"
    reason: "C4: 長時間セッション安定性要件が明確化したら外部 watchdog を Phase 5 で検討と予告（:75）— 本決定はその Phase 5 watchdog"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-07-02-decision-206A-report-received-ack.md"
    reason: "報告受領印（#220）= 段階0 consumer が消費する frontier の基盤"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-07-09-episode-239-report-undelivered-watchdog.md"
    reason: "段階0 oe-undelivered（#241）= out-of-session consumer substrate の既実装"
tags: [orchestration, succession, watchdog, statusline, heartbeat, phase5, decision, read-only]
---

# #238/#239 統括 succession/watchdog の上位アーキ — lean（declared + observed + statusline producer・seat defer・producer=sidecar）

## コンテキスト

統括（cockpit supervisor）は長寿命で context 肥大により機能停止し、handoff トリガは毎回「owner が異変に気づく」に依存してきた。観測された故障モードは4つ [unverified-summary]（#238/#239 本文・実運用「統括3代→4代」）:

- **mode1 context 肥大死**: malform 連鎖 + context 100% で機能停止。
- **mode2 お見合い（deadlock）**: 子が承認待ち idle × 統括の指示が staged 未 submit ＝双方停止。検知機構なし。
- **mode3 チャネル脆弱**: 子→親報告が親 pane 番号に結合 → 統括死亡で報告が虚空へ。
- **mode4 state 乖離**: 子が自己修正済みの問題に統括が冗長指示。

現状の効いた土台は **外部化 state board（memory START HERE）**で、統括2度死でも handoff は4代成立してきた。owner が反復して明示したのは **過剰設計注意** — gap は「**構造と鮮度**」であって succession 機構の存在ではない。engine には succession/lineage/seat/mailbox/reparent/watchdog/context 自己申告 の機構が無い [verified]（`grep -rn` 空・本設計時点）。cleanup ADR は「長時間セッション安定性要件が明確化したら外部 watchdog を Phase 5 で検討」と既に予告していた [verified] `decisions/2026-05-14-decision-cleanup-strategy.md:75`。#239 はその Phase 5 watchdog。

上位アーキの候補は3つ競合していた: **seat record（keystone）** / **Alt-α（hook・memory 層の schema 化）** / **Alt-δ（event-bus projection 主体）**。争点の1つは「periodic 拍動と context% を機械化できるか」で、当初提案では [speculation] のまま重く見積もられ、その不確実性を seat の統合力で吸収しようとしていた。

本決定の直前に **feasibility 2点を一次情報で解消**した（詳細は §根拠）。

## 決定

統括 succession/watchdog の上位アーキを **lean** に確定する（HG 決定）:

- **declared 層** = START HERE board に frontmatter + 必須 section の schema を与え、鮮度・構造を強制する（advisory validator）。＝ Alt-α の state 半分。**新 engine state ゼロ**。
- **observed 層** = watchdog は新正本（seat/registry 書換）を作らず read 時に観測する。
- **producer** = **statusLine スクリプトの side-effect**（`refreshInterval` タイマで idle 中も周期発火）が拍動 + context% を露出。config 層で完結し、seat/Alt-α/Alt-δ のどれとも直交する。
- **consumer** = **out-of-session cron**（統括と一緒に死なない・同一マシン実行）。段階0 `oe-undelivered` と同型。
- **producer 表現 = (i) sidecar file** = 拍動を `{ts, context_pct, pane}` の1ファイルへ刻む（O(1)・log 肥大なし）。（(ii) oe-events への beat イベント append は却下・§根拠）。
- **seat は薄い pointer に defer**。handoff をまたぐ `@seat` mailbox（stranding 予防）は本物の価値だが、未証明の need + 三者同期リスクゆえ「今の keystone」にしない。段階0 検知を運用に回し **報告 stranding が再発したら**導入する。
- **段階1 の実装 = 3 PR**: PR-A statusline 拍動 producer / PR-B 閾値・staleness consumer（read-only 姉妹 verb） / PR-C board schema。詳細計画は plan（下記 §結果のポインタ）。

## 根拠

### feasibility 2点の解消（重い build を正当化していた唯一の未知が消えた）

決め手は Claude Code の **statusline**（hook ではない）。私自身が公式 doc を直読して再確認 [verified] `https://code.claude.com/docs/en/statusline.md`:

- **periodic 拍動を機械発火できるか → YES**: hook は全て event 駆動で時間駆動 hook は無い [verified] `https://code.claude.com/docs/en/hooks.md` → 停止した統括は hook を撃てない。一方 statusLine の **`refreshInterval`（最小 1・event 駆動更新に加え idle 中も wall-clock timer で再実行）** が周期発火を与える [verified] statusline.md:67,141。→ 「劣化・アイドルな統括でも自己申告なしに周期発火する producer」が config 層で実現可能。
- **context% を外部から読めるか → YES**: statusLine の stdin JSON に `context_window.used_percentage`（0–100・pre-calculated）が入る [verified] statusline.md:173。hook payload には無い。→ #238 中核「context 閾値 handoff」を **自己申告依存から機械化**できる。

**含意**: 重い seat build を正当化していた主要動機の1つ（context% を運ぶ carrier）が不要になった。beat + context% は seat が運ぶ必要なく config 層の安い producer で片付く。

**正直な残余**（silently drop しない・[verified] statusline.md:139）: 拍動は **best-effort**（in-flight cancel + 300ms debounce）＝個々の beat は落ちうる → staleness 窓は粗く取る。さらに **fixed timer はプロセス層で event 非依存**ゆえ、hang/malform でも **プロセス生存中は beat を撃ち続ける** → beat-staleness は「hang 検知」でなく「**プロセス死検知**」である（段階1 plan の設計 SO でこの意味論を確定・低 context hang は未カバー）。

### lean を選び seat-keystone を却下した理由

- **C1 / DJ-188-4 に最も忠実**: 横断観測は「新 state でなく typed append-only event bus」と ADR が明示 [verified] `decisions/2026-06-19-decision-188-identity-unification.md`（DJ-188-4）。**seat を新正本にすると board/seat/registry の三者同期が生じ mode4（state 乖離）を悪化**させる。declared（人が書く board）+ observed（watchdog）の2層は排他でなく補完で、seat はその上の identity 糖衣にすぎない。
- **過剰設計注意（owner 反復）**: 4代 handoff は散文 board で成立済み。gap は「構造と鮮度」。board schema 化（declared）が **新エンティティなしに過不足なく**埋める。
- **seat の固有価値は「予防」だが今は要らない**: `@seat` mailbox は handoff をまたいで解決し mode3 を**予防**する（段階0 は**検知**のみ）。ただし (a) 4代 handoff は mailbox 無しで成立＝未証明の need、(b) 新正本は三者同期リスク、(c) context% carrier の動機が statusline で消えた。→ defer が妥当。
- **段階0 と地続き**: consumer（外部 cron・read-only）は `oe-undelivered`（#241）で既実装 [verified] 段階0 episode。producer（statusline）+ declared schema を足すだけで #238 中核に届き、seat 系の系列 PR を先行させるより回収が早い。

### producer 表現に (i) sidecar file を採る理由（(ii) event append を却下）

- **(i) sidecar**: beat を `{ts, context_pct, pane}` の1ファイルへ刻み、consumer は mtime/中身を読む。**O(1)・log 肥大なし**。小さいながら別 state 面を1つ増やすが、段階1 が要るのは liveness/閾値だけで **(i) で足りる**。
- **(ii) oe-events への beat イベント append**: DJ-188-4/C2 に最も忠実で mode4 の projection に自然だが、**1–5s cadence で append-only log が肥大**する。mode4（state 乖離）まで観測を伸ばす段階2 で再考する。
- 当初 arch 提案は「observed=projection」と断定しつつ段階1 PR で sidecar を specする**内部矛盾**を抱えていた（設計 SO cursor が material 指摘）→ **fork を明示し (i) を HG 確定**して解消。

### de-converge の経緯（探索の網羅性）

上位アーキの当初 synthesis は「確定」だったが、設計 SO（`oe-refute` exploration・3レーン）が **refuted（3/3）** [verified] `.oe/oe-refute-result.json`（audit `20260709133328HQB21ZBMYBW6`）。(1) observed=projection と段階1 PR=sidecar の内部矛盾、(2) 段階0 consumer の worktree 未取得、(3) statusline 拍動の liveness 意味論未検証、(4) Alt-β/γ 未評価、(5) seat-defer の安全性未反証 を材料に「確定は早すぎる」と反証 → 推奨を **lean + open question** に降格し、HG が lean + sidecar を確定した。Alt-γ（外部 event 駆動 watchdog）は「競合候補」でなく「**consumer は out-of-session（同一マシン）に置け**」という制約として本決定を補強する。

## 結果

### この決定で変わること

- #238 の中核「**context 閾値 handoff の自己申告脱却**」が段階1 で機械化される（statusline producer + 閾値 consumer）。
- declared 層（board schema）で **構造・鮮度が強制**され、handoff の唯一の正本が散文から構造化 doc になる。
- 新 engine state を作らない（C1/DJ-188-4 尊重）。seat 系の系列 PR を段階1 に持ち込まない。

### 注意点・残る穴（段階1 でカバーしない）

- **defer の安全性リスク**: seat defer 下では報告は pane アドレスのまま＝stranding は「検知」されるが「予防」されない。段階0 検知が interim safety の全て。stranding が高頻度なら不足しうる → **運用観測で stranding 頻度を測り再評価**。
- **mode2 お見合い / mode4 state 乖離 / 低 context hang**: 段階1 では取りこぼす（owner 目視）。低 context hang（プロセス生存 × context 低 × model 停止）は beat も context% も動かない。
- **topology 歪み**: seat handoff は子の `parent_pane` を動かさない [verified] `lib/delegate-registry.sh:47-65`ゆえ段階1 でも残る（表示修正 Alt-β・機構修正 re-parenting は段階1 外）。
- **producer の運用前提**: 統括 session が所定 statusLine を持つ前提。設定漏れ＝beat 無し → **sync 自動配備（非破壊 merge）**で規律依存を排除する（plan Q4）。

### 段階2 以降（本決定の外・再トリガー条件つき）

- `@seat` mailbox（stranding 再発時） / observed projection = (ii) event append（mode4 が実害化した時） / topology 表示（Alt-β・handoff 後の歪みが運用を妨げた時） / お見合い pane-capture heuristic（段階2） / malform proxy detector（#233/#93 と束ねる時）。いずれも段階1 の運用観測後に HG が判断。

### open questions（HG が最終判断・plan に推奨あり）

- consumer の置き場（同一マシン実行必須・OS cron 推奨） / context% 閾値（単一 env ノブ既定 ~85%） / producer 配備（sync 自動・非破壊 merge） / mode2 の扱い（段階1 は owner 目視） / MVP 停止段階（段階1 で止め運用観測） / board schema 置き場（schema は in-repo・board 実体は external 維持・単一 supervisor）。詳細と根拠は段階1 plan。

### ポインタ

- 段階1 実装（PR 分割 + open question 解消 + 設計 SO 反映）の committed 正本群（#250 で昇格元の working plan `.oe/plan-stage1.md` を (b) 張替。掃除後 dead-end 化しない）: Q3-Q8 の解消は本 decision の §open questions / §注意点、consumer 側の実装レベル設計判断（Q3 OS cron・Q7 閾値）と実装 SO は `projects/orchestration-engine/docs/plans/2026-07-11-plan-239-pr-b-vitals-consumer.md`、board schema（PR-C・Q8）は `projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md`、各 PR の実装記録は `projects/orchestration-engine/docs/episodes/2026-07-10-episode-239-statusline-heartbeat-producer.md`（PR-A）/ `projects/orchestration-engine/docs/episodes/2026-07-11-episode-239-pr-b-vitals-consumer.md`（PR-B）/ `projects/orchestration-engine/docs/episodes/2026-07-10-episode-238-board-schema-validator.md`（PR-C）、設計 SO 3段の軌跡・代替案・却下根拠は `projects/orchestration-engine/docs/discussions/2026-07-12-discussion-238-239-succession-watchdog-design-rationale.md`（§4・§6）。
- 段階0（`oe-undelivered`・報告未達検知・#241 済）: `/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub.docs-#238_succession_watchdog_design/projects/orchestration-engine/docs/episodes/2026-07-09-episode-239-report-undelivered-watchdog.md`

## 段階2 の pane-capture heuristic に課す制約 — 1枚の画面から状態を決めない（#239 の判定から追記・2026-08-11）

**本節は §結果「段階2 以降」が先送りした「お見合い pane-capture heuristic（段階2）」に、実装前の制約を課す追記であり、段階1 の決定を変えない。** 出典は `projects/orchestration-engine/docs/episodes/2026-08-10-episode-239-child-liveness-recipe.md`（以下「#239 episode」）で、該当の判定は同 `:19-21`、根拠の本文は同 `:178-186` である。**verification status のタグは下の凡例と同じ意味で使う**（本節のタグは 2026-08-11 に追記者が一次を開いて付けたもの）。

### なぜ段階2 でこの制約が要るのか

段階1 の拍動は **hang 検知ではなくプロセス死検知**である（§根拠の「正直な残余」）[verified]。**低 context hang（プロセス生存 × context 低 × model 停止）は beat も context% も動かず**、mode2 お見合いも段階1 では取りこぼす（§結果「注意点・残る穴」）[verified]。つまり段階2 は、機械が読める既存の信号が尽きたところから始まる。**そこで最初に手が伸びるのが画面であり、最初に踏むのが「1枚の画面から状態を読む」形である。**

### 決定

**禁じるのは1枚のスナップショットから状態を決めることであって、画面そのものではない。** 時間差で2回撮って差分を取る形は決定論的であり、稼働の判定に使ってよい。

### 根拠 — このリポジトリ自身が時間差の差分を使っている

`projects/orchestration-engine/bin/oe-selfcheck` の陽性対照がまさにその形である [verified]（本節の追記時に実体を読んだ）。

- 全ペインを capture して1枚目を保存する（同 `:120` と `:126`）。
- `OE_SELFCHECK_ACTIVITY_INTERVAL`（既定 1.2 秒）だけ待つ（同 `:132`）。
- 2枚目を撮り（同 `:134`）、`cmp -s` で1枚目と違ったペインを稼働と数える（同 `:138`）。

**したがって「画面を状態判定に使わない」という広い禁止を採ると、この実装を名指ししないまま無効化する。** 棄却したのはその広い禁止（「画面が使えるのは着弾の確認まで」）であり、棄却の根拠が自リポジトリの実装だった（#239 episode `:180-182`）[verified]。禁止の中身は変わっておらず、範囲だけが正確になっている。

### 当時の前提（将来偽になりうるもの）

1. **待機中を示す表示は、止まった後も画面に残る** [verified] `projects/orchestration-engine/docs/knowledge/items/01KZKWJM1KTAFN22XK0WP0F96J.md:25`。だから1枚では稼働を言えない。
2. **差分が在ることは稼働の十分条件ではない。** 描画だけが動いている場合を分離していない。**`%cpu` が実は画面の再描画コストの代理かもしれない**という疑いは未解決で #239 へ回してある [unverified-summary]（#239 episode `:175` と同 `:292`）。この疑いが立つと、段階2 は「画面を退けて立てた一次の信号が、間接的に同じものを測り直していた」ことになる。
3. **2枚差分の間隔は実装の値であって普遍の閾値ではない**（既定 1.2 秒は `oe-selfcheck` の値・上記 `:132`）[verified]。段階2 の consumer が別の間隔を採るなら、その値の根拠は自分で持つ必要がある。**閾値とサンプル数は #239 episode でも決めていない**（同 `:285`）[verified]。

### 覆すコスト

**覆すには「1枚から状態を決めてよい」という価値判断を戦わせる必要がある。** 差分方式が誤判定する事例が出ても、それは**差分方式の限界**であって1枚方式を復活させる根拠にはならない — 1枚は2枚差分の情報の部分集合なので、1枚で言えることは2枚でも言える。段階1 が「新 state を作らず observed 層は read 時に観測する」と決めた線（§決定）と同じ層の判断である。

### 段階2 の実装が同時に守る線

pane-capture で**承認**を読まないこと。承認の成立条件（受け取った経路だけを根拠にする）は `projects/orchestration-engine/docs/decisions/2026-07-17-decision-spawn-permission-handshake.md` の同日追記節が持つ。**本節（稼働判定の許容範囲）とあちら（承認の受領）は別の判断なので、片方を緩めてももう片方は緩まない。**

### 併設している実装アーティファクト（昇格先ではない）

- 手順: `canonical/skills/delegate-task/SKILL.md` の「委譲子の状態を親が判定する（1枚の画面から読まない）」節
- 再発する失敗の型: `projects/orchestration-engine/docs/knowledge/items/01KZKWJM1KTAFN22XK0WP0F96J.md`

**併設したことは昇格判定を代替しない**（`canonical/skills/episode-retrospective/SKILL.md:152`）。

## verification status 凡例

`[verified]`（私が実体を開いて確認）/ `[unverified-summary]`（一次を引くが entailment 未確認）/ `[speculation]`（根拠なし）。本 doc の feasibility 2点（statusline `refreshInterval` / `context_window.used_percentage`）と best-effort 残余（cancel/debounce・fixed timer のプロセス層性）は本決定時に公式 doc を直読して [verified]。故障モード4種は #238/#239 本文由来で [unverified-summary]。
