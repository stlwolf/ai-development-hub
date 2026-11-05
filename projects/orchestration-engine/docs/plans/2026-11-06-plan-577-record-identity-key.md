---
id: "01M6PD1RJJS6YXNRKB9ZYNV5X8"
title: "#577 engine の記録のキーを tmux のペインから切り離し、こちらで作る ID にする"
date: 2026-11-06
type: plan
status: draft   # 設計まで（P3 で停止）。持ち場の識別子の名前の答えと、分身レビュー（#404）と、ゲート3 の承認を待つ
so:
  design: weak
  impl: weak   # 仮。実装SO のモードとレーンは、ゲート3 のあとに統括が送る実装の追補の書面で決める
  reason: "engine の土台の記録を変え、全リポジトリに配る hook と verb に効く。設計SO は Codex と Cursor の2レーン（brief の指定）"
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577"
    reason: "本 plan の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577#issuecomment-6664844569"
    reason: "着手時の認識合わせの確定版（深掘りなし）。やることと、達成を見る数の候補3つはここから来た"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-11-06-discussion-577-record-identity-key.md"
    reason: "棚卸しの表・設計の判断 DJ-1〜DJ-17・ゲート1 の探索木"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "この plan が実装する decision の案（proposed）"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-06-episode-577-record-identity-key.md"
    reason: "この plan の作業の記録"
tags: [orchestration, registry, identity, supervisor, delegation, plan]
---

# #577 engine の記録のキーを tmux のペインから切り離し、こちらで作る ID にする

## 背景

owner と統括が #355（統括の復帰）の見取り図を読む中で、統括の復帰がいつも手作業になるのは、engine の記録が tmux のペインの番号（と tmux server の pid）を「誰か」のキーに兼ねているためだ、という見立てになった（2026-11-06・#577 の背景）。2026-09-09 から 10-30 までの5回の復帰は、どれも人と統括が registry・統括の `lineage`・子の宛先を手で張り替えた。この plan は、こちらで作る ID（`lineage_id` と `generation` の記録）をキーにし、ペインを観測する属性に下げる。

## この plan の範囲

- 委譲は**設計まで**である（brief の終端は P3、分身レビューの指摘を直す指示が来たら P4）。実装（I1 以降）は、ゲート3 の承認のあとに統括が送る実装の追補の書面で始める。
- 範囲の外: engine の `oe`（WezTerm）・復帰のスキル（#355）・統括のセッション名（#576）・全統括をまとめて戻す形・board の frontmatter への移行・ transport をセッション間の文を送る機能（cross-session messaging）に替えること（owner の答えによる・DJ-10）。

## 設計判断

設計の判断の正本は discussion の §5（DJ-1〜DJ-17）で、決まったことの要約は decision の案の「決定」（D1〜D16）である。ここでは繰り返さない。owner に聞いたのは DJ-1・DJ-7・DJ-10・DJ-11・DJ-17 の5件で、DJ-1・DJ-7・DJ-10・DJ-11 は答えを回収した（2026-11-06・判断ボードの Q65〜Q67・Q69）。DJ-17（持ち場の名前）は、1回目（`lineage`）が取り下げになり、2回目を統括のワークスペースの根の作業層の `.oe/question-577-3.json` で聞いている（推奨 `lease`）。新しい概念の名前は、#564 の決まりの案に合わせて識別子で書く（discussion の §5.0）。

## 確定版に無い判断

確定版（認識合わせ）から外れる判断と、確定版に無い新しい判断を分けて書く。どれも、ゲート3 で owner が承認の対象として見るものである。

| # | 判断 | 確定版との関係 | 出どころ |
|---|---|---|---|
| N1 | resume したセッションが自分の ID を知る方法を、環境変数と `CLAUDE_CODE_SESSION_ID` を主にし、「自分のペインの heartbeat から引く」を使わない（DJ-7） | **外れる。** 確定版は「自分のペインの heartbeat から session_id を引き、ID の記録に照らせば決まる見込み」と書いていた | P1 の発見（公式の文書と実機） |
| N2 | owner が resume するときの打ち方を決まりにするかは、I0 で計測してから決める（DJ-7・owner の答え: Q69「推測するな計測せよ」） | 新しい。owner の手の打ち方を変えうる | 最初は公式の文書の MCP server の文を Bash と hook の文と取り違えて出した（discussion の §2.2・episode の「訂正」） |
| N3 | transport は tmux の send-keys のままにし、セッション間の文を送る機能には乗らない。別の issue も起こさない（DJ-10・owner の答え: Q67） | 新しい（確定版には無い問いだった） | P1 の発見・ゲート1 の2レーン |
| N4 | 送れないときは `delivery_held` の event を残し、`lineage` の次の `generation` が拾う（DJ-16） | 新しい | ゲート1 の Codex の案E |
| N5 | heartbeat の sidecar と一時ファイルの掃除を、`lineage` の掃除と同じ verb で行う（DJ-4） | 新しい。確定版の「掃除の決まり」は `lineage` の記録の掃除を指していた | 棚卸し（一時ファイルが約1,075件残っている） |
| N6 | heartbeat からペインを引く規則を lib の1つの関数にまとめ、読む側の絞り方の違い（`oe-vitals` はペインだけ）をなくす（DJ-3） | 新しい | ゲート1 の Codex・棚卸し |
| N7 | `oe-confirm` と `oe-undelivered` の `seen` の記録のキーに、`lineage_id` か server の pid を足す（§3.2） | 新しい | 棚卸し |
| N8 | プロセスの観測（pid と開始時刻）を hook でも書けるようにする（DJ-3・任意） | 新しい。#355 の「hook を土台にしない」は守る | ゲート1 の Cursor の案H |
| N9 | `/tmp/oe-parent-<N>`（`oe-report` の古いフォールバック）を消すかを、実装の段階で決める | 新しい | 棚卸し |
| N10 | 新しい概念を識別子で呼ぶ（`lineage`・`generation`・`binding`・`epoch`・`delivery_held`）。持ち場の名前は owner に聞いている（DJ-17・推奨 `lineage`） | 新しい。確定版は「ID」「ラベル」とだけ書き、名前を決めていなかった | owner の指摘（2026-11-06・統括から）・#564 の決まりの案 |

## ゲート1（ゼロベースの代替探索）

discussion の §7 が正本である。`so-compare --with codex,cursor`（選択肢拡張つき）で2レーンとも返り、新しいカテゴリの案が7つ出た。採否は、一部を採った2つ（保留・hook の観測）・owner に聞いた1つ（transport）・採らなかった4つである。案A（`lineage` と `generation` の2段）は、`epoch`・ commit point ・server の開始時刻・heartbeat の引き方の一本化・`/clear` の定義・Enter の前の確かめ直しを足して残した。

新しいカテゴリが出たので、`predecision-exploration` の暫定の停止条件（新しいカテゴリが出なければ確定に進む）には当たらない。2周目のゼロベースの探索は回さず、ゲート2 で採った形をさらに反証にかけた。打ち切りは、ゲート3 で owner が見て決める。

## 設計SO（ゲート2・弱・Codex と Cursor の2レーン）

discussion の §8 が正本である。

- **Codex のレーンは返らなかった**（10秒でエラー・stderr の末尾に利用上限の行「try again at 4:41 AM」）。**Cursor（`composer-2.5`・指定）の1レーンで進めた。** brief の決まり（片方が返らなければ1レーンで進めてよく、そのことを plan に書く）による。実返却が1レーンあるので、弱 SO の「0 はなし」には当たらない。2レーンの多様性は得られていないので、Codex のレーンを利用上限が戻ったあとにやり直すかは、統括が決める（同じプロンプトが統括のワークスペースの根の `tmp/577-record-identity/gate2-prompt.md` にある）。
- 指摘は11件（高2・中7・低2）で、採ったのは9件、すでに書いてあるか直さないとしたのは2件である。採ったもの: #188 の frontmatter の直し・board schema の §9 の前提の上書き・`binding` するときにコマンド名を確かめる・sidecar の `lineage` の項目を手がかりに下げる・フォアグラウンドのプロセスの確かめを道具の実行中にも見る（R3）・旧い子も親の `lineage` へ送れる形・3 の方法だけで名乗るときの確かめ・1つの session_id は1か所だけ・比べを `epoch` 1つに寄せる。

## 実装の分け方（PR の単位）

1つの PR を1つの論理の変更にし、どの PR も前の PR が入ったあとで単独に確かめられるようにする。

| PR | 中身 | 既存の振る舞いに触るか | 確かめ方 |
|---|---|---|---|
| PR-1 | `lineage` の記録の lib と verb（作る・`binding` する・名乗る・引く・閉じる・掃除する）。heartbeat からペインを引く1つの関数（N6）と、生きていないことの確かめの関数（DJ-9） | 触らない（新しいファイルだけ） | 新しいテスト（偽の tmux と ps・一時ディレクトリの state）と shellcheck |
| PR-2 | 書く側を両方書きにする。`oe-delegate`（`lineage` を作り、`OE_LINEAGE_ID`・`OE_GENERATION`・親の `lineage` を環境に入れる）・`oe-register`・heartbeat の producer（`lineage_id` と `generation` を足す）・event の snapshot（DJ-13）・一度だけの取り込み（`oe-lineage adopt`）（DJ-11） | 触る（書く記録が増える。読む側は変えない） | 既存のテストが全部通ること・新しいテスト・実機で1回（下の「実機の確かめ」の R1） |
| PR-3 | 送る側。`oe-send` の `lineage` あて・送る前の確かめと Enter の前の確かめ直し（DJ-6）・親の `lineage` へ送る形・`delivery_held` の event（DJ-16）・`oe-report`。配布しているスキルの文（`delegate-task`・`doc-flow-guardrail` の「報告の宛先」・`orchestration-toolkit`） | 触る（送る前に止まる場面が増える） | 既存のテスト・新しいテスト・偽の transport 具での確かめ（下の注意） |
| PR-4 | 統括の `lineage`。`oe-handoff take` と `retire` を `lineage` の記録へ（`generation` の compare-and-swap・退任の状態・フォアグラウンドのプロセスで本人を確かめる）・`oe-vitals` が `lineage` の記録を読む（読み手と書き手を同じ PR で・DJ-12）。board の行は表示として書き続ける | 触る | 既存のテスト・新しいテスト（達成を見る数の M1・M3） |
| PR-5 | 観測する側。`oe-tree` が `lineage` の記録から木を描く（tmux を起こし直したあとも前の統括と子を出す）・`seen` の記録のキー（N7）・計測のスクリプト。registry を「誰か」のキーとして読むのをやめる（owner の答え Q66 により、この最後の切り替えは復帰のテストの時に一度に行ってよい） | 触る | 既存のテスト・新しいテスト（達成を見る数の M2） |

- 配る順: hook と statusLine の producer を変える PR（PR-2）と、送る側を変える PR（PR-3）は、sync で全リポジトリの統括に効く。sync の前に、ほかのリポジトリの統括へ知らせる（DJ-11）。知らせる文と、sync をいつ打つかは owner が決める（gate 6 と同じく、子は sync しない）。
- 並べ方: PR-1 → PR-2 → PR-3 → PR-4 → PR-5 の直列である。PR-3 と PR-4 はどちらも `bin/oe-handoff` と配布しているスキルの文に触りうるので、並列にしない。
- 偽の道具での確かめの注意（negative knowledge `01M5T897YCWY13GFTADD3136EC`）: transport 具を偽物に差し替えて確かめるときは、偽の `bin/` に足がかりの `oe-tree` ごと置き、`~/bin` を PATH から外し、存在しないペインの番号を使い、state の置き場（`OE_DELEGATE_STATE_DIR`・`OE_HEARTBEAT_DIR`・`lineage` の置き場）を一時ディレクトリに向ける。偽物の側に自分のパスを記録させ、「記録されたのは偽物だけ」と「本物の呼び出しが無い」の両方を見る。生きている `~/.claude/state/` には書かない。ほかのリポジトリの統括と子のペインへは送らない。

## 達成を見る数の確かめ方

確定版の候補3つを、次のように確かめる。

| 数 | 内容 | 機械の確かめ（PR の中） | 実機での確かめ |
|---|---|---|---|
| M1 | 統括のペインを閉じて新しいペインで resume したとき、書き換える記録が属性だけで済む | PR-4 のテスト。一時ディレクトリの state で、`binding` のプロセスが消えたあとに新しいプロセスが名乗ると、書き換わるのが `lineage` の記録の `binding` と `epoch`・heartbeat の sidecar・board の表示の行だけで、子の `lineage` の記録が1つも書き換わらないことを見る | 次に実際に起きる復帰（#355 の復帰の drill を含む）で、`oe-tree` が子を新しい統括の下に出し、子の報告が届くことを見る |
| M2 | tmux を起こし直したあとも、前の統括と子を ID で一覧できる | PR-5 のテスト。偽の tmux の server の pid と開始時刻を替えたあとも、`oe-tree` が前の `lineage` と子を「プロセスが無い」として出すことを見る | 次に自然に起きる tmux の起こし直しで見る（起こし直しを確かめのために起こさない） |
| M3 | シェルで始まるペインの前任を、retire が閉じてよいと判定できる | PR-4 のテスト。偽の tmux で `#{pane_pid}` をシェルにし、フォアグラウンドのプロセスを `binding` の pid と開始時刻にした場面で、閉じてよいと判定することと、開始時刻が違う場面で閉じないことを見る | 次の計画的な交代で、前任のペインが手でシェルから起こしたものなら、そのとき見る |

### 実機の確かめ

- **R2（statusLine が環境を受け継ぐか）**: PR-2 で、`OE_LINEAGE_ID` を入れて起こしたセッションの heartbeat の sidecar に、`lineage_id` が載ることを見る。R1 と同じ使い捨てのセッションで見る。載らなければ、DJ-3 の「session_id の並びで絞る」だけで動くことを、PR-2 のテストで固定する。
- **R3（フォアグラウンドのプロセスグループが claude を指すか）**: PR-3 で、子が自分のペインについて、入力待ちのときと、Bash の道具で長いコマンドを動かしているときの2つで、ペインの端末のフォアグラウンドのプロセスグループの番号と `CLAUDE_PID` を読んで比べる（自分のペインだけを読む）。道具の実行中に外れるなら、送る側は「確かめられない」で止まり、少し待って確かめ直す形にする。
- **R1（issue の「resume したセッションが自分の ID を知る方法を決め、実機で確かめる」）**: I0（PR-1 の前）に、使い捨ての claude のセッションを1つ、`OE_LINEAGE_ID` と一時ディレクトリの state を入れて起こし、終了し、`claude --resume <id>`（id を付けて）と、id を付けない `claude --resume` の両方で戻して、環境の `CLAUDE_CODE_SESSION_ID` と `oe-lineage bind` の結果を見る。claude を起こすのは owner の手を1回借りる（子は自分でセッションを起こさない）。生きている統括と子には触れない。

## 受入

- A1: 棚卸しの表が discussion にあり、網羅の確かめ（パターンの外からの対照）が episode にある（discussion の §3・§4・episode の「網羅の確かめ」）。
- A2: 設計の判断がそれぞれ、選択肢・推奨・理由・owner の答え（聞いたもの）を持つ（discussion の §5）。
- A3: decision の案が #188・#206・#238/#239 との関係を書いている（decision の案の「decision #188・#206・#238/#239 との関係」）。
- A4: この plan が、実装をどの PR に分けるかと、達成を見る数をどう確かめるかを持つ（上の2つの節）。
- A5（実装の段階）: M1〜M3 の機械の確かめが各 PR のテストにあり、R1 を一度通している。

## ステップ

### P1: worktree・確定版の照合・episode の枠・参照の読み（完了）

### P2: 棚卸し・網羅の確かめ・設計の判断・owner への問い・ゲート1・ゲート2・decision の案と plan（進行中）

### P3: discussion・decision の案・plan・episode を commit して push し、plan のパスを報告の宛先へ1行送り、exit code を確かめて止まる

### P4（指示されたとき）: 分身レビュー（#404）の指摘を直し、commit して push し、報告して止まる

### GATE 3: owner の plan 承認

### I0: resume の値の計測（R1・実装の追補の書面で始める）

owner の答え（Q69「推測するな計測せよ」）により、resume の打ち方の決まりを作る前に計測する。`--resume <id>`・id を付けない `--resume`・`--continue` のそれぞれで、Bash の `CLAUDE_CODE_SESSION_ID` を読み、resume した会話の id と比べる。生きている `~/.claude/state/` と、ほかの統括と子のペインに触れない形（使い捨てのディレクトリ・hook が書く置き場の切り離し）を、実装の追補の書面で統括と決める。結果で DJ-7 の決まりを決め、plan の「ゲート3 のあとの変更」に書く。

### I1〜I5: PR-1〜PR-5（実装の追補の書面で始める）

各 I のあとに、テストと shellcheck のゲート・実装SO・Copilot の1ラウンドを、別の項目として置く（実装の追補の書面で確定する）。

## GATE 3 の問い

（持ち場の名前の答えが届いたあとに書く。この plan で実装に進むか・確定版に無い判断 N1〜N10 を承認するか・DJ-1 の答えの当て方（持ち場と `generation` を1つのファイルの中の2つの表として持つ読み）で足りるか）

## ゲート3 のあとの変更

（まだ無い）
