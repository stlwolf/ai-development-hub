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
    reason: "調査の下請け4本の調査メモ。この文書の数字と表の出どころ"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "2026-02 の調査の結論"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "D10（transport は tmux の send-keys のまま・Claude Code に依存を深めない）を、外の変化と並べて見直す材料にする"
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

## 1. 要点

1. engine の中身は、性質の違う3つの層に分かれている。1つ目は、2026-05 の MVP である非対話の1サイクルの本体（`oe run`）で、06-04 以降は state が残っていない `[verified]`。2つ目は、tmux の `send-keys` で対話セッションへ委譲し、届いたかを確かめ、見張る層である。3つ目は、統括が落ちても持ち場が続くための lease・交代・復帰と、owner への問いを集める判断ボードである。README の「目的」節は1つ目の言葉で書かれたままで、冒頭の説明は2つ目と3つ目の言葉で書かれている `[verified]`。
2. 6か月の実装の大半は、2つの痛みへの手当てに使われてきた。対話セッションへ文を送ったときに届いたかが分からないことと、長く走る統括の文脈が尽きることである。配送の対策は少なくとも6回作り直され、そのうち1回は検知器が逆を指していた（`suspected_miss` の 97.6% が実は到達）`[verified]`。統括は 07-09 の3〜4代目から 11-06 の23代目まで交代している `[unverified-summary]`。
3. 2026-02 以降、外では「tmux と worktree でエージェントを並べて状態を見る」層が出そろった（Agent of Empires は 2026-11-08 に v1.22.3 で、ほぼ週次で出している `[verified]`）。Claude Code 公式にも、セッション間のメッセージ（同じマシンではセッションごとの Unix ソケットで届き、アイドルなら新しいターンを始める）と、落ちたセッションを再起動する supervisor が入った `[verified]`。子が Claude Code である限り、送信・生存監視・cockpit の表示は外へ寄せられる材料がそろった。
4. 外に同等のものが見当たらないのは、統括の座の排他（lease）と統括の世代交代、Claude Code 以外の CLI を子にする委譲、別ベンダーのモデルによるセカンドオピニオン、選択肢と根拠を付けて owner に1枚で出す判断ボードである。agent teams は「Lead is fixed」で、ネストもできない `[verified]`。外で統括の交代と stuck の検知を持つのは Gas Town だけだった `[verified]`。
5. #577 の D10 は「Claude Code への依存を深めないので、セッション間の文を送る機能には乗らない」と決めている `[verified]`。公式の文書には、スクリプトや hook からセッションのソケットへ投函する方法（`CLAUDE_CODE_MESSAGING_SOCKET`）と、届いたか・保留か・拒否かの3値が書かれている `[verified]`。D10 の前提をこの材料と並べて見直すかどうかは、フェーズ3の最初の論点になる。
6. 蒸留文書は engine の木で 208本・45,098行（decision・discussion・episode・plan の合計）あり、bin と lib を合わせた 14,727行の約3倍になる `[verified]`。owner の第一目的が「認知負荷が減る」ことである以上、文書の量と保守の手間も方向性の論点に入る。

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
- Gas Town は、統括（Mayor）・作業者・見張り（Witness・stuck を検出して回復させる）を持ち、文脈を入れ替える handoff を持つ。外で engine に最も近い `[verified]`（https://github.com/gastownhall/gastown）。
- Vibe Kanban は終了を告知し、Crystal は 2026-02 に deprecated になった `[unverified-summary]`。

他社の CLI（多くは二次情報）:

- Codex CLI 0.167.0（2026-11-06）に `codex agents` と subagent の親子関係の保存が入った。Gemini CLI は subagent が既定で有効で、ネストはできず、A2A で remote の subagent に渡せる。どの公式機能も自社のエージェント同士の委譲に閉じている `[unverified-summary]`。

### 3.3 engine の機能ごとの対照表

判定は「ある（外へ任せられる水準）」「部分的にある（条件付き）」「見当たらない」の3つ。`phase2-external.md` 6節の表を要約した `[unverified-summary]`。

| engine の機能 | 判定 | 外にあるもの | 足りないもの |
|---|---|---|---|
| 委譲と送受信 | 部分的にある | セッション間のメッセージ（ソケット・3値の結果）、Gas Town の mail | 受け手が読んだという応用の層の受領確認、Claude Code 以外の CLI への送信 |
| 登記と木構造 | 部分的にある | `claude agents --json` の一覧、agent teams の members | セッションをまたぐ任意の深さの親子の木 |
| 生存監視 | ある（子が Claude Code なら） | agent view の supervisor、hook の `StopFailure`・`Notification` | ほかの CLI の子は画面の推定か Gas Town |
| 世代交代と lease | 見当たらない（lease）、部分的にある（交代） | Gas Town の handoff、Projects の文脈の設計 | 統括の座の排他。公式は lead を移せない |
| 復帰 | 部分的にある | supervisor の再起動、保存した会話からの再開 | マシンの再起動のあとの自動の再開、統括と子の関係ごとの復元 |
| セカンドオピニオン | 部分的にある | `/code-review`、workflows の相互検証 | 別ベンダーのモデル（Codex など）に見せる仕組み |
| cockpit の表示 | ある | agent view、Agent of Empires、cmux、herdr | engine に固有の状態（木・lease）を映すこと |
| 判断ボード | 部分的にある | agent view の Needs input、Projects の「Waiting on you」、Gas Town の escalate | 選択肢と根拠を付けて1枚にまとめて出すこと |

### 3.4 外の変化で、engine の前提が動いた所

- **送信の transport。** engine は、受け手の入力欄の状態（下書き・確認のダイアログ・copy-mode）に左右される `send-keys` の上に、届いたかを確かめる層を4つ積んできた（2.7）。公式のメッセージは入力欄を通らず、届けたかどうかを送り手に返す `[verified]`。子が Claude Code の場合に限っては、配送の痛みの元を transport ごと取り替えられる可能性がある `[speculation]`。ただし、親の Bash から子のソケットへ投函する形（子がソケットのパスを lease に書き、親がそれを読む形など）が、権限の扱いや macOS の制約まで含めて実用になるかは、実機で確かめていない。
- **生存監視と cockpit の表示。** 子を Claude Code のバックグラウンドのセッションとして起こせば、再起動と状態の一覧は公式が持つ `[verified]`。engine の見張り3本と点検2本が定期実行の配線を持たないまま止まっている（2.5）こととあわせると、自前で持ち続ける理由は薄くなっている `[speculation]`。一方で、agent view は research preview で、マシンの再起動では止まる。
- **変わらなかった所。** 統括の座の排他と交代、ほかの CLI を子にすること、別ベンダーのセカンドオピニオン、判断ボードは、外に同等のものが無いままである。2026-02 の調査が独自性として挙げた意味の層と、11月に中心になった層（2.2 の (c)）がここに当たる。

## 4. 見取り図（フェーズ3に向けて）

### 4.1 engine を「残す層」と「寄せうる層」に分けて見る

2.2 の3つの層と 3.3 の対照表を重ねると、次の切り分けが見える。これは決定ではなく、決めるときの地図である。

| 層 | 外との関係 | 考えられる扱い |
|---|---|---|
| (a) 本体エンジン（`oe run`） | 公式の workflows や subagent が近い | 凍結して `projects/_archived/` へ移す、残す、パイプライン駆動の構想（#105）とあわせて作り直す |
| (b) 送受信・見張り・表示 | 子が Claude Code なら公式に寄せうる。ほかの CLI の子は tmux が残る | tmux を続ける、Claude Code の子だけ公式のメッセージと agent view へ寄せて tmux はほかの CLI のための経路にする |
| (c) 統括の継続性と判断ボード | 外に同等のものが無い | engine の中心として残し、独立したパッケージの芯にする |
| (d) 文書の手順 | engine のコードではない | engine から切り離してハーネスに置く、軽くする |

### 4.2 フェーズ3で決めること

#618 本文の候補3つと、コメントで足された1つに、この下調べで出てきた論点を足した。並びは、前の決定があとの決定の前提になる順にしてある。

| # | 決めること | 選択肢 | 材料 | 書き手の見立て |
|---|---|---|---|---|
| Q1 | engine は何を目指すか（目的と非目的） | 05-19 の「specialized instrument・Build to Delete」に戻す、10月の「認知負荷を減らす統括の道具」にする、ほかに切り直す | 2.6、owner の第一目的（10-24）、#537 | 認知負荷を第一目的に置き、README の「目的」節をそれで書き直すのが、ほかのすべての前提になる |
| Q2 | 本体エンジン `oe run` を残すか | 凍結して移す、残す、作り直す | 2.2 の (a)、06-04 以降の記録が無いこと | 凍結して移すと、lib 9本（1,823行）と #93 などの派生 issue を整理できる。パイプライン駆動の構想を続けるなら、そのときに作り直すほうが軽い |
| Q3 | 送信の transport（#577 D10 の見直し） | tmux の `send-keys` を続ける、Claude Code の子は公式のメッセージへ寄せる、両方を持つ | 3.4、2.7 の配送の痛み、D10 | 小さな実地の試験（子1本に公式のメッセージで送り、届いた・保留・拒否を記録する）をしてから決める。D10 は owner の答え（Q67）なので、試験の結果を添えて問い直す形がよい |
| Q4 | 生存監視と cockpit の表示を外に寄せるか | 自作を続ける、agent view や Agent of Empires を併用して自作は engine に固有の状態だけにする | 3.3、2.5 の未配線 | Q3 の結論に従う。寄せるなら、#546・#570・#547 など cockpit の表示の issue は畳める |
| Q5 | 統括の世代交代をどう扱うか | 交代を続ける、世代0から始める既定にする、Projects 型の「文脈を構造で小さく保つ」形に寄せる | 2.7、#609、引き継ぎ文書の約5万1千トークン、Projects の文脈の設計 | 交代を前提にするより、統括の会話に積まない設計（中間の結果を記録へ出す）を先に検討する価値がある |
| Q6 | 1つのリポジトリに複数の統括を置くか | 置かない、置く（区別の仕方を決める） | #618 本文、lease の label・board・セッション名が1人の前提 | この Epic を別の統括で進めることが最初の実地になる。このクラウドのセッションもその1つで、hub の lease も board も持たずに下調べができた |
| Q7 | ハーネスとエンジンの境目をまたぐ hook と検査の置き場 | hook を engine の持ち物にする、記録の形を見本で固定して書く側と読む側の検査を分ける | #618 のコメント（`test_session_name.sh`・`test_prompt_receipt.sh`） | Q3 と Q4 の結論で、受領の印の hook の役目自体が変わりうるので、そのあとに決める |
| Q8 | 名前と独立したパッケージの境界 | #618 本文のとおり、目的が決まってから付ける | #537、#564、#605 | Q1 から Q7 の結果として決まる。パッケージに入れるのは (c) と、残すと決めた (b) |
| Q9 | 文書の手順の重さ | いまのまま、型や必須の節を減らす、engine の木から切り離す | 1節の6、2.8 の status の保守、`phase1-history.md` 6.3 | engine の方向性とは別の Epic に切り出すのがよい。ただし (d) を engine から外すかどうかは Q8 と一緒に決める |
| Q10 | Claude Code 以外の CLI を子にするか | する（#562）、しない | 3.3、別ベンダーのセカンドオピニオン | 外に同等のものが無い数少ない所なので、Q3 で transport を分けるなら、tmux の経路を残す理由の芯になる |

### 4.3 年内（2026-12-31 まで）の順序の案

| 期間 | やること | 終わりの印 |
|---|---|---|
| 11月第3週 | owner がこの見取り図を読み、Q1 から Q10 のうち問いとして判断ボードに載せるものを選ぶ | 判断ボードに Q1 が載る |
| 11月第3〜4週 | Q1（目的）を決め、README の「目的」節を書き直す | decision 1本 |
| 11月第4週〜12月第1週 | Q3 と Q4 のための実地の試験。公式のメッセージで子へ送る試験と、agent view を併用する試験を、それぞれ数日回して記録する。並行して Q2 を決める | 試験の記録（episode）と、Q2・Q3・Q4 の decision |
| 12月第2週 | Q5 と Q6 を決める。#609 の復帰の試験の結果を材料にする | decision |
| 12月第3〜4週 | Q7・Q8 を決め、#537 の plan を書く。Q9 を別の Epic として起こすかを決める | #537 の plan、必要なら新しい Epic |

### 4.4 既存の issue への効き方

決定によって、開いている issue の扱いが変わる。対応は題名から書き手が読んだもので、本文は読んでいない `[speculation]`。

- Q2 で本体エンジンを凍結すると: #93（reviewer の nonce）、#520 の一部。
- Q3 で Claude Code の子の送信を公式へ寄せると: #486（確認のダイアログ中に Enter が選択肢を決める）、#490（下書きに連結される）、#432（起動待ちの固定の sleep）、#386（hook に `TMUX_PANE` が伝わらない）は、Claude Code の子については前提ごと無くなる。
- Q4 で表示と見張りを外に寄せると: #546・#570・#547・#169・#230・#356（cockpit の表示）、#301・#506・#507・#498・#330（見張り）。
- Q5・Q6: #609・#464・#238。
- Q8: #564・#537、#603（移行の後片付け）。
- Q10: #562。

## 5. 確かめていないこと

- 公式のメッセージを、tmux のペインで動く対話の子へ親の Bash から投函する形が、権限の既定（受け手が承認を求めるモードなら届ける）と macOS の制約のもとで実用になるか。
- agent view のバックグラウンドのセッションを、cockpit の WezTerm と tmux の画面と併用できるか。
- Codex・Cursor・MCP・A2A の公式の文書（このセッションのネットワークの許可外で、二次情報にとどまった）。
- Gas Town の handoff と見張りの一次の仕様、後継とされる Gas City の実体。
- `oe-events.jsonl` の実データ（verb ごとの利用頻度、`oe run` がいまも打たれているか）。クラウドのコンテナには `~/.claude/state/` の実データが無い。
- テストの赤9本が macOS の実機でも赤になるか。
