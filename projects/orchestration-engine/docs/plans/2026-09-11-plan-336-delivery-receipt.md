---
id: "01M26AH15W53H65C18TSXCR2XT"
title: "#336 親子の指示・報告の到達を仕組みで守る（設計プラン）"
date: 2026-09-11
type: plan
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/336"
scope: orchestration-engine
related:
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-09-11-episode-336-delivery-receipt.md"
    reason: "本プランの実行記録。実測の一次記録と gate の経緯"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/330"
    reason: "送出成功を到達と読む欠陥の同族。通知の扱いで同じ型を踏まないための参照（本プランでは解かない）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "統括 watchdog（oe-undelivered / oe-vitals）の出所。Layer 2 はこの上に足す"
tags: [oe-send, prompt_received, delivery-receipt, watchdog, event-bus, launchd]
so:
  design: weak
  impl: weak
  reason: "engine 増分で既存 verb（oe-send / oe-undelivered）と hook・event-bus 契約に触る。配布物（~/bin と ~/.claude/hooks）なので全セッションへ即時反映されリスクは低くないが、変更は verb 追加・exit 分岐・launchd 配線に分割でき各段が機械的テストで閉じる。設計は選択肢が複数（exit / 再送 / 通知）ある"
---

# #336 親子の指示・報告の到達を仕組みで守る（実行プラン）

> **plan-first**: 実装は owner HG（ゲート3）の後。本プランは gate 2（設計SO）まで通してから `.oe/report-336-plan.md` にパスを先行し、STOP する。

## 1. 何を解こうとしているか

委譲の親子が `oe-send` で送った指示・報告は、送信が成功しても相手の会話に着信しないことがある（双方向）。送り手はそれを知る手立てがなく、統括は届かないことを検知できずに子の画面を `tmux capture-pane` で読みに行き、見張りの輪を手で組んで pane を消すたび張り直していた。owner の方針「1. 通信経路を手厚く → 2. 交代と復帰」の 1 の最初として、到達を仕組みで守る。

**今回のアークの範囲（gate 0 で統括が確定・理由つき）**:

- **Layer 1（送り手の到達判定）**: 対象。送信後に受領印（`prompt_received`）と突合し「届いた／受け手が確認印を出せない／本当に沈黙」の 3 値を送り手が知れるようにする。
- **Layer 2（親側の常駐見張り）**: 対象。session の外（launchd）に置き、新しい report file・pane 消滅・未到達を通知で知れるようにする。統括が手で組んだ Monitor の輪を engine の verb で置き換える。
- **Layer 3（子の返信経路）**: brief テンプレの 1 行に留める。子の Stop hook による強制は defer。
- **no-tmux-pane の根本原因**（受け手 hook で `TMUX_PANE` が空になる件）は、別 issue の候補として §7 に書く。今回は起票しない。

理由: Layer 1 と Layer 2 で経路を厚くするのが owner 方針の最短。Layer 3 の hook 強制は版依存で検証が重く、Layer 2 の見張りが子の沈黙を拾えば当面代替できる。これは brief の「plan で今回どこまでやるかを決めてよい・理由を書く」の範囲内である。

## 2. 実測（一次情報・鎖のリンク単位で範囲を明示）

測ったのは「送信記録（`message_sent`）」と「受け手の取り込み印（`prompt_received`・nonce と宛先ペイン両方一致）」の対応まで。実行・読解は測っていない。データは `~/.claude/state/oe-events.jsonl`（2628 行）。

| 観測 | 値 | 決め手 |
|---|---|---|
| nonce 付き送信 | 927 件 | `message_sent` の `delivery_receipt.nonce` あり |
| 受領印あり | 717 件 | nonce + 宛先ペイン一致の `prompt_received` |
| 受領印なし | 210 件 | 上記が無い |
| うち no-tmux-pane と時刻一致 | 約 142 件（約 68%） | 受け手 `oe-receipt-diag.jsonl` の `no-tmux-pane` と ±5 秒（秒粒度・相関どまり・nonce 単位ではない） |
| 真の沈黙（残り） | 約 68 件 | 受領印も診断も無い。未計装セッション宛てが多い |
| 到達の速さ | 約 710/717 が 3 秒以内相当 | 多くは負の遅延（emit 順） |
| 遅延の裾 | 156s / 295s / 948s の受領実例 | 忙しい受け手が数分後にターン確定 |
| #336 中核 | %53 宛て 18 件中 2 件不達（09-09T19:41・09-10T06:48） | 計装済み受け手への間欠不達 |

**設計に効く3点**（詳細は episode の「含意」節）:

1. 「N 秒以内に受領印なし＝不達」の素朴な2値判定は、約4件に1件が偽陽性（受け手が印を書けない＋未計装）。検知器が外れると読み手に無視される（#144/#330 の型）。→ 判定は3値。
2. 到達は速いが遅延の裾は数分。固定の短い N は遅れて着信する受け手を誤検知する。→ 短窓と長窓の二段。
3. 親側の常駐は `oe-vitals` が launchd 900 秒で out-of-session に回る前例がある。停止を報告する主体を当人（統括session）に置くなという注入知見から、常駐は session 外に置く。

## 3. 設計判断（DJ・gate 1 と gate 2 を反映し owner 裁定で v3 へ）

> **v3（2026-09-11・owner の HG 裁定）**: 裁定 4 件のうち plan を変えるのは 1 件で、**未確認と見なす窓を 1800 秒から 600 秒程度へ下げ、その状態を終状態にしない**（owner は plan v2 の語で `silent` と呼んだ。v3 で値そのものが「届かなかった」と読めないよう **`unconfirmed` へ改名**した。以降 plan 全体でこの語を使う）（DJ-3 v3・DJ-6 v3・§5）。owner の理由は「30 分経てば自分が気づいて見に行くので機械が 30 分後に言っても意味が無い。欲しいのは『まだやっているのかな、でも見に行くほどではない』の 10 分前後」で、**実測の最大遅延（948 秒）に合わせる必要はない**という判断である。残り 3 件（非同期照会でよい／直 plist で回し #301 は起こさない／no-tmux-pane は統括が別 issue に起票済み）は v2 のままでよい。

gate 1（`oe-refute --rubric exploration --lanes 2`・audit_id `20260910184850F5F72CY3F18S`）で暫定設計は refuted され、方向（受領印との突合で到達を守る）は否定されず「インライン待ち」「診断相関で送信単位 3 値」「wez notify で到達」「これが最善」の 4 点が崩れた。さらに gate 2（設計SO・弱・codex→cursor の 2 レーン・1 本ずつ）が確定を止める欠陥を 7 件出し、両レーンとも「明文化すれば survived」で一致した。本 v2 はその両方を反映した確定案で、各 DJ に棄却案と反証・レビューの要旨を残す。

### DJ-1: 送り手はどこで到達を知るか

- **確定**: `oe-send` は現在の速い exit 契約（0 は配送成功を意味しない）を**変えない**。到達の判定は常駐側の reconciler が行い、read-only の query（新 verb `oe-confirm`・DJ-4）で送り手の次ターンや人がブロックせず verdict を読む。**待つ主体は AI でなく reconciler。**
- 棄却 案A（`oe-send` にインライン待ちを足し 3 値を返す）: gate1 反証。AI は戻り値を消費せず送信して次へ進むのが実態で、`oe-send` は同期ツール境界。10〜15 秒ブロックは並列ツール呼び出し・ツールタイムアウトと衝突。待つ主体の誤配置。
- 棄却 案C の極端形（送り手は何も返さず判断は人と Layer2 のみ）: 速い received の path を捨てるので不採用。ただし「AI をブロックしない」点は採用。

### DJ-2: message_sent を literal 注入の成功直後に emit する（dual-write gap を塞ぐ・v2）

- **確定（v2・gate2 反映）**: `oe_send_line` は `message_sent`（nonce つき・`delivery_signal="none"`）を **`tmux send-keys -l`（literal 注入）が成功した直後・Enter/finalize の前**に emit する。注入自体が失敗（`return 2`）したときは emit しない。現在は注入・Enter・finalize の**後**に emit するため、注入後・記録前に送り手が死ぬと配送済みでも記録が残らず Layer 2 が監視できない（codex 反証 #3）。
- **gate2 が止めた点と対処**: 「注入の前」に emit すると注入失敗でも幽霊レコードが残り、既存 consumer（`oe-ack` frontier・`oe-activity`・`oe-undelivered`）が通常送信として算入する（codex #1・cursor 1(b)）。→ emit を **`send-keys -l` 成功の直後**に限定し、注入失敗では出さない（cursor 案A・codex の attempted/terminal 分離より軽い最小形）。**finalize 内の第 2 emit（`delegate-send.sh:287-299` 付近）は削除**し、イベントログは注入直後の 1 行だけにする（append-only bus で二重計上を避ける・cursor 1(c)）。
- **残る窓の開示**: `send-keys -l` 成功後に Enter が失敗（`return 2`）した場合、message は入力欄に staged された状態で `message_sent` が残る。これは「消えた」ではなく「見える形で止まった」失敗で、Enter 失敗は stderr に出る。reconciler は event log だけからは Enter 失敗を判別できないので、この稀な経路は `unconfirmed` に見えうる点を開示する（実測の主対象＝計装済み受け手への間欠不達には影響しない）。
- 契約影響: `oe-undelivered` / `oe-activity` / `oe-ack` の frontier は `message_sent` の**存在と ts・jsonl 順序**に依存し emit タイミングには依存しない（cursor 1(a)・`oe-undelivered:246-251` で確認）。emit を数秒早めるのは 600 秒窓で無視できる。既存テストで非回帰を示す。
- **`delivery_signal` の表示が変わる（開示・v3 実装時に判明）**: `oe-activity` は DELIVERY 列で `delivery_signal` を**表示**している（`oe-activity:171`・README「DELIVERY … `unknown`|`none`」）。emit を finalize より前へ移すと、記録は常に `none` になり `unknown` は出なくなる。#299 の実測ではこの signal は配送の成否と**逆**を指していた（rc=3 側の 97.6% が到達確認済み）ので、誤解を招く表示が消えるのは改善だが、**挙動の変化なので README と `oe-activity` の注記を直す**。判定に使う consumer は無い（`oe-undelivered` は明示的に不使用）。

### DJ-3: 3 値（+ 鮮度）の出所は受け手診断への nonce 付与（v2）

- **窓（v3）**: 未確認と見なすまでの既定は **600 秒**。実測の遅延受領の裾（max 948 秒）より短いので、遅れて着信する送信が一度 `unconfirmed` に出ることがある。**それを許容し、遷移と文言で担保する**のが owner の裁定である（30 分では人間のポーリングと重なって機械が言う意味が無い）。
- **確定**: 受け手 hook `oe-prompt-receipt.sh` が「印を書けなかった系」のエラー（`no-tmux-pane`・`encode-failed`・`append-failed` 等・nonce が取れている経路）を診断へ残すとき、**nonce（と取れれば pane）を診断行へ載せる**。reconciler は送信単位で次に分ける。
  - **received**: nonce + 宛先ペイン一致の `prompt_received` がある。
  - **cannot-confirm**: 受領印は無いが、その nonce の診断がある（取り込まれたが印を書けなかった）。
  - **instrumentation-unknown（v2 で追加）**: 受領印も診断も無く、宛先ペインの計装状態が鮮度窓内で確認できない（初回 kick 先・hook 失効の疑い）。**`unconfirmed` と断じない。**
  - **unconfirmed（v3: 終状態ではない・plan v2 の `silent` を改名）**: 受領印も診断も無く、宛先ペインが**鮮度窓内で**計装済みと確認でき、送信から 600 秒（既定）を過ぎている。#336 中核（計装済みの統括宛ての間欠不達）はここに落ちる。**後から受領印が来たら `received`（遅延受領）へ遷移する。** 分類は毎回イベントログから再計算するので遷移は自然に起きる。人向けの文言は「届かなかった」ではなく**「10 分経っても受領を確認できていない」**とし、遅延受領の実例（156 / 295 / 948 秒）が誤報として読まれないようにする（owner 裁定 v3）。
- **gate2 が止めた点と対処**: 「一度でも受領印あり＝計装済み」は session epoch / 鮮度が無く誤分類する（pane ID 再利用で旧 session の印が新 session を `unconfirmed` に化かす・hook 失効後も永久に計装済み扱い・新 pane の初回の真の不達が cannot-confirm になる。codex #3・`oe-selfcheck:171` が同じ罠を直近窓で回避済み）。→ 計装判定を**鮮度窓**（直近 N の受領印・既定は送信元の観測窓と揃える）で行い、証拠が無ければ `instrumentation-unknown`。
- **`OE_EVENT_DIR` の配線（codex #4・cursor 2）**: hook は `${OE_EVENT_DIR:-$HOME/.claude/state}`、reconciler は `_oe_state_dir OE_EVENT_DIR` で各々解決する。hook 環境に `OE_EVENT_DIR` が伝播しないと events と diag が分裂し診断 nonce が読めず偽陽性の `unconfirmed` になる。→ **既定運用（未設定＝$HOME/.claude/state で一致）を正とし、custom dir は「hook へ配線する／非対応と明記」のどちらかを実装 SO で確定**（本 plan は既定運用前提を明記）。jq 不在系（`jq-missing`）は nonce 抽出に jq が要るため診断に nonce を載せられない＝この経路は instrumentation-unknown に落ちることを開示。
- 棄却 案A（診断＋時刻 ±5 秒相関で送信単位分類）: gate1 反証。現診断は nonce も宛先も持たず、相関は多対多で「届いた」の一次証拠にならない。
- defer（代替として記録）: transcript オラクル（受領正本を Claude transcript へ移し nonce 全文検索・hook 非依存・#340 で手動オラクルの実例）。pre-ingestion mailbox（pane 束縛を切り離す・#238/#239 で handoff 用に defer 済み）。durable outbox + reconciler（配送要求を transport 前に永続キューへ・worker 状態機械）。いずれも本増分より重いので Stage 外に置き、DJ-2 の record-before-transport は outbox の最小形として先取りする。

### DJ-4: 送信 3 値は新 verb `oe-confirm`・常駐は #301 に揃える（`oe-watch` は使わない・v2）

- **確定（v2・gate2 反映）**:
  - **送信到達の 3 値投影は新 read-only verb `oe-confirm`**（双方向＝child→parent と parent→child・DJ-3 の分類を event log ＋診断 nonce から投影）。`oe-undelivered` は **child→parent の report 未達**という現契約のまま非回帰で残す（`test_oe_undelivered.sh:96` が「kick は数えない」を固定）。
    - **v3 の簡素化（実装時に判明）**: `oe-confirm` は `report_received` の frontier を**必要としない**。`oe-confirm` が見るのは nonce による message_sent ↔ prompt_received ↔ 診断の対応で、`oe-ack` の「読んだ」層（frontier）とは別レイヤだからである。したがって frontier の共有 lib 切り出し（既存 3 verb の refactor）は本アークから外し、follow-up として surface する。4 つ目の copy は作らない（そもそも使わない）。
  - **report 新規と pane 消滅の検知**は read-only の観測として持つ（`oe-confirm` の追加セクションか小さな別検出のどちらにするかは実装 SO で確定・DJ-5）。
  - **常駐スケジューリングと相互鮮度監視は `oe-watch` を新設せず #301 に揃える。** `oe-watch` は #301（parked・plan `:95`/`:286`）が「既存 verb を `--json` で呼び `latest.json` を原子更新・verb 隔離・相互鮮度監視」する汎用ランナーとして予約済みで、#336 の直接検出とは別契約。本増分は**当面 `oe-vitals` 型の直 plist で `oe-confirm` を回し**、runner 統合（#301 の revive で `oe-confirm` も走らせる）は #301 側の判断に委ねる。
- **gate2 が止めた点と対処**: (i) DJ-4 が双方向 `oe-undelivered` を棄却しつつ S1-3 が双方向化する自己矛盾（codex #5・cursor 3）→ `oe-confirm` へ寄せて解消。(ii) `oe-watch` 名が #301 と衝突（codex #5・事実確認済み）→ 名を使わない。(iii) 通知フィルタ未記載（codex #7・cursor 3）→ 下記 DJ-6 で `cannot-confirm`/`instrumentation-unknown` を ping から除外。
- 棄却 案C（session 内 Monitor を長命コマンドで）: gate1 + 注入知見 1 件目。統括セッションが死ぬと見張りも死ぬので、常駐は session 外に置く。

### DJ-5: report 新規は poll ＋ seen-set（fs イベントでなく）

- **確定**: 対象ディレクトリ（統括が読む main の `.oe/`。`--reports <dir>` で渡すか `OE_CONFIRM_REPORT_DIR` で上書きする。**未指定なら report は見ない**）を poll し、`report-*.md` を seen-set（path＋mtime）と差分する。エッジの扱いを決める:
  - 書込途中: mtime が直近 N 秒以内の file は「まだ書いている」とみなし次回へ持ち越す（半端な file を新規報告と読まない）。
  - rename/削除/再作成: seen-set は追記のみ。削除は再通知しない（消えたことは通知対象でない）。
  - seen-set 破損: 壊れた行は skip（`oe-undelivered` と同じ degrade）。
  - worktree 横断: 対象は 1 ディレクトリに限る（既定は統括が読む main の `.oe/`）。横断は今回スコープ外。
  - 競合（report 新規・pane 消滅・未達が同時）: それぞれ独立の FLAG 行として出す（状態機械に畳まない）。
  - **初回起動（gate2・codex #6/cursor 4）**: 初回は既存 `report-*.md` を全件 FLAG せず watermark（起点時刻）を置く（`oe-undelivered --set-start-after` と同型）。
  - **書込途中の頑健化**: 「mtime が N 秒より古い」だけでは open のまま停止した file を完成扱いする。**2 回の poll 間で size ＋ mtime が不変**を完成条件に足す。`latest.json` は同一 dir に temp ＋ rename で原子的に置く（書込途中 crash 対策・#301 A1 と同型）。
  - **並行起動**: seen-set の check-then-append 競合を避けるため単一 launchd 前提（`oe-vitals` 同型）。手動実行と同時起動は lock で直列化。
- 棄却 案B（launchd WatchPaths / fs イベント）: `.oe/` は file 数が多く WatchPaths は coalesce する。poll ＋ seen-set の方が決定論的で既存 idiom に沿う。

### DJ-6: 通知は unconfirmed/pane 消滅/report 新規だけを ping・沈黙検知の出口は #301 に揃える（v2）

- **確定（v2・gate2 反映）**:
  - **通知フィルタ（cursor 3・codex #7 の要）**: stdout には全種を FLAG（観測用の durable signal）。`--notify`（owner ping）は **`unconfirmed` ＋ pane 消滅 ＋ report 新規のみ**。**cannot-confirm と instrumentation-unknown は ping しない**（stdout どまり）。これが 142/210 の偽陽性で読み手を慣れさせる #144/#330 型を防ぐ肝。
  - **文言（v3・owner 裁定）**: `unconfirmed` の人向け表示・通知は「届かなかった」と断定せず**「10 分経っても受領を確認できていない」**と書く。`unconfirmed` は終状態でなく、後から受領印が来れば `received`（遅延受領・遅延秒数つき）に変わる。
  - **経路**: durable signal（stdout ＋ `latest.json`＋ cron.log）が正本。ping は #301 既決の OSC 777（`notify.sh` 型）を優先し raw `wez notify` は fallback。送出成功で恒久抑止しない（seen cache は kind＋対象＋ts のメッセージ単位・`oe-undelivered` P4-4）。
  - **検知器自身の沈黙**: 機構（`latest.json` の最終走査時刻の陳腐化を別主体が読む）＋陽性対照（片方の job を止め、もう片方が stale を報告する）を本増分で持つ。ただし**自動で回る輪（誰がいつ `oe-selfcheck` を実行し結果を読むか）は #301 の parked な出口問題そのもの**であり、本増分では「検査枝が在り fixture で別主体の検知を示す」までを担う。常時自動化は #301 の revive に委ねる（同じ「出口の無い検知」を再生産しないための線引き）。
- 反証根拠: #301 は raw `wez notify` を gate2 不成立で棄却、cron.log が 2953 行まで育って未読だった実測、stale socket 失敗、共通原因故障（plist 未 load・worktree 削除・状態置き場破損）。#301 が park された理由（出口未確定）と本 DJ の沈黙検知は同じ論点。
- 境界: #330（`wez notify` の到達・抑止失効）は本増分で解かない。durable-first と非恒久抑止だけ守る。

## 4. ステップ（コマンド粒度・段階分け・gate を項目間に置く）

実装は owner HG（ゲート3）の後。段階の境界で owner が切れるように、独立に検証可能な単位へ割る。1 PR = 1 論理変更。

### Stage 1 — 送り手側の土台（record-before-transport ＋ 診断 nonce ＋ 3 値 query）

- [ ] S1-1: `lib/delegate-send.sh` の `oe_send_line` で `message_sent` の emit を **`send-keys -l`（literal 注入）成功の直後・Enter/finalize の前**へ移す（DJ-2）。注入失敗（`return 2`）では emit しない。**finalize パス内の第 2 emit（`:287-299` 付近）は削除**し、ログは注入直後の 1 行だけにする。finalize は rc のみ（best-effort・据え置き）。nonce は従来どおり載せる。
  - 検証: `bash projects/orchestration-engine/tests/test_delegate_send.sh` が全緑。(a) 注入成功時に send-keys ログの直後・Enter の前に emit が 1 回だけ出る (b) 注入失敗（mock で send-keys -l を失敗）時に emit が出ない (c) `--no-enter` では emit しない（従来どおり）、の 3 case を足す。
  - 併せて: `delivery_signal` が常に `none` になる挙動変更を `bin/README.md` の DELIVERY 列の説明と `oe-activity` の冒頭注記に反映する（DJ-2 の開示）。
- [ ] S1-2: `canonical/hooks/scripts/oe-prompt-receipt.sh` の `note_env_error` 系に nonce（と取れれば pane）を載せ、`no-tmux-pane` 診断行を `{..., "nonce":"<26桁>", "pane":"<%N|空>"}` に拡張（DJ-3）。stdout は汚さない・exit 0 据え置き。
  - 検証: `bash projects/orchestration-engine/tests/test_prompt_receipt.sh` が全緑。`TMUX_PANE` 空 fixture で診断に nonce が載ることを足す。
- [ ] gate（Stage 1a レビュー）: S1-1/S1-2 の非回帰（既存 test_delegate_send / test_prompt_receipt / test_event_bus）を確認してから次へ。
- [ ] S1-3: 新 read-only verb **`bin/oe-confirm`** を作る（DJ-4）。event log ＋診断 nonce から**双方向**（child→parent・parent→child）で received / received-delayed / cannot-confirm / instrumentation-unknown / unconfirmed / pending の 6 状態を送信単位に投影する。窓は既定 600 秒（v3）。計装判定は鮮度窓（DJ-3）。`oe-undelivered` の child→parent 契約は触らない。**frontier の共有 lib 切り出しは行わない**（v3 の簡素化・`oe-confirm` は frontier を使わない）。
  - 検証: 新規テスト `tests/test_oe_confirm.sh`。fixture で 6 状態それぞれを作り分けて投影を確かめる。特に**陽性対照**（message_sent あり・prompt_received なし・宛先が鮮度窓内で計装済み → `unconfirmed`）と、**遅延受領の遷移**（silent 相当の age でも受領印が在れば received・遅延秒数を出す）。`test_oe_undelivered`/`test_oe_ack`/`test_oe_activity`/`test_oe_vitals` が全緑（非回帰）。
- [ ] gate（Stage 1 実装 SO＝ゲート4・弱・2レーン）: `oe-review`（codex+cursor）＋テスト実行＋ Copilot。

### Stage 2 — 親側の常駐（`oe-confirm` を launchd で回す・`oe-watch` は新設しない）

- [ ] S2-1: report 新規と pane 消滅の検知を read-only で持つ（DJ-4/DJ-5）。実装形（`oe-confirm` の追加セクションか小さな別検出か）は実装 SO で確定。report 新規は対象 1 ディレクトリ（既定＝統括が読む main の `.oe/`・`OE_CONFIRM_REPORT_DIR` で上書き）を poll し `report-*.md` を seen-set と差分。エッジ（下記 DJ-5 v2）を実装。pane 消滅は `tmux list-panes -a` 突合（`oe-undelivered`/`oe-vitals` と同型）。
  - 検証: 新規テスト。stub tmux ＋ 一時 report ディレクトリで pane 消滅・report 新規の FLAG、seen-set 二重抑止、書込途中 file 持ち越し、初回 watermark、破損復旧を確かめる。
- [ ] S2-2: 通知経路（DJ-6）。durable signal（stdout ＋ `latest.json`）を正本にし、**`--notify` は `unconfirmed` ＋ pane 消滅 ＋ report 新規のみ**（cannot-confirm/instrumentation-unknown は stdout どまり）。ping は OSC 777（`notify.sh` 型）優先・`wez notify` は fallback。seen cache はメッセージ単位で恒久にしない。既定 shadow。
  - 検証: stub notifier で (a) cannot-confirm が ping されない (b) silent/pane 消滅/report 新規が ping される (c) 送出成功で恒久抑止しない・durable signal は常に残る、を確かめる。
- [ ] S2-3: 常駐自身の沈黙検知（DJ-6・受け入れ基準）。`latest.json`（最終走査時刻つき）を書き、その陳腐化を `oe-selfcheck` の検査枝として足す。**自動で回す輪は #301 に委ねる**（本増分は検査枝＋陽性対照まで）。
  - 検証: 新 case。`latest.json` が古いとき `oe-selfcheck` が broken/indeterminate を返す。陽性対照＝job を止めて陳腐化が検知される。
- [ ] S2-4: launchd 配線（当面の直 plist）。`com.stlwolf.oe-confirm.plist`（`oe-vitals` plist と同型・StartInterval 300）。**report ディレクトリは `--reports` の引数で渡す**（`OE_CONFIRM_REPORT_DIR` でも可）。env で渡すのは **`OE_EVENT_DIR`**（DJ-3 の分裂回避）と、**`wez` が居る `$HOME/bin` を含む `PATH`**（含めないと job にペイン tty が無いため OSC 経路が使えず fallback の `wez notify` も見つからず、`--notify` が黙って何も送らない）。plist は repo 外の手置きなので配線手順を README と episode に残す（#301 の学び）。cron.log の肥大（#301 は 2953 行）に上限運用を注記。
  - 検証: `plutil -lint` と手動 `launchctl load` で走ることを確認。
- [ ] gate（Stage 2 実装 SO＝ゲート4・弱・2レーン）: `oe-review`（codex+cursor）＋テスト実行＋ Copilot。
- [ ] follow-up（子からは追わない・報告に surface）: (a) #301 の revive で `oe-confirm` を runner に統合し相互鮮度監視で常時自動化するか (b) frontier jq の共有 lib 切り出し（`oe-undelivered`/`oe-ack`/`oe-activity` の 3 copy・本アークでは不要と判明）。

### Layer 3（brief テンプレのみ・今回）

- [ ] S3-1: `doc-flow-guardrail` の brief 固定節に「親からの問いに画面で答えず `oe-send "$PARENT_TMUX_PANE"` で返す／指示が長時間来ないと感じたら自分宛 `message_sent` に対応する `prompt_received` を確かめ無ければ照会する」の 1 行を足す（#336 コメントの運用知見）。Stop hook 強制は defer。
  - 検証: skill テキストの追記のみ。機械テストなし（規約追記）。

### 各 Stage 共通の締め（ゲート5 の手前）

- [ ] episode closure（マージ前・後追いは reconstructed 明示）・昇格判定・negative knowledge の観測書き戻し（注入 3 件）。
- [ ] plan と episode・knowledge を実装の最初の PR に載せる（plan だけの単独 PR にしない）。

## 5. 受け入れ基準と検証の対応（brief より・plan で検証可能な形に固定）

**N の二段定義（v3・owner 裁定）**: 送り手が到達を知る時間は 2 つに分ける。**N_received（速い・数秒級）**＝ record-before-transport（DJ-2）＋既存受領印で `received` が数秒で分かる（実測 約 710/717 が 3 秒以内相当）。**N_unconfirmed（既定 600 秒）**＝「まだ受領を確認できていない」と人に告げるまでの時間。**実測の最大遅延（948 秒）には合わせない** — owner の裁定は「30 分では自分が先に気づくので機械が言う意味が無い。欲しいのは 10 分前後の『まだやっているのかな』」である。600 秒は裾より短いので遅延受領が一度出ることを許容し、**`unconfirmed` を終状態にせず受領印が来たら `received`（遅延受領）へ遷移させる**ことと、文言を「10 分経っても受領を確認できていない」にすることで担保する。launchd poll=300 秒なので pane 消滅・report 新規は最大約 300 秒＋jitter で拾う。

| 受け入れ基準 | 検証方法（実装後・owner HG の後に実行） |
|---|---|
| 送り手が「届いていない」を N 秒以内に知れる | `received` は N_received（数秒）で分かることを fixture で確認。未確認は N_unconfirmed（既定 600 秒）で告げる。**加えて「一度 `unconfirmed` に出た送信が、後から受領印が来たら received（遅延受領）へ遷移する」ことを fixture でテストする**（v3・終状態でないことの担保） |
| 親が「子 pane が消えた」「新しい report file が置かれた」「送ったのに届いていない」を通知で知れる | 3 つそれぞれに fixture（pane gone・新規 report file・未達 message_sent）を置き、FLAG 行が stdout に出ることをテスト。**`--notify` は silent/pane 消滅/report 新規のみ発火し cannot-confirm/instrumentation-unknown は発火しない**ことも確認 |
| 通知の送出成功を到達と読まない（#330 の型） | durable signal（stdout/`latest.json`）が正本・OSC 777 優先で wez は fallback・送出成功で恒久抑止しない、をコード規律とテストで示す |
| 統括が `capture-pane` を手で読みに行かなくてよい | report 新規と pane 消滅を拾うことで手組み Monitor が不要になることを示す |
| 既存の `oe-send` / `oe-ack` / `oe-vitals` / event-bus の契約を壊さない | 既存テスト（test_delegate_send / test_oe_undelivered / test_oe_ack / **test_oe_activity** / **test_oe_vitals** / test_event_bus / test_prompt_receipt）が全緑。特に `oe-undelivered` の child→parent 契約（`test_oe_undelivered.sh:96`）が不変 |
| 検知器の沈黙を別の主体が検知できる（注入知見1件目） | `latest.json` 陳腐化を `oe-selfcheck` の検査枝で拾い、**陽性対照＝job を止めて陳腐化が検知される**ことを示す。常時自動化は #301 に委ねると開示 |
| 送信が成功して到達しない状態を意図的に作って検知を確かめた（陽性対照・issue 受け入れ条件） | fixture で「message_sent あり・prompt_received なし・宛先が鮮度窓内で計装済み」を作り `unconfirmed` 判定と FLAG を確認。**加えて「注入失敗で残った message_sent を `unconfirmed` と混同しない」**陽性対照も置く |

## 6. リスク・未確認事項

- **窓 600 秒は遅延受領の裾（実測 max 948 秒）より短い（v3・意図的）。** 遅れて着信する送信が一度 `unconfirmed` に出る。owner の裁定は「30 分では人間のポーリングと重なって意味が無い・欲しいのは 10 分前後」なので、**裾に合わせないことを選んだ**。誤報として読まれないための担保は 2 つ: (a) `unconfirmed` を終状態にせず受領印が来たら `received`（遅延受領）へ遷移させる (b) 文言を「10 分経っても受領を確認できていない」にする。この選択と根拠は開示する（注入知見 3 件目・測った鎖の範囲を明示）。
- **record-before-transport の残り窓（v3 実装時に位置を変えた・開示）。** 初版は emit を `send-keys -l` 成功の直後（Enter の前）に置き、Enter 失敗時に記録が残る点を「稀な経路として開示すれば足りる」と書いていた。**実装SO がこれを不成立にした** — 記録が残ると `message_sent` の意味が「submit 済み」から「literal を流した」へ静かに変わり、既存 consumer が算入して再送で二重になる。**emit を Enter 成功の直後へ動かして解決した**（契約は変えずに、閉じたかった窓＝finalize の約 3 秒だけを閉じる）。残る窓は「Enter が返ってから追記するまで」で桁が 3 つ小さい。この経緯は negative knowledge に収穫した。
- **診断 nonce 付与は hook 契約（版依存）に乗る。** hook が撃たなくなれば診断も出ない。`oe-selfcheck` が hook 発火を見ているので、そこに乗せて壊れたら気づける形にする。
- **launchd の共通原因故障（#301）** は本増分で完全には塞げない。plist 未 load・worktree 削除・状態置き場破損は残る。`latest.json` 陳腐化を別主体が拾う相互監視で「見張りが黙った」ことは拾えるようにするが、相互監視そのものの停止までは追わない（開示）。
- **#330（wez notify 到達・抑止失効）は本増分で解かない。** durable-first と非恒久抑止だけ守り、到達保証は #330 に残す。
- **未比較のまま defer した代替**（transcript オラクル・mailbox・full outbox+reconciler）は、Stage 2 の運用で `unconfirmed` の偽陽性が問題になったら再探索する。

## 7. no-tmux-pane 根本原因（別 issue 候補・今回起票しない）

受け手 hook `oe-prompt-receipt.sh` は `TMUX_PANE` が空だと受領印を書けず `no-tmux-pane` 診断だけ残す。実測で送信 927 件中の未受領 210 件のうち約 142 件がこれと時刻一致し、見かけの不達の主因になっている。UserPromptSubmit hook の実行環境に `TMUX_PANE` が伝播しない条件（どのセッション起動経路か）を特定して塞ぐのは #336 とは別単位。報告に候補として書く。
