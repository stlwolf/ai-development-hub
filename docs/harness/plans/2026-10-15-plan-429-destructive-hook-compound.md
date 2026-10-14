---
id: "01M4XY7FXPRTX5JGAWFGZJJ0MM"
title: "#429 破壊的コマンドのフックを、行に含まれる各コマンドで判定する形に直す"
date: 2026-10-15
type: plan
status: draft               # ゲート3（owner の承認）待ち
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/429"
    reason: "作業対象。認識合わせの確定版はこの issue のコメントにある"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/429#issuecomment-6176310004"
    reason: "着手時の認識合わせの確定版"
  - type: reference
    ref: "docs/harness/episodes/2026-10-15-episode-429-destructive-hook-compound.md"
    reason: "上流の断定の裏取り（probe の結果）と、実装方式の計測の記録"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "H-3（パイプ・サブシェル経由の拡充）がこの単位に当たる"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/pull/311"
    reason: "止める側の3本の共通区間（発火記録・trap・byte 一致の規律）。この単位は区切り器を同じ流儀で2本に置く"
  - type: design_context
    ref: "projects/orchestration-engine/docs/knowledge/items/01KYCQV7SD6BVBWVCRFYJH9TYG.md"
    reason: "deny-list に対する迂回は族で繰り返す。閉じる迂回と閉じない迂回を分ける根拠"
tags: [hooks, block-destructive, block-force-push, careful-operations, harness, tests]
so:
  design: weak
  impl: weak
  reason: "ハーネスの安全装置で誤って拒否すると作業が止まるので設計と実装の両方に外の目を入れるが、変更はフック2本とテストに収まる（brief の指定。レーンは設計1・実装1とも Codex、実装には Copilot を足す）"
---

# #429 破壊的コマンドのフックを、行に含まれる各コマンドで判定する形に直す

## 背景

`canonical/hooks/scripts/block-destructive.sh` は、Claude Code・Codex・Cursor のすべての Bash の実行の前に走り、破壊的なコマンドを止める。判定はコマンド文字列の先頭だけを見るので、`cd /tmp && rm -rf /` のように前に別のコマンドを付けると素通りする。`canonical/rules/careful-operations-rule.md` の §1 は「フックが機械的に止める」と書いているので、ルールが前提にしている守りが実物に無い。

この plan は、判定の単位を「行の先頭」から「行に含まれる各コマンド」に変える設計と、そのテストの構成を決める。区切りの文法（引用符の扱いを含む）、扱う形と扱わない形、誤って拒否しうる形とその判断、同じ型の抜けの扱い、ルールの書き方の直し方を、ここで決める。

## この plan の範囲

- 直すもの: `canonical/hooks/scripts/block-destructive.sh`。同じ型の抜けがある `block-force-push.sh` も直す（DJ-7・owner 判定）。`canonical/hooks/README.md` と `canonical/rules/careful-operations-rule.md` の書き方。
- 作るもの: フックの判定を固定し、迂回を捕まえるテスト（`projects/orchestration-engine/tests/test_hook_judgment.sh`）。
- 範囲外: `cc-lint.sh` の判定（独自の `&&` 抽出を据え置く。正規表現を変えると非回帰を証明できなくなる、という PR #311 の判断を引き継ぐ）。SQL の検査の意味論（DJ-6）。`xargs`・`find -delete`・変数展開・標準入力から読む shell など、行の字面に対象が現れない形（DJ-9 で「扱わない形」として列挙し、ルールの側で扱う）。発火記録の仕組み（#309）。

## 上流の断定の裏取り（結果と強さ）

#429 本文・確定版・brief の断定を、master `069b65b` のスクリプトにフックの判定だけをさせて当てた（コマンドは実行していない）。表と経緯は episode の「上流の断定の裏取り」節にあり、要点は次のとおりである。

- 3つの形はすべて allow（rc=0）になる。確認済み。bash 3.2 と bash 5 で結果は同じ。
- 先頭が `rm` のときだけ判定し、剥がすのは `sudo` だけ。確認済み。
- 3ツールの配備先はいずれも master の作業ツリーへの symlink で、sync は要らない。確認済み。worktree での編集は実物に影響しない。
- 判定専用のテストは無く、`test_hook_firing.sh` の [2] に例が3件あるだけ。確認済み。
- 同じ型の抜けは、同じフックの chmod・chown・mkfs・dd・git reset・git clean の6検査と、`block-force-push.sh` にもある。確認済み（issue は「確かめる」としか書いていなかった）。

## 今の判定の読み解き

probe で分かった今の判定を、抜けの族ごとにまとめる（表の全体は `tmp/429-destructive-hook/probe-bash5.tsv`）。

### 族1: 区切り（issue が名指しした族）

`&&`・`||`・`;`・`|`・改行・`( )`・`{ }`・`$( )`・バッククォート・`bash -c`・`sh -c`・`eval` のどれで前に別のコマンドを付けても allow になる。例外は `rm -rf / & true` で、これは先頭が `rm` で `&` が対象の1つに数えられるため偶然 deny になる。

### 族2: 前置き（issue が名指ししていない同じ型）

先頭の空白・`\rm`・`/bin/rm`・`env rm`・`command rm`・`exec rm`・`nohup rm`・`time rm`・`FOO=1 rm`・`>/dev/null rm`・`! rm` のどれでも allow になる。剥がすのが `sudo` だけだからである。`sudo -u root rm -rf /` も、`root` を先頭と見るので allow になる。

### 族3: 対象の書き方（同じく名指しなし）

`rm -rf "/"`・`rm -rf '/'`・`rm -rf "~"`・`rm -rf "$HOME"`・`rm -rf ${HOME}`・`rm -rf ./` が allow になる。対象を空白で切っただけで引用符を外していないためで、`./` は `.` と完全一致しない。一方 `rm -rf /tmp/x`（絶対パス）・`rm -rf $HOME/x`・`rm -rf ~/`・`rm -rf node_modules /`（安全と危険の混在）は deny になり、`rm -rf foo`・`rm -rf ../x`・`rm -r /`（`-f` なし）は allow になる。これらは今の規則どおりなので変えない。

### ほかの検査と force-push

chmod・chown・mkfs・dd・git reset・git clean の6検査は先頭固定で、`cd x && ...` で allow になる。git の2検査は `git -C x reset --hard` のような git 自身のオプションでも allow になる（`block-force-push.sh` は `git -C x push` を扱えるのに、こちらは扱えない）。SQL の検査（`DROP TABLE`・`DROP DATABASE`・`TRUNCATE TABLE`）だけは全文の部分一致なので、つないだ形も止めるが、heredoc の中のデータも止める（既知の過検知。episode の「自分のコマンドが実物のフックに止められた」節）。

`block-force-push.sh` は `cd x && git push --force`・`true; git push -f`・`bash -c "git push --force"`・`sudo git push --force` を allow にする。`git commit -m x && git push --force` は `git(\s+\S+)*\s+push` という正規表現が `commit && git` を途中の token として飲み込むので偶然 deny になる。

### 今の判定で変えないもの

今 allow で、直した後も allow のまま残すもの（受入の群C）: 安全ディレクトリだけを対象にする `rm -rf`（`cd x && rm -rf node_modules` を含む）、相対パスの `rm -rf foo`、`-f` の無い `rm -r /`、引用符の中に破壊的な文字列を持つだけのコマンド（`echo 'rm -rf /'`・`git commit -m "fix: deny cd /tmp && rm -rf /"`・`grep -n 'rm -rf /' file`・`python3 -c "print('rm -rf /')"`）、heredoc の本文に破壊的な文字列を持つだけのコマンド（`cat > f <<'EOF' ... EOF`）。

## 設計判断

### DJ-1 判定の単位を「行の先頭」から「行に含まれる各単純コマンド」に変える

コマンド文字列を仕事の列（queue）に積み、1件ずつ「区切り器」で単純コマンド（segment）に分け、各 segment を「token 化」し、segment の中で見つけた先頭（DJ-3）に既存の検査（rm・chmod・chown・mkfs・dd・git）を当てる。どれか1つでも deny なら deny で、全部通れば allow である。`$( )`・バッククォート・`bash -c`・`eval` の中身は、見つけたときに queue に積み戻す（DJ-2・DJ-4）。

今の実装は「安全な rm なら早期 allow」をするが、これは `rm -rf node_modules && git reset --hard` を allow にするので、早期 allow をやめて次の segment へ進む（意図した変更・群B）。

### DJ-2 区切り器の文法

引用符を意識して分ける（確定版が「設計で決める」とした点の答え）。引用符の中の `;` を区切りと誤ると、`git commit -m "a; b"` や `python3 -c "..."` が壊れるし、このフックを直す作業自体（コミットメッセージやテストに `cd /tmp && rm -rf /` を書く）が止まる。

- 引用符の外で区切るもの: `&&`・`||`・`;`（`;;` を含む）・`|`（`|&` を含む）・`&`（`&&` でも `&>`・`>&`・`<&` の一部でもないもの）・改行・`(`・`)`。
- 単一引用符の中は、閉じる `'` まで何も解釈しない。二重引用符の中は `\` の次の1文字を飛ばし、閉じる `"` まで区切らない。引用符の外の `\` は次の1文字を飛ばす（`\` + 改行は空白扱い）。
- `$(` とバッククォートは、引用符の外でも二重引用符の中でも、対応する閉じまでの中身を queue に積む（二重引用符の中でも実行されるため）。外側の segment はその部分を抜いて続ける。`$((` は `$(` として扱ってよい（中身は算術式で、検査に引っかかる先頭を持たない）。
- `#` が token の先頭に来たら、その行の終わりまで注釈として捨てる。
- `<<`（`<<-` を含む・`<<<` は here-string なので除く）を見たら、区切り語を読み（引用符付きなら外す）、同じ行の残りは普通に区切り、改行の後は区切り語だけの行（`<<-` なら先頭のタブを除いて）まで本文として捨てる。区切り語が最後まで現れなければ残り全部を本文として捨てる。heredoc の本文は「データ」と扱う（episode の節のとおり、本文を走査すると文書やテストを書く操作が止まる。`bash <<EOF` のように shell に食わせる形は DJ-9 の「扱わない形」に入れる）。
- 引用符が閉じないまま終わったら、残り全部を1つの segment として扱う（捨てない。`rm -rf / "` のような形でも先頭は見える）。
- segment の先頭の空白・`{`・`!`・`(` は落とす。末尾の `}` は token として残るが害は無い。

### DJ-3 segment の中で検査する「先頭」は、最初に現れる既知のコマンド名の token にする

token 化（引用符を外し、`\` を解いた値）の後、`rm`・`chmod`・`chown`・`mkfs*`・`dd`・`git`・shell（`bash`・`sh`・`zsh`・`dash`・`ksh`）・`eval` のどれかに一致する最初の token を先頭とし、その後ろを引数として検査する。一致の前に、token の先頭の `\` を落とし、`/` を含むならその basename を取る（`\rm`・`/bin/rm`・`'rm'` を同じ `rm` にする）。先頭より前の token（`sudo` とそのオプション・`env`・`timeout 10`・`nohup`・`FOO=1`・`>/dev/null`・`!`）は見ない。

- この形にする理由: 前置きを列挙して剥がす形（今の sudo 剥がし）は、列挙に無い前置き（`timeout`・`doas`・`setsid`・`caffeinate`・`stdbuf`）が残り、`sudo -u root` のようにオプションが引数を取る形も1つずつ扱うことになる。knowledge `01KYCQV7SD6BVBWVCRFYJH9TYG` の「1つ直しても同じ族の迂回が残る」がそのまま当たる族なので、列挙せずに閉じる。今の sudo 剥がしのコードは不要になる。
- コスト: 引用符で囲まれていないデータに既知のコマンド名が現れると deny になりうる。具体的には `echo rm -rf /`（引用符なし）が deny になる。`echo "rm -rf /"` は token が1つなので allow のままである。この形は受入の群B に「意図した deny」として載せ、誤検知の境界を固定する。
- 代替案（DJ-3'）: 前置きを固定の表（sudo・doas・env・command・exec・nohup・time・nice・timeout・builtin）で剥がし、代入と転送も剥がす。誤検知は減るが、表に無い前置きが残る。owner がこちらを選ぶなら表を plan に足して実装する（判断1）。

### DJ-4 `bash -c`・`sh -c`・`eval` の中身は queue に積み戻す

- shell の token の後ろで、`-c` が単独の token か短オプションの束（`-lc`・`-ec`・`-xc`）の中にあれば、その次の token（引用符を外した値）を1件として queue に積む。`eval` はその後ろの token をすべて空白で連結して積む。
- 深さは 8・総件数は 256 までとし、超えたら「解析できない」として deny にする（`cc-lint.sh` が grep の環境エラーを deny に倒すのと同じ保守的な向き。理由の名前は `nesting-limit`）。
- `bash script.sh`・`bash <<EOF`・`echo ... | bash`・`source x` は扱わない（DJ-9）。

### DJ-5 rm の対象の正規化

token 化が引用符を外すので、`"/"`・`'~'`・`"$HOME"` は今の判定の文字列（`/`・`~`・`$HOME`）に揃う。そのうえで次を足す。

- 末尾の `/` を落とす（`/` そのものは残す）。`./` は `.` に、`~/` は `~` に、`/tmp/x/` は `/tmp/x` になる。
- 先頭の `./` を繰り返し落とす（`./node_modules` を安全ディレクトリの完全一致に乗せる）。
- `${HOME}` と `${HOME}/*` を `$HOME` の形に加える。
- `~` で始まる token（`~user`・`~user/x`）は home と扱って deny にする。今は `~` と `~/*` だけである。
- 安全ディレクトリの判定（`SAFE_DIRS_RE`）は正規化した token に当てる。一覧は変えない。

### DJ-6 ほかの検査の扱い

- chmod・chown・mkfs・dd は、同じ先頭規則で segment ごとに当てる。引数の見方は今の正規表現と同じ意味に揃える（chmod は `-R` と `777` と `/` で始まる対象、chown は `-R` と `/` で始まる対象、mkfs は名前だけ、dd は `of=/dev/` で始まる引数）。
- git は、`git` の後ろの token から subcommand を取る。`-C`・`-c`・`--git-dir`・`--work-tree`・`--namespace` は次の token も飛ばし、`-` で始まる token は飛ばす。subcommand が `reset` で引数に `--hard` があれば deny、`clean` で option の token（`-` で始まるもの）の文字に f・d・x がそろうか `--force` があれば deny。`block-force-push.sh` の `git -C . push` の扱いと向きを揃える。
- **git clean の判定を option の token に限るのは意図した変更である。** 今は引数全体の文字列に f・d・x があるかを見るので、`git clean -fd xdir` のようにパスに `x` が含まれるだけで deny になる（過検知）。直した後は allow になる。受入の群D に載せ、owner に判断してもらう（判断4）。
- SQL の検査は raw の全文に対する部分一致のまま変えない。理由は3つある。README の陽性対照（`echo` に `DROP TABLE` 文を含める）がこの意味論に依存している。heredoc で `psql` に流す形を今は止めていて、segment 単位に変えると新しい迂回になる。既知の過検知（heredoc のデータが止まる）は今の判定なので、この単位では残して範囲外として報告する。

### DJ-7 `block-force-push.sh` も同じ単位で直す

- 区切り器と token 化を、2本（`block-destructive.sh`・`block-force-push.sh`）に byte 一致で置く新しい共通区間（`--- shared-cmd begin ---` から `--- shared-cmd end ---`）にする。既存の共通区間（発火記録・trap）は3本で byte 一致のまま触らない。`test_hook_firing.sh` の [1] に、新しい区間が2本で一致する検査を足す。
- `block-force-push.sh` の `main` は、segment ごとに先頭 `git` を取り、subcommand が `push` なら今の引数の判定（`--force`/`-f` と lease 系）をそのまま当てる。`sudo git push --force` は先頭規則で自然に止まる。
- `cc-lint.sh` には共通区間を置かない（使わない関数を持たせると shellcheck 0.10 の SC2329 が出るし、cc-lint の判定は据え置くため）。
- 代替案: force-push は別の issue にする。落とした理由は、区切り器を共通区間に置く以上 `block-force-push.sh` にも同じコードが入り、`main` の差分は十数行で、同じ型を同じ PR で閉じれば検証が1回で済むこと。ただし brief の SO の理由は「変更は1本のスクリプトとテストに収まる」と書いているので、2本に広げるかは owner に預ける（判断2）。

### DJ-8 実装は純 bash（`LC_ALL=C`・1文字ずつの走査・早い経路・heredoc は行単位）

- 計測（episode の「区切り器の実装方式の計測」節）: 1文字ずつの走査は、既定ロケールの bash 3.2 で 7KB に 779 ms かかるが、`LC_ALL=C` にすると 190 ms になり bash 5 と同じになる。短い1行は 5〜7 ms。awk なら 32 ms。現行フックの1回は約 17 ms。
- 早い経路: 引用符と `\` を除いた文字列に既知のコマンド名（`rm`・`chmod`・`chown`・`mkfs`・`dd`・`git`）が1つも含まれなければ、区切らずに allow へ進む（SQL の検査は別に当てる）。`ls`・`cat`・`grep`・`echo` だけの行はこれで今と同じ速さになる。`r\m` や `"r"m` は除去後に `rm` になるので早い経路をすり抜けない。
- heredoc の本文は行の比較だけで飛ばすので、長い文書を書く操作は走査の対象がほぼ残らない。残る遅い場合は、既知の名前を含む長い1行（7KB で約 190 ms）である。
- 代替案は awk の埋め込み（32 ms）。落とした理由は、第2の言語を hot path に入れること、BSD awk と gawk の差、awk から bash へ segment を戻す受け渡し（引用符の中の改行）が要ることである。SO と owner が所要時間の上限を 190 ms より厳しく置くなら awk に切り替える（判断3）。
- bash 3.2 で動く書き方に限る（`declare -A`・`mapfile`・`${var,,}` を使わない。`+=`・`${s:i:1}`・`=~`（パターンは変数に置く）は使える）。

### DJ-9 扱わない形と、careful-operations-rule の直し方

フックが見るのは「行の字面に書かれた各単純コマンド」である。次の形は字面に対象やコマンド名が現れないので、この単位では閉じない（knowledge のとおり、閉じないものは列挙して外に出す）。

| 形 | 例 | 理由 |
|---|---|---|
| 標準入力から対象を受ける | `echo / \| xargs rm -rf` | `rm -rf` に対象の token が無い |
| 標準入力から command を受ける shell | `echo "rm -rf /" \| bash`・`bash <<EOF`・`bash script.sh`・`source x` | 本文はデータとして扱う（DJ-2） |
| 変数・glob で決まる対象 | `rm -rf $DIR`・`for d in /; do rm -rf $d; done` | 展開後の値を知らない |
| 別の tool による削除 | `find / -delete`・`find / -exec rm -rf {} +` | rm の族ではない。ルール §2 の確認の対象にする |
| 別のインタプリタ | `python3 -c "os.system('rm -rf /')"` | 字面は引用符の中のデータ |
| 計算される名前・符号化 | `$(echo rm) -rf /`・`$'\x72m' -rf /`・macOS の `RM -rf /` | 名前が字面に無い |

`careful-operations-rule.md` の直し方（PR #366 で §1 を「要約であって列挙ではない」形にした判断を引き継ぎ、§1 は要約のままにする）:

- §1 の「The command is denied.」の後ろに1文を足す。「The hook inspects every simple command written on the line, including parts joined by `&&`, `||`, `;`, `|`, newlines, subshells, `$( )`, and the string passed to `bash -c` / `sh -c` / `eval`.」
- §1 の末尾に短い段落を足す。「The hook judges only what is written literally on the line. A destructive target that reaches the command through stdin (`xargs`), a variable or glob, `find -delete`, a script file, or a shell fed from stdin or a heredoc is not visible to the hook. These remain §1 bans that the agent refuses itself.」
- §2 に「Filesystem (not hooked)」の表を1つ足し、`xargs rm -rf` / `find ... -delete` / `rm -rf "$VAR"` を「Confirm: the resolved target」で載せる。
- §3 の「sudo handling」を「Prefix handling」に改め、sudo・env・timeout などの前置きの後ろでも同じ判定が当たる旨に書き換える。
- `review-when` の条件（hook が止めるパターンが変わったら見直す）に当たるので、この変更は正当である。

`canonical/hooks/README.md` の直し方: 「ブロック対象」に「制御演算子でつないだ各部分・`$( )`・`bash -c`・`eval` の中身・前置き（sudo・env・timeout 等）の後ろ」を足し、「対象外（将来の拡充候補）」から「パイプ・サブシェル経由」を外して、上の表の「扱わない形」に置き換える。陽性対照の注意（コマンド行に payload を置かない）はそのまま残す。

### DJ-10 テストの構成

新しいテスト `projects/orchestration-engine/tests/test_hook_judgment.sh` を表駆動で作る。1行が「期待 rc・フック・コマンド」で、フックには `HOOK_FIRING_DIR` を一時ディレクトリに向けて判定だけをさせる。実行系は `"$BASH"` で、`bash tests/...` と `/bin/bash tests/...` の両方で回す（テストが対象を別の実行系で走らせる罠を避ける。knowledge `01M00KCCHNMFPHP5HAGX2DZ1MK` の観測）。

| 群 | 内容 | 変更前の master での結果 | 役目 |
|---|---|---|---|
| A 固定 | 今の allow と deny（族3 のうち今止まるもの・安全ディレクトリ・`-f` なし・SQL の全文一致・force-push の lease）| 通る | 今の判定を固定する。受入の錨ではない |
| B 迂回の捕捉 | 本文の3つの形、族1・族2・族3 の allow になるもの、6検査の `cd x && ...`、`git -C x ...`、force-push の4形、早期 allow をやめる形、DJ-3 の意図した deny（`echo rm -rf /`） | **落ちる**（件数を I1 で記録） | 受入の錨（knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ`） |
| C 安全な形の守り | 引用符の中のデータ・heredoc のデータ・`python3 -c`・`git commit -m "... && rm -rf /"`・安全ディレクトリの `cd x && rm -rf node_modules` | 通る | 誤検知の見張り。変更後も通ることが受入 |
| D 意図した変更 | `git clean -fd xdir` の allow（DJ-6）| 落ちる | owner が判断4 で採ったときだけ入れる |

- deny の理由も照合する。群B の各行で `deny.jsonl` の `rule` が狙った検査（`rm-destructive`・`git-reset-hard` など）であることを見る（陽性対照は「期待した理由でその色が出たか」まで見る）。
- `test_hook_firing.sh` は変えないで通す（[2] の3件は群A と重なるが残す）。[1] に新しい共通区間の一致を足す。
- 所要時間は自動テストにせず、I1 の GATE で `time` で測って episode に記録する（上限は 7KB の1行で 250 ms・短い1行で 30 ms。超えたら DJ-8 の代替案へ）。

### DJ-11 deny のメッセージと理由の名前は変えない

`user_message` は今の「Destructive rm blocked: <コマンド全文>」のまま、`deny.jsonl` の `rule` も今の名前のままにする（`oe-hookfire` の集計と互換）。新しく足す理由は `nesting-limit` だけである。`argv0` は行全体の先頭 token（`cd /tmp && rm -rf /` なら `cd`）になるが、これは記録の定義（先頭 token）どおりなので変えない。

## 誤って拒否しうる形とその判断

| 形 | 直した後 | 判断 |
|---|---|---|
| `echo rm -rf /`（引用符なしのデータ） | deny | 許容する（DJ-3）。引用符を付ければ allow。群B に載せて境界を固定 |
| `ssh host rm -rf /`・`docker exec c rm -rf /`・`kubectl exec p -- rm -rf /` | deny | 許容する。遠隔・コンテナの中でも破壊的で、§2 の確認の対象でもある。引用符で囲めば allow（遠隔側の字面は見ない） |
| `rm -rf "/my dir"` | deny（今は allow） | 規則どおり（絶対パスは止める）。群B |
| `git commit -m "fix: deny cd /tmp && rm -rf /"` | allow | 引用符の中。群C |
| `cat > f <<'EOF'` の本文に `rm -rf /` | allow | heredoc はデータ。群C |
| `cat > f <<'EOF'` の本文に `DROP TABLE` | deny（今も deny） | SQL は全文一致のまま（DJ-6）。範囲外として報告 |
| `git clean -fd xdir` | allow（今は deny） | 過検知の訂正。判断4 |
| `grep -r rm -rf /`（contrived） | deny | 許容する。実用上まず書かない形 |

## 受入

- [ ] #429 本文の3つの形が deny になり、`deny.jsonl` の `rule` が `rm-destructive` である（群B）。
- [ ] 群B を変更前の master `069b65b` のスクリプトに当てると落ちる（件数を I1-2 で記録し、ここに書く）。群A・群C は変更前でも通る（錨に数えない）。
- [ ] 群A・群C が変更後も通る。
- [ ] `test_hook_judgment.sh` と `test_hook_firing.sh` が `bash` と `/bin/bash`（3.2）の両方で緑。
- [ ] `shellcheck` が2本（判断2 で1本なら1本）とテストで警告なし。
- [ ] 所要時間が上限（7KB の1行で 250 ms・短い1行で 30 ms）に収まる。
- [ ] README と careful-operations-rule の文面が DJ-9 のとおりで、`SAFE_DIRS_RE` と README の一覧の一致（PR #366 の検査）が崩れていない。
- [ ] sync は不要であることを、配備先の symlink の向きで再確認する。

## リスク

- 誤検知で普段の作業が止まる。対処: 群C で守る形を先に固定し、マージ後に止まった形が出たら `canonical/hooks/scripts/block-destructive.sh` を1ファイル戻せば済む（配備は symlink なので `git revert` と `git pull` だけ）。
- このフックを直す作業自体が実物のフックに止められる。対処: 判定させる文字列はファイルに置き、コマンド行に載せない（episode の節・README の注意）。実物は master の作業ツリーを指すので、worktree での変更は実物に影響しない。
- bash 3.2 と 5 の差。対処: 両系でテストを回す（受入）。
- 所要時間。対処: 早い経路・`LC_ALL=C`・heredoc の行単位の飛ばし。上限を超えたら awk へ（DJ-8）。
- 区切り器の文法の取りこぼし。対処: 閉じない形を DJ-9 に列挙してルールの側に出す。残る族が見つかったら群B に足す形で育てる。

## owner に預ける判断（ゲート3）

1. **DJ-3**: 先頭を「最初に現れる既知のコマンド名」で取る形（推奨）か、前置きの固定の表で剥がす形（DJ-3'）か。前者は `echo rm -rf /` が deny になる代わりに前置きの族を閉じる。
2. **DJ-7**: `block-force-push.sh` もこの単位で直す（推奨）か、別の issue にするか。brief の SO の理由は「1本のスクリプト」を想定していた。
3. **DJ-8**: 純 bash（推奨・7KB の1行で約 190 ms）か awk（約 32 ms）か。
4. **DJ-6**: `git clean` の過検知（パスに `x` があると deny）をこの単位で訂正する（推奨）か、今の判定のまま残すか。
5. **DJ-9**: careful-operations-rule の直し方の範囲。§1 に2文を足し §2 に表を1つ足し §3 を書き換える案（推奨）か、§1 の2文だけにするか。

## 設計SO（ゲート2）

（P2 で埋める）

## ステップ

### P1: worktree・episode の枠・今の判定の読み解き・plan（完了）

- [x] `wt switch --create 'fix/#429_destructive_hook_compound' --base master`（baseline `069b65b`）。
- [x] episode の枠を `docs/harness/episodes/2026-10-15-episode-429-destructive-hook-compound.md` に置いた。
- [x] probe（`tmp/429-destructive-hook/`）で今の判定を読み解き、3つの形の再現を含めて episode に記録した。
- [x] この plan。

### P2: 設計SO（弱・Codex 1レーン）

- [ ] プロンプトをファイルに書き、`so-compare -f <prompt> -w <worktree> -o <worktree>/tmp/429-destructive-hook/so-design --codex-only` で回す。問うのは DJ-2 の文法の取りこぼし、DJ-3 の誤検知の境界、DJ-8 の方式、DJ-9 の列挙の抜けである。
- [ ] 指摘の採否を「設計SO（ゲート2）」節と episode に書く。plan を直したら差分を節に残す。

### P3: 報告して止まる

- [ ] plan と episode をこの枝にコミットして push し、draft PR を作る（マージしない）。
- [ ] `.oe/report-429-plan.md` を書き、`projects/orchestration-engine/bin/oe-send '%207' '<report のパス>'` で送り、exit code を確かめる。
- [ ] **STOP**。ゲート3 の owner の承認を待つ。

### GATE 3: owner の plan 承認

- [ ] 上の5つの判断の答えを受け取り、plan の該当 DJ を確定させる（変わったら「ゲート3 のあとの変更」節を設ける）。

### I1-0: baseline の確認

- [ ] `git -C <worktree> merge-base --is-ancestor 069b65b HEAD` と `git fetch origin master` で、枝が最新の master から切れていることを確かめる。ずれていれば rebase する。

### I1-1: 今の判定を固定するテストを先に作る（群A・群C）

- [ ] `projects/orchestration-engine/tests/test_hook_judgment.sh` を表駆動で作る（Write ツールで書く。コマンド行に payload を載せない）。
- [ ] 変更前のスクリプトに当てて、群A・群C がすべて通ることを `bash` と `/bin/bash` で確かめる。
- [ ] コミット: `test(hooks): #429 止める側のフックの判定を固定するテストを足す`。

### I1-2: 迂回を捕まえるテストを足し、変更前で落ちることを確かめる（群B・群D）

- [ ] 群B（と判断4 で採れば群D）を同じ表に足す。
- [ ] 変更前のスクリプトに当てて、群B の落ちる件数を記録する（両系）。落ちない行があれば錨から外し、理由を episode に書く。
- [ ] コミット: `test(hooks): #429 迂回を捕まえる検査を足す`（この時点では赤）。

### I1-3: `block-destructive.sh` を直す

- [ ] 共通区間 `shared-cmd` に区切り器・token 化・先頭の決定・queue を書く（DJ-2〜DJ-5・DJ-8）。
- [ ] `main` を segment の繰り返しに変え、6検査を token 配列で判定する形に書き換える（DJ-6）。SQL は raw 全文のまま。
- [ ] `shellcheck canonical/hooks/scripts/block-destructive.sh`。
- [ ] コミット: `fix(hooks): #429 block-destructive を行に含まれる各コマンドで判定する`。

### I1-4: `block-force-push.sh` を直す（判断2 で採ったとき）

- [ ] 同じ共通区間を byte 一致で置き、`main` を segment の繰り返しに変える（DJ-7）。
- [ ] `test_hook_firing.sh` の [1] に共通区間の一致を足す。
- [ ] コミット: `fix(hooks): #429 block-force-push も行に含まれる各コマンドで判定する`。

### GATE I1: 受入の検査

- [ ] `bash projects/orchestration-engine/tests/test_hook_judgment.sh` と `/bin/bash ...` の両方が緑。`test_hook_firing.sh` も両系で緑。
- [ ] 所要時間を `time` で3通り（短い1行・7KB の heredoc・既知の名前を含む 7KB の1行）測り、episode に記録する。
- [ ] 群B が変更前で落ちた件数と、変更後に通った件数を plan の「受入」に書く。

### I1-5: README と careful-operations-rule の文面

- [ ] DJ-9 のとおりに直す。`SAFE_DIRS_RE` と README の一覧の一致を機械で確かめる。
- [ ] コミット: `docs(hooks): #429 フックが見る形と見ない形を README とルールに書く`。

### I2-1: 実装SO（弱・Codex 1レーン）

- [ ] 差分を `so-compare` に当てる（`-w` は worktree）。問うのは区切り器の取りこぼし・誤検知・bash 3.2 の互換・性能である。
- [ ] 採否を episode に書き、採った指摘を直して GATE I1 を回し直す。

### I2-2: PR と Copilot

- [ ] `pr-conventions` に従い PR を作る（本文は `Refs #429`・plan と episode を同じ PR に入れる）。`gh pr edit --add-reviewer @copilot` で1ラウンド依頼し、未返信を0件にする。

### I3: episode を閉じ、報告して止まる

- [ ] `episode-retrospective` で closure（昇格の判定・follow-up の行き先）。
- [ ] `.oe/report-429.md` を `implementer-contract` の形で書き、`oe-send '%207'` で送って **STOP**。マージ・worktree の掃除・issue の close はしない。
