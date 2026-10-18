---
id: "01M575BACNPQ2KNXFSW5RYFQJX"
title: "#401 宣言駆動 settings の検査を、撤去した等価性 fixture の代わりに立て直す"
date: 2026-10-18
type: plan
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/401"
    reason: "失った6つの能力・案X/Y/Z・反証の3つの検証方法の出所。この plan はそれを覆さない"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/401#issuecomment-6248150781"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）。「issue に書いていないが要ること」4点と「望む結果」の出所"
  - type: reference
    ref: "docs/harness/episodes/2026-10-18-episode-401-settings-apply-check.md"
    reason: "この plan の実行記録。いまのコードで確かめたことと設計SO の経緯はこちら"
  - type: design_context
    ref: "docs/harness/plans/2026-09-06-plan-359-settings-harness-layer.md"
    reason: "宣言駆動の apply と check を作った計画。撤去した [22] は PR-3 の受入「宣言が2項目のとき、変更前と変更後で結果が一致する」を fixture で示していた"
  - type: design_context
    ref: "docs/harness/episodes/2026-09-06-episode-359-settings-harness-layer.md"
    reason: "8つの fixture を作った経緯と、テストが shebang 経由で別の bash を走らせて版差の主張が空になった失敗（2回）の記録"
tags: [test, settings, sync, harness]
so:
  design: weak
  impl: weak
  reason: "テストの追加で、配布物の振る舞いは変えない。ただし検査の基準の置き方は設計判断なので、設計SO と実装SO の両方を通す（brief の指定）。設計は so-compare の Codex 1レーン（返らなければ Cursor に1回だけ切り替える）、実装は oe-review の既定の codex+cursor と Copilot 1ラウンド"
---

# #401 宣言駆動 settings の検査を、撤去した等価性 fixture の代わりに立て直す

## 背景

`test_apply_claude_settings.sh` の [22] は、#359 の移行が挙動を変えていないことを、git の履歴から取り出した旧実装（`sync-claude.sh` の `sync_claude_hooks` を含む最後の版）と新実装の結果を8つの fixture で比べて確かめていた。旧実装は hooks と statusLine の2つしか知らないので、#338 で宣言に3つ目の項目（`disableAgentView`）を足すと原理的に一致しなくなり、owner の裁定（2026-09-16）で撤去した。

撤去で失った検出能力は6つある（issue の本文）。#338 の作業では、`test_sync_output_styles.sh` が落ちる欠陥を apply と check のテストでは見つけられず、設計SO に言われて初めて分かった。

## この plan の範囲

- やること: 撤去した [22] の位置に、代わりの検査を立てる。置き場は `projects/orchestration-engine/tests/test_apply_claude_settings.sh` だけである。同じファイルの [4] と [17] が宣言の項目を名指しで並べているので、宣言から導く形に直す（DJ-8）。
- 直さないもの: `apply-claude-settings.sh`・`check-claude-settings.sh`・`sync-claude.sh`・宣言（`settings.harness.json`）とその正本。本体を直す必要は、いまのところ見つかっていない。実装中に見つかったら、直さずに問いとして上げる。
- 隣のテスト（`test_check_claude_settings.sh`）の `build_green` も宣言の項目を名指しで並べているが、[22] の代わりの外なので、この plan では直さない。ゲート3 の問い Q1 に置く。
- 本物の `~/.claude`（settings.json と各リンク）には触れない。テストが `sync-claude.sh` を走らせるときは、`$_TMP_DIR` の下に作る使い捨ての HOME だけを使う（DJ-9）。

## 上流の前提の確かめ（結果）

いまのコード（master `ed45de5`）に当てて確かめた。経緯は episode の「P1」の3つの節にある。

| 前提 | 出所 | 結果 |
|---|---|---|
| 反証の3つ目は「宣言に4項目目を足す」 | issue 本文 | **そのままでは使えない。** #415（2026-10-08）で `idleCompaction` が入り、宣言はすでに4項目ある。issue の意図は「項目を1つ足しても」なので、この plan では「5項目目を足す」と読み替える |
| apply と check は判定ロジックを共有していない | 確定版（統括が確かめた） | 成り立つ。どちらも別のファイルを読み込まず（`source` も `.` も無い）、互いの名前も参照しない。ポインタを解く jq の定義は、同じ書き方を両方が別々に持っている |
| 撤去前の8つの fixture は `99d0ecd` の親から取り出せる | 確定版 | 取り出せた。missing・hooks_only・own_statusline・wrapped・broken_json・symlink・personal_keys・dir の8つである |
| 使い捨ての HOME で `sync-claude.sh` を走らせた結果に check を当てれば、入口・shebang・終了コードの3つも取り戻せる見込みがある | 確定版 | 走らせられた。8件とも sync は 0 を返し、書ける相手の5件は check が 0、書けない相手の3件（broken_json・symlink・dir）は check が理由つきで 1 を返した。本物の settings.json は前後で変わらず、worktree の `git status` も空のままだった |
| `sync-claude.sh` は宣言の場所を apply に渡さない（`sync-claude.sh:203`） | issue 本文 | 成り立つ（いまは 203 行目）。apply は自分の位置から宣言を解く。だから、apply や宣言を差し替えた検査には、使い捨ての木（スクリプトと宣言の写し）が要る |

## 確定版の各点への答え

| 確定版の点 | この plan の答え |
|---|---|
| 案X を apply 単体に当てると、入口・shebang・終了コードの3つは戻らない | apply 単体ではなく、`sync-claude.sh` を shebang 経由で走らせ、その結果に check を当てる（DJ-2・DJ-6） |
| 8つの fixture を使うか、作り直すか | 8つをそのまま使い、宣言から導く fixture を1つ足す（DJ-3） |
| 成立条件（apply と check が判定を共有しない）の確かめと、今後の守り方 | 確かめた結果は上の表にある。守り方は2つの層で、どちらもテストの中で毎回確かめる。1つ目は、apply の写しにどんな入力にも誤った値を書く欠陥を入れ、check がそれを見つけられることである（DJ-5 の陽性対照 M6）。2つ目は、apply と check が互いのファイル名を含まず、別のファイルを読み込む行を持たないことである（DJ-5 の構造の確かめ）。apply と check の本体には手を入れない |
| plan と episode は harness の木に置く | `docs/harness/plans/` と `docs/harness/episodes/` に置いた |

## 設計判断

### DJ-1 判定の基準は check に移し、宣言の外は前後の不変で見る（案X）

fixture ごとに、sync を走らせた結果の settings.json に check を当てる。あわせて、宣言した pointer を取り除いた文書が、sync の前と後で同じであることを見る（以下「不変の検査」と呼ぶ）。

- 宣言の内側は check が見る。check は宣言の全項目を判定し、判定できた件数が宣言の件数と違えば緑を返さない（`check-claude-settings.sh` の 321 行目）ので、項目の一覧をテストが持たなくてよい。
- 宣言の外側は不変の検査が見る。比べる範囲は「文書全体から宣言した pointer を除いたもの」で、手元のキーを列挙しない。完全性の述語を母集団の側から書く形である（注入された negative knowledge `01KYJ76D…`）。
- 不変の検査の比べ方: 宣言の pointer を両方の文書から消したうえで、最上位のキーごとに「片方にだけある」か「値が違う」を拾い、拾ったキーの名前を並べる。値が `null` のキーと、キーが無いことを取り違えないように、値の比較の前にキーの有無を比べる。比べる処理そのものが失敗したときは、「拾ったキーが無い」ではなく失敗の印を返し、赤にする。
- 宣言の内側でも、op が `handler` か `merge-object` の pointer には、もう1つだけ規則を当てる。前の値がオブジェクトなら、前にあったキーは後にもすべて残っていることである。どちらの op も、手元にしかない下位のキーを残す約束を持つ（`apply-claude-settings.sh` の 255 行目の statusline-wrap の説明と、merge-object の定義）。この規則で、statusLine の padding のような、check の述語が見ないキーが消える欠陥を拾う。拾ったときは `statusLine.padding` のように pointer とキーをつないだ名前で出す。残る穴は、そうしたキーが消えずに値だけ変わる場合で、これは見えない（DJ-6 の4）。
- 判定の基準を旧実装から check に移すので、成立条件は「apply と check が別々の実装のままであること」になる。守り方は DJ-5 に書く。

### DJ-2 入口は `sync-claude.sh` にし、shebang 経由で起動する

検査は apply を直接呼ばず、`env -u BASH_ENV -u ENV HOME=<使い捨て> <木>/scripts/sync/sync-claude.sh` で full sync を走らせる。起動は shebang に任せ、`"$BASH"` を前に付けない。`BASH_ENV` と `ENV` を外すのは、テストを走らせた環境から引き継いだ起動時のファイルが、非対話の bash の起動で実行されるのを止めるためである（DJ-9）。

- こうすると、本番と同じ組み合わせで動く。`sync-claude.sh` は `#!/bin/bash`（macOS では bash 3.2）で動き、そこから呼ばれる apply は `#!/usr/bin/env bash`（PATH の bash）で動く。
- これは「本番の起動の組み合わせを走らせる」主張であって、「bash の版ごとに走らせる」主張ではない。このファイルのほかの項目は `"$BASH" "$APPLY"` で apply を直接起動し、テストを走らせた bash の版で apply を確かめている。2つは別の主張で、両方を残す。#359 では、テストを bash 3.2 で回しても対象が shebang 経由で bash 5 で動いていて、版差の主張が空になった失敗が2回あった。ここでは版差を主張しないので、その失敗の形には当たらない。主張が空でないことは M5 で、sync の側と apply の側の両方について確かめる（DJ-5）。
- 本物の木（`$REPO_ROOT`）で走らせる。本番と同じ木なので、写しを作るときの取り漏らし（#338 で `test_sync_output_styles.sh` が踏んだ形）が起きない。apply や宣言を差し替える陽性対照だけは、写しの木で走らせる（DJ-5）。写しの木に入れるもの（3本のスクリプト・宣言・公式キーの一覧・statusLine の置き場・宣言が参照する正本のすべて）は、宣言から引いて集める。手で並べると、宣言に項目を足したときに写しだけ取り残される（#338 で `test_sync_output_styles.sh` が踏んだ形）。写しの木が本物の木と同じに働くことは、M3 で9件すべてが期待どおりになることで確かめる。

### DJ-3 fixture は撤去前の8つをそのまま使い、宣言から導く1つを足す

| 名前 | 初期の状態 | 組 |
|---|---|---|
| missing | settings.json が無い | 書ける相手 |
| hooks_only | `{"hooks":{"Stop":[{"matcher":"","hooks":[]}]}}` | 書ける相手 |
| own_statusline | 独自の statusLine（`~/mybar.sh --fancy`・padding 2） | 書ける相手 |
| wrapped | すでに包まれた statusLine（`OE_HEARTBEAT_WRAP_CMD=/x/mybar.sh` で包んだ形・refreshInterval 10） | 書ける相手 |
| broken_json | `{ not json` | 書けない相手 |
| symlink | 別のファイル（`{"hooks":{}}`）への symlink | 書けない相手 |
| personal_keys | theme・tui・model・`remoteControlAtStartup: false`・`skipWorkflowUsageWarning: true` | 書ける相手 |
| dir | settings.json がディレクトリ | 書けない相手 |
| stale_replace（新規） | 宣言の `replace` の項目すべてに、正本と違う値 `{"__stale401__":true}` を入れたもの | 書ける相手 |

- 8つの中身は、撤去前の [22] の `FIX_INITS` から1文字も変えずに写す。
- stale_replace を足す理由: 失った能力の6つ目は「手元に別の値がある状態から replace で置き換える動作」で、撤去前にこれを見ていたのは hooks_only の hooks だけだった。stale_replace は宣言を読んで作るので、`disableAgentView`・`idleCompaction` と、今後足す `replace` の項目にも自動で広がる。入れる値をオブジェクトにしたのは、置き換えではなく重ね合わせ（jq の `*`）にする誤りも捕まえるためである。正本が `true` や `false` の項目に重ね合わせを当てると jq が失敗し、sync が 0 でない値で終わる。

### DJ-4 期待は fixture の組ごとに決める

- 書ける相手（6件）: sync が 0 を返す。check が 0 を返す。不変の検査で拾うキーが無い。missing は前の文書を `{}` として比べるので、apply が宣言の外のキーを作らないことも見える。
- 書けない相手（3件）: sync が 0 を返す（止めない）。中身が前と同じである（broken_json はバイト単位で同じ、symlink は symlink のままでリンク先の中身が同じ、dir はディレクトリのままで中にファイルが無い）。check は 1 を返し、理由の文言（「JSON として読めません」「symlink なので適用できません」「通常ファイルではないので適用できません」）を出す。
- 案X の「check に exit 0 を求める」は、書けない相手には当てはまらない。いまのコードで確かめたとおり、書けない相手では check は理由つきで 1 を返すのが正しい。

### DJ-5 陽性対照は6つにし、テストの中に常に置く

このファイルにはすでに、apply の写しに1行を挿して走らせる項目が多くある（[13b]・[13c]・[21]・[23]・[25]・[26]・[31]〜[36]・[39]）。同じ形で、陽性対照をテストの中に置き、毎回走らせる。どの対照も、まず差し替えを挿せたこと（差し替えた文字列が写しの中に1回だけあること）を確かめる。挿せなければ、その時点で落とす。

| 対照 | 写しの木で差し替えるもの | 期待（期待した理由で落ちたかまで見る） | 対応するもの |
|---|---|---|---|
| M1 | apply の replace の行（230 行目）を `setpath($path; (getpath($path) // $item.expected))` にする | 書ける相手のうち check が落とすのは hooks_only と stale_replace の2つだけである。hooks_only の check の出力に「差分 /hooks (replace)」が出る。stale_replace の check の出力に、宣言の `replace` の項目すべての「差分 <pointer> (replace)」が出る。不変の検査はどの fixture でも何も拾わない（落としたのは check である） | issue の反証1・失った能力6 |
| M2 | apply の適用の最後の行（273 行目）に `\| del(.theme)` を足し、statusline-wrap の独自コマンドを包む行（269 行目）の `$cur + $item.expected + {command: ($wrap_prefix` から `$cur + ` を外す | 不変の検査が拾うのは personal_keys と own_statusline の2つだけで、拾うキーはそれぞれ `theme` と `statusLine.padding` である。書ける相手の check はすべて 0 を返す（check だけでは見えないことを示す） | issue の反証2・失った能力4 |
| M3 | 宣言に5項目目（`/hub401Probe`・`replace`・写しの木だけに置く正本ファイルから値を引く）を足す | 9件すべてが DJ-4 の期待どおりになる。書ける相手の結果に `hub401Probe` が正本の値で入っている。check の出力に「一致 /hub401Probe」が出る。stale_replace の初期値にも `hub401Probe` が入っている | issue の反証3・望む結果「項目を足してもテストを書き換えずに済む」 |
| M4 | 宣言の最初の項目の正本ファイルを写しの木から消す | personal_keys で走らせ、sync が 0 でない値を返す。出力に「設定の適用に失敗しました（rc=2）」が出る。settings.json はバイト単位で前のままである | 失った能力3（終了コードの 0 でない組を観測する） |
| M5 | `sync-claude.sh` の `set -euo pipefail` の次の行と、apply の `set -uo pipefail` の次の行に、走っている bash の主版番号を使い捨ての HOME のファイルへ書く1行をそれぞれ足す | sync の側に書かれた主版番号が `sync-claude.sh` の shebang の interpreter の主版番号と同じで、apply の側に書かれた主版番号が apply の shebang の interpreter（`/usr/bin/env bash`）の主版番号と同じである。2つの interpreter の主版番号が同じ環境（PATH の bash が `/bin/bash` の環境）では、組み合わせを区別できないので、そのことを出力に書く | 失った能力2（本番の起動の組み合わせが実際に効いていること） |
| M6 | apply の replace の行を `setpath($path; {"__wrong401__": true})` にする（どんな入力にも誤った値を書く） | missing で走らせ、check が 1 を返し、宣言の `replace` の項目すべての「差分 <pointer> (replace)」が出る | 成立条件の守り（check が期待値を apply から作っていないこと） |

- 成立条件（apply と check が判定を共有しない）は、2つの層で守る。1つ目は M6 である。もし check が「空の settings に apply を当てて期待値を作る」形に変わると、M6 の誤った値が期待値にも入るので check が緑を返し、M6 が落ちる。M1 はこの変化を見つけられない（M1 の欠陥は空の入力には正しい値を書くため）ので、M1 の役目は replace の誤りへの感度に限る。2つ目は構造の確かめで、check が apply のファイル名を含まないこと、apply が check のファイル名を含まないこと、どちらも別のファイルを読み込む行（`source` か `.` に続くパス）を持たないことを、テストの中で毎回見る。ポインタを解く関数を共有のファイルへ出す変更は、この2つ目で落ちる。
- どちらの層も、apply と check を同じ型紙から別々に作り、同じように宣言を読み違えた場合は見つけられない。その穴は人が宣言を読む目に残る（確定版の「完成後の人手の残り」）。
- 失った能力1（入口からの配線）には専用の対照を置かない。配線が切れると、missing の settings.json が作られず check が 1 を返すので、DJ-4 の期待で落ちる。M4 も、apply の失敗が sync の終了コードまで届く配線を通る。
- 対照は M1〜M3 が9件ずつ、M4〜M6 が1件ずつで、本物の木の9件と合わせて sync を39回走らせる。いまの1回は約0.5秒（P1 の実測）なので、テストの時間は約13〜14秒から30〜40秒ほどに延びる見込みである。実測が60秒を超えたら、対照の fixture を絞る直しを「ゲート3 のあとの変更」として統括へ照会する。

### DJ-6 失った6つの能力の扱い

| # | 失った能力 | 扱い | どこで |
|---|---|---|---|
| 1 | full sync の入口（`sync-claude.sh`）からの配線 | 取り戻す | DJ-2（本物の木で sync を走らせる）・DJ-4 |
| 2 | shebang による shell の選択 | 取り戻す。主張は「本番の起動の組み合わせ（sync と apply のそれぞれの interpreter）を走らせる」までで、版の網羅ではない。2つの interpreter の主版番号が同じ環境では、組み合わせの違いを区別できない | DJ-2・M5 |
| 3 | sync 全体の終了コードの分類 | 取り戻す。0 の組を9件で、0 でない組を M4 で観測する。撤去前の [22] は旧実装と同じ組かを見ていただけで、0 でない組を新実装で観測していなかったので、この点は前より強い | DJ-4・M4 |
| 4 | 個別の主張が列挙していないキー変更 | 一部を取り戻す。宣言の外は不変の検査、宣言の内側は check が見る。`handler` と `merge-object` の pointer の中で、check の述語が見ないキー（statusLine の padding など）が消えることは、DJ-1 の2つ目の規則で拾う。残る穴は、そうしたキーが消えずに値だけ変わる場合と、包んだ元コマンドの中身が変わる場合である。後者の一部は既存の [12]（包むのは1回・元コマンドを退避）と [48]（チルダ展開）と `test_sync_claude_statusline.sh` の [7]（包んだコマンドを実際に実行する）が見ている | DJ-1・M2・既存の3項目 |
| 5 | 旧実装という、本番の判定ロジックから独立した基準 | 別の検査に回す。基準を check に移す。check は旧実装ほど独立ではない（同じ作者で、ポインタを解く jq の書き方も同じ）ので、apply と check が宣言を同じように読み違えた場合は通る。その穴は人が宣言を読む目に残る（確定版の「完成後の人手の残り」） | DJ-1・DJ-5 の M6 と構造の確かめ |
| 6 | 手元に別の hooks がある状態から replace で置き換える動作 | 取り戻し、広げる。hooks_only に加えて stale_replace で、宣言の `replace` の項目すべてに広げる | DJ-3・M1 |

達成を見る数（確定版）: 6つのうち、取り戻すのが4つ（1・2・3・6）、一部を取り戻すのが1つ（4）、別の検査に回すのが1つ（5）、諦めるのが0である。issue の反証の3つの複製は、M1・M2・M3 で 3/3 を確かめる。

### DJ-7 このテストで宣言を読む処理は、テストが自分で持つ

不変の検査（宣言の pointer を消す・`handler` と `merge-object` の pointer でキーが消えていないかを見る）と stale_replace（`replace` の項目を拾う）と M3（項目を足す）は、テストの中で宣言を jq で読む。apply や check の関数を呼ばない。テストが3つ目の読み手になるが、読むのは pointer と op だけで、正本の値を解いたり値を判定したりはしない。読み違えたときは不変の検査が余計なキーを拾うか、stale_replace が項目を取りこぼす。前者は赤になり、後者は M1 の「宣言の `replace` の項目すべて」の確かめで赤になる。

**項目を足してもテストを書き換えずに済む範囲。** M3 が確かめるのは、最上位の pointer に `replace` の項目を足す場合である。入れ子の pointer（たとえば `/new/enabled`）を足すと、missing で apply が親の `new` を作るので、不変の検査が `new` を拾って赤になる。そのときは不変の検査に、宣言の pointer の親を扱う規則を足す必要がある。赤になる側に倒れるので、黙って通ることはない。保証の対象は `test_apply_claude_settings.sh` だけで、隣の `test_check_claude_settings.sh` は含まない（Q1）。

### DJ-8 同じファイルの [4] と [17] を、宣言から導く形に直す

[4] と [17] は、apply の結果のキーが `disableAgentView hooks idleCompaction statusLine` であることを文字列で比べている。宣言に項目を足すと、この2つは書き換えが要る。確定版の「望む結果」の「宣言に項目を足してもテストを書き換えずに済む」と、issue の反証3（足してもテストを変えずに緑のまま）は、この2つが残ると成り立たない。期待の側を「op が `absent` でない項目の pointer の最初の区切りを、重ねずに並べたもの」に替える。`absent` を除くのは、消す指定の項目は結果のキーに現れないからである。主張（apply が作るファイルには宣言の項目だけが入る）は変えない。

[50] と [51] も項目を名指しするが、owner の裁定した値そのものを止めるための項目で、項目を足しても落ちない。直さない。

### DJ-9 本物の `~/.claude` に触れないための守り

- テストが `sync-claude.sh` を走らせる関数は、HOME にするディレクトリの物理パス（`cd` して `pwd -P`）が、`$_TMP_DIR` の物理パスの下にあることを確かめてから走らせる。外れていれば、走らせずに FAIL を数える。この守りが防ぐのは、変数が空になるといったテストの書き間違いで本物の HOME へ向くことである。HOME のパスはテストが `$_TMP_DIR` と固定の名前から組み立てるので、`..` を含む入力は来ない。
- 起動時に `BASH_ENV` と `ENV` を外す（DJ-2）。
- `sync-claude.sh` は、配る `.sh` に実行権が無いと、リポジトリのファイルに `chmod +x` を当てる（`sync-claude.sh` の 132〜134 行目）。判定は git の mode ではなく実物の `-x` で決まる。本物の木で走らせる前に、`canonical/hooks/scripts` と `canonical/claude/statusline` の `.sh` がすべて実物で実行可能であることを確かめ、そうでなければ走らせずに FAIL を数える。いまは git の上でも実物でもすべて実行可能である（P1 と設計SO で確かめた）。
- 受入で、本物の `~/.claude` とリポジトリに書き込んでいないことを2つの方法で確かめる（A11）。1つは、テストを macOS の `sandbox-exec` の下で、`~/.claude`・`~/.claude.json`・worktree への書き込みを拒む設定で1回走らせ、緑のままであることである。書き込もうとすれば拒否されて、その項目が赤になる。もう1つは、走らせる前と後で、`~/.claude/settings.json` の shasum と mtime、`~/.claude` の下のリンク先の一覧、worktree の `git status` が同じであることである。後者は最終の状態が同じことしか示さず、途中で書いて戻した場合は見えないので、前者を主な証拠にする。

### DJ-10 bash 3.2 で動く書き方に限る

このテストは bash 5 と `/bin/bash`（3.2）の両方で回す。連想配列・`mapfile`・`${var,,}`・`[[ -v ]]` を使わない。`set -u` の下で空の配列を `"${arr[@]}"` で展開すると bash 3.2 では止まるので、集計は配列でなく文字列で持つ。合否は終了コードでなく最後の集計の行（`=== PASS=<数> FAIL=0 ===`）で読む（注入された negative knowledge `01M54X75…`）。

## ゲート1（ゼロベース代替探索）

初期の選択肢は issue の案X・案Y・案Z である。暗黙の前提は「判定の基準は実装の外に1つ置く」「検査はテストのファイルに置く」「fixture は settings.json の初期状態で表す」の3つである。自分でゼロベースに挙げて退けた案と、設計SO の選択肢拡張で出た案（案S・案C）を、次の木にまとめた。

```text
DJ-1 判定の基準
├── 案X（issue・推奨）: 結果に check を当て、宣言の外は不変で見る → 採用
├── 案Y（issue）: 旧実装の出力を固定ファイルにして比べる → 不採用。作り直すたびに人が差分を読む運用が要り、項目を足すたびに固定ファイルを作り直すので「テストを書き換えずに済む」に反する
├── 案Z（issue）: 宣言外不変・項目順不変・冪等・無関係な項目の追加の契約 → 一部採用。宣言外不変は案X に含め、無関係な項目の追加は M3 で見る。項目順不変と冪等は、撤去で失った能力ではないので足さない（冪等は既存の [3] が1件で見ている）
├── 案W（ゼロベース）: テストの中に宣言の解釈器をもう1つ書き、期待の文書を作って全体を比べる → 不採用。3つ目の実装を同じ作者が書くことになり、op やハンドラを足すたびにテストを直す必要が出る
├── 案V（ゼロベース）: 直前の commit の apply と、いまの宣言で結果を比べる → 不採用。実行時に履歴へ頼る点が撤去した [22] と同じで、issue の「外した軸」に当たる
└── 案U（ゼロベース）: 「check が一致と言った項目には apply が触らない」という関係を見る → 不採用。宣言の契約（#359 の DJ-4）にこの関係は書かれておらず、ハンドラが述語の外のフィールドを更新するのは正当でありうる。契約にするかは宣言の設計の判断で、この単位の外である
DJ-2 入口
├── sync-claude.sh を shebang 経由で走らせる → 採用
├── apply を直接呼ぶ → 不採用。失った能力の1〜3が戻らない
└── sync-claude.sh を "$BASH" で走らせる → 不採用。本番の組み合わせ（sync は /bin/bash・apply は env bash）にならない
DJ-5 陽性対照の置き方
├── テストの中に常に置く → 採用。検出力（とくに成立条件）を毎回確かめられる。既存の項目と同じ形である
└── 受入のときに1回だけ手で走らせる → 不採用。apply と check の関係が後で変わったときに、気づく場所が無くなる
DJ-9 隔離の守り
├── HOME を差し替え、物理パスと実行権を前もって確かめる → 採用（テストの中に常に置く）
└── 案S（設計SO の選択肢拡張）: OS の書き込み制限（sandbox-exec）の下で full sync を走らせる → 一部採用。受入の A11 で1回だけ使う。テストの中には置かない。sandbox-exec は macOS だけのもので、テストを別の環境で回せなくなるためである
DJ-6 の4（statusLine の中）
└── 案C（設計SO の選択肢拡張）: 包んだコマンドを実際に実行し、元の表示が引き継がれるかを見る → 不採用。同じ観測を `test_sync_claude_statusline.sh` の [7] がすでにしている（チルダを含む元コマンドを包み、実行して元の表示と拍動の記録を確かめる）。この単位で同じものを足さない
未探索: fixture を settings.json 以外の状態（~/.claude.json・リンクの状態）へ広げる軸。#401 は settings の宣言の検査なので扱わない
```

案S と案C が初期の選択肢に無かった理由（設計SO の分解）: 案S は「隔離は HOME の差し替えと事後の比較で担う」という隠れていた前提による。案C は探索漏れで、ゲート1 が保存された JSON と判定の基準を中心に探し、生成されたコマンドを使う側の経路を扱っていなかった。

## 設計SO（ゲート2・弱・Codex 1レーン）

2026-10-18、`so-compare --codex-only` で plan の DJ-1〜DJ-10・受入・選択肢拡張を問うた。レーンのモデルは `gpt-6.1-sol`（`model_resolved_source=config`。実行後の観測値ではなく設定から読んだ値）、`codex-cli 0.163.0`、155 秒、初回で返答した。Codex が返ったので、Cursor には切り替えていない。依頼文と出力は `tmp/401-settings-apply-check/so-design-prompt.md` と `tmp/401-settings-apply-check/so-design-codex/`（作業層・消える）にある。レーンは issue の本文を GitHub の接続エラーで取得できず、確定版のコメントと plan で照合した（本文との照合は未完と開示された）。結論は「直してから進めてよい」で、指摘は7件、7件とも採った。

| # | 対象 | 指摘 | 採否 |
|---|---|---|---|
| 1 | DJ-5・DJ-7 | M1 は replace の誤りへの感度にはなるが、apply と check の独立性を機械的に守るものではない。check が「空の settings に apply を当てて期待値を作る」形に変わっても、M1 の欠陥は空の入力には正しい値を書くので見つけられない。ポインタを解く関数だけを共有のファイルへ出す変更も見つけられない | **採った**。M1 の役目を replace の誤りへの感度に限った。独立性の守りとして、どんな入力にも誤った値を書く M6 と、ファイル名の参照と読み込みの行が無いことを見る構造の確かめを足した（DJ-5） |
| 2 | DJ-6 | 能力4は一部の回復である。`/statusLine` 全体を不変の検査から除くので、`.statusLine` の下の正本に無いキーが消えても、check にも [12]・[48] にも見えない。集計も「取り戻す5」と分けるべき | **採った**。`handler` と `merge-object` の pointer では前にあったキーが消えていないことを見る規則を DJ-1 に足し、M2 に statusLine の padding を消す差し替えを足した。値だけ変わる場合は残る穴として書き、集計を「取り戻す4・一部を取り戻す1・別の検査に回す1」に直した（DJ-1・DJ-5・DJ-6） |
| 3 | DJ-1・DJ-8 | 「項目を足してもテストを書き換えずに済む」の範囲が広すぎる。入れ子の pointer を足すと、不変の検査が親を拾う。`absent` の項目を足すと、[4]・[17] の期待に現れないキーが入る | **採った**。保証の範囲を「最上位の pointer に `replace` の項目を足す場合」と「このテストのファイル」に限って書き、入れ子のときは赤に倒れることを書いた（DJ-7）。[4]・[17] の期待から `absent` の項目を除いた（DJ-8） |
| 4 | DJ-2・DJ-9・A11 | HOME の文字列の接頭辞だけでは隔離を保証できない（`..`・親の symlink）。引き継いだ `BASH_ENV` は HOME を変えても非対話の bash の起動で実行される。`chmod` は git の mode ではなく実物の `-x` で決まる。A11 の前後の一致は、途中で触れていないことの証明にならない | **採った**。物理パスで比べる・`BASH_ENV` と `ENV` を外す・走らせる前に実物の実行権を確かめる、を DJ-9 に足した。A11 は `sandbox-exec` で書き込みを拒む実行を主な証拠にし、前後の比較は最終の状態の確かめとして残した |
| 5 | DJ-2・M5 | M5 が観測するのは sync の interpreter だけで、sync が apply を `/bin/bash` で起動する形に変わっても見えない | **採った**。M5 に apply の側の観測を足し、sync と apply のそれぞれが自分の shebang の interpreter で動いていることを見る形にした。2つの主版番号が同じ環境では区別できないことも書いた（DJ-2・DJ-5・DJ-6） |
| 6 | A9 | 「check を呼ばない」弱め方の中身と、赤になるべき確かめが決まっていない | **採った**。3つの弱め方の中身と、赤になるべき確かめを A9 に書いた |
| 7 | DJ-3 | wrapped の説明「type が無い」は誤りで、撤去前の fixture には `"type":"command"` がある | **採った**。説明を直した。fixture の中身は変えない |

問題なしとされた点: 不変の検査の比べ方（キーの和集合・有無を先に比べる・構造で比べる）、stale_replace と期待の組分け、M1〜M4 の期待、差し替えの行が実物で1回ずつ当たること（replace は apply の230行、reduce は273行、`set -euo pipefail` は sync の21行）、sync の側の M5 が bash 5 で回したときに空でない主張になること、bash 3.2 の方針、[4]・[17] の直しと Q1 の切り分け。

選択肢拡張では、案S（OS の書き込み制限の下で full sync を走らせる）と案C（statusLine を使う側から確かめる）が出た。案S は A11 で1回だけ使い、案C は既存の項目が同じ観測をしているので足さない（「ゲート1」節）。

## 受入

| # | 確かめること | 見方 |
|---|---|---|
| A1 | 本物の木の9件が DJ-4 の期待どおりになる | テストの [22] の PASS の行 |
| A2 | M1 が DJ-5 の表のとおりに落ちる（issue の反証1） | テストの [22] の M1 の PASS の行。落ちた fixture の一覧と理由の文言を主張している |
| A3 | M2 が DJ-5 の表のとおりに落ちる（issue の反証2） | 同じく M2 の行。拾ったキーが `theme` と `statusLine.padding` であること |
| A4 | M3 で9件すべてが期待どおりになり、5項目目が実際に当たっている（issue の反証3） | 同じく M3 の行 |
| A5 | M4 で sync が 0 でない値を返し、settings.json が変わらない | 同じく M4 の行 |
| A6 | M5 で、sync と apply のそれぞれが自分の shebang の interpreter で走っている | 同じく M5 の行。bash 5 が PATH にある環境では区別できる主張になっていること |
| A6b | M6 と構造の確かめで、成立条件の守りが効いている | 同じく M6 の行と構造の確かめの行 |
| A7 | 宣言に5項目目を足しても、`test_apply_claude_settings.sh` 全体を変えずに緑のまま | worktree を scratchpad へ写し、写しの宣言に最上位の `replace` の項目を1つ足して、写しのテストを走らせる（1回だけ・I1-3） |
| A8 | bash 5 と `/bin/bash`（3.2）の両方で緑 | `test_apply_claude_settings.sh`・`test_check_claude_settings.sh`・`test_sync_output_styles.sh`・`test_sync_claude_statusline.sh` の4本を両方の bash で回し、最後の集計の行で FAIL が 0 であることを見る |
| A9 | 検査の側を弱めると、対応する確かめが赤になる | テストの写しで、次の3つを1つずつ当てて走らせる（1回だけ・I1-2）。W1: 不変の検査の関数が、比べずに常に空の文字列を返す。赤になるべきは M2 の「拾った fixture の一覧」と「拾ったキー」の確かめである。W2: sync を `"$BASH"` を前に付けて起動する。bash 5 で回したとき、赤になるべきは M5 の sync の側の確かめである。W3: check を呼ぶ箇所を、終了コード 0 と空の出力を返す形に置き換える。赤になるべきは、本物の木の書けない相手3件の「check が 1 と理由を返す」確かめ、M1 の「check が落とす fixture の一覧」と理由の確かめ、M6 の確かめである |
| A10 | shellcheck で新しい警告が出ない | `shellcheck projects/orchestration-engine/tests/test_apply_claude_settings.sh` の出力を変更前（警告0件・P2 で記録）と比べる |
| A11 | 本物の `~/.claude` とリポジトリに書き込んでいない | 主な証拠: `sandbox-exec` で `~/.claude`・`~/.claude.json`・worktree への書き込みを拒む設定の下で、テストを1回走らせて緑のまま。補う証拠: 走らせる前と後で、`~/.claude/settings.json` の shasum と mtime、`~/.claude` の下のリンク先の一覧、worktree の `git status` が同じ |
| A12 | テストの時間を記録する | 変更前（P1 の実測で bash 5 が14秒・3.2 が13秒）と変更後を比べ、60秒を超えたら DJ-5 の最後の箇条に従う |

## ステップ

**I1 以降は、統括から owner の承認（ゲート3）が届いてから進む。** P1〜P3 がこの委譲の最初の終端までの工程である。

### P1: worktree・episode の枠・参照の読み（完了）

- worktree: `test/#401_settings_apply_check`（`origin/master` の `ed45de5` から）。
- episode: `docs/harness/episodes/2026-10-18-episode-401-settings-apply-check.md`。

### P2: plan を書き、設計SO（弱・Codex 1レーン）を当てる（完了）

```bash
W='<worktree>'
SO_TIMEOUT=480 so-compare -w "$W" -f "$W/tmp/401-settings-apply-check/so-design-prompt.md" -o "$W/tmp/401-settings-apply-check/so-design-codex" --codex-only
```

- Codex が返らなければ、`--cursor-only` に1回だけ切り替え、理由を episode に書く。
- 結果と採否を、この plan の「設計SO」節と episode に書く。

### P3: plan と episode を commit して push し、報告して止まる

```bash
git -C '<worktree>' add docs/harness/plans/2026-10-18-plan-401-settings-apply-check.md docs/harness/episodes/2026-10-18-episode-401-settings-apply-check.md
git -C '<worktree>' commit -m 'docs(harness): #401 の plan と episode の枠を置く'
git -C '<worktree>' push -u origin 'test/#401_settings_apply_check'
```

- PR はまだ作らない。`.oe/report-401.md` に報告を書き、brief の「報告の宛先」の統括（`oe-tree` に root `cockpit` として出ることを確かめる）へ `projects/orchestration-engine/bin/oe-send` で plan のパスを1行送り、exit code を確かめて止まる。

### GATE 3: owner の plan 承認（「報告の宛先」の統括からの送信で届いたものだけを数える）

承認で決めてほしいことは3つある。

- Q1: `test_check_claude_settings.sh` の `build_green` は、宣言の4項目を名指しで組み立てるので、項目を足すと check のテストの [1] が「未適用」で落ちる。この PR で宣言から導く形に直すか、follow-up の issue にするか。推奨は follow-up である。[22] の代わりの外で、1つの PR を1つの論理的な変更に保てる。A7 では、写しで実際に落ちることを確かめて証拠に残す。
- Q2: 陽性対照（M1〜M6）と構造の確かめをテストの中に常に置き、テストの時間が30〜40秒ほどに延びることを受け入れるか（DJ-5）。
- Q3: 失った能力4を「一部を取り戻す」とする扱い（DJ-6）でよいか。残る穴は、statusLine の中で check の述語が見ないキーが、消えずに値だけ変わる場合と、包んだ元コマンドの中身が変わる場合で、後者の一部は既存の3項目が見ている。

### I1-0: baseline の確認

```bash
git -C '<worktree>' fetch origin
git -C '<worktree>' log --oneline ed45de5..origin/master -- scripts/sync canonical/claude canonical/hooks/claude.hooks.json projects/orchestration-engine/tests/test_apply_claude_settings.sh
```

- 出力が空なら進む。どれかが master で動いていたら、rebase してから差分を読み、plan の前提が崩れていれば止まって統括へ報告する。

### I1-1: [22] の検査と [4]・[17] の直しを書く（1コミット）

- [22] の跡の注記を、新しい [22] の節に置き換える。注記の「何を確かめていたか・なぜ外したか」は、新しい節の冒頭のコメントに短く残し、#338 と #401 を指す。
- ファイルの冒頭の「検証する軸」に、使い捨ての HOME で sync を走らせることと、新しい [22] の軸を足す。冒頭の「一時ディレクトリの settings.json だけを触る」も、使い捨ての HOME を含む書き方に直す。
- [4] と [17] の期待を、宣言から導く形にする（DJ-8）。

### GATE I1-1: テストが両方の bash で緑

```bash
cd '<worktree>' && for sh in bash /bin/bash; do "$sh" projects/orchestration-engine/tests/test_apply_claude_settings.sh 2>&1 | tail -1; done
```

- 2行とも `=== PASS=<数> FAIL=0 ===` であること。終了コードだけで読まない。

### I1-2: 検査の側を弱めた写しで、対照が赤になることを確かめる（A9）

- テストの写しを scratchpad に作り、3つの弱め方を1つずつ当てて走らせる。赤になった項目の名前を episode に書く。

### I1-3: 宣言に5項目目を足した写しで、テスト全体が緑のままであることを確かめる（A7）

- worktree を scratchpad へ写し、写しの宣言に項目を1つ足し、写しの `test_apply_claude_settings.sh`・`test_check_claude_settings.sh`・`test_sync_output_styles.sh` を走らせる。期待は、1本目と3本目が緑で、2本目が [1] で落ちることである（Q1 の証拠）。

### I1-4: 残りの受入（A8・A10・A11・A12）

- 4本のテストを両方の bash で回す。shellcheck を変更前と比べる。本物の `~/.claude` の前後を比べる。時間を記録する。

### GATE I1: A1〜A12（A6b を含む）がすべて満たされている

- 1つでも満たされなければ、止まって原因を episode に書き、plan の直しが要るなら級を決めて統括へ申告する。

### I2: 実装SO・PR・Copilot

- `oe-review` の既定の codex+cursor を差分に当て、採否を episode に書く。
- PR を作る（`pr-conventions`・本文は `Refs #401`）。Copilot に1ラウンド依頼し、未返信を0件にする。

### I3: episode を閉じ、報告して止まる

- `episode-retrospective` で closure を書く（マージ前）。`.oe/report-401.md` に報告を書き、「報告の宛先」へ `oe-send` で送って exit code を確かめ、止まる。マージ・worktree の掃除・issue の close はしない。
