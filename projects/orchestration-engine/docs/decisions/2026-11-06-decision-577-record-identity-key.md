---
id: "01M6PD1RHBVVNJDD3FPHKKRX15"
title: "#577 統括と委譲子の「誰か」は、こちらで作る席の ID と代の記録で持ち、tmux のペインは観測する属性にする — decision #188 の DJ-188-3 を tmux の道について置き換える"
date: 2026-11-06
type: decision
status: proposed   # 案。owner の答え（.oe/question-577-1.json の4件）とゲート3 の承認で accepted にする
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577"
    reason: "本 decision の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-11-06-discussion-577-record-identity-key.md"
    reason: "棚卸しの表・設計の判断 DJ-1〜DJ-16・ゲート1 の探索木"
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
    reason: "出来事の写しの決定。写しに席の ID を足す"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md"
    reason: "seat を先送りした決定。この decision がその先送りを始める"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md"
    reason: "board の `現統括` の正本を動かすときの決まり（§9）"
tags: [orchestration, registry, identity, supervisor, delegation, decision]
---

# #577 統括と委譲子の「誰か」は、こちらで作る席の ID と代の記録で持ち、tmux のペインは観測する属性にする

**この文書は案（proposed）である。** owner に聞いている4件（ID が何を指すか・移行の段取り・送る道・resume の打ち方）の答えと、ゲート3 の承認を受けて確定する。答えが推奨と違えば、該当する決定を直す。

## 前提の変化（最初に書く）

1. **decision #188 は、2つのペインの番号の世界が並んでいた時期の決定である。** #188（2026-06-19）は、WezTerm のペインで子を起こす道（engine の `oe`）と tmux のペインで子を起こす道（`oe-delegate`）が並び、2つの番号の世界に対応が物理的に無いことを前提に、「ペインの層で統一しない」「永続の対応表を作らず、読むときに突き合わせる」と決めた。そのあと使う道は tmux だけになった。WezTerm の道の state は 2026-06-04 のファイルが最後で、tmux で子を起こした出来事は 431 件・最新は 2026-11-05 UTC である [verified]（`projects/orchestration-engine/state/` と `~/.claude/state/oe-events.jsonl` を読むだけで数えた・2026-11-06）。
2. **セッションは自分の session_id と pid を知っている。** #355 と確定版と `lib/handoff-state.sh` は、セッションが自分の session_id を名乗る経路は無いことを前提にしていた。公式の文書では、`CLAUDE_CODE_SESSION_ID` が Bash と hook の子プロセスに入り（`--resume <id>` では resume した id・`/clear` で更新）、`CLAUDE_PID` が Claude Code 自身の pid として入る [verified]（https://code.claude.com/docs/en/env-vars.md の該当の2行）。ただし `--continue` と id を付けない `--resume` では起動したときの id が入ることがある [verified]（同じ行）。
3. **ペインを「誰か」の鍵に兼ねている箇所は、統括が数えた36本より多い。** 36本の走査の外に、`bin/oe-send`・`lib/seat.sh`・拍動の producer など7本があった [verified]（discussion の §4）。

## 決定

- **D1 席の ID と代の記録の2段にする**（discussion の DJ-1・owner に聞いている）。席は人が入れ替わっても続く持ち場（統括の席・委譲1件）で、ID は ULID である。代は席に座った1つの会話で、交代（`oe-handoff take`）でだけ進む。宛先は席、本人確認は代の束縛（claude の pid と開始時刻）で行う。
- **D2 置き場は `~/.claude/state/oe-seats/<席の ID>.json`** で、席ごとに1ファイル・代はその中に並べる（DJ-2）。書くのは verb だけで、席ごとのロックの中で、所有の番号（epoch）を比べてから書く（DJ-5）。
- **D3 ペインと tmux server の pid は属性で、観測は拍動の sidecar に残す**（DJ-3）。sidecar の書き手は statusLine の producer だけのままにし、環境に `OE_SEAT_ID` と `OE_SEAT_GEN` があるときだけ席の ID と代の番号を足す。server は pid と開始時刻で区別する。拍動からペインを引く規則は lib の1つの関数にまとめる。
- **D4 席と代は、server の世代やペインの生死では消さない**（DJ-4）。閉じた席を、明示の掃除の verb で、一定の日数のあとに消す。拍動の sidecar と一時ファイルの掃除も、同じ verb で行う。
- **D5 取り合わない決まり**（DJ-5）。束縛の張り替えと代を進めるのは、ロックの中で所有の番号（epoch）を比べる compare-and-swap で行い、1つの session_id は開いた席の1か所にしか入れない。張り替えは、前の束縛のプロセスが生きていないと機械で確かめられたときか、本人が張り替えるときだけ許す。席の記録の1回の書き込みを確定の点にし、board の行・登記の写し・出来事は、席の記録から作り直せる従の記録にする。
- **D6 送る前の確かめ**（DJ-6）。席 → いまの代 → 拍動の候補のペイン → `tmux list-panes -a` の所属 → ペインの端末の前面のプロセスの pid と開始時刻が束縛と一致、の順で引き、どれかで外れたら送らない。Enter の前にも確かめ直す。確かめと Enter のあいだの窓は残り、受領印で後から見つける。
- **D7 resume したセッションが自分の席と代を知る道**（DJ-7・owner に聞いている）。環境変数 → `CLAUDE_CODE_SESSION_ID` と代の session_id の並びの照合 → 会話の記録にある席の ID を名乗る verb に渡す、の順に使う。3 だけで名乗るときは workspace の一致を確かめ、統括の席なら owner の確かめを1回求める。owner の resume は、復帰の手順が出す id 付きのコマンドを写して打つことを決まりにする。
- **D8 退任した統括の見分け**（DJ-8）。代の記録に状態（在任・退任）・退任した時刻・後任の代を持ち、退任した代のセッションは統括の操作に進まない。
- **D9 生きていないことの機械の確かめ**（DJ-9）。束縛するときにそのプロセスのコマンドが claude であることを確かめる。束縛のプロセス（pid と、`LC_ALL=C` で取った開始時刻）が無ければ生きていない。拍動の古さ・画面・累積の CPU 時間では決めない。`oe-handoff retire` はこの確かめで、シェルで始まるペインの前任も閉じてよいかを判定できる。
- **D10 送る道は tmux の send-keys のままにする**（DJ-10・owner に聞いている）。代の記録に受け口（`CLAUDE_CODE_MESSAGING_SOCKET`）を持てる形にし、セッション間の文を送る機能は別の issue で試す。
- **D11 移行は両方書いて読む側を1つずつ切り替える**（DJ-11・owner に聞いている）。進行中の委譲は一度だけの取り込みで引き取り、`PARENT_TMUX_PANE` しか持たない子は古い宛先のまま終わらせる。ほかのリポジトリの統括には sync の前に知らせる。
- **D12 統括の席の正本は席の記録にする**（DJ-12）。board の `現統括:` の行は、`oe-handoff take` が書き続ける表示である。読み手（`oe-vitals`）と書き手（`oe-handoff take`）を同じ PR で切り替える（board schema の §9）。board の散文の形は変えない。
- **D13 出来事の写しに席の ID と代の番号を足す**（DJ-13）。束縛の張り替え（復帰）の型を足す。
- **D14 子の報告は親の席へ送る**（DJ-15）。`OE_SEAT_ID` を持つ子は、親の席のいまの代へ送る。label は席の記録から引き、pane-issue からは引かない。生の `%N` は逃げ道として残す。`OE_SEAT_ID` を持たない旧い子も、自分のペインと server の pid から自分の席を引き（`CLAUDE_PID` で本人を確かめる）、親の席へ送れるようにする。委譲固定節の「報告の宛先」の規則を、この形に置き換える。
- **D15 送れないときは保留して、席の次の代が拾う**（DJ-16）。拾う道具は #355 の側で決める。

## decision #188・#206・#238/#239 との関係

| 前の決定 | この decision での扱い |
|---|---|
| DJ-188-1（ペインの層で identity を統一しない） | 残す。ペインを統一せず、ペインの外に ID を作る |
| DJ-188-2（engine の session-state を delegate に広げない） | 残す。席の記録は engine の `oe` の state とは別の系統である |
| DJ-188-3（永続の対応表を作らず、読むときに突き合わせる） | **tmux の子と統括について置き換える。**「誰か」（席と代）は永続の記録にする。属性（ペインと server）は、いままでどおり読むときに拍動と突き合わせる |
| DJ-188-4（#206 で精緻化・自己完結の写し） | 残す。写しに席の ID と代の番号を足す |
| DJ-188-5（read-only は観測者を縛る） | 残す。新しい書き込みの道は producer の側（verb）に足す。DJ-188-5 の「新規書込経路を一切導入しない」は #188 自身の範囲の文である。#188 の frontmatter の「DJ-188-1/2/3/5 は不変」は、この decision の確定のときに直す |
| DJ-206-1・DJ-206-3 | 従う。#206 が後回しにした「`%N` の再利用で別の関係が混ざりうる」は、写しの席の ID で解く |
| #238/#239 の「seat は薄い pointer として先送り」 | **先送りを始める。** 再開の条件「報告 stranding が再発したら」は、2026-10-27 に子3本の宛先が切れたことで当たっている。先送りの理由の三者同期は、席の記録を正本・board の行を表示・登記を移行のあいだの写し、と分けて避ける |
| board schema の §9（移行後は frontmatter の `現統括` が正本になる・読み手と書き手を同時に切り替える） | **前提を上書きする。** board の `現統括` は、frontmatter に移しても表示であり、機械の正本は席の記録である。「読み手と書き手を同時に切り替える」の原則は残し、正本を board の外に移す切り替えを、読み手と書き手の同じ PR で行う。`validate-board.sh` の `現統括` の検査は、表示の行があるかの検査として残す |

decision #188 の本文は変えず、frontmatter の `superseded_by` に「DJ-188-3 の tmux の道の部分を、この decision で置き換える」を足す（この decision が accepted になったとき）。

## 検討した選択肢

discussion の §7 の探索木が正本である。要点だけを書く。

- **案B（代ごとの ID）**: 子の宛先が前任の代を指して残る。
- **案C（ID を作らず、掃除を直して張り替えの verb を足す）**: 「復帰は属性を書き換えるだけ」と「生きていないことを機械で確かめてから走らせる」に届かない。
- **常駐の管理プロセス**・**出来事の再生**・**ワークスペースへの置き場**・**長寿の中継のセッション**: それぞれ、新しい常駐を増やす・best-effort の記録に「いま」を頼る・ワークスペースをまたぐ委譲が成り立たない・中継も context を使い切る、の理由で採らなかった。
- **配送を Claude Code のセッション間の文を送る機能へ移す**: owner に聞いている（D10）。採っても席の記録は要る。

## 帰結

- 統括が交代しても、子の宛先を付け替える手（`oe-register link` を子ごとに打つ）が要らなくなる。
- tmux を起こし直しても、席と代の記録は残り、前の統括と子を ID で一覧できる。
- `oe-handoff retire` が、シェルで始まるペインの前任を閉じてよいかを判定できる。
- 残る穴:
  - 送る前の確かめと Enter のあいだの窓（受領印で後から見つける）。
  - id を付けない resume では、セッションが機械で名乗れない（会話の記録の席の ID と、生きていないことの確かめに頼る）。
  - 束縛の pid を持たない席（取り込みで pid を取れなかった席）は、生きているか分からないとして人の判断に回る。
- 新しい書き込みの道（席の記録）が1つ増える。書き手は verb だけで、拍動の道には入らない。

## 確定するときに直すこと

- owner の答えが推奨と違う決定（D1・D7・D10・D11）を直す。
- status を accepted にし、decision #188 の frontmatter に置き換えの行を足す。
