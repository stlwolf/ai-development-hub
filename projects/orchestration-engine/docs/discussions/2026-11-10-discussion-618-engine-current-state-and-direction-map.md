---
id: "01M72VPPAZRX781VX9PZP9P3QA"
title: "#618 engine の現在地と外の状況 — 方向性を決めるための見取り図"
date: 2026-11-10
type: discussion
status: draft
related:
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/618"
    reason: "この discussion はフェーズ1（現在地）とフェーズ2（外との比較）の材料で、フェーズ3（方向性）の決定はしない"
  - type: source_material
    ref: "docs/draft/618-engine-research/"
    reason: "調査の下請けの調査メモ9本（1回目の4本と、外の調査を広げた2回目の5本）。この文書の数字と表の出どころ"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "2026-02 の調査の結論"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "D10（transport は tmux の send-keys のまま・Claude Code に依存を深めない）を、外の変化と並べて見直す材料にする"
  - type: sibling
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562"
    reason: "Codex を子にする。3.9 節（ほかの CLI の口）と Q10 がここにつながる"
  - type: sibling
    ref: "https://github.com/stlwolf/ai-development-hub/issues/537"
    reason: "engine を独立したパッケージにする。名前と境界の決定がここにつながる"
  - type: sibling
    ref: "https://github.com/stlwolf/ai-development-hub/issues/609"
    reason: "統括の復帰と、世代0から始めるときの扱い"
tags: [orchestration-engine, roadmap, landscape, epic-618]
---

# #618 engine の現在地と外の状況 — 方向性を決めるための見取り図

## この文書の範囲

[#618](https://github.com/stlwolf/ai-development-hub/issues/618) のフェーズ1（engine にいま何があり、どこで人が手を動かしているか）とフェーズ2（2026-02 の調査以降、外で何が変わったか）を1枚にまとめ、フェーズ3で決めることの一覧と、決める順序の案を添える。

決定はしない。フェーズ3の決定は owner がする。4節の「書き手の見立て」は、材料から書き手が引いた推奨で、決定でも owner の意図の推測でもない。

## 調べ方と札の付け方

- 2026-11-10 に、クラウドのセッション1つ（hub の統括とは別）から、調査の下請けを4本並べて走らせた。実装・文書の経緯・2026-02 の調査・外の状況（Web）の4本である。調査メモは `docs/draft/618-engine-research/` に置いた。
- 書き手は、次の主張を元の資料で開き直して確かめた。本文では `[verified]` を付ける。
  - リポジトリ側: 行数（bin・lib・tests・蒸留文書の型ごとの本数と行数）、README の「目的」節の文言、`oe run` の state が 2026-06-04 で途絶えていること（`docs/discussions/2026-11-06-discussion-577-record-identity-key.md:51`）、配送シグナルの 97.6%（`docs/episodes/2026-08-03-episode-299-delivery-receipt.md:28`）、#577 の D10（`docs/decisions/2026-11-06-decision-577-record-identity-key.md:56`）、owner の「認知負荷が減る」（`docs/decisions/2026-10-24-decision-466-page-lifecycle-in-flow.md:54`）、`oe-ack` の利用実績（`bin/oe-ack:33-37`）、finalize の既定の目印（`lib/delegate-send.sh:66,221`）、小さな不具合2件（`bin/oe-capture:2`・`bin/oe-register:138,146`）、CI が無いこと。
  - 外側: Claude Code 公式の cross-session messaging・agent teams・agent view の各ページ、Agent of Empires のリリース一覧、Gas Town の README（いずれも 2026-11-10 に取得）。
- それ以外は調査の下請けの報告を引いたもので、`[unverified-summary]` として読む。推測は `[speculation]` とする。
- パスは、接頭辞の無いものを `projects/orchestration-engine/` からの相対とする。
- 同じ日に、別のクラウドのセッションが外の調査を2回目として広げた。1回目は「tmux と worktree で並べる道具」と Claude Code 公式が中心で、大小の OSS の横断が薄かったためである。下請け5本（2026-02 の21ツールの追跡・統括が子へ委譲する型の OSS・セッションを並べる層と端末・ほかの CLI の公式の口とプロトコル・設計のパターンと実践者の動向）の調査メモを `docs/draft/618-engine-research/` に足した。3.5 節から 3.9 節と、4節の書き直しがその反映である。
- 2回目の調査では、結論を左右する17ページを、書き手がもう一度取得させ、原文の引用で突き合わせた（2026-11-10）。引用で確かめられた主張にだけ `[verified]` を付ける。対象は、herdr の規模とライセンスと v0.9.5 の変更、Cyclops の配送の4段階、OpenAI 公式の Codex プラグイン、Anthropic の 2026-03-24 の記事、ai-orchestrator の設計 issue、Symphony の仕様書、Gas Town の設計書とコミット履歴、Gas City の移行の文書とコマンド対応表とリリース、Codex の hook と CLI リファレンス、CAO の配送の文書、multi-agent-shogun の README である。
- 突き合わせで、下請けの報告と原文が食い違った所が5つあった。本文はどれも原文に合わせてある。(1) Gas City の文書に「successor」の語は無い。(2) Symphony の仕様書は、統括が LLM でないとは明記していない。(3) Gas Town の README に Gas City への言及は無い。(4) Gas Town が agent teams へ乗る設計書は 2026-02-08 付けで、未実装と明記されている。(5) Codex の hook が既定で有効かどうかは、原文では確かめられなかった（信頼の確認を経てから走る、とは書かれている）。ページの取得は要約を挟む仕組みなので、`[verified]` でも、引用していない細部までは保証しない。
- 1回目の記述のうち、2回目で誤りと分かったものは 3.5 節にまとめ、本文の該当箇所も直した。

## 1. 要点

1. engine の中身は、性質の違う3つの層に分かれている。1つ目は、2026-05 の MVP である非対話の1サイクルの本体（`oe run`）で、06-04 以降は state が残っていない `[verified]`。2つ目は、tmux の `send-keys` で対話セッションへ委譲し、届いたかを確かめ、見張る層である。3つ目は、統括が落ちても持ち場が続くための lease・交代・復帰と、owner への問いを集める判断ボードである。README の「目的」節は1つ目の言葉で書かれたままで、冒頭の説明は2つ目と3つ目の言葉で書かれている `[verified]`。
2. 6か月の実装の大半は、2つの痛みへの手当てに使われてきた。対話セッションへ文を送ったときに届いたかが分からないことと、長く走る統括の文脈が尽きることである。配送の対策は少なくとも6回作り直され、そのうち1回は検知器が逆を指していた（`suspected_miss` の 97.6% が実は到達）`[verified]`。統括は 07-09 の3〜4代目から 11-06 の23代目まで交代している `[unverified-summary]`。
3. 2026-02 以降、外では「tmux と worktree でエージェントを並べて状態を見る」層が出そろった（Agent of Empires は 2026-11-08 に v1.22.3 で、ほぼ週次で出している `[verified]`）。Claude Code 公式にも、セッション間のメッセージ（同じマシンではセッションごとの Unix ソケットで届き、アイドルなら新しいターンを始める）と、落ちたセッションを再起動する supervisor が入った `[verified]`。子が Claude Code である限り、送信・生存監視・cockpit の表示は外へ寄せられる材料がそろった。
4. 外に同等のものが見当たらないのは、2回目の調査で2つに絞られた。1つは、LLM の統括のセッションの座を lease で排他し、後任へ世代交代させる組である。もう1つは、選択肢と根拠を付けて owner に1枚で出す判断ボードである。agent teams は「Lead is fixed」で、ネストもできない `[verified]`。1回目に同じ並びへ入れた「Claude Code 以外の CLI を子にする委譲」と「別ベンダーのモデルによるセカンドオピニオン」は、公式には無いが OSS には広くあり、セカンドオピニオンには OpenAI 公式の Claude Code 向けプラグインが出ている `[verified]`（3.8）。
5. 1回目の「統括の交代と stuck の検知を持つのは Gas Town だけ」は、探した範囲が狭かった。統括が子へ委譲し、見張り、文脈が尽きることへの手当てまで持つ OSS は少なくとも8件ある `[unverified-summary]`。そのうえ Gas Town 本体は、2026-07-23 のあと 10-20 まで main にコミットが無く、以後は依存の更新が大半である `[verified]`。仕掛けを取り出した先の Gas City は、見張り役（Deacon）の仕事を orchestrator の health patrol へ移した `[verified]`（3.5・3.6）。
6. 外の設計は、engine の痛みと同じ所で、3つの形に寄ってきている（3.8）。(a) 配送では、本文をファイルや台帳に置き、端末へ打つのは起こす合図だけにする。受領は hook の発火や、受け手が本文を取り出したことで確かめる。Gas City・multi-agent-shogun・Cyclops が別々にこの形へ着いた。(b) 状態の読み取りでは、各 CLI の hook による自己申告を主にし、画面を読むのは hook が黙ったときと承認のダイアログに限る。(c) 統括の文脈では、統括を長く生きる LLM のセッションにしないか、状態を統括の会話の外（台帳・ログ・ファイル）に置いて、統括はいつ入れ替わってもよいものにする。Anthropic は文脈のリセットを Opus 4.5 で外した `[verified]`。
7. #577 の D10 は「Claude Code への依存を深めないので、セッション間の文を送る機能には乗らない」と決めている `[verified]`。公式の文書には、スクリプトや hook からセッションのソケットへ投函する方法（`CLAUDE_CODE_MESSAGING_SOCKET`）と、届いたか・保留か・拒否かの3値が書かれている `[verified]`。2回目の調査で、D10 を保ったまま配送の痛みを減らす道（tmux のまま、本文と合図を分ける）も外に実例があると分かった。フェーズ3の最初の論点は、公式のソケットへ寄せる・本文と合図を分ける・いまのまま、の3つから選ぶ形になる。
8. Claude Code に固有の4つの口（#618 のコメント）のうち、プロンプトを受け取った印の hook・セッションの ID・再開の3つは、Codex へほぼそのまま移せる。拍動（statusLine）だけは、どの CLI にも同じ口が無い `[unverified-summary]`（Codex の hook と CLI のコマンドは `[verified]`）（3.9）。
9. 蒸留文書は engine の木で 208本・45,098行（decision・discussion・episode・plan の合計）あり、bin と lib を合わせた 14,727行の約3倍になる `[verified]`。owner の第一目的が「認知負荷が減る」ことである以上、文書の量と保守の手間も方向性の論点に入る。外の議論は、量を減らす・決定だけを分けて残す・繰り返す注意は文書でなく検査へ移す、でそろっている `[unverified-summary]`（3.8）。

## 2. 現在地（フェーズ1）

### 2.1 機能のまとまりと規模

bin は verb 29本・9,919行、lib は23本・4,808行、テストは53本・16,556行である `[verified]`。CI は無く、テストを一括で回すランナーも無い `[verified]`。

| まとまり | verb | bin の行数 | 性格 |
|---|---|---|---|
| 入口 | `oe` | 160 | #605 で足した振り分け役。`~/bin` に配る |
| 本体エンジン（WezTerm・非対話） | `oe-run`・`oe-capture` | 263 | 2026-05 の MVP。lib 9本（1,823行）を持つが、ほかのまとまりと共有するのは `session.sh` だけ |
| 委譲と送受信 | `oe-delegate`・`oe-kick`・`oe-send`・`oe-report`・`oe-ack` | 961 | 日々の主経路。送る本体は `oe-send` 152行と `lib/delegate-send.sh` 322行で小さい |
| 登記・宛先・木 | `oe-list`・`oe-select`・`oe-jump`・`oe-register`・`oe-tree`・`oe-ident` | 1,650 | cockpit の表示と移動。`oe-tree` が804行 |
| lease・交代・復帰 | `oe-lease`・`oe-handoff`・`oe-recover` | 2,284 | 最大のまとまり。`oe-handoff` 単体で1,410行 |
| 到達確認と見張り | `oe-confirm`・`oe-undelivered`・`oe-vitals`・`oe-activity`・`oe-threads`・`oe-status` | 2,414 | 読むだけの verb。定期実行が前提のものを含む |
| 前提の点検 | `oe-selfcheck`・`oe-hookfire` | 804 | 3値で判定する。定期実行は配線されていない |
| SO のゲート | `oe-refute`・`oe-review`・`oe-lane-explain` | 1,112 | `so-compare` を包む。engine のほかの部分と状態を共有しない |
| 文書の表示 | `oe-view` | 271 | WezTerm と glow に依存する |

出典は `docs/draft/618-engine-research/phase1-implementation.md` の1節 `[unverified-summary]`（合計の行数だけ `[verified]`）。

行数の重心は委譲そのものではなく、交代・復帰と到達確認・見張りにある。送る仕組みより、送ったあとを確かめる仕組みと、統括が落ちたときの仕組みのほうが4倍以上大きい。

### 2.2 3つの層の同居

README は「2系統」（本体エンジンと親子委譲 CLI）と書くが、実物は3つの層が同居している `[unverified-summary]`（`phase1-implementation.md` 6節の1）。

| 層 | 中身 | いまの使われ方 |
|---|---|---|
| (a) 本体エンジン | envelope → spawn → monitor → verify の1サイクル。WezTerm の整数のペイン番号と非対話の CLI で動く | state は 2026-06-04 が最後 `[verified]`。codex のディスパッチはスタブのまま（`lib/spawn.sh:177`）`[unverified-summary]` |
| (b) 委譲・送受信・見張り | tmux の `%N` のペインへ `send-keys` で送り、hook が受領の印を書き、見張りが読む | 毎日使われている。tmux で子を起こした event は 11-05 までに431件（`docs/discussions/2026-11-06-discussion-577-record-identity-key.md:51`）`[verified]` |
| (c) 統括の継続性 | lease の記録（#577）、交代（`oe-handoff`・#390）、復帰（`oe-recover`・#355）、判断ボード（#466・スキル `judgment-board-flow`） | 11月に入って中心になった層。lease への移行は registry との二重書きで止まっている |

文書の手順（蒸留の5段・昇格・ゲート）は engine のコードではないが、engine の運用を縛るスキル7本・1,881行として配られている `[unverified-summary]`（`phase1-history.md` 6.1）。

### 2.3 「誰が誰か」の置き場が4つある

同じ事実（どのセッションが統括で、どの子がどの親のものか）を、4か所が持っている `[unverified-summary]`（`phase1-implementation.md` 2.4・6節の2）。

- registry（`~/.claude/state/oe-delegate/`）。キーは tmux のペイン番号で、tmux を起こし直すと失われる。
- lease（`~/.claude/state/oe-lease/`）。自前の ID で、#577 以降の正本である。
- board の `現統括:` 行。宣言で、表示に下がった。
- heartbeat の sidecar（`~/.claude/state/oe-heartbeat/`）。session_id とペインを持つ。

書く側は registry と lease の両方に書き、読む側は lease を先に引いて、引けなければ registry に落ちる。`oe-list`・`oe-ident`・`oe-status`・`oe-ack`・`oe-tree` の既定は registry のままである。後片付けは #603 に回っている。

子から親へ返す経路も3本ある。`oe send --to-parent`（lease 経由）、`oe-send "$PARENT_TMUX_PANE"`（素のペイン）、`oe-report`（legacy）である。

### 2.4 環境への縛り

- tmux の `send-keys` と `capture-pane` が transport そのものである。
- Claude Code の画面の文字列を読む。finalize は入力欄の `❯` と、処理中の目印 `esc to interrupt` を既定で見ている `[verified]`。`oe-selfcheck` には、その目印が消えたのに約2か月気づかなかったと書かれている `[unverified-summary]`。壊れた前提を直す代わりに、壊れていることを検出する検査を足した形になっている。
- Claude Code の hook の契約（`UserPromptSubmit` の stdin と `TMUX_PANE` の伝播、statusLine の stdin）に、受領の印と生存の拍動が乗っている。
- macOS の launchd・BSD の `stat`・bash 3.2 を前提にした箇所がある。Linux の sandbox でテストを回すと53本中9本が赤になった。原因の大半は root での実行（chmod で読めない置き場を作るテストが成り立たない）と yq の実装の違いである `[unverified-summary]`。
- jq の呼び出しは bin と lib で442か所ある `[unverified-summary]`。

### 2.5 人が手を動かしている所

- 見張り3本（`oe-confirm`・`oe-undelivered`・`oe-vitals`）と点検2本（`oe-selfcheck`・`oe-hookfire`）は、定期実行の配線がリポジトリに無い。launchd のテンプレートがあるのは `oe-confirm` だけで、入れるには手作業が5手順要る `[unverified-summary]`。見張りが黙ったことを拾う `oe-selfcheck` 自身を、人が打たないと動かない（#301 は park 中）。
- 報告を読んだ印の `oe-ack` は手で打つ verb で、導入から約6週間で1件しか打たれていない `[verified]`（`bin/oe-ack:33-37`）。`oe-undelivered` はこの印を起点にしている。
- 交代では、引き継ぎ文書の自己申告の表に処分を書くこと、各子へ新しい宛先を伝えること、登記をつけかえることを、人か統括が持つ `[unverified-summary]`。
- 復帰では、手順5つのうち1〜3（気づく・`oe recover hint` を打つ・出た1行を新しいペインで打つ）を owner が持つ。verb は前の claude を閉じない `[unverified-summary]`。

### 2.6 目的の書かれ方の変化

文書に書かれた「engine とは何か」は、時期ごとに次のように動いている。原文の引用は `phase1-history.md` 5.1 にある `[unverified-summary]`（05-19 と 10-24 の引用は `[verified]`）。

| 時期 | engine とは | 人の位置 |
|---|---|---|
| 2026-05 | 非対話の1サイクルを自律に回すルーティングエンジン | 常駐しない |
| 05-19 | 「daily driver」ではなく「specialized instrument」。パイプラインの特定の段で起動する道具。Build to Delete | ゲートで承認する |
| 06月〜 | 人が覗ける対話セッションを並列に起こして渡す委譲の道具と cockpit | 画面を見て介入する |
| 07〜09月 | 長く走る統括を見張り、交代させる仕組み | 異変に気づく役から外したい |
| 10〜11月 | owner の判断を1枚に集め、統括が落ちても持ち場が続く記録を持つ道具。独立パッケージにする方向（#537） | 判断だけを返す |

05-19 のパイプライン駆動の方針（Epic #105・Phase 5）を取り下げた文書は無く、discussion は `draft` のまま残っている `[unverified-summary]`。「Build to Delete」と「独立したパッケージ」は向きが違うが、どちらが今の意図かを書いた文書も無い。owner がいちばん新しく第一目的として挙げたのは、並列のタスクに迷わず「認知負荷が減る」ことである `[verified]`。

### 2.7 繰り返し出てくる痛み

件数は episode などの言及数で、事故の回数ではない（`phase1-history.md` 3節）`[unverified-summary]`。

| 痛み | 言及 | 代表例 |
|---|---|---|
| 送ったのに届かない、届いたかが分からない | episode 45本 | 自動の Enter が吸収される（06-09）、受け手の copy-mode（06-16）、検知器が逆を指す（08-03）、nonce 付き送信927件のうち受領の印が無い210件、うち142件は印を書けなかっただけ（09-11） |
| 統括の文脈が尽きて交代する | episode 31本 | 4か月で約20回の交代。交代のたびに立ち上げのプロンプト36行と引き継ぎ50行を手で書いていた（09-11 まで）。引き継ぎ文書は約5万1千トークン（#618 本文） |
| ペイン番号をキーにした取り違え | episode 15本 | 後継が前任の子として表示される（07-13）、registry の全消しが3回（08-14）、統括が落ちて子3本の宛先が切れる（10-27）。同じ痛みに #188・#247・#577 で3回判断した |
| 画面を読んで誤判定する | episode 11本以上 | マーカーの取りこぼし、引用との偶然の一致、生の capture の貼り付けで会話が壊れる |
| owner への問いが流れる・重なる | decision 2本 | 1週間に判断のページが15枚（10-24）、約30分で割り込み6件以上（10-27）。判断ボードの問いは 10-24 の Q1 から 11-10 の Q105 まで進んだ |
| 判定器や承認で止まる | episode 5本 | 承認の中継を auto モードの判定器が2回止めた（10-05〜06） |

いちばん長く続いているのは配送の痛みで、「届かない」ことそのものより、「届いたかを確かめる仕組みが外れる」ことが繰り返されている。

### 2.8 止まっている計画

`phase1-history.md` 4.1 から主なものを挙げる `[unverified-summary]`。plan の status は保守されておらず（`draft` 17本の大半は実装済み）、status だけでは止まっているかを判定できない。

- Phase 5（Epic #105・パイプライン駆動）。実装は `oe-capture`（05-26）だけで、続きの文書が無い。
- 本体エンジン `oe run`。06-04 以降の実行記録が無い。派生の #93 は open のまま。
- `oe-selfcheck` の定期実行（#301）。見張りの「出口」（誰が検査を走らせ、誰が読むか）が決まっていないので park になっている。
- #577 の移行の後片付け（#603）。lease を持たない統括と古い子が生きていたので外せなかった。
- 判断ボードの残り（#539 作業の表、#540 出し忘れを知らせる道具、#329 SO のまとめ）。
- engine を独立したパッケージにする #537。複数の decision がこれを見越して設計しているが、#537 自体の plan も decision も無い。

### 2.9 小さな不具合（実物で確かめたもの）

フェーズ3とは独立に直せるものとして挙げる。

- `oe --help` で `capture` の説明が空になる。入口は各ファイルの2行目から説明を取るが、`bin/oe-capture:2` は `set -euo pipefail` である `[verified]`。
- `oe-register --help` は tmux の外で exit 1 になる。`TMUX_PANE` の検査（`bin/oe-register:138`）が `--help` の処理（`:146`）より前にある `[verified]`。`tests/test_home_unset.sh` は tmux の中で回したときだけ緑になる `[unverified-summary]`。
- `bin/README.md` の `oe-selfcheck` の検査表は5行だが、実装には6つ目の `watchdog-freshness` がある `[unverified-summary]`。

## 3. 外との比較（フェーズ2）

### 3.1 2026-02 の調査の結論と、いまとのずれ

2026-02-22 の調査（`projects/orchestration-research/`）の結論は、「CLI のランタイムは借り、協調のプロトコルとコンテキストの設計を Bash と jq で薄く作る」だった（`synthesis/architecture-sketch.md` §1・§2・§5）`[unverified-summary]`。engine の独自性として主張していたのは、認知の協調・昇格のフロー・ゲートの実行の証跡など、意味の層に限られる。委譲・観測・lease を「ほかに無い」とする文書は無く、インフラの層は「自前で書く必要がない」と認めている（`projects/orchestration-research/README.md`）`[unverified-summary]`。

いまの engine は、そのとき「借りる」としたプロセスの管理（送信・生存・復帰）に、自前の実装を最も多く積んでいる。2.1 の行数の重心がそれを示している。ずれの理由を書いた文書は無い `[speculation]`。dogfood で毎日使う中で、借りる先が当時は無かった所を自分で埋めたと読める。

#605 の調べもの（`docs/discussions/2026-11-09-discussion-605-single-entry-command.md`）は CLI の入口の作り方の比較で、agent-of-empires などと engine の機能の重なりは、リポジトリのどの文書にも書かれていなかった `[unverified-summary]`。3.3 の表がそれを初めて埋める。

### 3.2 2026-02 以降に外で変わったこと

Claude Code 公式（`code.claude.com/docs`）:

- **セッション間のメッセージ**（v2.1.224 以降）。同じマシンでは、セッションごとの Unix ソケットで届き、Anthropic のサーバーを通らない。受け手が作業中ならツール呼び出しの合間に読み、アイドルなら新しいターンを始める。受け手の側で、届けた・保留した・拒否したの3つに分かれる。ソケットのパスは hook と Bash に `CLAUDE_CODE_MESSAGING_SOCKET` として渡され、スクリプトや hook から投函できる。受け手の Claude には「利用者ではなく別のセッションから来た」と伝えられ、承認の代わりにはならない `[verified]`（https://code.claude.com/docs/en/cross-session-messaging）。
- **agent view とバックグラウンドのセッション**。supervisor が、予期せず終了したセッションを再起動する。マシンのシャットダウンと再起動では止まる。research preview で、外から状態を読む方法として支えられているのは `claude agents --json` で、`~/.claude/jobs/` の中のファイルは安定した接点ではない `[verified]`（https://code.claude.com/docs/en/agent-view）。
- **agent teams**。実験的で、既定では無効。制限として「Lead is fixed」（lead を移せない）、チームのネスト不可、`/resume` で in-process の teammate が戻らない、と書かれている `[verified]`（https://code.claude.com/docs/en/agent-teams）。
- ほかに、subagent のネスト（既定で3層まで）、Dynamic workflows（中間結果をスクリプトの変数に置き、Claude の文脈には最終結果だけが入る）、Projects（統括の会話が全履歴でなく最近のメッセージと project memory から動く・public beta）、hook のイベントの拡張（`StopFailure`・`PostCompact` など）がある `[unverified-summary]`（`phase2-external.md` 2節）。

並べて状態を見るツール:

- Agent of Empires は、tmux のセッションと git worktree を束ね、状態の検出と通知を持ち、Claude Code・Codex・Gemini CLI などを扱う。2026-11-08 に v1.22.3 を出した `[verified]`。claude-squad・CCManager・cmux・herdr も同じ層にいる。どれも「人が各セッションを操る前提で並べる」もので、親子の委譲は持たない `[unverified-summary]`。
- Gas Town は、統括（Mayor）・作業者・見張り（Witness・stuck を検出して回復させる）を持ち、文脈を入れ替える handoff を持つ `[verified]`（https://github.com/gastownhall/gastown）。ただし 2回目の調査で、本体は機能の変更が止まり、後継の Gas City へ重心が移ったと分かった（3.5）。
- Vibe Kanban は運営会社が 2026-04 に止まってコミュニティの保守になり、Crystal は 2026-02 に deprecated になった `[unverified-summary]`。

他社の CLI（多くは二次情報）:

- Codex CLI 0.167.0（2026-11-06）に `codex agents` と subagent の親子関係の保存が入った。Gemini CLI は subagent が既定で有効で、ネストはできず、A2A で remote の subagent に渡せる。どの公式機能も自社のエージェント同士の委譲に閉じている `[unverified-summary]`。

### 3.3 engine の機能ごとの対照表

判定は「ある（外へ任せられる水準）」「部分的にある（条件付き）」「見当たらない」の3つ。`phase2-external.md` 6節の表を、2回目の調査（`phase2-supervisor-orchestrators.md` 7節・`phase2-session-managers.md` 6節・`phase2-patterns-and-practice.md`）で更新した `[unverified-summary]`。

| engine の機能 | 判定 | 外にあるもの | 足りないもの |
|---|---|---|---|
| 委譲と送受信 | 部分的にある | Claude Code のセッション間のメッセージ（ソケット・3値の結果）。tmux のままなら Cyclops（配送を4段階に分ける）、CAO の inbox（受け手が待機中のときだけ届け、Enter を送り直す）、Gas City と multi-agent-shogun（本文は hook かファイル、端末は合図だけ） | 公式のソケットは、受け手が読んで着手したことまでは返さず、Claude Code 以外へは送れない。OSS 側は小さいもの（Cyclops はスター14）か、engine と土台が違うもの |
| 登記と木構造 | 部分的にある | `claude agents --json` の一覧、agent teams の members、agent-deck の conductor の親子、tmux-agent-sidebar の木 | セッションをまたぐ任意の深さの親子の木 |
| 生存監視 | ある（子が Claude Code なら） | agent view の supervisor、hook の `StopFailure`・`Notification`。ほかの CLI は herdr・Agent of Empires・workmux などの hook と画面読みの併用 | 見張りが黙ったことを拾う層は、どれも「最下層を LLM でない機械にする」作りで、engine にはまだ無い |
| 世代交代と lease | 見当たらない（統括の座の lease）、部分的にある（交代） | 交代は Gas Town の handoff、NTM の context rotation、multi-agent-shogun の `/clear` と読み直し。lease はタスクとファイルについては多数ある（Hermes の Kanban、mcp_agent_mail、Beads） | LLM の統括の座の排他。公式は lead を移せない。外の主流は、統括を LLM にしないことで排他の要る場面を作らない |
| 復帰 | 部分的にある | supervisor の再起動、保存した会話からの再開、herdr や workmux の復元 | マシンの再起動のあとの自動の再開、統括と子の関係ごとの復元 |
| セカンドオピニオン | ある | OpenAI 公式の Codex plugin for Claude Code（`/codex:review`・`/codex:adversarial-review`）`[verified]`、PAL MCP、Oracle | SO を手順のゲートとして必ず通す仕組み（`oe-refute`・`oe-review` の役目）は、metaswarm のほかに見当たらない |
| cockpit の表示 | ある | agent view、Agent of Empires、cmux、herdr、agent-deck、workmux | engine に固有の状態（木・lease）を映すこと |
| 判断ボード | 部分的にある | agent view の Needs input、Projects の「Waiting on you」、Gas Town の escalate。同じ形の設計は ai-orchestrator の issue（2026-11-08・問いの共通のキュー・選択肢・まとめて答える）`[verified]` と、個人作の decisions、TAKT の director（実験的） | 選択肢と根拠を付けて1枚にまとめて出すことを、運用まで回している公開の実装 |

### 3.4 外の変化で、engine の前提が動いた所

- **送信の transport。** engine は、受け手の入力欄の状態（下書き・確認のダイアログ・copy-mode）に左右される `send-keys` の上に、届いたかを確かめる層を4つ積んできた（2.7）。公式のメッセージは入力欄を通らず、届けたかどうかを送り手に返す `[verified]`。子が Claude Code の場合に限っては、配送の痛みの元を transport ごと取り替えられる可能性がある `[speculation]`。ただし、親の Bash から子のソケットへ投函する形（子がソケットのパスを lease に書き、親がそれを読む形など）が、権限の扱いや macOS の制約まで含めて実用になるかは、実機で確かめていない。
- **生存監視と cockpit の表示。** 子を Claude Code のバックグラウンドのセッションとして起こせば、再起動と状態の一覧は公式が持つ `[verified]`。engine の見張り3本と点検2本が定期実行の配線を持たないまま止まっている（2.5）こととあわせると、自前で持ち続ける理由は薄くなっている `[speculation]`。一方で、agent view は research preview で、マシンの再起動では止まる。
- **変わらなかった所。** 統括の座の排他と交代、判断ボードは、外に同等のものが無いままである。2026-02 の調査が独自性として挙げた意味の層と、11月に中心になった層（2.2 の (c)）がここに当たる。ほかの CLI を子にすることと、別ベンダーのセカンドオピニオンは、公式には無いが OSS には広くある（3.8）。

### 3.5 2回目の調査で広げた範囲と、1回目の訂正

1回目は、tmux と worktree で並べる道具と Claude Code 公式を中心に見た。2回目は、次の5つへ広げた。調査メモはどれも `docs/draft/618-engine-research/` にある。

| 調査メモ | 見た範囲 |
|---|---|
| `phase2-landscape-followup.md` | 2026-02 の21ツールと steipete の番外が、9か月でどうなったか |
| `phase2-supervisor-orchestrators.md` | 統括が子へ委譲し、見張り、長く走る型の OSS。候補25件と、候補に無かった17件を開いた |
| `phase2-session-managers.md` | セッションを並べ、状態を見て、入力を送る層と、エージェント向けの端末。状態の検出と入力の送信の方式 |
| `phase2-vendor-cli-and-protocols.md` | Codex・Gemini・Cursor・Copilot・OpenCode などの、外から束ねるための口。ACP・MCP・A2A |
| `phase2-patterns-and-practice.md` | 設計のパターンと実践者の動向。engine の痛みを外がどう解いているか。日本語圏の記事 |

1回目の記述のうち、訂正するものは次のとおりである。

| 1回目の記述 | 訂正 | 根拠 |
|---|---|---|
| 親子の委譲・監視・世代交代まで持つのは Gas Town だけ | 委譲と監視と文脈への手当てを持つものは少なくとも8件ある（Gas Town・Gas City・multi-agent-shogun・NTM・agent-deck の conductor・Hermes Agent の Kanban・Overstory・Claude Code Agent Farm）。Gas Town だけなのは、LLM の統括を handoff で交代させ、前任のセッションへ問い合わせる Seance まで持つ点である | `[unverified-summary]` `phase2-supervisor-orchestrators.md` 8節 |
| Gas Town は現役で保守されている | main のコミットは 2026-07-23 のあと 10-20 まで無く、以後は依存の更新とビルドの修正が大半である。仕掛けを取り出した先が Gas City（v1.5.1・10月24日）で、Gas City には Seance も escalate も無い。handoff は `gc handoff` として残る | `[verified]`（コミット履歴・コマンド対応表・リリース） |
| Gas Town は tmux の輸送を公式へ寄せつつある | agent teams に Witness を載せる設計書はあるが、2026-02-08 付けで「NOT YET IMPLEMENTED」のままである | `[verified]` |
| herdr は AGPL-3.0 | 本家は Apache-2.0 で、スターは約5万。1回目に開けたのはフォークだった | `[verified]` |
| Crystal の後継の Nimbalyst は有償のクローズドソース | MIT のオープンソースである | `[unverified-summary]` `phase2-session-managers.md` 2節 |
| Codex の subagent が既定で有効かは出典が割れている。`codex mcp-server` で Codex を子にできる | subagent は既定で有効とされる `[unverified-summary]`。`codex mcp-server` は削除され、app-server を使うよう案内されている `[verified]` | `phase2-vendor-cli-and-protocols.md` A.1 |
| lease に当たる公開の実装は見当たらない | 統括の座については同じ結論である。タスクとファイルの lease は多数ある（Hermes の Kanban は claim に TTL と heartbeat を持つ） | `[unverified-summary]` `phase2-supervisor-orchestrators.md` 7.1 |
| 別ベンダーのモデルに見せる仕組みは公式に無い | Claude Code の側には無いが、OpenAI が Claude Code 向けの公式プラグインを出している（約3.5万スター） | `[verified]` |

### 3.6 外の OSS の地図（2026-11）

統括が子へ委譲する型の OSS を、作りで分けると次のようになる（`phase2-supervisor-orchestrators.md` 6節）`[unverified-summary]`。

| 類型 | 作り | 主なもの | 統括の文脈への手当て | engine との距離 |
|---|---|---|---|---|
| tmux 階層型 | 役を決めた親子を tmux のペインに並べ、ファイルと `send-keys` でつなぐ | multi-agent-shogun、CAO、agent-deck の conductor、NTM、OpenRig、codex-orchestrator | `/clear` と読み直し、context rotation | 最も近い。土台（Bash・tmux・hook）まで同じなのは multi-agent-shogun |
| 台帳中心型 | 仕事と状態を課題の台帳に置き、セッションは短命で入れ替えられる。引き継ぎは台帳そのもの | Gas Town、Gas City、Beads、Hermes の Kanban、Paperclip | 台帳へ外に出す。交代は「新しいセッションが台帳を読む」だけ | 中。engine は対話のセッションを主に置く |
| メールボックス型 | 永続の mailbox で連絡し、受領の確認や予約を持つ | Cyclops、mcp_agent_mail、hcom、ClawTeam | 本文を端末に流さない | 配送と受領の確認の面で近い |
| 制御ループ型 | デーモンや reconcile のループが配り、やり直し、片付ける。LLM は子だけ | Symphony、Gas City の orchestrator、Hermes の dispatcher、bernstein | 統括に文脈が無いので問題にならない | 遠いが、流れはこちらへ向いている |
| 公式機能に乗る型 | agent teams や subagents を土台に、手順とほかの CLI の呼び出しを足す | oh-my-claudecode、metaswarm | 公式の compaction に任せる | 方針しだい |
| ループ型・仕様書駆動型 | 同じ指示を新しい文脈で繰り返す、または文書で役割と手順を定める | ralph-orchestrator、BMAD-METHOD | 反復ごとの新しい文脈、計画を文書へ | 遠い |

セッションを並べる層では、次の動きがあった（`phase2-session-managers.md` 5節）。

- 状態の検出は、各 CLI の hook による自己申告が主になり、画面を読むのは従になった。ただし置き換わってはいない。herdr は v0.9.5 で Codex の hook を入れるのをやめ、画面の検出へ戻した `[verified]`。hook が黙ったときのために、無音の時間で見張る部品（10秒・5分・10分）を各ツールが持つ `[unverified-summary]`。
- 入力の送信は、端末へ打つ形のままのものが多い。変わったのは外側で、応答を返す API、送信と「状態が変わるまで待つ」を1回にまとめる要求、hook のイベントで受領を確かめる仕組みが出そろった。Superset の `terminals send --wait` は、送って10秒以内に新しい hook のイベントが出なければ失敗にする `[unverified-summary]`。
- tmux の上に薄く乗るもの（agent-deck・workmux・Agent of Empires・Cyclops）と、tmux ごと置き換えるもの（herdr・tuios・cmux）に分かれる。workmux は tmux と WezTerm の両方を土台にできる `[unverified-summary]`。

### 3.7 2026-02 の21ツールのその後

`phase2-landscape-followup.md` の要約である `[unverified-summary]`。

- 近縁のツールは一つも消えず、スターは数倍から20倍になった。ただし、同じ形のまま伸びたものは少ない。
- **agent-orchestrator** は、Bash 由来の「DB なし・フラットファイル・tmux」を捨て、Go のデーモンと SQLite と変更の追記ログへ移った。tmux は legacy の扱いである。engine がいまいる場所は、このツールが出発した場所に近い。
- **CAO** は、engine に構造が最も近いまま残った（tmux・統括と作業者・inbox・SQLite）。画面の読み方を、生の出力への正規表現から、端末として描画した画面を読む形へ替えた。配送は、受け手が待機中のときだけ届け、貼り付けたあと8秒のうちに処理の始まりが見えなければ、最大2回まで立て直す `[verified]`。
- **TAKT** は、常駐の `takt manager` と、複数の manager をまたいで未回答の問いを見回る `takt director` を足した（実験的）。判断ボードへ外から最も近づいている動きである。
- **oh-my-claudecode** は、公式の agent teams に乗る `/team` と、tmux でほかの CLI を起こす `omc team` の二本立てを保っている。
- 止まったのは、o-m-cc（凍結）、Aider（リリースが1年無い）、AutoGen と ControlFlow（アーカイブ）、MetaGPT である。
- 伸びた設計は、計画をモデルの気分ではなくスクリプトやワークフローの定義が持つ形である。消えた設計は、中央を置かない P2P の協調、ほかの CLI を MCP サーバーで包む経路、画面の生の出力への正規表現である。

### 3.8 痛みごとに見た外の解き方と、engine の位置

2.7 の痛みを、外がどう解いているかと並べる。位置の判定は、下請けと書き手の読みである `[speculation]`。もとにした事実は `phase2-patterns-and-practice.md` と `phase2-supervisor-orchestrators.md` にある。

| 痛み | 外の主流の解き方 | engine の位置 |
|---|---|---|
| 送ったのに届かない、届いたかが分からない | 本文はファイルや台帳に置き、端末へ打つのは起こす合図だけにする。受け手が状態を自分で申告する。合図を落としても、正本を読みに行けば拾える作りにする。multi-agent-shogun は `send-keys` の入力の衝突に48回の修正を重ねてから、この形へ移った `[unverified-summary]`。README は「メッセージ内容は tmux を経由しない」と書く `[verified]`。Cyclops は配送を Accepted・Notified・Claimed・Completed に分ける `[verified]` | 遠回りしている。6回の作り直しは、外が先に通った道と同じである。一方、「届いた」と「読んで着手した」を分ける考え方は、外でも少数の先頭と並んでいる |
| 統括の文脈が尽きて交代する | 状態を統括の会話に持たせない。統括は、いつ入れ替わっても正本から立ち上がれるものにする。Anthropic は、Sonnet 4.5 では要った文脈のリセットを Opus 4.5 で外した `[verified]`。交代を続ける側は、引き継ぎを小さく保つ。Gas Town は「台帳の状態がそのまま handoff である」とし、Amp は次の目的に要る分だけを抜き出す `[unverified-summary]` | 交代そのものは並んでいる。引き継ぎの文書が約5万1千トークンに育った点は遠回りしている |
| ペイン番号をキーにした取り違え、統括の座の排他 | 環境変数で渡す固定の名前や ID、tmux の変わらないペイン ID、会話の UUID を使う。座は名前で一意にして、セッションは使い捨てにする。または統括を1つのデーモンにして、排他の要る場面を作らない | ペイン番号をキーにした点は遠回りしていた（#577 で直している）。統括の座の lease は、公開の実装がほぼ無く、先に着いている。ただし外は、lease の要らない作りで済ませている |
| owner への問いが流れる・重なる | どのセッションが待っているかの一覧と通知までが主流である。問いを項目にし、選択肢を付け、1か所に集めてまとめて答える設計は、2026年の後半に個人作で出始めた段階である `[verified]`（ai-orchestrator の issue・2026-11-08） | 先に着いている。外の議論が足しているのは、上げる量そのものを減らすことと、答えを束で返して統括を1回だけ起こすことの2つである |
| 見張りが黙ったことに気づけない | 最下層を LLM でない機械（cron・systemd・デーモン）にする。見張られる側が拍動を自分で書き、見張る側は鮮度だけを閾値で見る。監督は主経路から外し、例外だけを見る。Gas Town は、作業者の完了を見張り役が1件ずつ通す作りで詰まり、作業者が自分で待機へ移る形に直した `[unverified-summary]` | 問題の捉え方は並んでいる。解は外に定石があり、engine はその手前にある（2.5 の未配線） |
| 文書がコードの3倍ある | 短い目次と正本の `docs/`、機械的な鮮度の検査。決定だけを分けて残す。計画と作業のログは残さない。繰り返す注意は検査へ移す。Anthropic の 2026-11-06 の記事は、書きすぎた記憶が成績を下げた実験を報告している `[unverified-summary]` | 決定を残す規律は並んでいる。量は遠回りしている |

ほかに、次の2点が方向性に効く。

- **セカンドオピニオンの効き方。** 2026-10 のプレプリント（900回のレビューの対照実験）は、別のモデルによるレビューと、同じモデルの新しいセッションによるレビューに、有意な差が無かったと報告している。効くのは、別のベンダーであることより、白紙の文脈であることと、レビュー役が十分に強いことだと読める。別のモデルは、2回目のレビューとして足すと上積みがある `[unverified-summary]`（要旨だけを読んだ・`phase2-patterns-and-practice.md` 6.2）。
- **足場を外す動き。** Anthropic の 2026-03-24 の記事は「every component in a harness encodes an assumption about what the model can't do on its own」と書き、モデルが新しくなるたびに部品を外して確かめたと述べる `[verified]`。外の実践者が挙げる目安は「外すのに1時間なら選択肢、1週間なら負債」である `[unverified-summary]`。05-19 の「Build to Delete」（2.6）は、この流れと同じ向きである。

### 3.9 Claude Code 以外の CLI を子にする口

#618 のコメント（統括も子も Claude 固定でなく選べる形）の材料である。`phase2-vendor-cli-and-protocols.md` の要約で、Codex の hook のイベントと CLI のコマンドだけ `[verified]`、ほかは `[unverified-summary]` である。

| Claude Code の口 | Codex | Gemini CLI | Copilot CLI | OpenCode |
|---|---|---|---|---|
| 拍動（statusLine） | 同じ口は無い。ツール実行の hook か、app-server の状態の通知で代える | 同じ口は無い。hook で代える | 同じ口は無い。hook で代える | `GET /event` の SSE を購読する |
| プロンプトを受け取った印の hook | `UserPromptSubmit` がある | `BeforeAgent` がある | `userPromptSubmitted` がある | シェルの hook は無い。SSE かプラグイン |
| セッションの ID | hook の標準入力と `exec --json` の出力から取る。環境変数は当てにできない | hook の標準入力から取る | hook の標準入力から取る | `session list --format json` と API |
| 再開 | `codex resume <ID>`・`codex exec resume <ID>` | `gemini --resume <UUID>` | `--resume` はあるが定義は未確認 | `opencode run --session <id>` |

- Codex の hook には `UserPromptSubmit`・`Stop`・`SessionStart`・`SessionEnd`・`PermissionRequest` がある `[verified]`。形は Claude Code に寄せてあり、Codex・Gemini・Cursor は Claude Code の hook との互換のための環境変数や移行の処理を持つ。
- 外部のコマンドを一定の間隔で呼ぶ口（statusLine）は、調べた範囲でどの CLI にも無い。差し替える層は、口の名前ではなく役割（起こす・送る・受領を確かめる・生存と状態を得る・ID を得る・再開する・判断待ちを知る）で切ることになる `[speculation]`。
- Codex には、打鍵のほかに送る口がある。`codex queue --thread <ID> --message`（Stable の表記）と、app-server（Experimental）である `[verified]`。`codex queue` が、動いている最中のセッションへどう届くかは文書に無い。
- どの CLI にも、対話なしの実行と JSON の出力と再開がある。「対話なしで仕事を進め、人が見たいときだけ同じ ID を対話で開き直す」が、全 CLI に通る最小の形になる。
- 相手の CLI を MCP サーバーとして子にする道は、公式には細っている。Codex は口を削り、`claude mcp serve` は道具だけを出す。ACP は、送る・状態を読む・承認に答える・再開するまで安定しているが、子が画面を持たないので、人が途中で覗いて手を入れることと両立しにくい。
- Gemini CLI は 2026-06-18 に個人向けの提供を止め、Antigravity CLI へ移ったとされる。

## 4. 見取り図（フェーズ3に向けて）

### 4.1 engine を「残す層」と「寄せうる層」に分けて見る

2.2 の3つの層と 3.3 の対照表を重ねると、次の切り分けが見える。これは決定ではなく、決めるときの地図である。

| 層 | 外との関係 | 考えられる扱い |
|---|---|---|
| (a) 本体エンジン（`oe run`） | 公式の workflows や subagent が近い | 凍結して `projects/_archived/` へ移す、残す、パイプライン駆動の構想（#105）とあわせて作り直す |
| (b) 送受信・見張り・表示 | 子が Claude Code なら公式に寄せうる。tmux のまま堅くする実例も外にある（本文と合図を分ける）。ほかの CLI の子は tmux か、対話なしの実行が残る | tmux を続けて本文と合図を分ける、Claude Code の子だけ公式のメッセージと agent view へ寄せて tmux はほかの CLI のための経路にする、表示は外の道具（agent view・agent-deck・workmux など）を併用する |
| (c) 統括の継続性と判断ボード | 外に同等のものが無い。ただし外は、統括の状態を会話の外へ出して、交代と排他を軽くする向きである | engine の中心として残し、独立したパッケージの芯にする。交代を磨くか、統括の持つ状態を記録へ出して交代を軽くするかは Q5 |
| (d) 文書の手順 | engine のコードではない | engine から切り離してハーネスに置く、軽くする |
| (e) SO のゲート | 呼び出す道具は OpenAI 公式のプラグインなどが外にある。手順のゲートとして必ず通す仕組みは外にほぼ無い | `so-compare` を続ける、呼び出しを公式のプラグインへ寄せてゲートの判定だけを持つ |

### 4.2 フェーズ3で決めること

#618 本文の候補3つと、コメントで足された1つに、この下調べで出てきた論点を足した。並びは、前の決定があとの決定の前提になる順にしてある。

| # | 決めること | 選択肢 | 材料 | 書き手の見立て |
|---|---|---|---|---|
| Q1 | engine は何を目指すか（目的と非目的） | 05-19 の「specialized instrument・Build to Delete」に戻す、10月の「認知負荷を減らす統括の道具」にする、ほかに切り直す | 2.6、owner の第一目的（10-24）、#537 | 認知負荷を第一目的に置き、README の「目的」節をそれで書き直すのが、ほかのすべての前提になる |
| Q2 | 本体エンジン `oe run` を残すか | 凍結して移す、残す、作り直す | 2.2 の (a)、06-04 以降の記録が無いこと | 凍結して移すと、lib 9本（1,823行）と #93 などの派生 issue を整理できる。パイプライン駆動の構想を続けるなら、そのときに作り直すほうが軽い |
| Q3 | 送信の transport（#577 D10 の見直し） | (ア) tmux の `send-keys` をいまのまま続ける、(イ) tmux は続け、本文はファイルに置いて端末へは合図だけを打ち、受領は hook の発火で確かめる、(ウ) Claude Code の子は公式のメッセージへ寄せる、(エ) イとウを両方持つ | 3.4、3.6、3.8、2.7 の配送の痛み、D10 | (イ) は D10（Claude Code への依存を深めない）を保ったまま痛みの元を減らせ、Codex の子にも同じ形で通るので、先に試す値打ちがある。(ウ) は小さな実地の試験（子1本に公式のメッセージで送り、届いた・保留・拒否を記録する）をしてから決める。D10 は owner の答え（Q67）なので、試験の結果を添えて問い直す形がよい |
| Q4 | 生存監視と cockpit の表示を外に寄せるか | 自作を続ける、agent view や外の道具（agent-deck・workmux・Agent of Empires）を併用して自作は engine に固有の状態だけにする | 3.3、3.6、2.5 の未配線 | Q3 の結論に従う。寄せるなら、#546・#570・#547 など cockpit の表示の issue は畳める。見張りを残すなら、最下層を LLM でない機械にし、拍動の鮮度で沈黙を拾う形（3.8）へ寄せる |
| Q5 | 統括の世代交代をどう扱うか | 交代を続ける、世代0から始める既定にする、統括の状態を会話の外（記録・台帳）へ出して交代を軽くする、Projects 型の「文脈を構造で小さく保つ」形に寄せる | 2.7、3.8、#609、引き継ぎ文書の約5万1千トークン、Projects の文脈の設計 | 交代を磨くより、統括の会話に積まない設計を先に検討する価値がある。外で交代を続けている側は、どれも引き継ぎを小さく保っている（台帳の状態を引き継ぎにする、次の目的に要る分だけ抜き出す、上書きのスナップショットにする）。lease と board はすでに会話の外にあるので、引き継ぎの文書から何を lease と board へ移せるかが最初の問いになる |
| Q6 | 1つのリポジトリに複数の統括を置くか | 置かない、置く（区別の仕方を決める） | #618 本文、lease の label・board・セッション名が1人の前提 | この Epic を別の統括で進めることが最初の実地になる。このクラウドのセッションもその1つで、hub の lease も board も持たずに下調べができた |
| Q7 | ハーネスとエンジンの境目をまたぐ hook と検査の置き場 | hook を engine の持ち物にする、記録の形を見本で固定して書く側と読む側の検査を分ける | #618 のコメント（`test_session_name.sh`・`test_prompt_receipt.sh`） | Q3 と Q4 の結論で、受領の印の hook の役目自体が変わりうるので、そのあとに決める |
| Q8 | 名前と独立したパッケージの境界 | #618 本文のとおり、目的が決まってから付ける | #537、#564、#605 | Q1 から Q7 の結果として決まる。パッケージに入れるのは (c) と、残すと決めた (b) |
| Q9 | 文書の手順の重さ | いまのまま、型や必須の節を減らす、engine の木から切り離す | 1節の6、2.8 の status の保守、`phase1-history.md` 6.3 | engine の方向性とは別の Epic に切り出すのがよい。ただし (d) を engine から外すかどうかは Q8 と一緒に決める |
| Q10 | Claude Code 以外の CLI を子にするか。するなら、差し替える層をどう切るか | しない、する（#562）。するなら、対話なしの実行を都度起こす形を全 CLI の基準にする、Codex には対話と hook と `codex queue` を重ねる、app-server や ACP に乗る | 3.9、#562、#618 のコメント（統括を始める入口・エージェントの選択） | 公式が扱わない所なので、tmux の経路を残す理由の芯になる。ただし OSS では普通の機能になっており、ここだけでは独自性にならない。差し替える層は、口の名前ではなく役割で切る。先に Codex の実機で、`codex queue` の届き方と、hook が走る条件を確かめる |
| Q11 | SO のゲートをどう持つか | `so-compare` を続ける、呼び出しを OpenAI 公式のプラグインへ寄せてゲートの判定だけを持つ、ゲートを軽くする | 3.3、3.8、2.1 の「SO のゲート」（1,112行） | 呼び出しの部分は寄せられる材料がそろった。別のベンダーであることの効き目は、白紙の文脈であることより小さいという報告もあるので、ゲートを何のために通すかを Q1 と合わせて決める |
| Q12 | 判断ボードを、engine の芯としてどう磨くか | いまのまま、上げる量を減らす仕組みを足す、答えを束で受けて統括を1回だけ起こす形にする、放置された問いをもう一度知らせる | 3.8、2.7（問いは Q1 から Q105 まで進んだ） | 外より先に着いている所なので、独立したパッケージの芯にする値打ちがある。外の議論が足している2点（量を減らす・束で返す）は、owner の第一目的（認知負荷が減る）にそのまま当たる |

### 4.3 年内（2026-12-31 まで）の順序の案

| 期間 | やること | 終わりの印 |
|---|---|---|
| 11月第3週 | owner がこの見取り図を読み、Q1 から Q12 のうち問いとして判断ボードに載せるものを選ぶ | 判断ボードに Q1 が載る |
| 11月第3〜4週 | Q1（目的）を決め、README の「目的」節を書き直す | decision 1本 |
| 11月第4週〜12月第1週 | Q3・Q4・Q10 のための実地の試験を、それぞれ数日回して記録する。(1) 本文をファイルに置き、端末へは合図だけを打つ送信。(2) 公式のメッセージで子へ送る送信。(3) agent view を併用する表示。(4) Codex を子にして、`codex queue` の届き方と hook の走る条件を確かめる。並行して Q2 と Q11 を決める | 試験の記録（episode）と、Q2・Q3・Q4・Q11 の decision |
| 12月第2週 | Q5 と Q6 を決める。#609 の復帰の試験の結果を材料にする。Q10 の差し替える層の切り方を決める | decision |
| 12月第3〜4週 | Q7・Q8・Q12 を決め、#537 の plan を書く。Q9 を別の Epic として起こすかを決める | #537 の plan、必要なら新しい Epic |

### 4.4 先に読むとよい外の資料

フェーズ3の問いに、じかに材料を出す順に並べた。調査メモごとの「読む価値がある順」は、各メモの終わりにある。

| 資料 | 効く問い | 読む理由 |
|---|---|---|
| multi-agent-shogun の README と、作者の Zenn の記事（https://zenn.dev/shio_shoppaize/articles/shogun-hook-revolution ） | Q3、Q1 | 土台が Bash・tmux・ファイル・hook で engine と同じ。`send-keys` をやめて hook とファイルへ移った経緯が日本語で読める。作者は 2026-08 に、10体の構成を解いて1体に絞ったと書いている `[verified]` |
| Cyclops の README（https://github.com/cyclops-team/cyclops ） | Q3 | tmux へ打つ形のまま、配送を4段階に分け、不確かな結果を成功にしない。小さい（スター14）ので、借りるのは設計の語彙である |
| CAO の `docs/inbox-delivery.md`（https://github.com/awslabs/cli-agent-orchestrator/blob/main/docs/inbox-delivery.md ） | Q3 | `send-keys` の形のまま堅くする手順が、秒数と回数まで書いてある |
| Gas Town の設計書（`docs/design/` の mail-protocol・dog-infrastructure・polecat-self-managed-completion・escalation）と、Gas City の `coming-from-gastown.md` | Q4、Q5 | 見張りの見張り、合図と mail の使い分け、監督を主経路から外した経緯。同じ作者たちが、次の版で何を残し何を落としたかが分かる |
| Anthropic「Harness design for long-running application development」（2026-03-24）と「Scaling Managed Agents」（2026-04-08） | Q1、Q5 | 文脈のリセットを入れた理由と、モデルが新しくなって外した経緯。統括を使い捨てにして、状態を文脈の外に置く設計 |
| ai-orchestrator の設計 issue（https://github.com/nickderobertis/ai-orchestrator/issues/2408 ） | Q12、Q6 | 判断ボードとほぼ同じ発想の設計。複数の統括に共通の1本のキュー、選択肢、まとめて答える。違いを見るのに向く |
| agent-deck の conductor と、リリースノート | Q4、Q12 | 長く走る統括のセッションが子を見張り、自分で答えるか人へ上げるかを分ける。`send-keys` を続けたときに起きる失敗の実録でもある |
| Codex の hook と CLI のリファレンス（https://learn.chatgpt.com/docs/hooks ） | Q10 | 差し替える層の設計に要る一次の仕様 |

### 4.5 既存の issue への効き方

決定によって、開いている issue の扱いが変わる。対応は題名から書き手が読んだもので、本文は読んでいない `[speculation]`。

- Q2 で本体エンジンを凍結すると: #93（reviewer の nonce）、#520 の一部。
- Q3 で Claude Code の子の送信を公式へ寄せると: #486（確認のダイアログ中に Enter が選択肢を決める）、#490（下書きに連結される）、#432（起動待ちの固定の sleep）、#386（hook に `TMUX_PANE` が伝わらない）は、Claude Code の子については前提ごと無くなる。
- Q4 で表示と見張りを外に寄せると: #546・#570・#547・#169・#230・#356（cockpit の表示）、#301・#506・#507・#498・#330（見張り）。
- Q5・Q6: #609・#464・#238。
- Q8: #564・#537、#603（移行の後片付け）。
- Q10: #562。#618 のコメントの「統括を始める入口」と「エージェントの選択」。
- Q11: #329（SO のまとめ）。
- Q12: #539・#540（判断ボードの残り）。

## 5. 確かめていないこと

- 公式のメッセージを、tmux のペインで動く対話の子へ親の Bash から投函する形が、権限の既定（受け手が承認を求めるモードなら届ける）と macOS の制約のもとで実用になるか。
- agent view のバックグラウンドのセッションを、cockpit の WezTerm と tmux の画面と併用できるか。
- 本文をファイルに置き、端末へは合図だけを打つ送信が、engine の hook（受領の印）と組んで実用になるか。合図を打つ所には、いまと同じ入力欄の問題が残る。
- Codex の実機での挙動。`codex queue` が、待機中・動作中・承認待ちのセッションへどう届くか。hook が既定で走るか、信頼の確認が要るか。セッションの ID が環境変数に入るか。調査メモの Codex の記述は、公式の文書の要約を経ており、`--help` と突き合わせていない。
- Cursor の hook が CLI で発火するか、Copilot CLI の再開の定義、Antigravity CLI の一次の仕様。
- Gas City の `gc handoff` の中身、Gas Town で Mayor が二重に起きたときの扱い（どちらもソースを読む必要がある）。Gas City の orchestrator が LLM でないことは、文書の記述（control dispatcher・health patrol）からの読みで、明記は確かめていない。
- TAKT の `takt director` が持つ問いの型（選択肢や根拠を持つか）。判断ボードとの比較に要る。
- 2026年6月以降に出た新顔の網羅。GitHub のページからリポジトリの作成日が取れず、初出を一次情報で裏づけられたのは4件（Cyclops・pando・nsq・agent-console）だけだった。名前だけ確かめて中を開いていないものが、調査メモに30件ほど残っている。日本語圏の個人開発は、multi-agent-shogun の系譜のほかはほとんど拾えていない。
- 別のモデルによるレビューの効き目の報告（arXiv 2610.01471）は要旨だけを読んだ。方法と限界は確かめていない。
- スターの数とリリースの日付は、2026-11-10 にページから読んだ概数である。年が表示されない日付は、前後から 2026 年と読んだものを含む。
- `oe-events.jsonl` の実データ（verb ごとの利用頻度、`oe run` がいまも打たれているか）。クラウドのコンテナには `~/.claude/state/` の実データが無い。
- テストの赤9本が macOS の実機でも赤になるか。
