---
id: "01M2674K3AX1A8FP27ZR7FZN64"
title: "#336 親子の指示・報告の到達を仕組みで守る（plan-first・設計ゲートまで）"
date: 2026-09-11
type: episode
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/336"
scope: orchestration-engine
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-09-11-plan-336-delivery-receipt.md"
    reason: "本 episode が記録する作業の plan（本 episode と同じ枝で作る）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/330"
    reason: "送出成功を到達と読む欠陥の同族。通知の扱いで同じ型を踏まないための参照"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "統括 watchdog（oe-undelivered / oe-vitals）の出所。親側の見張りはこの上に足す"
tags: [oe-send, prompt_received, delivery-receipt, watchdog, event-bus, hooks]
---

# #336 親子の指示・報告の到達を仕組みで守る — 作業記録

## なぜこの作業が始まったか

委譲の親子が `oe-send` で送った指示・報告は、送信が成功しても相手の会話に着信しないことがある（双方向・#336 の 3 例目と 4 例目で受け手側の受領印 `prompt_received` の不在として確定）。統括は届かないことを機械で知る手段を持たず、子の画面を `tmux capture-pane` で読みに行き、見張りの輪を手で組んで pane を消すたび張り直していた。owner は cockpit の改善順序を「1. 通信経路を手厚く → 2. 交代と復帰」と定め、本作業はその 1 の最初として、到達の判定・親側の見張り・子の返信経路の 3 層を仕組みにする plan を作る（plan-first・実装は owner HG の後）。

## 注入された negative knowledge（brief の slot）

- `01KZVHE0KJ12W3NG6A4R0WSWS4` 停止を報告する主体を当人に置くな
- `01KZKWJM1KTAFN22XK0WP0F96J` 画面 1 枚・CPU 累積・入力欄表示で子の状態を判定するな
- `01KZVHE0KFDPXMY6EED80RN9ZR` 到達性は測った範囲を鎖のリンク単位で書け

観測の書き戻し（Step 6）は closure で行う。

## 着手時の実測（2026-09-11・plan の前提）

`~/.claude/state/oe-events.jsonl`（2628 行）を nonce で突合した。測った鎖のリンクは「送信記録（`message_sent`）」と「受け手の取り込み印（`prompt_received`・nonce と宛先ペインの両方一致）」の対応で、実行や読解までは測っていない。

- nonce 付き送信は 927 件。対応する受領印があるのは 717 件、無いのは 210 件。宛先ペインの不一致は 0 件。
- 受領印が付いた 717 件の到達は速い。約 710 件が送信から約 3 秒以内に相当する（多くは負の遅延＝受領印が `message_sent` より先に書かれる emit 順のため）。ただし 156 秒・295 秒・948 秒で受領した実例が数件ある。忙しい受け手が数分後に注入行をターンとして確定した経路で、#336 が言う「忙しいと落ちる」と同じ状況で落ちずに遅れて着信した側である。
- 受領印の無い 210 件のうち 142 件（約 68%）は、受け手側の診断 `oe-receipt-diag.jsonl` の `no-tmux-pane`（タグ付きプロンプトを受け取ったがペインに束縛できず受領印を書けなかった）と時刻が ±5 秒で一致する。突合は秒粒度の時刻一致で nonce 単位ではない（診断は nonce を残さない）ので、対応は相関どまりである。この 142 件は「ターンとして取り込まれた＝会話へは届いた」が受領印だけ書けなかった側で、真の不達ではない。
- 残る約 68 件は受領印も診断も無い。宛先には受領印を一度も出していないペイン（未計装セッションの疑い）が多く含まれる。現統括 `%53` 宛て（18 件中 16 件受領）の 2 件の不達（09-09T19:41 の #336 4 例目・09-10T06:48）は計装済みの受け手への間欠不達で、これが #336 の中核現象にあたる。

含意（plan の設計に効く）:

- 送り手側で「N 秒以内に受領印が無い＝不達」と素朴に 2 値判定すると、上の 142 件（受け手が受領印を書けない）と未計装セッションのぶんで、およそ 4 件に 1 件が偽陽性になる。検知器が 4 回に 1 回外れると読み手に無視される（注入 negative knowledge 1 件目の懸念・#144/#330 の型）。判定は「届いた／受け手が確認印を出せない／本当に沈黙」の 3 値にし、2 値にしない。
- 到達は速いが遅延の裾は数分に達する。固定の短い N は遅れて着信する受け手を誤検知し、長い N は目的を損なう。送信直後に N 秒ブロックして 2 値で断ずる形は裾に弱い。窓つきの突合（`oe-undelivered` 型）か、短い確認と 3 値の据え置きの組み合わせが筋になる。
- 親側の常駐は前例がある。`oe-vitals` が launchd で 900 秒ごとに out-of-session で回り、統括自身の context% と pane 消滅を見ている。`oe-undelivered`（子→親の不達）は verb として在るが launchd 未配線で、新しい report file の検知は持たない。停止を報告する主体を停止しうる当人（統括セッション）に置くなという注入知見 1 件目から、常駐は out-of-session（launchd）側に置くのが整合する。

## gate 0 の判断（2026-09-11・統括が確定）

範囲を統括に確認して確定した。今回のアークの対象は次のとおり。

- **Layer 1（送り手の到達判定）**: 対象。送信後に受領印と突合し「届いた／受け手が確認印を出せない／本当に沈黙」の 3 値を送り手が知れるようにする。
- **Layer 2（親側の常駐見張り）**: 対象。session の外（launchd）に置き、新しい report file・pane 消滅・未到達を通知で知れるようにする。
- **Layer 3（子の返信経路）**: brief テンプレの 1 行に留める。子の Stop hook による強制は defer。
- **no-tmux-pane の根本原因**（受け手 hook で `TMUX_PANE` が空になる件）は、別 issue の候補として報告に書く。今回は起票しない。

理由: owner の方針「1. 通信経路を手厚く → 2. 交代と復帰」の 1 の最初として、送り手の判定（Layer 1）と親の常駐（Layer 2）で経路を厚くするのが最短。Layer 3 の hook 強制は版依存で検証が重く、Layer 2 の見張りが子の沈黙を拾えば当面代替できるので defer。これは brief の「plan で今回どこまでやるかを決めてよい・理由を書く」の範囲内である。

昇格の印: no-tmux-pane が受け手 hook の環境で起きる根本原因は #336 と別単位の issue 候補

### 撤回の記録（対話ツールの誤用）

gate 0 の scope すり合わせで、最初に対話の選択肢ツール（AskUserQuestion）で統括へ問おうとした。統括に止められた。子ペインには対話に答える人がいないので必ず止まる。判断が要る問いは question file に書いて `oe-send` でパスを送る非同期経路に乗せるのが正しい。以後この形に統一する（記憶 `feedback_child_no_interactive_questions` に収めた）。

## gate 1 — ゼロベース代替探索（2026-09-11・oe-refute exploration・2レーン）

claim doc（暫定設計を `最善` と主張）を `oe-refute --rubric exploration --lanes 2` にかけた。verdict は refuted（codex/cursor とも material に反証）。exploration ルーブリックでは「初期案の外に未比較の代替が残る／一次情報で地に足がついていない」を refute とするので、これは狙いどおり探索を広げた結果である。反証レーンの生出力は `tmp/oe-refute-20260910184850F5F72CY3F18S`（永続しない・audit_id 20260910184850F5F72CY3F18S）。verdict/reason は plan §3 の各 DJ の棄却理由へ転記した。

### 捨てた前提と、突き合わせて分かった divergence

初期案で置いていた前提のうち、反証で崩れたもの:

- 「送り手（AI）は送信直後に数秒待てる」→ 崩れた。AI は戻り値を消費せず次へ進むのが実態で、oe-send は同期ツール境界。10〜15 秒ブロックは並列ツール呼び出し・ツールタイムアウトと衝突する。待つ主体を AI に置くのは誤配置。
- 「no-tmux-pane と時刻一致した 142 件は届いた、と送信単位で読める」→ 崩れた。診断行に nonce も宛先も session ID も無いので、±5 秒相関は多対多。「近傍でペインに束縛できないタグ付き prompt が hook まで来た」ことまでしか言えない。cannot-confirm を送信単位で返すにはデータモデル拡張（診断に nonce）が要る。
- 「launchd + durable log + wez notify で owner 到達を守れる」→ 崩れた。#301 で raw wez notify は棄却済み（OSC 777 経路が既決）。cron.log は 2953 行・385KB まで育って誰も読まなかった実績があり、durable log は保存であって「知らせた証拠」ではない。検知器自身の沈黙を別主体が拾う相互監視が要る。
- 「tmux 直送を固定し、配送後の観測だけで信頼化できる」→ 揺らいだ。codex が dual-write gap（注入後・`message_sent` 追記前に送り手が死ぬと配送済みでも記録が残らない）を挙げ、記録を transport の前へ置く outbox カテゴリを提示した。

### 反証が出した初期案外の代替（plan に記録し採否を書く）

- durable outbox + reconciler（codex）: 配送要求を先に永続キューへ原子的に登録し、session 外 worker が lease・注入・受領印照合・期限切れ・再試行を状態機械（queued → injecting → confirmed | unverifiable | expired）で担う。待つ主体は AI でなく reconciler。
- transcript オラクル（cursor）: 受領の正本を hook の prompt_received から Claude transcript へ移し、nonce 全文検索で到達を判定（hook 非依存）。#340 で手動オラクルとして既に使った実例あり。
- pre-ingestion mailbox（cursor）: 注入直後にペイン非依存の mailbox ファイルへ nonce 付きメッセージを置き、受け手が消費時に prompt_received を書く。pane 束縛失敗を切り離す。
- 観測のみダッシュボード（cursor）: Layer1 で 3 値を返さず、送信＝記録、判断は Layer2 と人のみ。

### 収束と再構成（reconcile）

反証は方向（受領印との突合で到達を守る）自体は否定していない。否定したのは「インライン待ち」と「診断相関で送信単位 3 値」と「wez notify で到達」と「これが最善」の 4 点である。これを反映し、送り手側の確認は AI をブロックせず reconciler ベースにし、cannot-confirm は診断に nonce を足して初めて根拠づける形へ組み直した。この divergence（初期案がインライン待ちを選んでいた）は反証が拾った探索漏れであり、plan の DJ-1/DJ-2/DJ-6 に反映した。段階分けで最小増分に収める。

## gate 2 — 設計 SO（弱・2 レーン・1 本ずつ・2026-09-11）

plan v1 を対象に、codex（`tmp/so-20260911-035942`・リトライ後 298 秒成功）→ cursor（`tmp/so-20260911-040954`・composer-2.5・133 秒成功）の順で 1 本ずつ回した。両レーンとも実返却あり（弱 SO の "0 はなし" を満たす）。両レーンとも「確定を止める」と判定したが、cursor は「明文化すれば survived に移せる」と述べ、方向（受領印との突合で守る・段階分け・DJ-2(a) frontier 非依存）は両者とも承認した。確定を止めた欠陥は次で、いずれも plan v2 で明文化して解消した。

- **DJ-2(b)**: `message_sent` を注入前に emit すると、注入失敗（rc=2）でも記録が残り既存 consumer（oe-ack frontier / oe-activity / oe-undelivered）に通常送信として算入される。→ v2: `send-keys -l` 成功の直後・Enter/finalize の前に emit し、注入失敗時は emit しない。finalize 内の第 2 emit は削除（cursor 案A・codex の attempted/terminal 分離より軽い最小形）。
- **DJ-3**: 「一度でも受領印あり＝計装済み」は session epoch / 鮮度が無く誤分類（pane ID 再利用・hook 失効・新 pane の初回 silent）。→ v2: 鮮度窓で判定し、証拠が無ければ `instrumentation-unknown`（silent と断じない）。`OE_EVENT_DIR` を plist と hook に配線（食い違うと診断 nonce が読めず偽陽性 silent）。
- **DJ-4 自己矛盾**: DJ-4 は `oe-undelivered` 双方向化を棄却しつつ S1-3 は双方向化していた。→ v2: 新 verb `oe-confirm`（双方向 3 値）に寄せ、`oe-undelivered` の child→parent 契約は非回帰維持。
- **DJ-4 名前衝突**: `oe-watch` は #301（parked）が汎用ランナー（既存 verb を --json で呼び latest.json 原子更新・相互鮮度監視）として予約済み（#301 plan `:95`/`:286`・事実確認済み）。→ v2: `oe-watch` を使わない。常駐スケジューリングと沈黙検知の出口は #301 の parked な論点に揃える（当面は oe-vitals 型の直 plist）。
- **DJ-4 通知フィルタ**: `cannot-confirm` を FLAG/notify から除外する規則が未記載で、3 値の目的（142/210 偽陽性回避）と矛盾。→ v2: `--notify` は silent ＋ pane 消滅 ＋ report 新規のみ。cannot-confirm と instrumentation-unknown は stdout どまり。
- **DJ-6 沈黙検知**: `oe-selfcheck` に検査を足すだけで「誰がいつ実行し誰が読むか」が未配線＝#301 が park された「出口の無い検知」と同じ穴。→ v2: 機構（latest.json 陳腐化を別主体が読む）＋陽性対照は本増分で持つが、自動で回る輪は #301 の出口論点に依存すると開示。受け入れ基準は「検査枝が在り fixture で別主体の検知を示す」と読み下す。
- **§5 取りこぼし**: N が DJ-3 に無い／N 二段が未反映／注入失敗の陽性対照が無い／非回帰に oe-activity・oe-vitals が無い。→ v2 で全て反映。

弱 SO は 1 周で足りる（iteration 任意）。両レーンが「明文化で survived」と事前に一致しているので、v2 への反映で gate 2 を通過とし、SO の再走はしない（必要なら owner HG 後に再レビュー可）。反証レーンの生出力パスは committed から消えるので、上の verdict と修正対応をここへ転記した（注入知見 3 件目・測った範囲を明示）。

昇格の印: #301（parked）の「出口の無い検知」問題と #336 Layer 2 の常駐・沈黙検知は同じ論点で、統合の設計判断は decision 級になりうる

## 判断の why・棄却した選択肢・撤回の経緯

（起きたその場で節を立てて追記する）
