---
id: "01M4XY7FXPK6BQPQEBR7WP1GYY"
title: "#429 破壊的コマンドのフックが、前に別のコマンドが付いた rm を止めない"
date: 2026-10-15
type: episode
status: draft
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
- 報告の宛先は brief の `%207` で、`oe-tree` に root `cockpit` として生きて出ていることを確かめた（自分は `%244`・label `#429`・その子として出ている）。`$PARENT_TMUX_PANE` も `%207` で一致する。
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

- plan と episode を枝にコミットして push し、draft PR #434 を作った。`.oe/report-429-plan.md` を書いて `oe-send '%207'` で送った（exit 0）。統括から受領の返事が届き、待機した。
- ゲート3: owner が plan を承認し、6つの判断はすべて推奨どおりだった（統括の記録 `.oe/decision-429-gate3.md`・作業層。承認した plan の digest は `8b22b61` の全文で `39a542f0…`）。判断6 の follow-up は統括が #435 に起こした。
- plan の本文で変えたのは、status を `in-development` に、DJ-9 (c) の `+refspec` の行き先を #435 に、「owner に預ける判断」節の冒頭に答えの1行を足し、P3 と GATE 3 の項目を済みにしたことだけである。DJ の中身は変えていない。
