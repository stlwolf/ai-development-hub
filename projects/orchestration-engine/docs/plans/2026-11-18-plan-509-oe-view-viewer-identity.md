---
id: "01M7NG80QKXGGG47CVT1WZN4QR"
title: "#509 oe-view が前の viewer を閉じる前に、同じ WezTerm の中のペインかを確かめる"
date: 2026-11-18
type: plan
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/509"
    reason: "対象の issue"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/509#issuecomment-6958775204"
    reason: "owner が確定させた着手時の認識合わせ"
  - type: design_context
    ref: "projects/orchestration-engine/docs/plans/2026-06-21-plan-210-oe-view-clickable-md.md"
    reason: "oe-view の設計（viewer を毎回置き換える方式・DJ-4）の元の plan"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/484"
    reason: "この不具合を見つけた engine の監査（候補 C-5）"
tags: [oe-view, wezterm, viewer, pane-identity]
so:
  design: weak
  impl: weak
  reason: "変更は lib/oe-viewer.sh とそのテストに収まり、戻すのも1つの commit で済む。誤りの影響は viewer を閉じ損ねる側に倒す設計なので、弱 SO（so-compare を1周）で足りる"
---

# #509 oe-view が前の viewer を閉じる前に、同じ WezTerm の中のペインかを確かめる

## Context（なぜ）

`oe-view` は md を開くたびに前の viewer（glow のペイン）を閉じて新しく開き直す。前の viewer は、記録のファイル（`~/.claude/state/oe-view/viewer-pane-id`）に書いた WezTerm のペイン番号で指している。閉じる前に確かめているのは「その番号のペインが今あるか」だけである。WezTerm を起動し直すとペイン番号は0から振り直されるので、記録に残った番号が、利用者が開いている作業中のペイン（Claude のセッションなど）に当たると、そのペインを閉じてしまう。2026-10-23 の engine の監査（#484 の候補 C-5・重大度 高）で報告された。

## 確かめた事実

| 事実 | 確かめた度合い | 出どころ |
|---|---|---|
| WezTerm のペイン番号は、プロセスの中の1つのカウンタで、0 から1ずつ増やして割り当てる。同じプロセスの中では使い回さない。プロセスを起動し直すと0から始まる | verified | [mux/src/pane.rs:24-28](https://github.com/wezterm/wezterm/blob/main/mux/src/pane.rs)（`static PANE_ID: AtomicUsize = AtomicUsize::new(0)` と `fetch_add(1)`） |
| ペインの中のプログラムが正常に終わるとペインは閉じ、異常に終わるとペインは残る（既定の `exit_behavior = "CloseOnCleanExit"`） | verified | [docs/config/lua/config/exit_behavior.md](https://github.com/wezterm/wezterm/blob/main/docs/config/lua/config/exit_behavior.md) |
| GUI のソケットの名前は `gui-sock-<GUI のプロセス番号>` である。GUI はこのパスを、自分が起こすペインの `WEZTERM_UNIX_SOCKET` にも入れる | verified | [wezterm-gui/src/main.rs:413-415](https://github.com/wezterm/wezterm/blob/main/wezterm-gui/src/main.rs)（`format!("gui-sock-{}", libc::getpid())` と `set_var("WEZTERM_UNIX_SOCKET", …)`） |
| `wezterm cli` は、`WEZTERM_UNIX_SOCKET` のソケットにつながらないと、そのパスで mux サーバを自動で起動しようとする（`--no-auto-start` で止められる） | verified | [wezterm-client/src/client.rs](https://github.com/wezterm/wezterm/blob/main/wezterm-client/src/client.rs) の `compute_unix_domain`（`WEZTERM_UNIX_SOCKET` から作る domain は自動起動を禁じない）と `unix_connect`（つながらなければ `serve_command` を起動する） |
| `wez` は呼ぶたびに接続先のソケットを決め直す。優先は `--socket`、次に `WEZTERM_UNIX_SOCKET`、最後に `~/.local/share/wezterm/gui-sock-*` の自動検出である。`wez pane` はサブコマンドの前に `--socket <path>` を受け付ける | verified | `projects/wezterm-ai-mode/lib/discover.sh:9-50`・`projects/wezterm-ai-mode/lib/pane.sh:782-850` |
| `LC_ALL=C ps -o lstart= -p <番号>` は、同じプロセスに対して同じ文字列を返す（末尾に空白が付く） | 手元で観察 | GUI のプロセスに2回打って、2回とも `Tue Nov 10 16:51:24 2026` が返った |
| いまの記録はペイン番号1行だけで、閉じる前の確かめは `wez pane list` に番号があるかだけである | verified | `projects/orchestration-engine/lib/oe-viewer.sh:41-44`・`:62-75`・`:121-123` |

最初の事実から、次のことが言える。**記録したときと同じ WezTerm のプロセスに対してなら、記録した番号のペインが今あれば、それは oe-view が起こした viewer である**（番号を使い回さないため）。取り違えが起きるのは、記録したときと別のプロセスに番号を問い合わせたときだけである。

## 設計判断 DJ-1: 前の viewer を閉じてよいかを、何で確かめるか

### 決めたこと（ゲート3 で owner の承認を受ける）

案 A を、設計 SO の指摘で固めた形で採る。**閉じるのは、記録したときと同じ WezTerm の GUI のプロセスに、同じソケットで問い合わせられると確かめられたときだけ**にする。確かめられないときは閉じずに、新しい viewer を開くだけにする。

閉じる条件（すべてを満たすときだけ `pane kill` を呼ぶ）:

1. 記録が新しい形で、`pane_id`（数字だけ）・`socket`・`mux_started` が空でなくそろっている。
2. 今回の接続先のソケット S（`wez discover --quiet` を1回だけ呼んで決め、シンボリックリンクをたどった実体のパス）が、記録の `socket` と同じである。別の GUI に切り替わった場面と、WezTerm を起動し直してプロセス番号が変わった場面は、ここで止まる。
3. S の名前が `gui-sock-<数字>` で、その番号のプロセスの `LC_ALL=C ps -o lstart=` の前後の空白を削った値が、記録の `mux_started` と同じである。OS を起動し直したあと、ログインのときに起動した WezTerm が前回と同じプロセス番号になった場面は、ここで止まる。
4. S に対する `pane list` に、記録の番号がある。
5. 記録の番号が、呼び出し元のペイン（`WEZTERM_PANE`）と同じではない。ほかの条件が正しければ当たらないが、閉じたときの被害がいちばん大きいペインなので、1行で別に止める。

1回の resolve の中の `pane list`・`pane kill`・`pane split`・`pane activate` は、すべて `wez pane --socket S` で呼ぶ。GUI を2つ同時に開いていると、自動検出は呼ぶたびに別のソケットを選びうるためである。新しい記録は、spawn のあとに S の開始時刻を取って書く。取れなければ記録を消す（次の回は閉じない）。

### 手当てしない経路

設計 SO は、次の経路も挙げた。どれもゼロではないが、現実にはまず起きない組み合わせなので、手当てしない（owner の判断・2026-11-18）。手当てすると、コードとテストが増えるわりに、実際に起きる場面での安全は変わらない。

- 条件を確かめてから `pane kill` が届くまでの数ミリ秒のあいだに、GUI が終わり、同じプロセス番号の新しい GUI が同じパスにソケットを作り、そこに記録と同じ番号のペインができている。
- 前の GUI と同じプロセス番号の GUI が、前の GUI と同じ秒に起動している。
- `gui-sock-<数字>` という名前のシンボリックリンクが、WezTerm 以外のプロセスの番号を名乗っている（Codex と Cursor はプロセス名の確かめを足す案を出した）。
- spawn の最中に GUI が起動し直し、新しい viewer の番号と、別の GUI の開始時刻が組になる（Codex は spawn の前後で開始時刻を取る案を出した）。
- 接続の確かめ（`pane.sh:845`）と `wezterm cli kill-pane` のあいだにソケットが消え、`wezterm cli` がそのパスで mux サーバを自動で起動する。起動したばかりの mux サーバには、利用者の作業ペインも無い。

閉じ損ねる場面は増える。たとえば、別の GUI から oe-view を呼んだときと、新しい形に変えたあとの最初の1回は、前の viewer が残る。これは受け入れる。

### 探索の記録（ゼロベースの設計 SO の結果・確定の前に書いた）

設計 SO は 2026-11-18 に1回回した（`so-compare --with codex,cursor,claude`・3つのレーンとも実返却あり）。Codex は gpt-6.1-sol、Cursor は composer-2.5（指定）、Claude は claude-opus-5-5 だった。出力は `tmp/509-design-so/`（作業層・commit しない）に置いた。この1回でゲート1（ゼロベースの代替探索）とゲート2（設計 SO）を兼ねた。

```text
DJ-1 前の viewer を閉じてよいかの確かめ方
├── 案A WezTerm のプロセス（ソケット＋開始時刻）を記録して照らす（初めの案）
│     → 採用。設計 SO の指摘で次を足した:
│       ソケットはシンボリックリンクをたどった実体のパスで比べる（Codex・Cursor）
│       1回の resolve で全部の wez pane を同じ --socket に固定する（3レーンとも）
│       呼び出し元のペインは閉じない（Claude）・lstart の空白を削る（Claude）
│     → 足さなかったもの: プロセス名の確かめ（Codex・Cursor）、spawn の前後で開始時刻を取る確かめ（Codex）。
│       どちらも、ゼロではないが現実にはまず起きない組み合わせだけを防ぐので、上の「手当てしない経路」に置いた
├── 案B tty_name を照らす → 不採用: tty の名前は使い回され、一致しても同じペインと言えない
├── 案C title が glow かを見る → 不採用: title は誰でも変えられる
├── 案D 閉じない → 不採用: viewer が増え続け、#210 の置き換えの方式（DJ-4）をやめることになる
├── 案E ペインでなく、viewer のプロセスを止める（Claude・Codex。glow を包むプロセスが自分の番号と乱数の目印を記録し、閉じるときはその目印を確かめてプロセスを止め、ペインは正常終了で閉じる）
│     → 今回は不採用。ペインの番号に頼らない点で案A より強いが、glow を包む層と、止めたあとにペインが閉じることを実機で確かめる必要があり、変更が大きい。
│       ペイン番号に頼らない形にしたくなったときの第一の代わりにする
├── 案F viewer を閉じず、中身だけ差し替える常駐の viewer（Claude・Codex）
│     → 範囲の外。focus を奪う問題（#111）とペインの配置の崩れも消えるので、別の改善の候補として残す
├── 案G ペインの title に乱数の目印を書いて照らす（Claude・Cursor）
│     → 不採用。glow が title を上書きするかを確かめていない。上書きするなら、一度も閉じられなくなる
├── 案H 呼び出し元のペインがある GUI のソケットに固定する（Cursor）
│     → 不採用。使い勝手は良くなるが、安全には効かない（条件2で別の GUI は閉じない）
├── 案I viewer 専用のタブ、または viewer 専用の WezTerm を使う（Cursor）
│     → 不採用。画面の構成と運用が変わる
├── 案J 照合と閉じるを WezTerm の側で1つにする（Codex）
│     → 不採用。WezTerm 本体の変更が要る
└── 案K 状態を wezterm.lua の側に持つ（Claude）
      → 不採用。oe-view はクリックの経路に頼らず単体で動く必要がある（bin/oe-view の usage）
```

初めの案に E・F・G が無かったのは、「閉じる手段はペイン番号での `wez pane kill` で、問題は番号の確かめ方だけ」という前提を置いていたためである（設計 SO の3レーンの指摘）。新しいカテゴリの案（E・F）は出たが、どちらも変更が大きいので、この issue では案A を固め、E と F は残す。

## 作業の手順

ゲートは仕様（`canonical/orchestration-spec/document-format.md` の「ゲート配置」節）の番号に、名前を添えて書く。

### ゲート0（着手前の認識合わせ）: 済み

- [x] `issue-intake` で認識合わせを通し、owner の確定を受けて確定版を #509 に投稿した。

### ゲート1（ゼロベースの代替探索）とゲート2（設計 SO）: 済み

- [x] この plan の下書きと DJ-1 の初めの案・暗黙の前提を、`so-compare` の「選択肢拡張」のテンプレートつきで、codex・cursor・claude の3つのレーンに1回渡した。
- [x] 出た案と指摘を確かめ、上の探索の記録と DJ-1 に採否を書いた。指摘のうち事実で決まるもの（ソケットの名前の付け方・`wezterm cli` の自動起動）は、WezTerm のソースで確かめた。

### ゲート3（plan の承認）: 済み

- [x] owner がこの plan を承認した（2026-11-18・会話で「承認する」）。承認の前に、設計 SO が挙げた危険のうち現実にはまず起きないものを「手当てしない経路」へ移し、その分の確かめを2つ外した（owner の指摘）。

### 実装（ゲート3のあと）

1. [x] `branch-naming` のとおりにブランチ名を決め、この worktree で切り替える（`git switch -c feature/#509_<slug>`）。この plan を最初の commit に入れる。
2. [x] episode を engine の木に作る（`projects/orchestration-engine/docs/episodes/2026-11-18-episode-509-oe-view-viewer-identity.md`）。作業中に随時書き足す。
3. [x] 先にテストを足す（`projects/orchestration-engine/tests/test_oe_view.sh`）。mock の `wez` を `wez pane --socket <path> <sub>` と `wez discover --quiet` に対応させ、ソケットごとに `pane list` の中身を変えられるようにする。`ps` の mock を足し、プロセス番号ごとに `lstart` を変えられるようにする。足す場面は次のとおりである。
   - 閉じる場面: 新しい形の記録で、ソケットとプロセスと開始時刻が一致し、番号が list にある。`pane kill` が1回呼ばれる（今ある [3] をこの形に直す）。
   - 閉じない場面（どれも `pane kill` が呼ばれず、新しい viewer は開く）:
     - 記録のソケットは A、今回の接続先は B（GUI が2つある）。
     - 同じソケットで、そのプロセス番号の開始時刻が記録と違う（番号の使い回し）。
     - 記録が番号だけの古い形。
     - 記録が壊れている（キーが欠ける・`pane_id` が数字でない・値が空）。
     - ソケットの名前が `gui-sock-<数字>` でない。シンボリックリンクの先が `gui-sock-<数字>` でない。
     - `ps` が失敗する、または空を返す。
     - 記録の番号が list に無い。
     - 記録の番号が `WEZTERM_PANE` と同じ。
   - そのほかの場面:
     - 1回の resolve の中のすべての `wez pane` の行に、同じ `--socket S` が付いている。
     - `wez discover` が失敗したら、kill も split も呼ばれず、rc 2 で終わる。
     - 書いた記録が3行で、使ったソケットの実体のパスと、空白を削った開始時刻が入っている。
     - spawn のあとに開始時刻が取れなければ、記録を書かない（ファイルが無くなる）。
     - `ps` の出力の末尾に空白があっても、記録と同じと判定して閉じる。
4. [x] 足したテストを変更の前のコードで走らせ、閉じない場面と `--socket` の場面が落ちることを確かめる。
5. [x] `projects/orchestration-engine/lib/oe-viewer.sh` を直す。
   - 接続先を決める関数を足す。`wez discover --quiet` を1回呼び、シンボリックリンクをたどった実体のパスを返す（`bin/oe-view` にある `_oe_view_canonicalize` と同じたどり方を使う）。
   - GUI のプロセスの開始時刻を返す関数を足す。名前が `gui-sock-<数字>` でなければ、または `ps` が失敗すれば、空を返す。開始時刻は `LC_ALL=C ps -o lstart= -p <番号>` の前後の空白を削った値にする。
   - 記録を `key=value` の3行（`pane_id`・`socket`・`mux_started`）で書き、今と同じく一時ファイルからの rename で置き換える。読むときは `source` や `eval` を使わず、最初の `=` で分ける。DJ-1 の条件1 を満たさなければ「確かめられない」とする。
   - `oe_viewer_resolve` を、DJ-1 の閉じる条件のとおりに直す。`_oe_viewer_pane_exists` と `_oe_viewer_spawn` はソケットを引数で受け取る。
6. [x] `bin/oe-view` の usage と `bin/README.md` の oe-view の節を、新しい記録の形と閉じる条件に合わせて直す。新しい形に変えたあとの最初の1回は前の viewer が残ることも書く。
7. [x] 検査を回す。
   ```bash
   bash projects/orchestration-engine/tests/test_oe_view.sh
   /bin/bash projects/orchestration-engine/tests/test_oe_view.sh
   bash projects/orchestration-engine/tests/test_home_unset.sh
   shellcheck -x -P SCRIPTDIR projects/orchestration-engine/lib/oe-viewer.sh projects/orchestration-engine/bin/oe-view projects/orchestration-engine/tests/test_oe_view.sh
   bash -n projects/orchestration-engine/lib/oe-viewer.sh
   git diff --check
   ```
   `/bin/bash` は bash 3.2 で回すためのものである。
8. [x] 手元の WezTerm で1回だけ実物を確かめる。`oe view <md>` を3回打つ。1回目は古い形の記録なので前の viewer が残り、2回目と3回目では前の viewer が閉じて新しい viewer が開くことと、記録が3行になっていることを見る。WezTerm の起動し直しは owner の作業を止めるので、自動のテストで確かめた場面に任せ、実物では試さない。

### ゲート4（実装の確かめ）

- [x] 実装 SO を1周回す（弱 SO・codex と cursor の2レーン）。差分と DJ-1 の閉じる条件を渡し、閉じてはいけないペインを閉じる経路が残っていないかを問う。
  ```bash
  so-compare -w "$(pwd)" -f tmp/509-impl-so-prompt.md -o tmp/509-impl-so --with codex,cursor
  ```
- [x] `pr-conventions` のとおりに PR を作り、Copilot のレビューを依頼する。指摘は `copilot-review-response` で1ラウンド対応する（PR #672・Copilot は Approval recommended で行ごとの指摘は0件だった）。

### ゲート5（closure とマージ）

- [ ] `episode-retrospective` で episode を閉じる（昇格の判定を含む）。この PR に入れる。
- [ ] マージは owner が行う。

### ゲート6（マージのあと）

- [ ] `branch-finish` で後始末をする。#509 を閉じるかを判断し、着地のコメントを書く。
- [ ] `oe` は本体のチェックアウトの `bin/oe` へのリンクとして配られているので、master を取り込めば反映される。`sync.sh` は要らない。

## ゲート3 のあとの変更

どれも補正で、閉じる条件（DJ-1）は変えていない。

- ブランチの前置きを `feature/` ではなく `fix/` にした（`fix/#509_oe_view_viewer_identity`）。`branch-naming` は、ブランチの主な commit の型に前置きを合わせる。
- 実装 SO（ゲート4）の should の2件を取り入れて、テストを足した。viewer を開く前は開始時刻が取れ、開いたあとは取れない場面と、`ps` が空白だけを返す場面、記録が無い初回でもすべての `wez pane` に `--socket` が付くことを数える確かめである。
- 手順8 は、`oe view` を3回打つ形から、6つの場面を順に試すスクリプト（作業層の `tmp/509-real-check.sh`）を owner が実行する形に変えた。理由は2つある。`~/bin/oe` は本体のチェックアウト（master）のコードを呼ぶので、ブランチのコードを試すには `bin/oe-view` を直接呼ぶ必要があった。また、このセッションは WezTerm の外で動いていて、ここから打つと owner の tmux の画面が分割される。スクリプトは、記録を書き換えて「別の GUI」「開始時刻の違い」「古い形の記録」の場面も作り、閉じないことを実物で確かめた。
- 手順5 の symlink のたどり方を、`bin/oe-view` の `_oe_view_canonicalize` と同じたどり方から、`realpath` があれば使い、無ければたどらない形に変えた。`_oe_view_canonicalize` は bin の側にあり、lib から bin の関数を呼ぶと向きが逆になるためである。たどらなかった symlink は `gui-sock-<番号>` の名前にならないので、閉じない側に倒れる（DJ-1 の閉じる条件は変わらない）。
- 手順8 の1回目は、tmux に古い `WEZTERM_UNIX_SOCKET` が残っていて `wez discover` が失敗し、viewer を開く前に止まった（#431 の不具合。master でも同じく失敗する）。スクリプトでその変数を外して実行し直し、6つの場面がすべて期待どおりになった。

## 範囲の外

- engine のほかの記録で WezTerm のペイン番号をキーにしているもの（`bin/oe` の spawn まわり）。#577 の discussion で lease への移行の範囲の外とした（discussion-577 の表）。
- `wez` が `wezterm cli` に `--no-auto-start` を付けていない件。`projects/wezterm-ai-mode` の変更なので、別の issue の候補にする。
- `WEZTERM_UNIX_SOCKET` が古いと自動検出に戻らない件（#431）。tmux の中で `WEZTERM_UNIX_SOCKET` と `WEZTERM_PANE` が古いまま残り、split と activate が別の GUI に向く件も同じ根なので、#431 に書き足す候補にする。
- mux サーバ（`wezterm-mux-server`）のソケットのように、名前からプロセス番号が取れない接続先で置き換えを効かせること。この plan では閉じない側に倒す。
- 案E（viewer のプロセスを止める）と案F（常駐の viewer）。上の探索の記録に残した。
