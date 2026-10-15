---
id: "01M4XY7FXPRTX5JGAWFGZJJ0MM"
title: "#429 破壊的コマンドのフックを、行に含まれる各コマンドで判定する形に直す"
date: 2026-10-15
type: plan
status: in-development      # ゲート3 承認済み（2026-10-15・6つの判断はすべて推奨どおり）。実装中
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/429"
    reason: "作業対象。認識合わせの確定版はこの issue のコメントにある"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/429#issuecomment-6176310004"
    reason: "着手時の認識合わせの確定版"
  - type: reference
    ref: "docs/harness/episodes/2026-10-15-episode-429-destructive-hook-compound.md"
    reason: "上流の断定の裏取り（probe の結果）、実装方式の計測、設計SO の経緯の記録"
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

この plan は、判定の単位を「行の先頭」から「行に含まれる各コマンド」に変える設計と、そのテストの構成を決める。区切りの文法（引用符の扱いを含む）、扱う形と扱わない形、誤って拒否しうる形とその判断、同じ型の抜けの扱い、ルールの書き方の直し方を、ここで決める。設計SO（ゲート2・Codex 1レーン）の指摘は本文に反映済みで、採否の一覧は「設計SO（ゲート2）」節にある。

## この plan の範囲

- 直すもの: `canonical/hooks/scripts/block-destructive.sh`。同じ型の抜けがある `block-force-push.sh` も直す（DJ-7・owner 判定）。`canonical/hooks/README.md` と `canonical/rules/careful-operations-rule.md` の書き方。既存テスト `test_hook_firing.sh` のフック起動の実行系の明示（DJ-10）。
- 作るもの: フックの判定を固定し、迂回を捕まえるテスト（`projects/orchestration-engine/tests/test_hook_judgment.sh`）。
- 範囲外: `cc-lint.sh` の判定（独自の `&&` 抽出を据え置く。正規表現を変えると非回帰を証明できなくなる、という PR #311 の判断を引き継ぐ）。SQL の検査の意味論（DJ-6）。DJ-9 に列挙した「扱わない形」。発火記録の仕組み（#309）。

## 上流の断定の裏取り（結果と強さ）

#429 本文・確定版・brief の断定を、master `069b65b` のスクリプトにフックの判定だけをさせて当てた（コマンドは実行していない）。表と経緯は episode の「上流の断定の裏取り」節にあり、要点は次のとおりである。

- 3つの形はすべて allow（rc=0）になる。確認済み。bash 3.2 と bash 5 で結果は同じ。
- 先頭が `rm` のときだけ判定し、剥がすのは `sudo` だけ。確認済み。
- 3ツールの配備先はいずれも master の作業ツリーへの symlink で、sync は要らない。確認済み。worktree での編集は実物に影響しない。
- 判定専用のテストは無く、`test_hook_firing.sh` の [2] に例が3件あるだけ。確認済み。
- 同じ型の抜けは、同じフックの chmod・chown・mkfs・dd・git reset・git clean の6検査と、`block-force-push.sh` にもある。確認済み（issue は「確かめる」としか書いていなかった）。

設計SO が挙げた「今の判定」についての断定13件も、同じ方法で当ててから採った（episode の「設計SO」節）。

## 今の判定の読み解き

probe で分かった今の判定を、抜けの族ごとにまとめる（表の全体は `tmp/429-destructive-hook/probe-bash5.tsv` と `probe2-so-bash5.tsv`）。

### 族1: 区切り（issue が名指しした族）

`&&`・`||`・`;`・`|`・改行・`( )`・`{ }`・`$( )`・バッククォート・`bash -c`・`sh -c`・`eval` のどれで前に別のコマンドを付けても allow になる。例外は `rm -rf / & true` で、これは先頭が `rm` で `&` が対象の1つに数えられるため偶然 deny になる。

### 族2: 前置き（issue が名指ししていない同じ型）

先頭の空白・`\rm`・`/bin/rm`・`env rm`・`env -u git rm`・`command rm`・`exec rm`・`nohup rm`・`time rm`・`FOO=1 rm`・`>/dev/null rm`・`! rm` のどれでも allow になる。剥がすのが `sudo` だけだからである。`sudo -u root rm -rf /` も、`root` を先頭と見るので allow になる。`bash -c -- 'rm -rf /'` も allow になる。

### 族3: 対象の書き方（同じく名指しなし）

`rm -rf "/"`・`rm -rf '/'`・`rm -rf "~"`・`rm -rf "$HOME"`・`rm -rf ${HOME}`・`rm -rf ./` が allow になる。対象を空白で切っただけで引用符を外していないためで、`./` は `.` と完全一致しない。一方 `rm -rf /tmp/x`（絶対パス）・`rm -rf $HOME/x`・`rm -rf ~/`・`rm -rf node_modules /`（安全と危険の混在）は deny になり、`rm -rf foo`・`rm -rf ../x`・`rm -r /`（`-f` なし）・`rm -rf node_modules > "/tmp/log"`（転送先は対象でない）は allow になる。これらは今の規則どおりなので変えない。

### ほかの検査と force-push

chmod・chown・mkfs・dd・git reset・git clean の6検査は先頭固定で、`cd x && ...` で allow になる。git の2検査は `git -C x reset --hard` のような git 自身のオプションでも allow になる（`block-force-push.sh` は `git -C x push` を扱えるのに、こちらは扱えない）。SQL の検査（`DROP TABLE`・`DROP DATABASE`・`TRUNCATE TABLE`）だけは全文の部分一致なので、つないだ形も止めるが、heredoc の中のデータも止める（既知の過検知。episode の「自分のコマンドが実物のフックに止められた」節）。

`block-force-push.sh` は `cd x && git push --force`・`true; git push -f`・`bash -c "git push --force"`・`sudo git push --force` を allow にする。`git commit -m x && git push --force` は `git(\s+\S+)*\s+push` という正規表現が `commit && git` を途中の token として飲み込むので偶然 deny になる。

### 今の判定で変えないもの

今 allow で、直した後も allow のまま残すもの（受入の群C）: 安全ディレクトリだけを対象にする `rm -rf`（`cd x && rm -rf node_modules`・`rm -rf node_modules > "/tmp/log"` を含む）、相対パスの `rm -rf foo`、`-f` の無い `rm -r /`、引用符の中に破壊的な文字列を持つだけのコマンド（`echo 'rm -rf /'`・`git commit -m "fix: deny cd /tmp && rm -rf /"`・`grep -n 'rm -rf /' file`・`python3 -c "print('rm -rf /')"`）、heredoc の本文に破壊的な文字列を持つだけのコマンド（`cat > f <<'EOF' ... EOF`）、コマンドの所在を確かめるだけの形（`command -v mkfs.ext4`・`type rm`・`ls -l /sbin/mkfs.ext4`・`test -x /sbin/mkfs.ext4`）、`git clean --force -n`（dry-run）。

### 今 deny で、直した後は allow になるもの（意図した変更・群D）

今の判定の過検知を、この単位の作り直しで直すもの。owner に判断4 で預ける。

- `git clean -fd xdir`: 引数全体の文字列に `x` があるだけで deny になっている。option の token だけを見るようにする。
- `git clean -fdxn`: dry-run を deny している。`-n` / `--dry-run` があれば allow にする。
- `rm -rf node_modules # /`: 注釈の `/` を対象に数えている。注釈を捨てる。
- `git push --force-with-lease # --force`: 注釈の `--force` を見ている。同上。

I1-1 で群C を変更前のフックに当てたとき、同じ種類の過検知がさらに見つかり、群D に移した（ゲート3 の判断4 と同じ種類なので、この単位で allow に直す。I3 の報告で owner に見せる）。

- `rm -rf node_modules >> /tmp/log 2>&1`・`rm -rf node_modules &> /tmp/log`: 空白を挟んだ転送の相手（絶対パス）を rm の対象に数えている。転送の相手は token から除く（DJ-2）。
- `git clean -fdx --dry-run`: `-n` と同じく dry-run。
- `mkfs.ext4`（引数なし）: DJ-3 の mkfs の規則（引数があるときだけ deny）の帰結。

## 設計判断

### DJ-1 判定の単位を「行の先頭」から「行に含まれる各単純コマンド」に変える

コマンド文字列を仕事の列（queue）に積み、1件ずつ「走査器」で単純コマンド（segment）に分け、各 segment を「token 化」し、segment の中に現れる既知のコマンド名（DJ-3）ごとに既存の検査（rm・chmod・chown・mkfs・dd・git）を当てる。どれか1つでも deny なら deny で、全部通れば allow である。`bash -c`・`eval` の中身は、見つけたときに queue に積み戻す（DJ-4）。`$( )`・バッククォートの中身は走査器が同じ1回の走査で segment にする（DJ-2）。

今の実装は「安全な rm なら早期 allow」をするが、これは `rm -rf node_modules && git reset --hard` を allow にするので、早期 allow をやめて次の segment へ進む（意図した変更・群B）。

### DJ-2 走査器の文法（1回の走査・文脈の積み重ね）

引用符を意識して分ける（確定版が「設計で決める」とした点の答え）。引用符の中の `;` を区切りと誤ると、`git commit -m "a; b"` や `python3 -c "..."` が壊れるし、このフックを直す作業自体（コミットメッセージやテストに `cd /tmp && rm -rf /` を書く）が止まる。走査は文字列を1回だけ通し、各周回で必ず位置が進む（終わらない入力を作らない。設計SO の指摘13）。

- 状態は4つ: 引用符の外・単一引用符の中・二重引用符の中・ANSI-C 引用（`$'...'`）の中。
- 引用符の外で区切るもの: `&&`・`||`・`;`（`;;`・`;&`・`;;&` を含む）・`|`（`|&` を含む）・`&`（`&&` でも `&>`・`>&`・`<&` の一部でもないもの）・改行・`(`・`)`（深さ0のとき。サブシェルの開閉）。segment の先頭の空白・`{`・`!` は落とす。
- 単一引用符の中は、閉じる `'` まで何も解釈しない。
- 二重引用符の中は、`\` が意味を持つのは `$`・バッククォート・`"`・`\`・改行の前だけで、それ以外の `\` は文字として残す（`"mk\fs.ext4"` は `mk\fs.ext4` のまま）。`$(` とバッククォートはここでも実行されるので、次の項の扱いに入る。
- ANSI-C 引用（`$'...'`）は独立の状態で、`\'` は閉じ引用符ではなく `'` の文字、`\\` は `\`、ほかの `\X` は復号せずそのまま残す（`$'rm'` は `rm` になり、`$'\x72m'` は閉じない形として DJ-9 に残す）。
- `$(` とバッククォートは、引用符の外でも二重引用符の中でも、そのときの引用の状態を積んで（push）引用符の外の状態に入り、対応する `)`（またはバッククォート）で元の状態に戻す（pop）。中身はこの同じ走査で segment に分かれる。外側の segment はその部分を抜いて続く。再帰も再走査もしない。
- `$((` は算術式の文脈に入り、中身は見ないが、その中の `$( )` とバッククォートは実行されるので同じように積む（`echo $(( $(git reset --hard) + 1 ))` は deny）。`( )` の入れ子を数えて `))` で抜ける。中の `<<` はシフト演算子のままで heredoc と混同しない（実装SO の指摘5 で「読み飛ばす」から改めた）。
- 引用符の外の `\` は自分を消して次の1文字を文字として残す（`r\m` は `rm`）。`\` と改行の組は引用符の外でも二重引用符の中でも**消して連結する**（`r\` + 改行 + `m` は `rm`。空白にはしない。設計SO の指摘3）。単一引用符の中では文字のまま残す。
- `#` が token の先頭に来たら、その行の終わりまで注釈として捨てる。
- heredoc: `<<` または `<<-`（`<<<` は here-string なので除く）を見たら区切り語を読む。区切り語には token と同じ引用の規則（`'…'`・`"…"` の中の `\` は `$`・バッククォート・`"`・`\` の前だけ・`$'…'`・`\`）を当て、引用符か `\` が1つでもあれば「引用あり」とし、値は引用を解いたもの（空も有効）にする（実装SO の指摘4 で `<<$'EOF'`・`<<"E\OF"` を正しく扱う形に改めた）。1行に複数あれば順に待ち行列に積み、同じ行の残りは普通に区切る。改行の後は、待ち行列の順に、区切り語と同じ行（`<<-` なら先頭のタブを除いて比べる）まで本文として読む。**引用ありの本文はデータとして捨てる。引用なしの本文は、`\` と改行を連結してから区切り語と比べ、本文全体を「データの中の `$( )` とバッククォートだけが実行される」モードで走査する**（二重引用符と同じ `\` の規則で、`"` だけは文字。`cat <<EOF` の本文に `$(rm -rf /)` があれば deny、`\$(rm -rf /)` はデータ、置換が複数行にまたがっても引用の中に `)` があっても正しく扱う。設計SO の指摘4 と実装SO の指摘3・6）。区切り語が最後まで現れなければ残り全部を本文とする。
- 引用符や `$(` が閉じないまま終わったら、残りをそのまま最後の segment として扱う（捨てない。`rm -rf / "` でも先頭は見える）。
- token 化（segment ごと）: 上の引用の規則で値を解いた token の列にする。転送の演算子とその相手（`>f`・`> f`・`>>f`・`>|f`・`<f`・`<>f`・`&>f`・`&>>f`・`2>&1`・`n>&m`・`<<<word`）は token の列から除く（`rm -rf node_modules > "/tmp/log"` の `/tmp/log` を対象に数えない。設計SO の指摘8）。`NAME=value` の代入と `--` は token として残す（既知のコマンド名ではないので害は無い）。
- 走査器が解釈しない構文は DJ-9 の (b) に列挙する（`case` の `)`・`${...}` の内部・brace expansion・`$'\xNN'` の復号）。

### DJ-3 segment の中で、既知のコマンド名に一致するすべての token を先頭として検査する

token 化の後、`rm`・`chmod`・`chown`・`mkfs*`・`dd`・`git`・shell（`bash`・`sh`・`zsh`・`dash`・`ksh`）・`eval` のどれかに一致する token を**すべて**先頭とし、それぞれの後ろを引数として検査する。一致の前に、token の先頭の `\` を落とし、`/` を含むならその basename を取る（`\rm`・`/bin/rm`・`'rm'`・`$'rm'` を同じ `rm` にする）。前置き（`sudo` とそのオプション・`env -u git`・`timeout 10`・`nohup`・`FOO=1`・`>/dev/null`・`!`）は見ない。

- 最初の1つではなくすべてを見る理由: 最初の1つだけだと `env -u git rm -rf /`・`sudo -u git rm -rf /` のように、前置きのオプションの引数が既知の名前（`git`）のとき本体の `rm` を隠せる（設計SO の指摘1）。すべてを見れば `git`（subcommand は `rm` なので何もしない）と `rm`（deny）の両方が検査される。
- `mkfs*` は名前だけで deny していたが、それでは `command -v mkfs.ext4`・`type mkfs.ext4`・`ls -l /sbin/mkfs.ext4`・`test -x /sbin/mkfs.ext4` が deny になる（設計SO の指摘2）。「後ろに `-` で始まらない token があれば deny」では `git grep -n 'mkfs.ext4' -- README.md` が deny になる（実装SO の指摘7）ので、mkfs は「`/dev/` で始まる引数があるとき」か「segment の先頭（コマンドの位置）に在って `-` で始まらない引数があるとき」だけ deny にする（`mkfs.ext4 /dev/sda`・`cd x && mkfs.ext4 /dev/sda`・`mkfs.ext4 disk.img` は deny、`mkfs.ext4` 単独と `sudo mkfs.ext4 disk.img` は allow に変わる。後者は前置きの後ろのイメージファイルという稀な形で、dd の基準（`of=/dev/`）に揃えた）。
- shell（`bash`・`sh` など）は、`-c` の文字列を取れた最初の1つだけを列に積む。`env -u bash sh -c '…'` のように前置きの引数に shell の名前があっても、文字列の無いものは飛ばして次を見る（実装SO の指摘2）。
- この形にする理由: 前置きを列挙して剥がす形（今の sudo 剥がし）は、列挙に無い前置き（`timeout`・`doas`・`setsid`・`caffeinate`・`stdbuf`）が残り、`sudo -u root` のようにオプションが引数を取る形も1つずつ扱うことになる。knowledge `01KYCQV7SD6BVBWVCRFYJH9TYG` の「1つ直しても同じ族の迂回が残る」がそのまま当たる族なので、列挙せずに閉じる。今の sudo 剥がしのコードは不要になる。
- コスト: 引用符で囲まれていないデータに既知のコマンド名と危険な引数が並ぶと deny になる。`echo rm -rf /`（引用符なし）が deny になり、`echo "rm -rf /"`（全体が1つの token）は allow のままである。名前だけを引用しても（`echo 'rm' -rf /`）token 化で外れるので避けられない。この形は受入の群B に「意図した deny」として載せ、境界を固定する。
- 設計SO は代替の DJ-3'（前置きの固定表: sudo・doas・env・command・exec・nohup・time・nice・timeout・builtin と、代入・転送を剥がす）を勧めた。本 plan が DJ-3 を推奨のまま残す理由は、(1) すべての token を見る形にすれば指摘1 の隠し方は閉じ、前置きの族そのものが閉じること、(2) DJ-3' は表に無い前置きを DJ-9 に残し続けること、(3) 誤検知の形が「引用符なしのデータに既知の名前と危険な引数を並べる」に限られ、エージェントの実用でまず書かないことである。どちらを採るかは owner に預ける（判断1）。

### DJ-4 `bash -c`・`sh -c`・`eval` の中身は queue に積み戻す

- shell の token の後ろを shell のオプションとして歩く。`--` はオプションの終わり、`-c` が単独か短オプションの束（`-lc`・`-ec`・`-xc`）の中にあれば「`-c` あり」、`-o X`・`+o X`・`--rcfile X`・`--init-file X` は次の token も飛ばし、ほかの `-` で始まる token は飛ばす。最初の「オプションでない token」が、`-c` ありなら command 文字列（引用符を外した値）として queue に積む（`bash -c -- 'rm -rf /'` も `bash -o errexit -c 'rm -rf /'` も拾う。設計SO の指摘9）。`-c` なしならスクリプトファイルなので扱わない（DJ-9 の (a)）。
- `eval` はその後ろの token をすべて空白で連結して積む。
- queue の入れ子の深さは 8 までとし、超えたら「解析できない」として deny にする（理由の名前は `nesting-limit`。`cc-lint.sh` が grep の環境エラーを deny に倒すのと同じ保守的な向き）。件数の上限は置かない（`$( )` は走査器の1回の走査で扱うので、`$(true)` が257個あっても queue には積まれない。shell と eval は segment ごとに1つしか積まないので、件数は segment の数に収まる）。各 queue の要素は元の文字列の部分文字列なので、仕事の量は元の長さ × 深さに収まる。最初の実装は安全装置として件数の上限 64 も置いていたが、`bash -c 'echo ok'` を64個並べた1行を止めてしまうので外した（実装SO の指摘8）。

### DJ-5 rm の対象の正規化

token 化が引用符を外し転送を除くので、`"/"`・`'~'`・`"$HOME"` は今の判定の文字列（`/`・`~`・`$HOME`）に揃う。そのうえで次を足す。

- 末尾の `/` を落とす（`/` そのものは残す）。`./` は `.` に、`~/` は `~` に、`/tmp/x/` は `/tmp/x` になる。
- 先頭の `./` を繰り返し落とす（`./node_modules` を安全ディレクトリの完全一致に乗せる）。
- `${HOME}` と `${HOME}/*` を `$HOME` の形に加える。
- `~` で始まる token（`~user`・`~user/x`）は home と扱って deny にする。今は `~` と `~/*` だけである。
- 安全ディレクトリの判定（`SAFE_DIRS_RE`）は正規化した token に当てる。一覧は変えない。

### DJ-6 ほかの検査の扱い

- chmod・chown・mkfs・dd は、同じ先頭規則で segment ごとに当てる。引数の見方は今の正規表現と同じ意味に揃える（chmod は `-R` と `777` と `/` で始まる対象、chown は `-R` と `/` で始まる対象、mkfs は DJ-3 のとおり、dd は `of=/dev/` で始まる引数）。
- git は、`git` の後ろの token から subcommand を取る。`-C`・`-c`・`--git-dir`・`--work-tree`・`--namespace` は次の token も飛ばし、`-` で始まる token は飛ばす。subcommand が `reset` で引数に `--hard` の token があれば deny。subcommand が `clean` なら、`--` より前の option の token（`-` で始まるもの）から文字を**集めて**（短オプションの束は1文字ずつ、`--force` は f、`-d` は d、`-x` は x、`-n` と `--dry-run` は「dry-run」）、dry-run でなく f・d・x がそろえば deny にする。`git clean -f -d -x` は deny のまま、`git clean --force -n` は allow のまま、`git clean -fdxn` は allow に変わる（設計SO の指摘10）。`block-force-push.sh` の `git -C . push` の扱いと向きを揃える。
- **git clean で見る文字を option の token に限るのは意図した変更である。** 今は引数全体の文字列に f・d・x があるかを見るので、`git clean -fd xdir` のようにパスに `x` が含まれるだけで deny になる（過検知）。直した後は allow になる。受入の群D に載せ、owner に判断してもらう（判断4）。
- SQL の検査は raw の全文に対する部分一致のまま変えない。理由は3つある。README の陽性対照（`echo` に `DROP TABLE` 文を含める）がこの意味論に依存している。heredoc で `psql` に流す形を今は止めていて、segment 単位に変えると新しい迂回になる。既知の過検知（heredoc のデータが止まる）は今の判定なので、この単位では残して範囲外として報告する。

### DJ-7 `block-force-push.sh` も同じ単位で直す

- 走査器・token 化・既知の名前の検出・queue を、2本（`block-destructive.sh`・`block-force-push.sh`）に byte 一致で置く新しい共通区間（`--- shared-cmd begin ---` から `--- shared-cmd end ---`）にする。既存の共通区間（発火記録・trap）は3本で byte 一致のまま触らない。`test_hook_firing.sh` の [1] に、新しい区間が2本で一致する検査を足す。
- `block-force-push.sh` の `main` は、segment ごとに `git` の token を取り、subcommand が `push` なら今の引数の判定（`--force`/`-f` と lease 系）をそのまま当てる。`sudo git push --force` は先頭規則で自然に止まる。
- `cc-lint.sh` には共通区間を置かない（使わない関数を持たせると shellcheck 0.10 の SC2329 が出るし、cc-lint の判定は据え置くため）。
- 代替案: force-push は別の issue にする。落とした理由は、走査器を共通区間に置く以上 `block-force-push.sh` にも同じコードが入り、`main` の差分は十数行で、同じ型を同じ PR で閉じれば検証が1回で済むこと。ただし brief の SO の理由は「変更は1本のスクリプトとテストに収まる」と書いているので、2本に広げるかは owner に預ける（判断2）。

### DJ-8 実装は純 bash（`LC_ALL=C` を走査器に限って適用・1文字ずつの走査・早い経路・heredoc は行単位）。条件付きの採用

- 計測（episode の「区切り器の実装方式の計測」節）: 1文字ずつの走査は、既定ロケールの bash 3.2 で 7KB に 779 ms かかるが、`LC_ALL=C` にすると 190 ms になり bash 5 と同じになる。短い1行は 5〜7 ms。awk なら 32 ms。現行フックの1回は約 17 ms。**この計測は引用の状態を追う走査器だけのもので、token 化・queue・対象の正規化・heredoc を含む完成版の所要ではない**（設計SO の指摘12）。
- `LC_ALL=C` は走査器の関数の中で `local LC_ALL=C` として適用し、外へ出さない（bash 3.2 でも `local` で効くことを確かめた。episode の「設計SO」節）。deny のメッセージの出力と、共通区間の記録の `cmd_len`（文字数）の契約は変えない。UTF-8 をバイトで走査しても、判定するのは ASCII の構文だけで、元のバイト列はそのまま残るので成立する。
- 早い経路: 既知のコマンド名（`rm`・`chmod`・`chown`・`mkfs`・`dd`・`git`・`eval`・`sh`）の文字の間に引用符・`\`・改行・`$` が挟まることを許した正規表現1回で見て、1つも当たらなければ走査せずに allow へ進む（SQL の検査は別に当てる）。`ls`・`cat`・`grep`・`echo` だけの行はこれで今と同じ速さになる。`r\m`・`"r"m`・`r$'m'`・`r\` + 改行 + `m` も当たるので早い経路をすり抜けない。文字列置換で引用符を除く形は採らない（bash 3.2 の `${var//…}` は一致が多い行で極端に遅い。実装SO の指摘1・9）。
- 同じ名前の判定は segment の中で1回に抑える（後ろに現れた同じ名前の引数は先に現れたものの引数の部分集合なので、先の判定で足りる。git は subcommand が位置で決まるので毎回見て、reset・clean・push の判定だけを1回にする）。heredoc の本文は残り全文を写さず窓で行を読む。これで「`rm` を1360個並べた1行」「`''` を2048個並べた1行」「短い行が4090行の heredoc」の3つの形が上限に収まった（実装SO の指摘9。計測は episode の「I2-1」節）。
- heredoc の本文は行の比較（引用なしなら `$(` とバッククォートの検出も）で飛ばすので、長い文書を書く操作は走査の対象がほぼ残らない。残る遅い場合は、既知の名前を含む長い1行である。
- **条件付きの採用**: GATE I1 で完成版の2本を通した所要を、1 KB・4 KB・16 KB の3つの大きさ × 3つの形（heredoc で文書を書く行・既知の名前を含む1行・既知の名前を含まない1行）× 両方の bash で測る。上限は 8 KB 相当で 250 ms・短い1行で 30 ms とし、超えたら awk の埋め込み（32 ms）に切り替える。awk を最初から採らない理由は、第2の言語を hot path に入れること、BSD awk と gawk の差、awk から bash へ segment を戻す受け渡し（引用符の中の改行）が要ることである（判断3）。
- bash 3.2 で動く書き方に限る（`declare -A`・`mapfile`・`${var,,}` を使わない。`+=`・`${s:i:1}`・`=~`（パターンは変数に置く）・`local LC_ALL=C` は使える）。

### DJ-9 扱わない形と、careful-operations-rule の直し方

フックが見るのは「行の字面に書かれた各単純コマンド」である。次の形はこの単位では閉じない（knowledge のとおり、閉じないものは列挙して外に出す）。理由を3つに分ける（設計SO の指摘11）。

**(a) 実行環境の情報が要る（字面に無い）**

| 形 | 例 |
|---|---|
| 変数・glob で決まる対象 | `rm -rf $DIR`・`for d in /; do rm -rf $d; done` |
| 標準入力から対象を受ける | `echo / \| xargs rm -rf` |
| 標準入力・heredoc・ファイルから command を受ける shell | `echo "rm -rf /" \| bash`・`bash <<'EOF'`・`bash script.sh`・`source x` |
| alias・関数 | `alias wipe='rm -rf /'; wipe` |

**(b) 字面にはあるが、静的解析を実装しない**

| 形 | 例 |
|---|---|
| brace expansion | `rm -rf {.,..}` |
| 二重引用符の中の `$( )` に `case` の `)` がある形 | `"$(case x in x) rm -rf /;; esac)"`（`)` を置換の終わりと誤る。引用符の外の `$( )` と、行の先頭の `case` は正しく扱える） |
| `${...}` の内部 | `${v:-rm -rf /}`（文字として扱う。誤検知も見逃しも起きない） |
| 符号化・大文字・計算される名前 | `$'\x72m' -rf /`・macOS の `RM -rf /`・`$(echo rm) -rf /` |

**(c) 別の操作族（この族の検査ではない）**

| 形 | 例 | 行き先 |
|---|---|---|
| 別の tool による削除 | `find / -delete`・`find / -exec rm -rf {} +` | ルール §2 の確認の対象 |
| 別のインタプリタ | `python3 -c "os.system('rm -rf /')"` | ルール §1 を自分で守る |
| refspec による force push | `git push origin +HEAD:main` | #435（force-push の別形。この単位では扱わない。ゲート3 で統括が起票） |

`careful-operations-rule.md` の直し方（PR #366 で §1 を「要約であって列挙ではない」形にした判断を引き継ぎ、§1 は要約のままにする）:

- §1 の「The command is denied.」の後ろに1文を足す。「The hook inspects every simple command written on the line, including parts joined by `&&`, `||`, `;`, `|`, newlines, subshells, `$( )`, and the string passed to `bash -c` / `sh -c` / `eval`, whatever prefix (`sudo`, `env`, `timeout`, ...) precedes it.」
- §1 の末尾に短い段落を足す。「The hook judges only what is written literally on the line. A destructive target that reaches the command through stdin (`xargs`), a variable or glob, an alias, `find -delete`, a script file, or a shell fed from stdin or a heredoc is not visible to the hook. These remain §1 bans that the agent refuses itself.」
- §2 に「Filesystem (not hooked)」の表を1つ足し、`xargs rm -rf` / `find ... -delete` / `rm -rf "$VAR"` を載せる。`rm -rf "$VAR"` の行は「If the resolved target falls under §1, refuse; otherwise confirm the resolved target」と書き、§1 の禁止を確認で解除できる書き方にしない（設計SO の指摘11）。
- §3 の「sudo handling」を「Prefix handling」に改め、sudo・env・timeout などの前置きの後ろでも同じ判定が当たる旨に書き換える。
- `review-when` の条件（hook が止めるパターンが変わったら見直す）に当たるので、この変更は正当である。

`canonical/hooks/README.md` の直し方: 「ブロック対象」に「制御演算子でつないだ各部分・`$( )`・`bash -c`・`eval` の中身・前置き（sudo・env・timeout 等）の後ろ」を足し、「対象外（将来の拡充候補）」から「パイプ・サブシェル経由」を外して、上の (a)(b)(c) に置き換える。陽性対照の注意（コマンド行に payload を置かない）はそのまま残す。

### DJ-10 テストの構成

新しいテスト `projects/orchestration-engine/tests/test_hook_judgment.sh` を表駆動で作る。1行が「期待 rc・フック・コマンド」で、フックには `HOOK_FIRING_DIR` を一時ディレクトリに向けて判定だけをさせる。フックを起動する実行系は `"${HOOK_BASH:-$BASH}"` にし、`bash tests/...` と `/bin/bash tests/...` の両方で回す（テストが対象を別の実行系で走らせる罠を避ける。knowledge `01M00KCCHNMFPHP5HAGX2DZ1MK` の観測）。

| 群 | 内容 | 変更前の master での結果 | 役目 |
|---|---|---|---|
| A 固定 | 今の allow と deny（族3 のうち今止まるもの・安全ディレクトリ・`-f` なし・SQL の全文一致・`git clean -f -d -x`・force-push の lease）| 通る | 今の判定を固定する。受入の錨ではない |
| B 迂回の捕捉 | 本文の3つの形、族1・族2・族3 の allow になるもの、6検査の `cd x && ...`、`git -C x ...`、`bash -c -- '...'`、`env -u git rm`、引用なし heredoc の `$( )`、`r\` + 改行 + `m`、force-push の4形、早期 allow をやめる形、DJ-3 の意図した deny（`echo rm -rf /`） | **落ちる**（件数を I1 で記録） | 受入の錨（knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ`） |
| C 安全な形の守り | 引用符の中のデータ・heredoc のデータ（引用ありと、引用なしで `$( )` の無いもの）・`python3 -c`・`git commit -m "... && rm -rf /"`・`"mk\fs.ext4"`・`cd x && rm -rf node_modules`・`rm -rf node_modules > "/tmp/log"`（転送の書き方を数通り）・`command -v mkfs.ext4` などの所在の確認・`git clean --force -n` | 通る | 誤検知の見張り。変更後も通ることが受入 |
| D 意図した判定の変更 | `git clean -fd xdir`・`git clean -fdxn`・`rm -rf node_modules # /`・`git push --force-with-lease # --force`（いずれも allow に変わる）| 落ちる | owner が判断4 で採ったものだけを入れる。採らなければ群A に戻す |
| E 終わること | 閉じない引用符・閉じない `$(`・区切り語の無い heredoc・深い `( )` の入れ子・`$(true)` を257個含む行・9段の `bash -c` の入れ子（`nesting-limit`）| 通る（今は走査しないため）| `timeout 10` の下で rc が 0 か 2 に到達し、hang しない（設計SO の指摘13） |

- 1行ごとに rc・`permission` の JSON（`CLAUDE_PROJECT_DIR` を置いたとき）・deny なら `deny.jsonl` の `rule`（狙った検査のもの）・allow なら `deny.jsonl` の行数が増えていないことを照合する（陽性対照は「期待した理由でその色が出たか」まで見る）。`nesting-limit` の行は `rule` が `internal-error` でないことを見る。
- **錨から外した行もテストとしては残す。** 変更前で落ちなかった行は「錨に数えない」と注記するだけで、表からは消さない（設計SO の指摘14）。
- `test_hook_firing.sh` は、フックを起動する箇所（`fire`・`fire_out`・FIFO と timeout の中の `bash '$BD'`）の実行系を `"${HOOK_BASH:-$BASH}"` に揃える。[3]（`inherit_errexit`）は bash 4.4 未満には無いので、版を見て skip する。[1] に新しい共通区間の一致を足す。これ以外は変えない（設計SO の指摘15）。
- 所要時間は自動テストにせず、GATE I1 で DJ-8 の行列を `time` で測って episode に記録する。

### DJ-11 deny のメッセージと理由の名前は変えない

`user_message` は今の「Destructive rm blocked: <コマンド全文>」のまま、`deny.jsonl` の `rule` も今の名前のままにする（`oe-hookfire` の集計と互換）。新しく足す理由は `nesting-limit` だけである。`argv0` は行全体の先頭 token（`cd /tmp && rm -rf /` なら `cd`）になるが、これは記録の定義（先頭 token）どおりなので変えない。

## 誤って拒否しうる形とその判断

| 形 | 直した後 | 判断 |
|---|---|---|
| `echo rm -rf /`（引用符なしのデータ） | deny | 許容する（DJ-3）。全体を引用符で囲めば allow。群B に載せて境界を固定 |
| `ssh host rm -rf /`・`docker exec c rm -rf /`・`kubectl exec p -- rm -rf /` | deny | 許容する。遠隔・コンテナの中でも破壊的で、§2 の確認の対象でもある。全体を引用符で囲めば allow（遠隔側の字面は見ない） |
| `git rm -rf .` | deny（今は allow） | 許容する。`git rm -r --cached .` は `-f` が無いので allow。群B |
| `rm -rf "/my dir"` | deny（今は allow） | 規則どおり（絶対パスは止める）。群B |
| `git commit -m "fix: deny cd /tmp && rm -rf /"` | allow | 引用符の中。群C |
| `cat > f <<'EOF'` の本文に `rm -rf /` | allow | 引用ありの heredoc はデータ。群C |
| `cat <<EOF` の本文に `$(rm -rf /)` | deny | 引用なしの heredoc では実行される。群B |
| `cat > f <<'EOF'` の本文に `DROP TABLE` | deny（今も deny） | SQL は全文一致のまま（DJ-6）。範囲外として報告 |
| `command -v mkfs.ext4`・`ls -l /sbin/mkfs.ext4` | allow | mkfs は引数があるときだけ（DJ-3）。群C |
| `git clean -fd xdir`・`git clean -fdxn` | allow（今は deny） | 過検知の訂正。判断4・群D |
| `grep -r rm -rf /`（contrived） | deny | 許容する。実用上まず書かない形 |

## 受入

- [x] #429 本文の3つの形が deny になり、`deny.jsonl` の `rule` が `rm-destructive` である（群B）。
- [x] 群B を変更前の master `069b65b` のスクリプトに当てると落ちる。記録（I1-2・bash 5 と /bin/bash 3.2 で同じ）: 群B 69行のうち 68行が落ちる。落ちない1行（`rm -rf node_modules && rm -rf /`）は変更前でも deny なので錨に数えず、行は残した。群D は 8行すべて落ちる。群A 57行・群C 38行・群E 7行は変更前でも通る（錨に数えない）。
- [x] 変更後は 198行すべて通る（群A 57・群B 78・群C 43・群D 8・群E 12。実装SO の後で群B +9・群C +5・群E +5。変更前の master では群B 78行のうち 77行・群D 8行が落ちる）。
- [x] `test_hook_judgment.sh`（198件）と `test_hook_firing.sh`（bash 5 で 54件・3.2 で 50件と [3] の skip）が両方の bash で緑。フックの起動も同じ実行系。
- [x] `shellcheck` がフック2本とテスト2本で警告なし。
- [x] 所要時間（GATE I1・episode の表。実装SO の後の最終の値）: 短い1行は変更前 +1〜3 ms（bash 3.2 で 18 ms・bash 5 で 18 ms）。既知の名前を含む 4 KB の1行は 20 ms（3.2）/ 20 ms（5）、16 KB で 32 ms / 26 ms。heredoc 4 KB は 20 ms / 21 ms、16 KB は 38 ms / 36 ms。この行列は上限（8 KB 相当で 250 ms・短い1行で 30 ms）に収まる。実装SO が足した3つの形は、引用符の密な 4 KB の1行が 19 ms / 21 ms、短い行が 4090 行の 16 KB の heredoc が 268 ms / 267 ms（8 KB 相当なら約 134 ms で上限内）、`rm` を 1360 個並べた 4 KB の1行が 166 ms / 148 ms で、**最後の形だけは token の数に比例して増える（約 0.12 ms / token）ので、8 KB 相当（約 2700 token）では上限を超える見込み**である。実用のコマンドにこの形は無く、終了は数百 ms で hang ではないので、この単位では awk に切り替えず、既知の限界として README と報告に書く（判断3 の条件に当たるかは owner に見せる）。最初の版は 1文字ずつ token に足していて 16 KB の1行で 0.8〜1.0 秒かかり、窓（256 バイト）ごとに進む形に直し、実装SO の後に早い経路の正規表現化・同じ名前の判定の1回化・heredoc の行の窓読みを足して上の値になった。
- [ ] README と careful-operations-rule の文面が DJ-9 のとおりで、`SAFE_DIRS_RE` と README の一覧の一致（PR #366 の検査）が崩れていない。
- [x] sync は不要であることを、配備先の symlink の向き（3ツールとも master の作業ツリーの `canonical/hooks/scripts/` を指す）で再確認した。

## リスク

- 誤検知で普段の作業が止まる。対処: 群C で守る形を先に固定し、マージ後に止まった形が出たら `canonical/hooks/scripts/block-destructive.sh` を1ファイル戻せば済む（配備は symlink なので `git revert` と `git pull` だけ）。
- このフックを直す作業自体が実物のフックに止められる。対処: 判定させる文字列はファイルに置き、コマンド行に載せない（episode の節・README の注意）。実物は master の作業ツリーを指すので、worktree での変更は実物に影響しない。
- bash 3.2 と 5 の差。対処: 両系でテストを回す（受入）。
- 所要時間。対処: 早い経路・走査器に限った `LC_ALL=C`・heredoc の行単位の飛ばし。上限を超えたら awk へ（DJ-8）。
- 走査器の文法の取りこぼし。対処: 閉じない形を DJ-9 に列挙してルールの側に出す。残る族が見つかったら群B に足す形で育てる。
- 走査器が終わらない。対処: 1回の走査で各周回が必ず進む形にし、群E で `timeout` の下に置く。

## owner に預ける判断（ゲート3）

**ゲート3 の答え（2026-10-15）: 6つとも推奨どおりで、plan 全体を承認。** owner の裁定は統括が `.oe/decision-429-gate3.md`（作業層）に記録し、判断6 の follow-up は統括が #435 に起こした。以下の各項は承認時の記述のまま残す。

1. **DJ-3**: 既知のコマンド名に一致するすべての token を先頭として検査する形（推奨）か、前置きの固定の表で剥がす形（DJ-3'）か。前者は `echo rm -rf /` が deny になる代わりに前置きの族を閉じる。設計SO は後者を勧めた（理由は DJ-3 の末尾）。
2. **DJ-7**: `block-force-push.sh` もこの単位で直す（推奨）か、別の issue にするか。brief の SO の理由は「1本のスクリプト」を想定していた。
3. **DJ-8**: 純 bash の条件付き採用（推奨。完成版の計測が上限を超えたら awk）か、最初から awk か。
4. **DJ-6・DJ-10 の群D**: 今の過検知4つ（`git clean -fd xdir`・`git clean -fdxn`・注釈の中の `/` と `--force`）をこの単位で allow に直す（推奨）か、今の判定のまま残すか。
5. **DJ-9**: careful-operations-rule の直し方の範囲。§1 に2文を足し §2 に表を1つ足し §3 を書き換える案（推奨）か、§1 の2文だけにするか。
6. **DJ-9 (c)**: `git push origin +HEAD:main`（refspec による force push）を follow-up の issue にする（推奨）か、この単位の `block-force-push.sh` に含めるか。

## 設計SO（ゲート2）

弱 SO・Codex 1レーン（`gpt-6.1-sol`・`codex-cli 0.162.1`・初回で返答・261秒）。結果は `tmp/429-destructive-hook/so-design/codex-stdout.txt`。判定は「直してから通す」で、指摘は15件（高10・中5）。採否は次のとおりで、採った指摘は本文に反映済みである。設計SO が挙げた「今の判定」についての断定（指摘2・8・9・10・11・14）は、採る前に変更前のスクリプトに当てて確かめた（`tmp/429-destructive-hook/probe2-so-bash5.tsv`・13行すべて SO の言うとおりだった）。

| # | 重要度 | 指摘の要点 | 採否 | 反映先 |
|---|---|---|---|---|
| 1 | 高 | DJ-3 は `env -u git rm -rf /` で本体を隠せる。DJ-3' を勧める | 一部採る。既知の名前を**すべて**検査する形に変えて隠し方を閉じた。DJ-3' への変更は採らず、owner の判断1 に SO の勧めを併記 | DJ-3 |
| 2 | 高 | `command -v mkfs.ext4` 等が deny になる | 採る。mkfs は引数があるときだけ deny。誤検知表の「引用符を付ければ」の説明も直した | DJ-3・群C |
| 3 | 高 | `\` + 改行を空白にすると `r\`+改行+`m` を見逃す | 採る。消して連結する。早い経路も同じ規則 | DJ-2・DJ-8 |
| 4 | 高 | 引用なし heredoc の `$( )` は実行される | 採る。区切り語の引用の有無を持ち、引用なしの本文は `$( )` とバッククォートだけ見る | DJ-2・群B |
| 5 | 中 | 複数 heredoc・区切り語の引用の形・空の区切り語 | 採る。待ち行列と引用解除の契約を書いた | DJ-2 |
| 6 | 高 | `$'...'` と二重引用符の `\` の規則が無い | 採る。ANSI-C 引用を独立の状態にし、二重引用符の `\` は5文字の前だけ | DJ-2 |
| 7 | 高 | `$( )` の閉じは括弧の数で決まらない（`case` の `)`）。`${...}`・`$((` の扱い | 一部採る。走査を1回の文脈の積み重ねにし、`$((` は読み飛ばす。`case` の `)` が二重引用符の中の `$( )` に在る形は実装せず DJ-9 (b) に載せた。`${...}` は文字として扱い、SO の言う誤検知は起きないことを確かめた | DJ-2・DJ-9 |
| 8 | 高 | 転送先を rm の対象に数えると安全な形が退行する | 採る。token 化で転送の演算子と相手を除く。群C に転送の形を足す | DJ-2・群C |
| 9 | 高 | `bash -c -- '...'` を拾えない | 採る。shell のオプションを歩く | DJ-4 |
| 10 | 高 | `git clean --force -n` の誤検知と `-f -d -x` の退行 | 採る。option の文字を集め、dry-run は allow | DJ-6・群A・群D |
| 11 | 中 | DJ-9 の分類と、alias・brace expansion・`+refspec`・§2 の書き方 | 採る。3つに分け、`+refspec` は判断6（follow-up 推奨）、§2 の行は「解決した対象が §1 なら拒否」 | DJ-9・判断6 |
| 12 | 中 | 190 ms は完成版の所要でない。`LC_ALL=C` の副作用 | 採る。条件付きの採用にし、計測の行列を GATE I1 に置く。`LC_ALL=C` は走査器の `local` に限る（bash 3.2 で効くことを確認） | DJ-8・GATE I1 |
| 13 | 高 | queue の上限では解析時間と hang を抑えられない | 採る。走査を1回にして件数の上限をやめ、各周回が進むことを設計に書き、群E を足した | DJ-2・DJ-4・群E |
| 14 | 高 | 錨から外した行を消すと非回帰が消える。群D の範囲 | 採る。外した行も残す。群D を4件に広げ、allow 時に deny が記録されないことも見る | DJ-10 |
| 15 | 中 | `test_hook_firing.sh` は外側を 3.2 にしてもフックは bash 5 で動く | 採る。起動の実行系を揃え、[3] は版で skip | DJ-10・範囲 |

## 実装SO（ゲート4）

弱 SO・Codex 1レーン（`gpt-6.1-sol`・`codex-cli 0.162.1`・初回で返答・285秒）。結果は `tmp/429-destructive-hook/so-impl/codex-stdout.txt`。判定は「直してから通す」で、指摘は9件（高6・中3）。SO が「いまの挙動」と断定した11行を、採る前に直す前の実装に当てて確かめた（`tmp/429-destructive-hook/probe4-so-impl-new.tsv`・11行すべて SO の言うとおりだった）。9件とも採り、直した後に同じ11行が狙った判定になることと、既存の表（179行）と範囲外の形（52行）の判定が変わらないことを確かめた。

| # | 重要度 | 指摘の要点 | 採否 | 反映先 |
|---|---|---|---|---|
| 1 | 高 | `r$'m' -rf /` が早い経路をすり抜ける | 採る。早い経路を正規表現1回にし、名前の文字の間の引用・`\`・改行・`$` を許す | DJ-8・群B |
| 2 | 高 | `env -u bash sh -c '…'` で前置きの引数の shell 名が本体の `-c` を隠す | 採る。`-c` の文字列を取れた最初の shell だけを積む | DJ-3・群B |
| 3 | 高 | heredoc の本文の置換を行単位・引用非対応で切り出すと取りこぼす | 採る。本文全体を「データの中の `$( )` と `` ` `` だけ実行」モードで走査器に通す | DJ-2・群B |
| 4 | 高 | 区切り語の `$'EOF'`・`"E\OF"` を誤って解き、後続を本文に吸い込む | 採る。区切り語に token と同じ引用の規則を当てる | DJ-2・群B |
| 5 | 高 | `$(( $(git reset --hard) + 1 ))` を算術式ごと読み飛ばす | 採る。算術式の文脈で `$( )` と `` ` `` だけ拾う | DJ-2・群B |
| 6 | 中 | 引用なし heredoc の `\$(…)` と `a\`+改行+`EOF` を誤って deny | 採る。3 の走査と `\` + 改行の連結で解決 | DJ-2・群C |
| 7 | 中 | `git grep -n 'mkfs.ext4' -- file` を mkfs と誤認 | 採る。mkfs は `/dev/` の引数か、行の先頭に在って引数があるときだけ | DJ-3・群C |
| 8 | 中 | 列の長さの上限 64 が plan（上限なし）と食い違い、64個の `bash -c` を止める | 採る。上限を外し README を直した | DJ-4・群E |
| 9 | 高 | 多数の短い token・引用符の密な行・短い行の多い heredoc で極端に遅い（4 KB で3秒超） | 採る。同じ名前の判定を segment で1回に、早い経路を正規表現に、heredoc の行を窓で読む形に | DJ-8・群E・GATE I1 |

SO が挙げた `sh -c "$(printf 'rm -rf /')"`（置換で組み立てた文字列）は DJ-9 (b) の「計算される名前」に当たるので扱わない。

## ステップ

### P1: worktree・episode の枠・今の判定の読み解き・plan（完了）

- [x] `wt switch --create 'fix/#429_destructive_hook_compound' --base master`（baseline `069b65b`）。
- [x] episode の枠を `docs/harness/episodes/2026-10-15-episode-429-destructive-hook-compound.md` に置いた。
- [x] probe（`tmp/429-destructive-hook/`）で今の判定を読み解き、3つの形の再現を含めて episode に記録した。
- [x] この plan。

### P2: 設計SO（弱・Codex 1レーン）（完了）

- [x] `so-compare -f tmp/429-destructive-hook/so-design-prompt.md -w <worktree> -o <worktree>/tmp/429-destructive-hook/so-design --codex-only`。
- [x] 指摘の採否を「設計SO（ゲート2）」節と episode に書き、plan を直した。

### P3: 報告して止まる（完了）

- [x] plan と episode をこの枝にコミットして push し、draft PR #434 を作った（マージしない）。
- [x] `.oe/report-429-plan.md` を書き、`oe-send '%207'` で送った（exit 0）。
- [x] **STOP**。ゲート3 の owner の承認を待った。

### GATE 3: owner の plan 承認（完了・2026-10-15）

- [x] 6つの判断の答えを受け取った。すべて推奨どおりなので DJ の本文は変えない。判断6 の行き先を #435 に書き換えた（DJ-9 (c)）。

### I1-0: baseline の確認

- [ ] `git -C <worktree> fetch origin master` と `git merge-base --is-ancestor origin/master HEAD` で、枝が最新の master を含むことを確かめる。ずれていれば rebase する。

### I1-1: 今の判定を固定するテストを先に作る（群A・群C・群E）

- [ ] `projects/orchestration-engine/tests/test_hook_judgment.sh` を表駆動で作る（Write ツールで書く。コマンド行に payload を載せない）。
- [ ] `test_hook_firing.sh` のフック起動の実行系を `"${HOOK_BASH:-$BASH}"` に揃え、[3] を版で skip する。
- [ ] 変更前のスクリプトに当てて、群A・群C・群E がすべて通ることを `bash` と `/bin/bash` で確かめる。
- [ ] コミット: `test(hooks): #429 止める側のフックの判定を固定するテストを足す`。

### I1-2: 迂回を捕まえるテストを足し、変更前で落ちることを確かめる（群B・群D）

- [ ] 群B と、判断4 で採った群D を同じ表に足す。
- [ ] 変更前のスクリプトに当てて、群B・群D の落ちる件数を記録する（両系）。落ちない行があれば錨から外す注記を付け、理由を episode に書く（行は消さない）。
- [ ] コミット: `test(hooks): #429 迂回を捕まえる検査を足す`（この時点では赤）。

### I1-3: `block-destructive.sh` を直す

- [ ] 共通区間 `shared-cmd` に走査器・token 化・既知の名前の検出・queue を書く（DJ-2〜DJ-5・DJ-8）。
- [ ] `main` を segment の繰り返しに変え、6検査を token 配列で判定する形に書き換える（DJ-6）。SQL は raw 全文のまま。
- [ ] `shellcheck canonical/hooks/scripts/block-destructive.sh`。
- [ ] コミット: `fix(hooks): #429 block-destructive を行に含まれる各コマンドで判定する`。

### I1-4: `block-force-push.sh` を直す（判断2 で採ったとき）

- [ ] 同じ共通区間を byte 一致で置き、`main` を segment の繰り返しに変える（DJ-7）。
- [ ] `test_hook_firing.sh` の [1] に共通区間の一致を足す。
- [ ] コミット: `fix(hooks): #429 block-force-push も行に含まれる各コマンドで判定する`。

### GATE I1: 受入の検査

- [ ] `bash projects/orchestration-engine/tests/test_hook_judgment.sh` と `/bin/bash ...` の両方が緑。`test_hook_firing.sh` も両系で緑。
- [ ] 所要時間を DJ-8 の行列（3つの大きさ × 3つの形 × 両方の bash × 2本）で `time` で測り、episode に記録する。上限を超えたら DJ-8 の代替案（awk）へ切り替えて I1-3 からやり直す。
- [ ] 群B・群D が変更前で落ちた件数と、変更後に通った件数を plan の「受入」に書く。

### I1-5: README と careful-operations-rule の文面

- [ ] DJ-9 のとおりに直す。`SAFE_DIRS_RE` と README の一覧の一致を機械で確かめる。
- [ ] コミット: `docs(hooks): #429 フックが見る形と見ない形を README とルールに書く`。

### I2-1: 実装SO（弱・Codex 1レーン）

- [ ] 差分を `so-compare` に当てる（`-w` は worktree）。問うのは走査器の取りこぼし・誤検知・bash 3.2 の互換・性能である。
- [ ] 採否を episode に書き、採った指摘を直して GATE I1 を回し直す。

### I2-2: PR と Copilot

- [ ] `pr-conventions` に従い draft PR を ready にする（本文は `Refs #429`・plan と episode を同じ PR に入れる）。`gh pr edit --add-reviewer @copilot` で1ラウンド依頼し、未返信を0件にする。

### I3: episode を閉じ、報告して止まる

- [ ] `episode-retrospective` で closure（昇格の判定・follow-up の行き先。`+refspec` は #435、SQL の過検知の行き先を含む）。
- [ ] `.oe/report-429.md` を `implementer-contract` の形で書き、`oe-send '%207'` で送って **STOP**。マージ・worktree の掃除・issue の close はしない。
