---
id: "01M6PD1RHBVVNJDD3FPHKKRX15"
title: "#577 統括と委譲子の「誰か」は、こちらで作る `lease_id` と `generation` の記録で持ち、tmux のペインは観測する属性にする — decision #188 の DJ-188-3 を `oe-delegate`（tmux）の子と統括について置き換える"
date: 2026-11-06
type: decision
status: accepted   # 2026-11-07 に accepted（ゲート3 の承認は 2026-11-06・plan @ 4cec7e8。D7 は I0 の計測のあとに補正 H1 で確定）
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577"
    reason: "本 decision の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-11-06-discussion-577-record-identity-key.md"
    reason: "棚卸しの表・設計の判断 DJ-1〜DJ-20・ゲート1 の探索木"
  - type: reference
    ref: "projects/orchestration-engine/docs/plans/2026-11-06-plan-577-record-identity-key.md"
    reason: "実装の分け方と、達成を見る数の確かめ方"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-06-episode-577-record-identity-key.md"
    reason: "作業の記録。実機と公式の文書で確かめた事実・網羅の確かめ・SO の採否"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "一部を置き換える前の決定（DJ-188-3）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-22-decision-206-activity-log-self-contained-events.md"
    reason: "event の snapshot の決定。snapshot に `lease_id` を足す"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md"
    reason: "seat を先送りした決定。この decision がその先送りを始める"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md"
    reason: "board の `現統括` の正本を動かすときの決まり（§9）"
tags: [orchestration, registry, identity, supervisor, delegation, decision]
---

# #577 統括と委譲子の「誰か」は、こちらで作る `lease_id` と `generation` の記録で持ち、tmux のペインは観測する属性にする

**この decision は accepted である（2026-11-07）。** ゲート3 は 2026-11-06 に owner が承認した（plan @ `4cec7e8`）。設計の問いと分身レビューへの owner の答え（Q65〜Q84）は、すべてこの文書と discussion に入っている。

## 前提の変化（最初に書く）

1. **decision #188 は、2つのペインの番号の世界が並んでいた時期の決定である。** #188（2026-06-19）は、WezTerm のペインで子を起こす engine の `oe`と tmux のペインで子を起こす `oe-delegate`が並び、2つの番号の世界に対応が物理的に無いことを前提に、「ペインの層で統一しない」「永続の対応表を作らず、読むときに突き合わせる」と決めた。そのあと使っているのは `oe-delegate`（tmux）だけになった。engine の `oe`（WezTerm）の state は 2026-06-04 のファイルが最後で、tmux で子を起こした event は 431 件・最新は 2026-11-05 UTC である [verified]（`projects/orchestration-engine/state/` と `~/.claude/state/oe-events.jsonl` を読むだけで数えた・2026-11-06）。
2. **セッションは自分の session_id と pid を知っている。** #355 と確定版と `lib/handoff-state.sh` は、セッションが自分の session_id を名乗る経路は無いことを前提にしていた。公式の文書では、`CLAUDE_CODE_SESSION_ID` が Bash と hook の子プロセスに入り（hook の入力の `session_id` と一致・`--resume <id>` では resume した id・`/clear` で更新）、`CLAUDE_PID` が Claude Code 自身の pid として入る [verified]（https://code.claude.com/docs/en/env-vars.md の該当の2行）。「`--continue` と id を付けない `--resume` では起動したときの id が入ることがある」は、MCP server の子プロセスについての文である [verified]（同じ行）。Bash と hook で id を付けない resume のときにいまの id が入るかは、実機で確かめていない [unverified-summary]。
3. **ペインを「誰か」のキーに兼ねている箇所は、統括が数えた36本より多い。** 36本の走査の外に、`bin/oe-send`・`lib/seat.sh`・heartbeat の producer など7本があった [verified]（discussion の §4）。

## 決定

- **D1 `lease_id` と `generation` の記録の2段にする**（discussion の DJ-1・owner の答え: Q65「1つの ID に2つの意味を持たせない」）。`lease` は人が入れ替わっても続く持ち場（統括の `lease`・委譲1件）で、ID は ULID である。`generation` は `lease` に座った1つの会話で、交代（`oe-handoff take`）でだけ進む。宛先は `lease`、本人確認は `generation` の `binding`（claude の pid と開始時刻）で行う。
- **D2 置き場は `~/.claude/state/oe-lease/<lease_id>.json`** で、`lease` ごとに1ファイルの中に、`lease` の表と `generation` の表を分けて持つ（DJ-2・owner の答え Q73）。書くのは verb だけで、`lease` ごとのロックの中で、`epoch` を比べてから書く（DJ-5）。
- **D3 ペインと tmux server の pid は属性で、観測は heartbeat の sidecar に残す**（DJ-3）。sidecar の書き手は statusLine の producer だけのままにし、環境に `OE_LEASE_ID` と `OE_GENERATION` があるときだけ `lease_id` と `generation` を足す。server は、いままでどおり pid で区別する（開始時刻でも区別する案は owner の答え Q76 で外した）。heartbeat からペインを引く規則は lib の1つの関数にまとめる（計測の道具 `scripts/measure-delivery-arrival.py` は、#299 の到達率と比べる物差しを変えないために外す・owner の答え Q83）。
- **D4 `lease` と `generation` は、server の世代やペインの生死では消さない**（DJ-4）。閉じた `lease` を、明示の掃除（`oe-lease gc`）で、一定の日数のあとに消す。heartbeat の sidecar の掃除も同じ verb で行う。gc は `oe-handoff take` のついでに走らせる。書き込みの途中の一時ファイル（`.hb.*`）が残る漏れは、heartbeat を書く側の直しとして別 issue にする（owner の答え Q78）。
- **D5 取り合わない決まり**（DJ-5・owner の答え: Q72。下の「plan-390 のゲート3 の回答1 との関係」）。`binding` の張り替えと `generation` を進めるのは、ロックの中で `epoch` を比べる compare-and-swap で行い、1つの session_id は開いた `lease` の1か所にしか入れず、session_id を登録する操作はすべての `lease` に共通の1つのロックの中で行う。親の書き換えでも `epoch` を増やす。保証するのは正本の `binding` が1つになるまでで、同じ会話の2つ目のプロセスが起きること自体は防がない（負けた側は bind で失敗して統括の操作に進まない）。張り替えは、前の `binding` のプロセスが生きていないと機械で確かめられたときか、本人が張り替えるときだけ許す。`lease` の記録の1回の書き込みを commit point にし、board の行・registry の複製・event は、`lease` の記録から作り直せる派生の記録にする。
- **D6 送る前の確かめ**（DJ-6）。`lease` → いまの `generation` → heartbeat の候補のペイン → `tmux list-panes -a` の所属 → ペインの端末のフォアグラウンドのプロセスの pid と開始時刻が `binding` と一致、の順で引き、どれかで外れたら送らない。確かめと Enter のあいだの窓は残る。別のペインに届いた取り違えは receipt で後から見つけるが、同じペインの中で会話が替わった場合は見つけられない（Enter の前の確かめ直しは owner の答え Q76 で外した）。
- **D7 resume したセッションが自分の `lease` と `generation` を知る方法**（DJ-7・owner の答え: Q69「推測するな計測せよ」）。環境変数 → `CLAUDE_CODE_SESSION_ID` と `generation` の session_id の並びの照合 → 会話の記録にある `lease_id` を `oe-lease bind` に渡す、の順に使う。どの方法も「どの `lease` か」を決めるだけで、`binding` の張り替えは必ず D5 の条件を通す。3 だけで名乗るときは workspace の一致を確かめ、統括の `lease` なら owner の確かめを1回求める。owner の resume の打ち方は決まりにしない。I0 の計測で、id を付けた `--resume` と `--continue` のどちらでも Bash の `CLAUDE_CODE_SESSION_ID` が会話の id と一致したためである。対話の一覧から選ぶ resume は計測していない（成り立たなければ方法3 に落ちる）。
- **D8 退任した統括の見分け**（DJ-8）。`generation` の記録に状態（在任・退任）・退任した時刻・後任の `generation` を持ち、退任した `generation` のセッションは統括の操作に進まない。
- **D9 生きていないことの機械の確かめ**（DJ-9）。`binding` するときにそのプロセスのコマンドが claude であることを確かめる。`binding` のプロセス（pid と、`LC_ALL=C` で取った開始時刻）が無ければ生きていない。問い合わせが失敗したときは「分からない」として張り替えない。heartbeat の古さ・画面・累積の CPU 時間では決めない。`oe-handoff retire` はこの確かめで、シェルで始まるペインの前任も閉じてよいかを判定できる。retire は引き継ぎ文書の機械の節を読まず、`lease` の記録だけで判定する。機械の節は `lease` の記録から作る表示にする（owner の答え Q84）。
- **D10 transport は tmux の send-keys のままにする**（DJ-10・owner の答え: Q67）。Claude Code への依存を深めないので、セッション間の文を送る機能には乗らず、別の issue も起こさない。Claude Code に頼るのは、文書化された環境変数（`CLAUDE_CODE_SESSION_ID`・`CLAUDE_PID`）だけにする。
- **D11 移行は両方書いて読む側を1つずつ切り替える**（DJ-11・owner の答え: Q66）。両方書く期間は復帰のテスト（#355 の drill）までとし、registry をキーとして読むのをやめる最後の切り替えは、そのとき一度に行ってよい。進行中の委譲は一度だけの取り込みで引き取り、`PARENT_TMUX_PANE` しか持たない子は古い宛先のまま終わらせる（owner の答え Q76 で D14 の古い子の経路を外したので、この D11 が正である）。ほかのリポジトリの統括には sync の前に知らせる。
  - （2026-11-09・PR-6 で追記）drill は 2026-11-08 に通ったが、両方書く期間はまだ終わっていない。ほかのリポジトリで PR-2 より前から動いている統括3つが `lease` を持たず、`PARENT_TMUX_PANE` だけを持つ子が5つ生きていたので、registry の両方書き・`oe-lease adopt`・`PARENT_TMUX_PANE` の注入・スキルの古い規則・`oe-report` は外さず、外す作業を #603 に移した。外したのは、書く側の無かった `/tmp/oe-parent-<N>` のフォールバックだけである。確かめた結果は episode の「I6: 外す条件を本物の記録で確かめた」、行ごとの判定は plan の「移行の終わり方」にある。
- **D12 統括の `lease` の正本は `lease` の記録にする**（DJ-12）。board の `現統括:` の行は、`oe-handoff take` が書き続ける表示である。読み手（`oe-vitals`）と書き手（`oe-handoff take`）を同じ PR で切り替える（board schema の §9）。board の散文の形は変えない。
- **D13 event の snapshot に `lease_id` と `generation` を足す**（DJ-13）。`binding` の張り替え（復帰）の型を足す。
- **D14 子の報告は親の `lease` へ送る**（DJ-15）。`OE_LEASE_ID` を持つ子は、親の `lease` のいまの `generation` へ送る。label は `lease` の記録から引き、pane-issue からは引かない。生の `%N` はフォールバックとして残す。`OE_LEASE_ID` を持たない古い子は D11 のとおり古い宛先のまま終わらせる（古い子も親の `lease` へ送れるようにする案は owner の答え Q76 で外した）。移行のあいだは、`#N` のラベルを `lease` の記録で引けなければ古い引き方に落とす（owner の答え Q77）。委譲固定節の「報告の宛先」の規則を、この形に置き換える。
- **D15 送れないときの保留は、この decision では決めない**（DJ-16・owner の答え Q80）。`delivery_held` の event と、送れないときに止めて保留する動きは、#355（復帰）で拾い方と一緒に決める。送る前の確かめ（D6）で外れたときは、いまの `oe-send` と同じく失敗の終了コードで返す。
- **D16 新しい概念は識別子で呼ぶ**（discussion の §5.0・DJ-17・owner の答え: Q71）。持ち場は `lease`（ID の項目は `lease_id`・verb は `oe-lease`。Kubernetes の Lease に合わせた。時間で期限切れにならない点は Kubernetes と違う）、その持ち場に座った会話は既存の `generation`、プロセスとの結び付きは `binding`、比べる番号は `epoch`、送れなかったことを残す events の型の名前の案は `delivery_held` である（使うかは #355 で決める）。`seat` は current_supervisor の意味から外す方向（#564）なので使わない。
- **D17 最初の `binding` と、あとから増える session_id の書き手**（DJ-18）。起こした子と後継は、起こした側の verb（`oe-delegate`・`oe-handoff start`）が、ペインの生存を確かめる時点で、端末のフォアグラウンドのプロセスの pid と開始時刻を `binding` に書く（コマンドが claude であることを確かめ、確かめられなければ未確定で止める）。手で立てた統括は、本人が `oe-lease create --root` を打つ。session_id を登録するのは、本人が動かす `oe-lease` の verb だけで、自分の `CLAUDE_PID` が `binding` と一致するときに自分の `CLAUDE_CODE_SESSION_ID` を登録する。heartbeat の sidecar は登録の根拠にしない。
- **D18 ペインの本人確認を1つの関数にする**（DJ-19）。tmux に固有の確かめを集めた小さな lib に置き、送信・adopt・retire・`oe-jump`・`oe-select` がそれを使う。
- **D19 子から親への報告の入口を `oe-send --to-parent` の1本にする**（DJ-20）。PR-3 では配っているスキルの文を替え、`oe-report` と `/tmp/oe-parent-<N>` は、古い子が残っていないと確かめてから PR-6 で廃止する。（2026-11-09・PR-6 で追記）PR-6 で外したのは書く側の無い `/tmp/oe-parent-<N>` のフォールバックだけで、`oe-report` の verb は、それを呼びうる古い子が生きていたので #603 に移した。

## decision #188・#206・#238/#239 との関係

| 前の決定 | この decision での扱い |
|---|---|
| DJ-188-1（ペインの層で identity を統一しない） | 残す。ペインを統一せず、ペインの外に ID を作る |
| DJ-188-2（engine の session-state を delegate に広げない） | 残す。`lease` の記録は engine の `oe` の state とは別の系統である |
| DJ-188-3（永続の対応表を作らず、読むときに突き合わせる） | **tmux の子と統括について置き換える。**「誰か」（`lease` と `generation`）は永続の記録にする。属性（ペインと server）は、いままでどおり読むときに heartbeat と突き合わせる |
| DJ-188-4（#206 で精緻化・自己完結の snapshot） | 残す。snapshot に `lease_id` と `generation` を足す |
| DJ-188-5（read-only は観測者を縛る） | 残す。新しい write path は producer の側（verb）に足す。DJ-188-5 の「新規書込経路を一切導入しない」は #188 自身の範囲の文である。#188 の frontmatter の「DJ-188-1/2/3/5 は不変」は、この decision の確定のときに直す |
| DJ-206-1・DJ-206-3 | 従う。#206 が後回しにした「`%N` の再利用で別の関係が混ざりうる」は、snapshot の `lease_id` で、足したあとの新しい event について解く（足す前の event は見分けられない） |
| #238/#239 の lean の決定（新しい engine state を作らない・seat は薄い pointer として先送り） | **lean の決定を、identity（誰か）について覆す。** `lease` は新しい engine state であり、#238/#239 が「新正本にすると三者同期が生じる」として退けたものに当たる。先送りの再開の条件「報告 stranding が再発したら」は、2026-10-27 に子3本の宛先が切れたことで当たっていると筆者は読むが、再開してよいかは HG の判断なので、ゲート3 で owner に見せる。三者同期は、`lease` の記録を正本・board の行を表示・registry を移行のあいだの複製、と分けて避ける。declared の層（board）・observed の層（watchdog）・statusline の producer の形は変えない |
| plan-390 のゲート3 の回答1（席に lease と fencing を入れない・停止を fencing の代わりにする） | **`lease` の記録への書き込みに限って更新する**（owner の答え Q72）。`epoch` と compare-and-swap は `lease` の記録の書き込みにだけ効かせ、古い `generation` の送信やファイルの編集まで止める fencing は入れない。それ以外は回答1 のまま |
| board schema の §9（移行後は frontmatter の `現統括` が正本になる・読み手と書き手を同時に切り替える） | **前提を上書きする。** board の `現統括` は、frontmatter に移しても表示であり、機械の正本は `lease` の記録である。「読み手と書き手を同時に切り替える」の原則は残し、正本を board の外に移す切り替えを、読み手と書き手の同じ PR で行う。`validate-board.sh` の `現統括` の検査は、表示の行があるかの検査として残す |

decision #188 の本文は変えず、frontmatter の `superseded_by` に「DJ-188-3 の `oe-delegate`（tmux）の部分を、この decision で置き換える」を足す（この decision が accepted になったとき）。

## plan-390 のゲート3 の回答1 との関係

- **前の裁定**: #390（計画的な交代）の plan のゲート3 で、owner は「席に排他制御（lease と fencing）を入れるか」に「(a) lean の決定を維持する。停止を fencing の代わりに使う」と答えた [verified]（`projects/orchestration-engine/docs/plans/2026-09-11-plan-390-supervisor-planned-succession.md` の「ゲート3 — owner の裁定（2026-09-11）」の表の1行目）。そのとき棄却した案は「lease と fencing token による席（compare-and-swap・世代番号・consumer が token を検査）」で、棄却の理由は「新しい正本を作るので lean の決定に正面から反する。採るなら accepted な ADR を覆す owner 判断が要る」だった（同じ plan の「棄却した案（ゲート1・ゼロベース代替探索）」の表）。採った形は「プロセスを閉じることが、この構成で使える唯一の fencing である」（同じ plan の DJ-7）。
- owner の答え（2026-11-06・判断ボードの Q72）は「`epoch` と compare-and-swap は入れるが、効かせるのは `lease` の記録への書き込みだけ。古い `generation` の送信やファイルの編集まで止める本格的な fencing は入れない」である。答えに至った経緯（この設計で近いところと違うところの見立て）は、discussion の §6 にある。
- **この decision は、plan-390 の回答1 を、`lease` の記録への書き込みに限って更新する。** `lease` の記録の書き込みは `epoch` の compare-and-swap で取り合いを防ぐ。それ以外（退任した `generation` の送信・委譲・board やファイルの編集）は、回答1 のまま、前任のプロセスを閉じることを fencing の代わりにする（#390 の DJ-7）。

## #564（engine の用語集）との関係

- #564 は、`lib/seat.sh` を `lib/current-supervisor.sh` に、`oe_seat_*` を `oe_current_supervisor_*` に改名する計画を持つ [verified]（https://github.com/stlwolf/ai-development-hub/issues/564 の「用語の表（案）」の `current_supervisor` の行）。その計画では、この lib は current_supervisor を読み書きする正本の部品である。
- この decision では、current_supervisor の機械の正本は `lease` の記録になり（D12）、`lib/seat.sh` は board の `現統括:` の行という表示を書く部品に下がる。名前を `current-supervisor` にすると、表示の書き手に正本の名前が付く。
- どちらを先にするか（#564 の改名を先にしてこの decision に合わせるか、この decision の PR-4 で `lib/seat.sh` の役割を変えてから #564 で名前を決めるか）は、上流で合わせる点として残す。この decision の実装は `lib/seat.sh` の名前を変えない。

## 検討した選択肢

discussion の §7 の探索木が正本である。要点だけを書く。

- **案B（`generation` ごとの ID）**: 子の宛先が前任の `generation` を指して残る。
- **案C（ID を作らず、掃除を直して張り替えの verb を足す）**: 「復帰は属性を書き換えるだけ」と「生きていないことを機械で確かめてから走らせる」に届かない。
- **常駐の管理プロセス**・**event の再生**・**ワークスペースへの置き場**・**長寿の中継のセッション**: それぞれ、新しい常駐を増やす・best-effort の記録に「いま」を頼る・ワークスペースをまたぐ委譲が成り立たない・中継も context を使い切る、の理由で採らなかった。
- **配送を Claude Code のセッション間の文を送る機能へ移す**: owner が採らなかった（D10）。採っても `lease` の記録は要った。

## 帰結

- 統括が交代しても、子の宛先を付け替える手（`oe-register link` を子ごとに打つ）が要らなくなる。
- tmux を起こし直しても、`lease` と `generation` の記録は残り、前の統括と子を ID で一覧できる。
- `oe-handoff retire` が、シェルで始まるペインの前任を閉じてよいかを判定できる。
- 残る穴:
  - 送る前の確かめと Enter のあいだの窓。別のペインに届いた取り違えは receipt で後から見つけるが、同じペインの中で会話が替わった場合は見つけられない。
  - 移行のあいだ、`PARENT_TMUX_PANE` しか持たない古い子は、親の交代のあとに前任へ送るか、ペインの番号の使い回しで別人へ送りうる（D11 のとおり古い宛先のまま終わらせることの残り）。
  - 復帰の手順が出すコマンドを使わずに resume すると、環境変数（1 の方法）が入らない。そのときは session_id の照合（2 の方法）に頼る。id を付けない resume で 2 の方法が成り立つかは、実機で確かめるまで分からない。
  - `binding` の pid を持たない `lease`（取り込みで pid を取れなかった `lease`）は、生きているか分からないとして人の判断に回る。
  - D6 の送る前の確かめと D9 の retire の判定がペインの端末のフォアグラウンドのプロセスで本人を確かめるのは、claude がフォアグラウンドのプロセスグループの長であることが前提である。非対話の wrapper（`bash -c` など）の子として claude を起こすと、フォアグラウンドのプロセスは wrapper のシェルになり、本人を確かめられない（`binding` できない・送れない・閉じてよいと判定できない）。`oe-delegate` と `oe-handoff start` は `exec` で起こすので当たらない。由来は #355 の drill で、knowledge `01M6XN85N408CMMERA12QR1C3F` にある（2026-11-09・PR-6 で足した）。
- 新しい write path（`lease` の記録）が1つ増える。書き手は verb だけで、heartbeat の write path には入らない。

## 確定したときに直したこと

- D1・D10・D11・D16 は owner の答え（Q65〜Q67・Q71）を入れた。D7 の resume の打ち方は、I0 の計測のあとに決める。D5 の epoch と compare-and-swap は、owner の答え（Q72）で、`lease` の記録への書き込みだけに効かせると決まった。
- （済み・2026-11-07・PR #580）status を accepted にし、置き換えられる側の decision に印を足した。どれも本文は変えず、frontmatter の `superseded_by` か、末尾の追記の節に1つずつ書いた。
  - decision #188: 「DJ-188-3 の `oe-delegate`（tmux）の部分を、#577 の decision で置き換えた。DJ-188-1・2・4・5 は残る」。
  - decision #238/#239: 「lean の決定（新しい engine state を作らない・seat の先送り）を、identity について #577 の decision で覆した。declared・observed・producer の形は残る」。
  - decision #238 の board schema（§9 の後ろ）: 「§9 の『移行後は frontmatter の `現統括` が正本になる』という前提を、#577 の decision で上書きした。`現統括` は表示で、機械の正本は `lease` の記録である」。
  - #390 の plan のゲート3 の回答1 には、plan の側に印を書かない（plan は実行の記録なので）。この decision の「plan-390 のゲート3 の回答1 との関係」の節が正本である。
