---
id: "01KXB6H0H15JY8QEYTGYRRYC3K"
title: "#238/#239 統括 succession/watchdog の設計根拠 — 代替案の全体像・seat-keystone 却下根拠・設計SO 3段の de-converge 軌跡（proposal 群からの昇格）"
date: 2026-07-12
type: discussion
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/238"
    reason: "統括 succession 第一級化（seat を今の keystone にしなかった探索の記録）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "watchdog（producer/consumer）。多段のため keep-open"
  - type: promotion_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/250"
    reason: "本 doc は #250 の成果。#249 昇格規則の初回実地適用（gitignored 作業層 → committed discussion）"
  - type: decision
    ref: "projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md"
    reason: "確定した lean 上位アーキの正本。本 doc はその手前の探索・却下根拠を担う（決定要旨は重複させない）"
  - type: decision
    ref: "projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md"
    reason: "declared 層（board schema）の決定。段階1 PR-C の正本"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "C1（DJ-188-3 read 時相関 / DJ-188-4 typed event bus）— seat 却下・observed 層を規定した制約"
tags: [orchestration, succession, watchdog, seat, exploration, de-converge, rationale, discussion, read-only]
---

# #238/#239 統括 succession/watchdog の設計根拠 — 探索と却下の記録

## 1. なぜこの doc（昇格の経緯）

統括 succession/watchdog の設計は 2026-07-09 に3本の working doc（gitignored `.oe/`）で探索された — 原案 `proposal-238-239.md`（seat-keystone 寄り）／決定支援 `proposal-238-arch.md`（feasibility 解消後）／段階1 実装計画 `plan-stage1.md`。確定した上位アーキと段階1 の実装は既に committed へ蒸留されている（[§6](#6-非対象既-committed-へのポインタ)）が、**探索の過程・棄却された代替案とその理由・確定に効いた非自明な転回**は gitignored な working 層に滞留していた。本 doc はそれを昇格したもの（#250・#249 昇格規則の初回実地適用）。

- **この doc の立ち位置**: 決定は decision doc、実装は merged code + 各 PR の episode/plan が正本。decision doc は **結論 + 要約された根拠** を載せる（結論のみではない）。本 doc が担うのは **その手前の「探索と却下」の詳細** — decision doc が carry しない代替案の全体像・棄却ロジック・探索の軌跡。根拠の一部（seat defer の理由・feasibility の含意）は decision doc の根拠節と主題が重なるが、本 doc はそれを **却下・探索の側から詳細化**し、確定した結論の正本は decision doc を指す（重複させない意図で、重なる箇所は pointer 化して探索の新規分のみ残す）。
- **verification status 凡例**: `[verified]`（実体を開いて確認）/ `[unverified-summary]`（一次を引くが entailment 未確認・多くは proposal の [verified] を二次で引くもの）/ `[speculation]`（根拠なし）。
- **本 doc 自身の蒸留ゲート（disclosure）**: この蒸留は弱設計SO（`oe-refute --rubric exploration --lanes 3`・audit `20260712130417P0X8CSTCK5D5`）を1周通した。**refuted（claude/cursor が material に「過剰 prune」を指摘・codex はレーン error＝partial）**。指摘に応じて §3.4（作らなかった段階ロードマップ）追補・§4 の round findings に durable substance 追記・§1/§3 の前提修正・重複箇所の pointer 化を反映した。弱SO ゆえ 1周で reconcile し iterate しない。**源泉側の網羅性**（別 worktree の gitignored proposal 3本＝94k に他の durable 落ちが無いか）は反証レーンが source を直読できず、蒸留者の block 単位判断に依存する `[unverified-summary]`。plan-stage1 非再蒸留 scope は owner が committed source と突合し承認済（claude レーンも一次で妥当性を confirm）。**committed 側に残っていた plan-stage1 への「詳細と根拠」ポインタ**は、その後 owner 決定 = (b) 張替（#250）で committed 正本へ張り替え済み（§6.1・掃除後 dead-end 化しない）。

---

## 2. 探索した設計空間（question-driven + zero-base 代替）

設計は各設計判断（DJ）に issue の初期案と zero-base 代替を立てて展開した。骨子のみ（全展開は却下されたので過程として残す）:

- **DJ-1 watchdog の責務**: 案A（liveness 監視のみ・判断せず ping/trigger）／案B（部分的判断委譲＝re-parent 自動決定・successor 自動選定）／案C（zero-base: そもそも agent でない＝決定論 script）。→ **案C 採用**（A を再フレーム）。案B は「中央の賢い決定者」で HG を侵食するため棄却。
- **DJ-2〔keystone〕succession の最小プリミティブ**: 案A/B/C（mailbox / 子 re-parenting / START-HERE 生成の3並列候補）／案D（zero-base:「seat〔席〕」= delegate 層の succession 記録）。→ 当初は案D（seat）を keystone に据えたが、設計SO で却下（[§3](#3-seat-keystone-をなぜ-keystone-にしなかったか)）。
- **DJ-3 run-state doc の形式**: 案A（機械可読 1枚）／案B（統括専用ドキュメント体系＝過剰設計で棄却）／案C（zero-base: declared〔人・小〕+ observed〔event log projection〕の2層）。→ 案C の2層観が最終 lean（declared + observed）へ継承された。
- **DJ-4 watchdog MVP シグナル**: 当初は「in-flight（子 alive + 未 ack 報告）中に seat が窓時間 event を出さない」単一 staleness。→ 設計SO で最も訂正が入った（後述）。

### 代替案の全体像（Alt-α〜ε）と各 disposition

設計SO が breadth 補完として surface した5代替。**decision doc は Alt-β/γ を1〜2行触れるのみ**なので、全体像と却下/defer 根拠をここに残す:

| # | 代替 | 要点 | disposition と理由 |
|---|---|---|---|
| Alt-α | hook/memory 層 succession | 4代 handoff を支えた START HERE / MEMORY を schema 化 + 検知は #233→#24 の決定的 hook。engine 新 state ゼロ | **state 半分は最終 lean に採用**（declared 層）。ただし検知半分（決定的 hook）は棄却 — hook は event 駆動ゆえ「行動を止めた統括」（solo 死・idle）を撃てない [verified] `hooks.md`。検知は statusline producer + out-of-session consumer が担う |
| Alt-β | registry relation type 追加 | seat より軽い「seat-lite for display」。oe-tree が lineage を描く。topology 表示は解くが mailbox/run-state は別 | **却下でなく段階後ろへ defer**。上位 fork（succession-state をどこに置くか）を動かさない display concern。段階2+ の topology スライスの実装候補 |
| Alt-γ | 外部 event 駆動 watchdog | CAO 型・terminal IDLE 監視。cleanup ADR C4 が Phase5 で予告済 | **競合でなく制約に還元**（[§5](#5-確定に効いた非自明な転回)）。in-session 監視は統括と共に死ぬ → 「consumer は out-of-session 必須」という制約として本推奨を補強 |
| Alt-δ | event-bus projection 主体 | seat を薄い pointer に留め、観測は既存 oe-events の projection（DJ-188-4 の typed event bus 方向） | **observed 層の方向として採用**。ただし declared state（人が書く board）は投影では作れない → Alt-α の state 半分と**補完**（競合でない）。段階1 は sidecar で足り、projection 本格化は段階2 defer |
| Alt-ε | mailbox なし inbox + #220 cron のみ | seat すら作らず報告未達 cron + owner ping だけ。mode3 部分対応の最小起点 | **段階0 として実現**（`oe-undelivered`・#241）。succession 本体は据え置き＝最も過剰設計回避 |

> **exhaustion 注記**: Alt-α〜ε は proposal では確定を与えず HG へ「選択肢」として提示された。最終的に lean は **Alt-α（state 半分）⊕ Alt-δ（observed 方向）+ statusline producer** の折衷で、seat（DJ-2 案D）と Alt-β/ε は defer/段階化された。「競合3候補」に見えた seat / Alt-α / Alt-δ が、実は排他でなく declared/observed の2層に分かれるという再フレームが鍵だった。

---

## 3. seat-keystone をなぜ keystone にしなかったか

最強競合は seat（DJ-2 案D）だった。決定は「今の keystone にせず薄い pointer に defer」。decision doc は defer の結論と要約根拠(a)(b)(c)を載せるので、ここでは重複を避け、**却下ロジックの探索側の詳細**（seat 設計骨子・lifecycle 非対称・topology 非解決）を残す。§3.3 の defer 3根拠は decision の(a)(b)(c)に対応する（正本はそちら・ここは探索の帰結として並べる）。

### 3.1 seat の設計骨子と lifecycle 非対称

- seat = delegate 層の succession 記録 `{seat_id, current_pane, lineage[], run_state_path}`（read 時 resolve・DJ-188-3 整合＝engine identity 統一ではなく delegate 層の別契約）[unverified-summary] `proposal-238-239.md §3 DJ-2`。
- 当初 doc は「mailbox / re-parenting / START-HERE の3候補は seat という共有 identity に束ねられる」＝seat 1概念で一括、と論じた。だが3機能の **lifecycle が非対称**である [unverified-summary] `lib/delegate-registry.sh:47-65`（proposal の [verified] 引用）:
  - mailbox = 毎 send の read-time resolve
  - re-parenting = handoff 時の batch mutation（全子 registry 書換）
  - topology 表示 = read-time 表示
- → **1ファイル化は非対称を潰し、MVP が実効カバーするのは mailbox の顔だけ**。keystone の「統合力」を MVP の sufficiency 根拠に流用していた点が設計SO の material 訂正（[§4](#4-設計so-3段の-de-converge-軌跡) round1-2）。

### 3.2 topology 歪みは seat handoff では直らない（load-bearing）

- `oe_reg_record` は spawn 時に子の `parent_pane` を**焼き込むのみで書換機構がない** [unverified-summary] `lib/delegate-registry.sh:47-65`。→ **seat handoff（seat JSON の current_pane/lineage 更新）は子の `parent_pane` を動かさない** → topology 歪みは handoff 後も残る。
- **live evidence（この設計セッション自体の実測）**: `%119 (gone) └─ %144 (alive・現統括4代目) └─ %147 (this)` [verified]（`oe-tree` 実行・2026-07-09）。successor（%144）が gone の親（%119）の子として描かれる — #238 comment1 が予言した歪みの実物。
- 含意: seat を入れても topology 表示は別 lifecycle（Alt-β 表示 or re-parenting 機構）が要る。keystone にしても mode の1つ（topology 歪み）は解けない。

### 3.3 却下でなく defer の判断

seat 固有価値は `@seat` mailbox による mode3（チャネル脆弱）の**予防**にある（段階0 は**検知**のみ）。それでも「今」入れなかった理由:

- **未証明の need**: 散文 board で 4代 handoff は mailbox なしに成立してきた [unverified-summary]（#238/#239 本文・実運用）。予防機構の need が実証されていない。
- **三者同期リスク**: seat を新正本にすると board / seat / registry の三者同期が生じ、mode4（state 乖離）を**悪化**させる。C1/DJ-188-4 は「横断観測は新 state でなく typed append-only event bus」と明示 [verified] `projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md`。
- **carrier 動機の消滅**: feasibility 解消で context% は seat が運ぶ必要がなくなった（[§5](#5-確定に効いた非自明な転回)）。seat keystone を正当化していた動機の1つが消えた。
- → **defer が妥当**。段階0 検知を運用に回し、**報告 stranding が再発したら** seat を導入する。これは「4代成立」実績に賭けた判断であり、stranding 頻度を運用観測して再評価する（decision doc の残リスク）。

### 3.4 作らなかった段階ロードマップ（seat 込みの全体像・lean が切った先）

原案は seat を keystone とした **段階0-3 / PR-1..10** の系列を描いた。lean はこれを段階1 の3 PR（producer / consumer / board schema）に切り詰めた。**切った先の系列自体が durable**（stranding 再発時に seat を再導入する設計材料 + committed 側の宙吊り参照の解決先）なので圧縮して残す:

- **段階0（do-less・最小起点）** = Alt-ε: 報告未達 cron + owner ping のみ（seat すら作らない）。→ `oe-undelivered`（#241）として実現。
- **段階1（succession 最小の顔）**: seat 記録 + mailbox resolve（PR-1 seat schema / PR-2 handoff mutation / PR-3 `@seat` mailbox）。topology/re-parenting は含めず歪みは残す。→ **lean はここを seat 抜きの declared+observed に置換**。
- **段階2（liveness 最小）**: heartbeat producer + 停止検知（+報告未達）。→ lean の statusline producer + consumer が別ルートで実現。
- **段階3（+）**: run-state declared schema（PR-4）/ **PR-9 = `oe-tree` lineage 表示（seat を root・handoff 描き分け・display のみ・Alt-β）** / observed projection（mode4・PR-6）/ **PR-10 = 子の自動 re-parenting（handoff 時の batch mutation・seat とは別 lifecycle の独立 deferred 枝）** / malform proxy (d)（PR-8）/ context auto-trigger。
- **宙吊り参照の解決**: 段階0 episode が「PR-9 候補据え置き」と書いた PR-9 は **上記の `oe-tree` lineage 表示**。この対応が gitignored proposal にしか無かったため、本 doc で committed 側へ解決先を移す。
- **PR-1..10 の依存**: PR-1（seat）が keystone。lean が seat を defer した結果、PR-1/2/3/9/10（seat 系）は段階1 から外れ、topology 歪み（§3.2）と `@seat` 予防は未実現のまま残った。

---

## 4. 設計SO 3段の de-converge 軌跡（早期収束の構造的抑止・実地例）

この設計は `oe-refute --rubric exploration --lanes 3`（弱 SO・1周）を **3段階で当て、3回とも refuted（3/3）** された。各段が「確定」へ寄った synthesis を de-converge した — `exhaustion-before-conclusion-rule` が言う「収束を model 自身の判断に委ねない」の実地サンプル。**round1 と round3 の audit は committed にゼロ、round2 は decision doc に5点要約のみ**なので、軌跡をここに残す。

| round | 対象 | audit_id | verdict | de-converge した論点（要点） |
|---|---|---|---|---|
| 1 | 原案（seat-keystone） | `20260709040107X3MY0SAC3NPE` | refuted 3/3 | (1) staleness 単一検知が mode1(solo)/mode2(ack済 deadlock) を構造的に取りこぼす (2) seat 1ファイル化が lifecycle 非対称を潰し MVP は mailbox の顔のみ (3) context% GC-handoff の実質 defer (4) 未探索責務分界（Alt-α〜ε の棄却証跡不在）(5) run-state declared と engine session-state の境界未整理。→「3点で確定」を撤回し「候補＋論点」へ |
| 2 | 決定支援（feasibility 後） | `20260709133328HQB21ZBMYBW6` | refuted 3/3 | (1) observed=projection と段階1 PR=sidecar の内部矛盾 (2) 段階0 consumer の worktree 未取得 (3) producer liveness 意味論（cancel/debounce）未検証 (4) Alt-β/γ 未評価 (5) seat-defer の安全性未反証 (6) 自前の停止条件未実行のまま確定寄り。→「確定 synthesis」を撤回し lean + open question へ降格・内部矛盾を fork 化 |
| 3 | 段階1 実装計画 | `20260709144654QABV8MQFD4HA` | refuted 3/3 | PR 分割の骨格は3レーンとも否定せず維持。検知意味論（hang vs プロセス死）・統括スコープ・配備経路・A→B 契約・open question の過大断定を修正 |

- **round1 の load-bearing な findings の durable substance**（表索引の裏の設計帰結・後段に効いた分）:
  - **(3) context% GC-handoff の実質 defer**: 原案は context% を「統括の自己申告」に依存させており、劣化した統括は申告しない＝#238 中核（context 閾値 handoff）が実質先送りになる、と反証された。これが後の feasibility 解消（statusline が context% を機械露出）で解け、seat carrier の動機を消した（[§5.1](#51-feasibility-解消が-seat-の統合力を糖衣へ後退させた-divergence-の-reconcile-記録)）— round1 の defer 指摘が reframe の起点。
  - **(5) declared run-state と engine session-state の境界未整理**: run-state を engine の session-state に載せようとしていたが、対話 delegate 子は success/blocked/timeout の完了 lifecycle を持たない＝session-state は category error（DJ-188-2）。→ run-state は **delegate/succession 層の別契約**として設計せよ、と境界を確定。これが最終 lean の「declared 層（board schema）は engine state ゼロ」へ収束した探索根拠 [verified] `projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md`（DJ-188-2/4）。
- **round2 の spot-check（親の独立検証）**: SO の material claim を鵜呑みにせず一次で裏取り — `git merge-base --is-ancestor HEAD master` で worktree が master より前を確認、`statusline.md:139` の cancel 挙動を doc 直読で確認。SO の指摘は正確だった [verified]。
- **round3 の看板修正はさらに supersede された（軌跡の正直さ）**: round3 は「beat-staleness＝プロセス死検知」（生存プロセスは `refreshInterval` の fixed timer で beat を撃ち続けるから）へ修正した。だが後段の **PR-B 設計SO（audit `20260710165558WHKWV6XCJXXA`・refuted 3/3）がこの premise をさらに反証**し、death 判定を「tmux 確定 gone のみ」へ再転回した（`?×stale` を偽 death 扱いする経路と、idle-premise が実機未検証で death の linchpin にできない点を突いた）[verified] `plans/2026-07-11-plan-239-pr-b-vitals-consumer.md` DJ-3 / `episodes/2026-07-11-episode-239-pr-b-vitals-consumer.md`。→ **round3 の findings 詳細は committed（PR-B plan/episode）に上書き済み**。ここでは軌跡のノードとしてのみ記録し、詳細は再蒸留しない（古い前提を復活させない）。
- **軌跡の meta 価値**: 同一設計に対し独立した3ラウンド（+ PR 段の2ラウンド）が successively 早期の「確定」を崩し続けた。model は各段で「探索十分・確定してよい」と申告したがり、SO ゲートがそれを構造的に抑止した。これが「収束は model の call ではない」の生きた例（`exhaustion-before-conclusion-rule` §Application）。

---

## 5. 確定に効いた非自明な転回

### 5.1 feasibility 解消が seat の統合力を「糖衣」へ後退させた（divergence の reconcile 記録）

- 原案（`proposal-238-239.md`）は **seat-keystone 寄り**だった。その根拠の一部は「periodic heartbeat の producer が存在しない」という前提を [speculation] のまま重く見積もり、**その不確実性を seat の統合力で吸収しようとしていた**点にある。
- feasibility 2点が一次情報で解消（statusline の `refreshInterval` が周期発火を、stdin JSON の `context_window.used_percentage` が context% を与える）[verified] `statusline.md` → producer が config 層に落ちた → **「拍動できるか」という上位アーキの争点そのものが消滅**した。
- 結果、seat の統合力（context% carrier を兼ねる等）は「**あると綺麗だが今は要らない糖衣**」に後退した。
- **これは収束でなく divergence**（`reframe-on-stall-rule` の reconcile 原則）: 原案が「producer の実在可能性」を過小評価していた点の訂正であって、両パスが同じ結論に landed したのではない。feasibility が producer を config 層へ落とした瞬間に前提が覆り、seat の位置づけが変わった。この転回点が lean 確定の実質的な hinge。

### 5.2 Alt-γ は「競合候補」でなく「consumer への制約」

- 外部 event 駆動 watchdog（Alt-γ）を正しく検討すると、上位アーキの competitor ではないと分かる。in-session の監視（`/loop` / `CronCreate` は session-scoped）は**統括が死ぬと監視器も一緒に死ぬ**＝検知したい故障モードで検知器が落ちる。
- → Alt-γ が与えるのは「**consumer は out-of-session でなければならない**」という制約であり、これは lean を否定せず補強する。段階0 `oe-undelivered` が既にこの形（外部 cron・read-only）[verified] 段階0 episode。OS cron か GitHub Actions かは別 open question（同一マシン実行が真の軸）。
- （decision doc §de-converge は「Alt-γ は制約として補強」を1文で載せる。ここで残す新規分は **なぜ in-session 監視が死ぬか**の理由づけ〔session-scoped〕であって結論の再掲ではない。）

### 5.3 「beat の停止が何を意味するか」の意味論チェーン

- 単一 staleness（DJ-4 当初案）→ 「hang 検知」と素朴に読める → round3 SO が「生存プロセスは beat を止めない＝**プロセス死検知**であって hang 検知ではない」と訂正 → PR-B SO がさらに「未検証 premise に依存せず **tmux 確定 gone のみ**を death とする」へ再転回。
- 「1つのシグナルが何を意味するか」を確定せず素朴に読むと故障モードの取りこぼしに直結する、という非自明な教訓。低 context の hang（プロセス生存 × context 低 × model 停止）は beat も context% も動かず、段階1 のどのシグナルも拾わない — この未カバー穴の同定自体が意味論を詰めた副産物（decision doc の残穴・PR-B plan §5 に committed）。
- **故障モード × 検知シグナルの coverage（段階1 の honest な下限と defer 理由）**: mode1（context 死）= context% 閾値 + プロセス死検知／mode3（チャネル脆弱）= 報告未達（段階0）が拾う。**mode2（お見合い・idle+staged 未submit）／mode4（state 乖離）／低 context hang は段階1 のどのシグナルも拾わず owner 目視へ defer**（mode2 = pane-capture heuristic の脆さ、mode4 = observed projection 未実装が理由）。この対応表は段階2 トリガ（お見合い heuristic / malform proxy）判断の探索資産 [unverified-summary] `proposal-238-239.md §3 DJ-4`。

---

## 6. 非対象（既 committed へのポインタ）

本 doc は下記と重複させない。確定・実装の正本はこちら:

- **上位アーキの決定**: `projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md`（lean・seat defer・sidecar・feasibility 2点）
- **declared 層の決定**: `projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md`
- **段階1 実装（merged code + 蒸留）**:
  - PR-A statusLine 拍動 producer（[#245](https://github.com/stlwolf/ai-development-hub/pull/245)）→ `episodes/2026-07-10-episode-239-statusline-heartbeat-producer.md`
  - PR-B oe-vitals consumer（[#246](https://github.com/stlwolf/ai-development-hub/pull/246)）→ `plans/2026-07-11-plan-239-pr-b-vitals-consumer.md` / `episodes/2026-07-11-episode-239-pr-b-vitals-consumer.md`（death=tmux確定gone への再転回はここが正本）
  - PR-C board schema validator（[#244](https://github.com/stlwolf/ai-development-hub/pull/244)）→ `episodes/2026-07-10-episode-238-board-schema-validator.md`
  - 段階0 oe-undelivered（[#241](https://github.com/stlwolf/ai-development-hub/issues/241)）→ `episodes/2026-07-09-episode-239-report-undelivered-watchdog.md`
- **昇格規則の文脈**: `projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md`（§6.1 DJ-2 昇格義務 / DJ-10 discard 記録）

### 6.1 残件の解消（設計SO cursor が surface → owner 決定 = (b) 張替・#250 で実施済み）

本 doc は **arch レベルの探索・却下根拠**に絞り、plan-stage1 の実装詳細（Q3-Q8 open question 解消・cross-PR 統合 rationale）は再蒸留しない（owner 承認 scope・実装は merged code + PR 各 doc が正本）。当初この scope 下では committed→plan-stage1 の dead-pointer が残件だったが、**owner 決定 = (b) 張替**で解消済み:

- **元の残件**: lean-arch decision / PR-B plan / board-schema decision / PR-A・PR-C episode が「詳細と根拠」の正本として **gitignored な `plan-stage1.md` / `ref-plan-stage1.md` を指したまま**で、docs/#238 worktree 掃除で恒久 dead-end 化する状態だった。
- **解消（(b) 張替・#250）**: これらのポインタを、参照内容を現に持つ committed doc（本 discussion §4/§6・各 decision の §open questions / §2/§4・PR-B plan・各 PR episode）へ張り替えた。**各張替先に内容が実在することを確認済み（gap なし）** — Q3-Q8 の解消・段階1 実装（PR 分割）・設計 SO 反映はすべて committed に存在する。plan-stage1 のみに残る最深部の rationale は owner 承認 scope 上「追わない」とした「詳細」で、ポインタが約束する substance（解消済みの決定・実装・SO）は committed で満たされる。→ docs/#238 worktree 掃除後も dead-end 化しない。

---

## 7. 関連リンク

- [#238](https://github.com/stlwolf/ai-development-hub/issues/238) / [#239](https://github.com/stlwolf/ai-development-hub/issues/239) / [#250](https://github.com/stlwolf/ai-development-hub/issues/250)
- Claude Code hooks: https://code.claude.com/docs/en/hooks.md / statusline: https://code.claude.com/docs/en/statusline.md
- source（gitignored `.oe/`・昇格元）: `proposal-238-239.md` / `proposal-238-arch.md` / `plan-stage1.md`（worktree `docs/#238_succession_watchdog_design`）
