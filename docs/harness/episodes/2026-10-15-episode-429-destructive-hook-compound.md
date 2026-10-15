---
id: "01M4XY7FXPK6BQPQEBR7WP1GYY"
title: "#429 破壊的コマンドのフックが、前に別のコマンドが付いた rm を止めない"
date: 2026-10-15
type: episode
status: stable               # closure 2026-10-15（マージ前）。達成
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/429"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/429#issuecomment-6176310004"
    reason: "着手時の認識合わせの確定版（統括が投稿）"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-15-plan-429-destructive-hook-compound.md"
    reason: "この単位の plan"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "H-3（パイプ・サブシェル経由の拡充）がこの単位に当たる"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/pull/311"
    reason: "止める側のフックの共通区間（発火記録・trap）を入れた PR。共通区間の byte 一致の規律はここから"
tags: [hooks, block-destructive, block-force-push, careful-operations, harness]
promotion:
  - subject: "先頭だけを見る判定は同じフックの6検査と force-push にもあり、区切り・前置き・対象の書き方の3つの族に分かれる"
    verdict: not-required
    ref: "本文: 上流の断定の裏取り（フックに判定だけをさせて再現した・2026-10-15）"
  - subject: "引用なしの heredoc の本文はデータではなく、$( ) とバッククォートだけが実行される"
    verdict: not-required
    ref: "本文: 設計SO（ゲート2・弱・Codex 1レーン・2026-10-15）"
  - subject: "外部レビューが『現行はこう動く』と断定した行は、採る前に変更前のスクリプトに当てる"
    verdict: not-required
    ref: "本文: 設計SO（ゲート2・弱・Codex 1レーン・2026-10-15）"
  - subject: "走査器だけの計測は完成版の所要を裏付けない"
    verdict: not-required
    ref: "本文: GATE I1: 所要時間（2026-10-15・5回の平均・ms）"
  - subject: "字面の検査に構文を足すときは、小さな解析器を横に置かず本体の走査器にモードを足す"
    verdict: required
    ref: "本文: I2-1: 実装SO（ゲート4・弱・Codex 1レーン・2026-10-15）"
  - subject: "作り直しは変更前の判定が偶然止めていた形を落とす。変更前で deny だった行は錨とは別に全部残す"
    verdict: not-required
    ref: "本文: I2-2: PR を ready にし、Copilot の1ラウンド（2026-10-15）"
  - subject: "segment の中で既知の名前に一致するすべての token を判定する（前置きの固定表ではなく）"
    verdict: not-required
    ref: "本文: 設計SO（ゲート2・弱・Codex 1レーン・2026-10-15）"
knowledge_observations:
  - "01M2DRCP3QSG4NQWHNY6DSD3NJ"
  - "01M00KCCHNMFPHP5HAGX2DZ1MK"
  - "01KZ3MHMEQN5XEJGV9809QPH2A"
  - "01KYMRE1NC7XX6N66RQ0MGGHF1"
---

# #429 破壊的コマンドのフックが、前に別のコマンドが付いた rm を止めない

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

`canonical/hooks/scripts/block-destructive.sh` は、すべての Bash の実行の前に走り、破壊的なコマンドを止めるフックである。ところが判定は「コマンド文字列の先頭が `rm` か」で始まるので、`cd /tmp && rm -rf /` のように前に別のコマンドを付けただけで素通りする。`canonical/rules/careful-operations-rule.md` はこの種類のコマンドをフックが機械的に止めると書いているので、ルールが前提にしている守りが実物に無い状態だった。2026-10 の棚卸しで見つかり、#24 の H-3 に当たる。

統括の brief（`.oe/brief-429-destructive-hook-compound.md`・plan-first・最初の終端は P3）。認識合わせは統括が通した確定版（related の2件目）を前提にする。確定版の要点は次のとおり。

- `&&`・`;`・`|` などでつないだコマンドの後ろの部分と、`bash -c` の中身も調べる。本文の3つの形を3つとも止める。
- フックの許可と拒否を確かめる専用のテストが無いので、直す前に今の判定を固定するテストを作る。
- 同じスクリプトを Claude Code・Codex・Cursor の3つが使う。直した結果は3つ全部に効く。
- 今許可している安全な形は許可のまま。引用符の中の `;` を区切りと誤らないようにするかは設計で決める。
- 直しきれない形が残るなら、careful-operations-rule の「フックが機械的に止める」という書き方を残る抜けに合わせて直す。

brief が加えた規律のうち、この作業で効いたものは次の3つである。テストで本物のフックを動かすときは発火の記録の置き場を一時ディレクトリに向ける。破壊的なコマンドそのものは決して実行せず、フックには判定だけをさせる。上流の断定は使う前に実在を確かめる。

## 作業の記録

### 確定版の照合と、報告の宛先の確認（2026-10-15）

- `issue-intake` の 1-2 の手順で、#429 の認識合わせのコメントを全件から探した。最後の1件は `confirmed`・見出し4つで、URL は brief の「認識合わせ」欄と文字列として一致した。自分では認識合わせを通し直さない。
- 報告の宛先は brief に書かれた統括のペインで、`oe-tree` に root `cockpit` として生きて出ていることを確かめた（自分は label `#429` でその子として出ている）。起動時に渡された親のペイン（`$PARENT_TMUX_PANE`）も同じだった。
- worktree は `wt switch --create 'fix/#429_destructive_hook_compound' --base master` で自分で作った。baseline は master `069b65b`（`origin/master` と一致）。

### 上流の断定の裏取り（フックに判定だけをさせて再現した・2026-10-15）

brief・#429 本文・確定版の断定を、master `069b65b` のスクリプトに当てた。方法は、`jq` で `{tool_input:{command:...}}` を組んで標準入力から渡し、`HOOK_FIRING_DIR` を一時ディレクトリに向け、`CLAUDE_PROJECT_DIR` を置いて `bash` と `/bin/bash`（3.2）で起動し、終了コード（0 = allow / 2 = deny）を読む。コマンドは1つも実行していない。表と結果は `tmp/429-destructive-hook/`（gitignored）の `table1.tsv`・`probe-bash5.tsv`・`probe-bash32.tsv` にあり、2つの bash で結果は完全に一致した。

| 断定 | 結果 | 一次情報 |
|---|---|---|
| 判定は先頭が `rm` のときだけ（`^rm[[:space:]]`）で、前に剥がすのは `sudo` だけ | 確認済み | `block-destructive.sh` の `parse_rm` と `main` の sudo 剥がし |
| `cd /tmp && rm -rf /`・`true; rm -rf ~`・`bash -c "rm -rf /"` の3つが allow になる | 確認済み（3件とも rc=0） | 上の probe |
| 同じスクリプトを3ツールが使う | 確認済み | `~/.claude/hooks/`・`~/.codex/hooks/`・`~/.cursor/hooks/` の `block-destructive.sh` が、いずれも master の作業ツリーの `canonical/hooks/scripts/block-destructive.sh` への symlink |
| 直した結果に sync は要らない | 確認済み（上と同じ理由。worktree での編集は実物に影響しない） | 同上 |
| 判定専用のテストが無く、発火の記録のテストに例が数件あるだけ | 確認済み | `projects/orchestration-engine/tests/test_hook_firing.sh` の [2] に block-destructive の例が3件（allow・safe rm・deny） |
| 同じ型（先頭だけを見る判定）が同じフックのほかの検査にもある | 確認済み。chmod・chown・mkfs・dd・git reset・git clean の6検査がすべて先頭固定で、`cd x && ...` を付けるとすべて allow になる。SQL の検査だけは全文の部分一致で、つないだ形も止める | probe の「other checks」群 |
| `block-force-push.sh` にも同じ型がある | 確認済み。`cd x && git push --force`・`true; git push -f`・`bash -c "git push --force"`・`sudo git push --force` が allow。`git commit -m x && git push --force` は正規表現の形のせいで偶然 deny になる | probe の「force-push」群 |

さらに、issue が名指ししていない同じ型の抜けを3つの族に分けて記録した（詳細は plan の「今の判定の読み解き」）。

- 区切りの族: `||`・`|`・改行・`( )`・`{ }`・`$( )`・バッククォート・`eval` のどれでも素通りする。
- 前置きの族: 先頭の空白・`\rm`・`/bin/rm`・`env`・`command`・`exec`・`nohup`・`time`・`FOO=1 rm`・`>/dev/null rm`・`! rm` のどれでも素通りする。
- 対象の書き方の族: `rm -rf "/"`・`rm -rf '/'`・`rm -rf "$HOME"`・`rm -rf ${HOME}`・`rm -rf ./` が素通りする。`rm -rf $HOME`（引用符なし）と `rm -rf ~/` は止まる。

昇格の印: 先頭だけを見る判定は、名指しされた rm だけでなく同じフックの6検査と force-push に同じ形で在り、区切り・前置き・対象の書き方の3つの族に分かれる

### 自分のコマンドが実物のフックに止められた（2026-10-15）

probe の表を heredoc でファイルに書く Bash を打ったら、実物の `block-destructive.sh` が止めた。表の中に SQL の `DROP TABLE` を含む行があり、SQL の検査は全文の部分一致なので、heredoc のデータも止まる。`canonical/hooks/README.md` の「対照コマンドを検査スクリプトの外側のコマンド行に置かないこと」をそのまま踏んだ形である。以後、フックに判定させる文字列は Write ツールでファイルに置き、Bash のコマンド行には載せていない。

ここから2つのことが分かる。第一に、実物のフックは `$HOME/.claude/state/hook-firing/deny.jsonl` にこの deny を1件記録した（これは判定の実物なので汚染ではない）。第二に、この単位で区切り器を入れると、`cd x && rm -rf /` のような文字列を含む文書やテストを heredoc で書く操作が、設計しだいで同じように止まる。plan の DJ-2 で heredoc の本文をデータとして扱う理由はこれである。

### 区切り器の実装方式の計測（2026-10-15）

純 bash の文字走査がどれだけ遅いかを、7KB（`echo "line N" && true` を300行）と、二重引用符の中に 7000 文字を入れた1行で測った（`tmp/429-destructive-hook/bench_*.sh`）。

| 方式 | bash 3.2・7KB | bash 5・7KB | 短い1行（10回平均） |
|---|---|---|---|
| 純 bash・1文字ずつ・既定ロケール | 779 ms | 214 ms | 5〜7 ms |
| 純 bash・1文字ずつ・`LC_ALL=C` | 190 ms | 188 ms | 同上 |
| 純 bash・`=~` で区切り文字まで飛ばす・`LC_ALL=C` | 368 ms | 369 ms | 同上 |
| awk（macOS の BSD awk / gawk） | 32 ms / 82 ms | 同左 | 未計測 |

既定ロケールで bash 3.2 が遅いのは、`${s:i:1}` が UTF-8 の文字数を先頭から数え直すためで、`LC_ALL=C` にするとバイト単位になり4倍速くなる。「飛ばす」方式は残りの文字列を毎回コピーするので逆に遅い。現行フックの1回の所要は約 17 ms（jq と bash の起動が主）。plan の DJ-8 はこの数字で決めた。設計SO はこの計測が走査器だけのものだと指摘したので（下の節）、DJ-8 は完成版の計測を条件にする形に変えた。

### plan の執筆（2026-10-15）

plan を `docs/harness/plans/2026-10-15-plan-429-destructive-hook-compound.md` に書いた。設計判断は DJ-1〜DJ-11、owner に預ける判断は5つである（設計SO の後で6つになった）。

### 設計SO（ゲート2・弱・Codex 1レーン・2026-10-15）

- プロンプトは `tmp/429-destructive-hook/so-design-prompt.md`。問うたのは DJ-2 の文法の取りこぼし、DJ-3 の誤検知の境界、DJ-8 の方式、DJ-9 の列挙の抜け、退行と fail-open、DJ-10 のテストの構成の6点。`so-compare -f ... -w <worktree> --codex-only`・`SO_TIMEOUT=900`。
- 返答: `gpt-6.1-sol`・`codex-cli 0.162.1`・初回で返答・261秒・15件（高10・中5）・判定「直してから通す」。本文は `tmp/429-destructive-hook/so-design/codex-stdout.txt`。
- **採る前に SO の断定を確かめた。** SO が「現行は allow / deny」と言った13行（転送先を含む rm・`git clean --force -n`・`git clean -f -d -x`・`git clean -fdxn`・注釈を含む rm と force-push・`command -v mkfs.ext4`・`ls -l /sbin/mkfs.ext4`・`bash -c -- '...'`・`env -u git rm`・brace expansion・`+refspec`）を変更前のスクリプトに当て、13行すべて SO の言うとおりだった（`probe2-so-bash5.tsv`）。bash の事実3つ（`bash -c -- '...'` が動く・`local LC_ALL=C` が bash 3.2 で効く・二重引用符の中の `\` + 改行が消える・`$'can\'t'` が1語）も `/bin/bash` で確かめた。
- 採否の一覧は plan の「設計SO（ゲート2）」節。15件のうち13件を採り、2件を一部採った。plan で変わった主なものは次のとおり。
  - DJ-3: 「最初に現れる既知の名前」から「既知の名前に一致する**すべて**の token」へ。`env -u git rm -rf /` で `git` が本体の `rm` を隠す指摘（1）を閉じるため。SO は代替の DJ-3'（前置きの固定表）を勧めたが、族を閉じる側を推奨のまま残し、owner の判断1 に SO の勧めを併記した。
  - mkfs は引数があるときだけ deny（2）。`command -v mkfs.ext4` を allow に保つ。
  - DJ-2: `\` + 改行は消して連結（3）。引用なしの heredoc の本文は `$( )` だけ見る（4）。複数 heredoc と区切り語の引用の契約（5）。ANSI-C 引用と二重引用符の `\` の規則（6）。走査を1回の文脈の積み重ねにし `$((` を読み飛ばす（7・13）。token 化で転送を除く（8）。
  - DJ-4: shell のオプションを歩き `--` を扱う（9）。queue の件数の上限をやめ、深さだけ残す（13）。
  - DJ-6: git clean は option の文字を集め、dry-run は allow（10）。
  - DJ-8: 条件付きの採用。完成版を GATE I1 で 3つの大きさ × 3つの形 × 両 bash × 2本で測る。`LC_ALL=C` は走査器の `local` に限る（12）。
  - DJ-9: 「実行環境の情報が要る」「静的解析を未実装」「別の操作族」の3つに分けた。`case` の `)` が二重引用符の中の `$( )` に在る形は実装せず (b) に置いた（7）。`+refspec` は判断6（11）。
  - DJ-10: 群D を4件に広げ、群E（終わること）を足し、錨から外した行も残す（14）。`test_hook_firing.sh` のフック起動の実行系を揃える（15）。
- 採らなかった部分: 指摘1 の「DJ-3' を採れ」（上のとおり owner に預ける）。指摘7 の `case` の完全な解析（実装の量に見合わず、形が狭い）。

昇格の印: 引用符なしの heredoc の本文はデータではなく、`$( )` とバッククォートだけが実行される。本文を一律にデータと扱うと見逃す

昇格の印: 外部レビューが「現行はこう動く」と断定した行は、採る前に変更前のスクリプトに当てる。13行で1件も食い違わなかったが、確かめずに写せば検証の空回りになる

### P3 の報告と、ゲート3 の承認（2026-10-15）

- plan と episode を枝にコミットして push し、draft PR #434 を作った。`.oe/report-429-plan.md` を書いて `oe-send` で統括のペイン（報告の宛先）へ送った（exit 0）。統括から受領の返事が届き、待機した。
- ゲート3: owner が plan を承認し、6つの判断はすべて推奨どおりだった（統括の記録 `.oe/decision-429-gate3.md`・作業層。承認した plan の digest は `8b22b61` の全文で `39a542f0…`）。判断6 の follow-up は統括が #435 に起こした。
- plan の本文で変えたのは、status を `in-development` に、DJ-9 (c) の `+refspec` の行き先を #435 に、「owner に預ける判断」節の冒頭に答えの1行を足し、P3 と GATE 3 の項目を済みにしたことだけである。DJ の中身は変えていない。

### I1: テストを先に作り、フック2本を直した（2026-10-15）

- I1-0: `origin/master` は `069b65b` のままで、枝はそれを含む。rebase は不要だった。
- I1-1（群A・C・E・commit `ad8e122`）: 表を変更前のフックに当てたら、群C の2行（`rm -rf node_modules >> /tmp/log 2>&1`・`rm -rf node_modules &> /tmp/log`）が今 deny だった。空白を挟んだ転送の相手（絶対パス）を rm の対象に数える過検知で、設計SO の指摘8 の形そのものである。plan の「今 allow」の見立てが外れていたので群D に移した。同じく `git clean -fdx --dry-run` と引数なしの `mkfs.ext4` も群D に置いた（判断4 と同じ種類。plan に追記）。`test_hook_firing.sh` はフックの起動を `"${HOOK_BASH:-$BASH}"` に揃え、[3] は `inherit_errexit` の無い bash で skip するようにした。
- I1-2（群B・D・commit `ad5ab70`）: 変更前のフックに当てて、群B 69行のうち 68行、群D 8行すべてが落ちることを両方の bash で確かめた。落ちない1行は `rm -rf node_modules && rm -rf /` で、先頭が rm で `/` が対象に混ざるため今も deny になる。錨に数えない注記を付けて行は残した（設計SO の指摘14）。
- I1-3・I1-4（commit `5b44f10`・`faf6001`）: 走査器と token 化と既知の名前の検出を `shared-cmd` 区間に書き、2本に byte 一致で置いた。組み立ては、変更前のファイルの共通区間（`# --- shared end ---`）までをそのまま取り、`tmp/429-destructive-hook/shared-cmd.sh` と各フックの判定部を結合する形にして、手で写す誤りを避けた。`test_hook_firing.sh` の [1] に `shared-cmd` 区間の一致の検査を足した。
  - 最初の版で落ちたのは `rm -rf ${HOME}` の1行だけだった。`${ … }` を写す関数が、先頭の `$` を足した直後に「深さ 0 なら終わり」で抜けていた。`$` を足してから `{` に入る形に直した。
  - shellcheck は、判定の関数が名前で間接に呼ばれるため SC2317（到達不能）を出す。関数ごとに `disable` を付けた（既存の trap の関数と同じ扱い）。`'\'` は SC1003 を出すので `"\\"` に書き換えた。
- 範囲外の形も当てた（`tmp/429-destructive-hook/table3-extra.tsv`・52行）。plan の DJ-9 どおりに、`"$(case x in x) rm -rf /;; esac)"`・`sh -c "$(printf 'rm -rf /')"`・`cat <<EOF | bash`・`bash script.sh`・変数の対象は allow のまま、`$( (rm -rf /) )`・`echo $((1<<2)); cat <<EOF … rm -rf /`・`printf '%s\n' $'can\'t'; rm -rf / # '`・`chmod 777 -R /`・`git --git-dir=.git reset --hard` は deny になった。`git commit -m "$(echo rm -rf /)"` は deny になる（DJ-3 の「引用符なしのデータ」が置換の中に在る形。許容）。

#### GATE I1: 所要時間（2026-10-15・5回の平均・ms）

`tmp/429-destructive-hook/timing.sh`。フックには判定だけをさせる。「既知あり」は `git commit -m "<長い本文>"`、「既知なし」は `echo "<長い本文>"`、heredoc は `cat > f <<'EOF'` で既知の名前を含む文書を書く行。

| 入力 | 変更前 3.2 / 5 | 最初の版 3.2 / 5 | 窓ごとに進む版 3.2 / 5 |
|---|---|---|---|
| 短い1行（`cd x && git status`） | 15 / 18 | 16 / 20 | 16 / 20 |
| 既知あり 1 KB | 15 / 17 | 27 / 30 | 17 / 19 |
| 既知あり 4 KB | 16 / 17 | 93 / 92 | 24 / 20 |
| 既知あり 16 KB | 23 / 20 | 837 / 1038 | 82 / 28 |
| 既知なし 16 KB | 22 / 19 | 67 / 21 | 67 / 23 |
| heredoc 4 KB | 17 / 18 | 27 / 23 | 27 / 22 |
| heredoc 16 KB | 24 / 20 | 139 / 54 | 139 / 51 |

最初の版は1文字ずつ token に足していて、長い token で2乗の時間がかかった（設計SO の指摘12 が「完成版で測れ」と言ったとおり、走査器だけの計測では見えなかった）。解釈の要らない文字の並びを 256 バイトの窓でまとめて進む形に直し（commit は `fix(hooks): #429 走査器が長い token を窓ごとに進むようにする`）、上限（8 KB 相当で 250 ms・短い1行で 30 ms）に収まった。awk には切り替えない（判断3 の条件を満たす）。

#### 最終の計測（実装SO と Copilot の後の版・2026-10-15・5回の平均・ms）

`tmp/429-destructive-hook/timing-new3.txt` の全セル（`tmp/` は gitignored で消えるのでここに写す）。列は フック × bash の版。「既知あり」は `git commit -m "<長い本文>"`、「既知なし」は `echo "<長い本文>"`、「heredoc」は `cat > f <<'EOF'` で既知の名前を含む文書（1行 72 文字）を書く行。下の3つは実装SO が足した形。

| 入力 | 長さ (bytes) | block-destructive 3.2 | block-destructive 5 | block-force-push 3.2 | block-force-push 5 |
|---|---:|---:|---:|---:|---:|
| 短い1行 `echo hello` | 10 | 17.0 | 17.8 | 15.2 | 17.4 |
| 短い1行 `cd x && git status` | 18 | 18.0 | 18.5 | 15.7 | 17.9 |
| 短い1行 `rm -rf node_modules && npm ci` | 29 | 18.1 | 18.7 | 18.3 | 18.6 |
| heredoc 1 KB | 1014 | 18.7 | 19.0 | 17.4 | 18.6 |
| 既知あり 1 KB | 1040 | 17.6 | 18.4 | 16.3 | 19.2 |
| 既知なし 1 KB | 1031 | 16.9 | 17.7 | 15.9 | 18.1 |
| heredoc 4 KB | 3996 | 20.0 | 21.0 | 19.0 | 20.5 |
| 既知あり 4 KB | 4112 | 20.0 | 19.8 | 18.6 | 20.6 |
| 既知なし 4 KB | 4103 | 16.9 | 18.5 | 17.5 | 18.2 |
| heredoc 16 KB | 16265 | 37.7 | 35.9 | 36.4 | 34.7 |
| 既知あり 16 KB | 16400 | 31.7 | 26.4 | 30.0 | 26.4 |
| 既知なし 16 KB | 16391 | 24.9 | 20.9 | 19.3 | 20.1 |
| `rm` を 1360 個並べた 4 KB の1行 | 4093 | 165.9 | 148.3 | 149.1 | 138.8 |
| `''` を 2048 個並べた 4 KB の1行 | 6148 | 18.5 | 20.6 | 16.9 | 18.2 |
| 短い行が 4090 行の 16 KB の heredoc | 16375 | 267.7 | 267.3 | 265.9 | 262.6 |

変更前（master `069b65b`）のフックは、どの入力でも 14〜24 ms だった（`timing-prechange.txt`。2本とも、既知の名前の有無や長さで変わらない）。

昇格の印: 走査器だけの計測は完成版の所要を裏付けない。token に1文字ずつ足す形は長い token で2乗になり、16 KB で約1秒かかった

### I2-1: 実装SO（ゲート4・弱・Codex 1レーン・2026-10-15）

- プロンプトは `tmp/429-destructive-hook/so-impl-prompt.md`。問うたのは走査器の取りこぼし・誤検知・bash 3.2 と fail-open・性能・テストと文書の5点。`so-compare -f … -w <worktree> --codex-only`・`SO_TIMEOUT=900`。
- 返答: `gpt-6.1-sol`・`codex-cli 0.162.1`・初回で返答・285秒・9件（高6・中3）・判定「直してから通す」。本文は `tmp/429-destructive-hook/so-impl/codex-stdout.txt`。SO は判定を JSON の入力だけで確かめ、コマンドは実行していないと明記した。
- **採る前に SO の断定を確かめた。** SO が「いまの挙動」と断定した11行（`r$'m'`・`env -u bash sh -c`×2・heredoc の本文の置換×2・区切り語の引用×2・算術式の中の置換・`\$(…)`・`a\`+改行+`EOF`・`git grep mkfs.ext4`）を直す前の実装に当て、11行すべて SO の言うとおりだった（`probe4-so-impl-new.tsv`）。64個の `bash -c` の行が `nesting-limit` になることも確かめた。
- 9件とも採った（採否の表は plan の「実装SO（ゲート4）」節）。直した中身は commit `b42527c` の本文のとおりで、要点は次の4つである。
  - 早い経路の文字列置換（`${var//…}`）をやめて正規表現1回にした。SO は `r$'m'` の取りこぼし（1）と、bash 3.2 で `''` を2048個並べた行が3秒で打ち切られること（9）を別々に挙げたが、原因は同じ置換だった。
  - 引用なしの heredoc の本文を、独自の簡易パーサーで切り出すのをやめ、本文全体を「h モード」（二重引用符と同じ `\` の規則で `"` だけは文字。外側はデータで `$( )` と `` ` `` の中だけコマンド）として共通の走査器に通す形にした。設計SO の指摘4 で足した簡易パーサーが、実装SO の指摘3・6 で4つの形（複数行の置換・引用の中の `)`・`\$(`・`\`+改行の連結）を落としていた。**部分的な解析器を足すより、同じ走査器にモードを足すほうが穴が少ない。**
  - `$(( ))` を「読み飛ばす」から「算術式の文脈」に変え、中の `$( )` と `` ` `` だけ拾う（5）。設計SO の指摘7 で `<<` の混同を避けるために読み飛ばす形にしたが、それが新しい穴を作っていた。
  - 同じ名前の判定を segment の中で1回に抑えた（9）。後ろの同じ名前の引数は先の引数の部分集合なので、先の判定で足りる。git だけは subcommand が位置で決まるので毎回見て、reset・clean・push の判定を1回にする。
- 直した後、11行は狙った判定になり、既存の表 179行と範囲外の形 52行の判定は変わらなかった。表には群B +9・群C +5・群E +5 を足し、変更前の master で群B 77/78・群D 8/8 が落ちることを両方の bash で確かめ直した。

昇格の印: 設計SO の指摘で足した簡易パーサー（heredoc の本文の置換の切り出し）と読み飛ばし（算術式）が、実装SO で新しい穴になった。部分的な解析器を足すより、同じ走査器にモードを足すほうが穴が少ない

#### 実装SO の後の所要時間（2026-10-15・5回の平均・ms・3.2 / 5）

| 入力 | 実装SO の前 | 実装SO の後 |
|---|---|---|
| 短い1行（`cd x && git status`） | 16 / 20 | 18 / 18 |
| 既知あり 4 KB | 24 / 20 | 20 / 20 |
| 既知あり 16 KB | 82 / 28 | 32 / 26 |
| heredoc 16 KB（72 文字の行） | 139 / 51 | 38 / 36 |
| `''` を 2048 個並べた 4 KB（SO の形） | 3秒で打ち切り / 23 | 19 / 21 |
| `rm` を 1360 個並べた 4 KB（SO の形） | 3秒で打ち切り / 3秒で打ち切り | 166 / 148 |
| 短い行が 4090 行の 16 KB の heredoc（SO の形） | 588 / 495 | 268 / 267 |

### I2-2: PR を ready にし、Copilot の1ラウンド（2026-10-15）

- draft PR #434 を ready にし、`gh pr edit --add-reviewer @copilot` で依頼した。`requested_reviewers` には bot が出ないが、timeline に `review_requested`（Copilot）が記録され、約3分でレビューが付いた（先例 PR #425 と同じ形）。
- Copilot は8件（高6・中2）。すべて具体的な入力つきで、採る前に直す前の実装に当て、8件とも指摘どおりだった（`tmp/429-destructive-hook/probe5-copilot-before.tsv`）。bash の実際の挙動が要る2件（区切り語の `\`+改行・本文の `\\`）は `/bin/bash` に無害な heredoc を流して確かめた。
- 8件とも採って commit `1a05342` で直した（採否と直し方は plan の「Copilot のレビュー」節）。実装SO の指摘9件と合わせて、走査器の穴は「置換の中の括弧」「転送の相手が `(`」「区切り語の連結」「行末の `\` の数」のように、**本体の走査器が持つ規則の組み合わせ**で見つかっている。
- 直した後、判定のテストは 214 件（群B 91・群C 45・群D 9）で両方の bash で緑、範囲外の形 52 行と実装SO の 11 行の判定も変わらなかった。変更前の master では群B 86行・群D 9行が落ちる。Copilot の指摘のうち `<( )` の2行と `git clean -e` の2行は変更前の master では deny だった形で、新しい走査器が一度落としていた（非回帰の守りとして残し、錨に数えない）。
- 8スレッドに対応内容とコミットを返した（未返信 0 件）。再依頼はしない（1ラウンドで止める）。

昇格の印: 新しい走査器は、変更前の単純な判定が偶然止めていた形（`rm -rf <(true) /`・`git clean -fdx -e'*.json'`）を一度落とした。作り直しの非回帰は「変更前で deny だった行」を錨とは別に全部残すことで守る

plan の行列（3つの形 × 3つの大きさ）はすべて上限（8 KB 相当で 250 ms・短い1行で 30 ms）に収まる。SO の3つの形のうち、`rm` を並べた行だけは token の数に比例して増え（約 0.12 ms / token。走査器の token の終わり・token 化の後の名前の照合・rm の判定の3つの loop がそれぞれ token 数に比例する）、8 KB 相当では上限を超える見込みである。実用のコマンドにこの形は無く hang でもないので、この単位では awk に切り替えず、既知の限界として README と報告に書く。

## フィードバック

closure（2026-10-15・PR #434 の Copilot のラウンドの後・マージ前）。tier は heavy（設計SO と実装SO を意図して起動し、撤回が2回あり、設計判断を比較して棄却している）。本文にある内容は pointer で指し、再掲しない。

- 事実・失敗:
  - 自分の probe が実物のフックに止められた（`本文: 自分のコマンドが実物のフックに止められた（2026-10-15）`）。
  - plan の「今 allow」の見立てが2行外れていた（空白を挟んだ転送）。テストで露呈した（`本文: I1: テストを先に作り、フック2本を直した（2026-10-15）`）。
  - 最初の実装で `${HOME}` を写す関数が先頭の `$` で抜けていた。テストの1行で見つけた（同上）。
  - 1文字ずつ token に足す走査が 16 KB で約1秒かかり、窓ごとに進む形に直した（`本文: GATE I1: 所要時間（2026-10-15・5回の平均・ms）`）。
  - 設計SO で足した簡易パーサーと読み飛ばしが、実装SO で4つの穴になった（`本文: I2-1: 実装SO（ゲート4・弱・Codex 1レーン・2026-10-15）`）。
  - 新しい走査器が変更前の判定が偶然止めていた4つの形を一度落とし、Copilot が見つけた（`本文: I2-2: PR を ready にし、Copilot の1ラウンド（2026-10-15）`）。
  - 列の長さの上限を plan に無い安全装置として足し、README にだけ書いていた。実装SO が plan との食い違いとして指摘し、外した（`本文: I2-1: 実装SO（ゲート4・弱・Codex 1レーン・2026-10-15）`）。
  - 設計SO の指摘15件（高10・中5・「直してから通す」）。13件を採り2件を一部採って plan を直した。DJ-3 を「最初の1つ」から「すべて」へ変え、SO が勧めた固定表は owner に預けた（`本文: 設計SO（ゲート2・弱・Codex 1レーン・2026-10-15）`。採否の表は plan の「設計SO（ゲート2）」）。
  - 実装SO の指摘9件（高6・中3・「直してから通す」）。取りこぼし5件（早い経路の `r$'m'`・前置きの shell 名による隠蔽・heredoc の本文の置換・区切り語の引用・算術式の中の置換）、誤検知2件（`\$(…)` と `a\`+改行+`EOF`・`git grep mkfs.ext4`）、plan との食い違い1件、性能1件（多数の token・引用符の密な行・短い行の多い heredoc で3秒超）。9件とも採った（`本文: I2-1: 実装SO（ゲート4・弱・Codex 1レーン・2026-10-15）`。採否の表は plan の「実装SO（ゲート4）」）。
  - Copilot の指摘8件（高6・中2）。process substitution・区切り語の `\`+改行・本文の `\\`・置換の中のサブシェルの `)`・`-O`・`git clean -e`・`--` の後ろの rm・`.//`。8件とも採った（`本文: I2-2: PR を ready にし、Copilot の1ラウンド（2026-10-15）`。表は plan の「Copilot のレビュー」）。
- 決定と根拠:
  - 判定の単位を行の先頭から各単純コマンドへ、先頭の決め方を既知の名前に一致するすべての token へ（棄却: 前置きの固定表。設計SO はこちらを勧めたが owner は推奨を採った）。`本文: 設計SO（ゲート2・弱・Codex 1レーン・2026-10-15）` と plan の DJ-3。
  - 純 bash の条件付き採用（棄却: awk の埋め込み。計測で条件を満たした。多数の token の形だけは上限を超える見込みで owner に見せる）。`本文: GATE I1: 所要時間（2026-10-15・5回の平均・ms）`。
  - SQL の検査は全文の部分一致のまま（棄却: segment 単位。README の陽性対照と heredoc 経由の psql の扱いを変えないため）。plan の DJ-6。
  - heredoc の本文は本体の走査器のモードで扱う（棄却: 行単位の簡易パーサー。実装SO で穴が出た）。`本文: I2-1: 実装SO（ゲート4・弱・Codex 1レーン・2026-10-15）`。
- わかったこと:
  - 先頭だけを見る判定の抜けは、名指しされた rm だけでなく6検査と force-push にあり、3つの族に分かれる（`本文: 上流の断定の裏取り（フックに判定だけをさせて再現した・2026-10-15）`）。
  - 引用なしの heredoc の本文では `$( )` が実行され、`\`+改行の連結は行末の `\` が奇数個のときだけ起きる（`本文: 設計SO（ゲート2・弱・Codex 1レーン・2026-10-15）`・`本文: I2-2: PR を ready にし、Copilot の1ラウンド（2026-10-15）`）。
  - bash 3.2 の `${var//…}` は一致の多い行で極端に遅く、`local LC_ALL=C` は 3.2 でも効く（`本文: 区切り器の実装方式の計測（2026-10-15）`・`本文: I2-1: 実装SO（ゲート4・弱・Codex 1レーン・2026-10-15）`）。
- 原則:
  - 字面の検査に構文を足すときは本体の走査器にモードを足す。小さな解析器を横に置くと次の穴になる（収穫: `docs/harness/knowledge/items/01M4YV4JC48G5HHCK08QBRB99J.md`）。
  - 変更前で deny だった行は、錨に数えなくても全部残す（作り直しの非回帰）。`本文: I2-2: PR を ready にし、Copilot の1ラウンド（2026-10-15）`。
- 行動変更: なし（手順の変更は上の原則と knowledge item に着地。hook や skill の変更は無い）。
- 蒸留シグナル:
  - knowledge store: 1件収穫済み（上の原則の1つ目）。
  - decision: なし。設計判断は plan（committed・ゲート3 の承認の記録つき）が持ち、覆すには実物（テストの表）を見れば決まる確認の側なので decision には上げない。
  - skill / rule: careful-operations-rule はこの PR で直した（DJ-9）。ほかは無し。
- 残課題（行き先つき）:
  - `+` 付き refspec の force push → #435（統括が起票済み）。
  - SQL の検査が heredoc のデータを止める既知の過検知 → 追わない（README に既知として記載。陽性対照の形を変える動機が出たら issue にする）。
  - 1行に数千の token を並べた形の所要時間が token 数に比例する → README に既知の限界として記載。awk に切り替えるかは I3 の報告で owner に見せる（判断3 の条件）。
  - `sudo mkfs.ext4 disk.img`（前置きの後ろのイメージファイル）が allow に変わる → 追わない（plan の DJ-3 に明記。dd の基準に揃えた）。
  - DJ-9 (a) の実行環境の情報が要る形（変数・glob で決まる対象、`xargs` で標準入力から受ける対象、標準入力・heredoc・ファイルから command を受ける shell、alias・関数） → 追わない（字面の検査では閉じられない。README「対象外」とルール §1 の段落・§2 の表に列挙し、エージェントが自分で守る側に置いた）。
  - DJ-9 (b) の静的解析を実装しない形（二重引用符の中の `$( )` の `case`・`${ }` の内部・brace expansion・計算される名前） → 追わない（README「対象外」とルール §1 に列挙。扱う動機が出たら issue にする）。
  - `test_hook_firing.sh` の `oe-hookfire` の起動は裸の `bash` のまま → 追わない（フックではなく engine の検査で、この単位の範囲外）。
- 次の消費者: これらのフックを次に直す担当（README が plan の DJ-2〜DJ-9 を指す）、#435 の担当（force-push の走査器の構造）、マージ時の owner（判断3 の条件の再判定）。
- 認識合わせの抜け: なし（群D の追加は実装で見つけた今の過検知で、確定版に無かった要件ではない）。
- evidence anchor: `tmp/429-destructive-hook/` は gitignored で消える。判定の表の結果・所要時間・SO の採否・Copilot の指摘は本文と plan に数値と形で転記した。SO の返答の本文は `tmp/` にしか無く、採否の表（plan）と要点（本文）を残した。
- 観測の書き戻し: brief の slot の4件（`01M2DRCP3QSG4NQWHNY6DSD3NJ`・`01M00KCCHNMFPHP5HAGX2DZ1MK`・`01KZ3MHMEQN5XEJGV9809QPH2A`・`01KYMRE1NC7XX6N66RQ0MGGHF1`）に1レコードずつ書き戻した（commit `4acf081`・4件とも followed・`validate-knowledge` OK）。
- SO 証跡（Step 4・heavy tier の外部チェック）: `so-compare --codex-only`（`gpt-6.1-sol`・37秒）で closure の4観点を focused に検証した。出力は `tmp/429-destructive-hook/so-closure/codex-stdout.txt`（揮発）。結果は「失敗の選択的省略あり（外部レビュー3本の指摘の全体が事実・失敗の項目に無い）」「routing に DJ-9 (a) の限界が無い」「evidence anchor と back-propagation は問題なし」で、前の2つを上に足した（事実・失敗に3項目、残課題に1項目）。
- 形式メモ: チャネル骨格で拾えたのは「事実・失敗」の10件と「原則」の2件。外部チェックが拾ったのは、外部レビューの指摘を家族ごとにまとめて書いたせいで個々の指摘が項目に見えなかったこと。皮（KPT/YWT）は使っていない。摩擦は、pointer の見出しが長いこと。
