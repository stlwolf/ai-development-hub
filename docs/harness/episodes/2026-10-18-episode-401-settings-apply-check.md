---
id: "01M575BADF09N8GPWRP195C2PD"
title: "#401 宣言駆動 settings の検査を、撤去した等価性 fixture の代わりに立て直す"
date: 2026-10-18
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/401"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/401#issuecomment-6248150781"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）。この単位はこれを前提にする"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-18-plan-401-settings-apply-check.md"
    reason: "この episode が記録する作業の計画"
  - type: design_context
    ref: "docs/harness/plans/2026-09-06-plan-359-settings-harness-layer.md"
    reason: "宣言駆動の apply と check を作った計画。撤去した [22] の受入（PR-3 の等価性）の出所"
  - type: design_context
    ref: "docs/harness/episodes/2026-09-06-episode-359-settings-harness-layer.md"
    reason: "8つの fixture を作った経緯と、テストが shebang 経由で別の bash を走らせて版差の主張が空になった失敗の記録"
tags: [test, settings, sync, harness]
promotion:
  - subject: "宣言を読む側のテストのうち、項目を名指しで並べる箇所は、項目を足すたびに書き換えが要る"
    verdict: not-required
    ref: "本文: P1: 上流の前提とのずれ（2026-10-18）"
  - subject: "陽性対照で性質 P を守ると言うときは、P を壊す変化を書き出し、対照がそれぞれを見つけるかを確かめる"
    verdict: required
    ref: "本文: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）"
  - subject: "判定の基準を旧実装から check に移し、宣言の外は前後の不変で見る（成立条件を M6 と構造の確かめで守る）"
    verdict: not-required
    ref: "本文: P2: plan の草稿を書いた（2026-10-18）"
  - subject: "bash で変数の直後に ASCII 以外の文字が来る位置は ${var} で囲む"
    verdict: required
    ref: "本文: I1-1: [22] と [4]・[17] を書いた（2026-10-18）"
  - subject: "issue の反証3の「4項目目」を「5項目目」に読み替えた"
    verdict: not-required
    ref: "本文: P1: 上流の前提とのずれ（2026-10-18）"
  - subject: "sandbox-exec は受入で1回だけ使い、テストの中には置かない"
    verdict: not-required
    ref: "本文: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）"
---

# #401 宣言駆動 settings の検査を、撤去した等価性 fixture の代わりに立て直す

## なぜこの作業が始まったか

2026-09-16 の #338 で `disableAgentView` を宣言（`canonical/claude/settings.harness.json`）に足したとき、`test_apply_claude_settings.sh` の [22]（git の履歴から取り出した旧実装と新実装の結果を8つの fixture で比べる検査）が原理的に通らなくなり、owner の裁定で撤去した。旧実装は hooks と statusLine の2つしか知らないからである。撤去で6つの検出能力を失い、#338 の作業では `test_sync_output_styles.sh` が落ちる欠陥を、apply と check のテストでは見つけられなかった。この単位は、[22] の代わりの検査を立て、失った6つの能力の扱いを決める。

## この単位の入力

- brief: `.oe/brief-401-settings-apply-check.md`（cockpit 統括19代目・baseline master `ed45de5`）。plan-first で、最初の終端は P3、委譲全体の終端は I3。
- 認識合わせ: 確定版コメント（上の related）。`issue-intake` の 1-2 の手順で、最後の認識合わせのコメントが `confirmed`・見出し4つで、URL が brief の欄と文字列として一致することを確かめた。
- 注入された negative knowledge は4件である（brief の「negative knowledge」節）。陽性対照は理由まで見る（01M00KCC…）、bash 3.2 の合否は集計の行で見る（01M54X75…）、完全性の述語は母集団の側から書く（01KYJ76D…）、足した運用を打ち消す側を同じ変更で探す（01M486Z2…）。

## 作業の記録

### P1: worktree・認識合わせの照合・参照の読み（2026-10-18）

- worktree は `test/#401_settings_apply_check` で、`origin/master` の `ed45de5` から切った（`wt switch --create`）。local の master と `origin/master` は同じ `ed45de5` だった。
- 読んだもの: `apply-claude-settings.sh`・`check-claude-settings.sh`・`sync-claude.sh`・`settings.harness.json`・`test_apply_claude_settings.sh` の全体と [22] の跡の注記、撤去前の [22] の本体（`git show 99d0ecd^:…`）、`test_check_claude_settings.sh`・`test_sync_output_styles.sh`・`test_sync_claude_statusline.sh`、#359 の plan の PR-3 節と episode の shebang の節、#338 の着地と閉じたときのコメント。

### P1: 上流の前提とのずれ（2026-10-18）

**宣言はすでに4項目ある。** issue の反証の3つ目は「宣言に4項目目を足してもテストを変えずに緑のまま」だが、issue を書いたあとの #415（2026-10-08）で `idleCompaction` が入り、いまの宣言は hooks・statusLine・disableAgentView・idleCompaction の4項目である。数字のとおりに読むと、すでに満たされた状態を指してしまう。issue の意図は「宣言に項目を1つ足しても」なので、plan では「いまの宣言に5項目目を足しても」と読み替える。

**同じファイルの中に、宣言の項目を名指しで並べる主張が2つある。** [4] と [17] は、apply の結果のキーが `disableAgentView hooks idleCompaction statusLine` であることを文字列で比べている。宣言に項目を足すと、この2つは書き換えが要る（#415 で `idleCompaction` を足したときもここを直したはずである）。確定版の「望む結果」の「宣言に項目を足してもテストを書き換えずに済み」は、この2つが残ると成り立たない。

**隣のテストにも同じ形がある。** `test_check_claude_settings.sh` の `build_green` は、宣言どおりの settings.json を4項目の名指しで組み立てる。項目を足すと、check のテストの [1] が「未適用」で落ちる。これは #401 の対象（[22] の代わり）の外なので、plan では問いとして上げる。

昇格の印: 宣言を読む側のテストのうち、項目を名指しで並べる箇所（test_apply の [4]・[17]、test_check の build_green）は、項目を足すたびに書き換えが要る。「宣言に足してもテストを直さずに済む」を保証したいなら、宣言を読む側をまとめて母集団の側から書き直す必要がある

### P1: いまのコードで確かめたこと（2026-10-18）

使い捨ての HOME（scratchpad の下）で、撤去前の8つの fixture のそれぞれに `sync-claude.sh` を shebang 経由で走らせ、結果に check を当てた。本物の `~/.claude/settings.json` の shasum は前後で変わらず、worktree の `git status` も空のままだった。

| fixture | sync の終了コード | check の終了コード | sync の時間 |
|---|---|---|---|
| missing | 0 | 0 | 6.08 秒（1回目・キャッシュが冷えている） |
| hooks_only | 0 | 0 | 0.54 秒 |
| own_statusline | 0 | 0 | 0.51 秒 |
| wrapped | 0 | 0 | 0.55 秒 |
| broken_json | 0 | 1（JSON として読めません） | 0.55 秒 |
| symlink | 0 | 1（symlink なので適用できません） | 0.47 秒 |
| personal_keys | 0 | 0 | 0.52 秒 |
| dir | 0 | 1（通常ファイルではないので適用できません） | 0.47 秒 |

- 書ける相手の5件は check が 0 を返し、書けない相手の3件は check が理由つきで 1 を返す。案X の「check に exit 0 を求める」は、書けない相手の3件には当てはまらない。fixture ごとに期待を2つの組に分ける必要がある。
- sync はいま8件とも 0 を返す。撤去前の [22] は旧実装との「同じ組か」を見ていたが、旧実装が無い今、終了コードの主張を 0 だけにすると、sync が常に 0 を返す欠陥を見逃す。0 でない組を1件は観測しないと、終了コードの分類を取り戻したことにならない。
- 案X の成立条件（apply と check が判定を共有しない）: 両方とも別のファイルを読み込む行（`source` や `.`）を持たず、互いの名前も参照しない。grep で当たった `. as $doc` と `. as $actual` は jq のプログラムの中の文で、読み込みではない。ポインタを解く jq の定義（`ptr2path`）は、同じ書き方を両方が別々に持っている。
- 陽性対照の差し替え先は、apply の中で1行ずつに決まる。replace の行（`if $item.op == "replace" then setpath($path; $item.expected)`）と、適用の最後の行（`reduce $decl[0][] as $item (.; apply_item($item))`）は、それぞれ1回だけ出る。
- `sync-claude.sh` が実行権を付け直す相手（`canonical/hooks/scripts` と `canonical/claude/statusline` の `.sh`）は、git の上ですべて 100755 だった。本物の木で sync を走らせても、リポジトリのファイルは書き換わらない。
- 宣言を読むもの: `apply-claude-settings.sh`・`check-claude-settings.sh`・`scripts/sync.sh`（`--check` のときに check を呼ぶ）・`test_apply_claude_settings.sh`・`test_sync_output_styles.sh`（参照する正本を宣言から引いて写す）。`sync-claude.sh` は宣言を読まず、apply を呼ぶだけである。

### P2: plan の草稿を書いた（2026-10-18）

- plan: `docs/harness/plans/2026-10-18-plan-401-settings-apply-check.md`。案X を採り、`sync-claude.sh` を本物の木で shebang 経由で走らせた結果に check を当て、宣言の外は前後の不変で見る形にした。
- 撤去前の8つの fixture はそのまま使い、宣言の `replace` の項目すべてに正本と違う値を入れる fixture（stale_replace）を足した。失った能力の6つ目（replace で置き換える動作）を見ていたのが hooks_only の hooks だけだったので、宣言から導いて全項目に広げるためである。
- 陽性対照は5つにして、テストの中に常に置くことにした。issue の反証3つに当たる M1〜M3 に加えて、終了コードの 0 でない組を観測する M4 と、shebang の選択が効いていることを示す M5 を足した。M4 を足した理由は、P1 で sync が8件とも 0 を返すと分かり、0 だけを主張すると「常に 0 を返す sync」を見逃すからである。M5 を足した理由は、#359 で「テストを bash 3.2 で回しても対象が別の bash で動き、版差の主張が空だった」失敗が2回あったので、shebang の主張が空でないことを主張の側で確かめるためである。
- 時間の見積もり: いまのテストは bash 5 で14秒・3.2 で13秒（PASS=221）。sync を38回足すので、30〜40秒ほどに延びる見込みである。

**[4] と [17] を範囲に入れた理由。** 確定版の「望む結果」と issue の反証3は「項目を足してもテストを書き換えずに済む」ことを求めている。同じファイルの [4] と [17] が項目を名指しで並べている限り、新しい [22] がどれだけ宣言から導いても、ファイル全体としては書き換えが要る。主張そのもの（apply が作るファイルには宣言の項目だけが入る）は変えず、期待の側だけを宣言から導く。隣のテストの `build_green` は同じ形だが、[22] の代わりの外なので、ゲート3 の問い Q1 に置いた。

**退けた案。** ゲート1 の探索木は plan の「ゲート1」節にある。自分で挙げて退けたのは、テストの中にもう1つ解釈器を書く案（案W）、直前の commit の apply と比べる案（案V）、「check が一致と言った項目に apply が触らない」関係を見る案（案U）の3つである。案U は、宣言の契約にその関係が書かれていないので退けた。ハンドラが述語の外のフィールドを更新するのは正当でありうるので、契約にするかは宣言の設計の判断である。

### 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）

`so-compare --codex-only`・`gpt-6.1-sol`（設定から読んだ値）・`codex-cli 0.163.0`・155 秒・初回で返答。Codex が返ったので Cursor へは切り替えていない。依頼文と出力は `tmp/401-settings-apply-check/`（作業層）にある。レーンは issue の本文を GitHub の接続エラーで取得できず、確定版のコメントと plan で照合したと開示した。結論は「直してから進めてよい」、指摘は7件で7件とも採った。表は plan の「設計SO」節にある。ここには、採ったことで設計がどう変わったかと、自分の見落としの形を書く。

**M1 を独立性の守りだと思い込んでいた。** 草稿では、M1（replace で手元の値を残す欠陥）が成立条件の守りを兼ねると書いた。check が apply を呼んで期待値を作るように変われば M1 が伝わって落ちる、という筋だった。レーンの反例は「check が空の settings に apply を当てて期待値を作る」形で、M1 の欠陥は空の入力には正しい値を書くので、check は従来どおり hooks_only を落とせる。つまり M1 はこの結合を見つけられない。陽性対照について「期待した理由で落ちるか」は見ていたが、「守りたい性質を壊す変化のうち、どれを見つけてどれを見つけないか」を数えていなかった。直しとして、どんな入力にも誤った値を書く M6 と、ファイル名の参照と読み込みの行が無いことを見る構造の確かめを足した。

昇格の印: 陽性対照で「性質 P を守る」と言うときは、P を壊す変化を2〜3通り書き出し、その対照がそれぞれを見つけるかを確かめてから言う。1つの欠陥への感度を、性質の守りと取り違えやすい

**能力4は「取り戻す」と書けるほどではなかった。** `/statusLine` 全体を不変の検査から除いていたので、statusLine の中の正本に無いキー（padding など）が消えても見えなかった。草稿は残りを [12] と [48] に回すと書いたが、[12] が見るのは padding の1つだけである。`handler` と `merge-object` の pointer では前にあったキーが消えていないことを見る規則を足し、M2 に padding を消す差し替えを足した。正本の値を解かずに済む規則（キーが消えていないか）にしたのは、テストが読むのを pointer と op だけに保つためである（DJ-7）。値だけが変わる場合は残る穴として書いた。

**隔離の守りは文字列の比較では足りなかった。** HOME の接頭辞の比較・引き継いだ `BASH_ENV`・実物の実行権の3点を DJ-9 に足した。A11 の前後の比較は最終の状態しか示さないという指摘から、`sandbox-exec` で書き込みを拒む実行を1回入れ、それを主な証拠にした。`sandbox-exec` がこの環境で動くことは、拒否したディレクトリへの `touch` が `Operation not permitted` で失敗し、ほかへの `touch` が成功することで確かめた。

**M5 は sync の側しか見ていなかった。** apply の側の interpreter も記録する形にした。

**事実の誤り1件。** wrapped を「type が無い」と書いていたが、撤去前の fixture には `"type":"command"` がある。読んだ fixture を要約するときに、思い込みで1つ足していた。

選択肢拡張では、OS の書き込み制限の下で sync を走らせる案（案S）と、statusLine を使う側から確かめる案（案C）が出た。案S は A11 で1回だけ使う。テストの中に常に置かないのは、`sandbox-exec` が macOS だけのものだからである。案C は `test_sync_claude_statusline.sh` の [7] が同じ観測をしているので足さない。

### P3: 報告して止まった（2026-10-18）

- plan と episode を `dbb5b4b` で commit し、枝を push した。PR はまだ作っていない。
- 報告の宛先は brief の欄の統括で、`oe-tree` で root の `cockpit` として生きていることを送る直前に確かめた（自分の親として出ている）。`.oe/report-401.md` に報告を書き、`oe-send` で1行のポインタを送った。exit は 0 である。exit 0 は取り込みの確認ではない。
- 承認で決めてほしいこととして Q1〜Q3 を上げた（plan の「GATE 3」節）。ゲート3 の承認が統括から届くまで、テストの変更には入らない。

### GATE 3: owner の承認を受けた（2026-10-18）

- 統括から、owner が plan（`dbb5b4b` の版）を承認したと届いた。Q1〜Q3 と設計判断はすべて推奨どおりである。Q1 の `build_green` は #454 に起票され、この PR では直さない。承認の記録と baseline は統括の作業層（`.oe/decision-401-gate3.md`）にある。
- 送り手は brief の「報告の宛先」の統括で、この session への送信として届いた。

### I1-0: baseline の確認（2026-10-18）

- `origin/master` は `ed45de5` のままで、`scripts/sync`・`canonical/claude`・`canonical/hooks/claude.hooks.json`・対象のテストに変更は無かった。
- `dbb5b4b` の plan の blob（`6b633c3…`）と brief の sha256（`87d4b67…`）は、承認の記録の値と一致した。

### I1-1: [22] と [4]・[17] を書いた（2026-10-18）

- plan の DJ-1〜DJ-10 のとおりに、撤去した [22] の跡の注記を新しい [22] に置き換え、[4] と [17] の期待を宣言から導く形にした。冒頭の「検証する軸」と触る範囲の説明も直した。
- 結果: bash 5 で `=== PASS=269 FAIL=0 ===`（40秒・変更前は PASS=221 で14秒）、`/bin/bash`（3.2）で `=== PASS=269 FAIL=0 ===`（36秒・変更前は13秒）。どちらも最後の集計の行で読んだ。3.2 の実行では、M5 が「テストを走らせた bash と sync の interpreter の主版番号が同じなので区別できない」と NOTE を出した。設計どおりである。時間は plan の見積もり（30〜40秒）に収まり、60秒の照会の線には届かない。
- shellcheck は警告0件のまま。

**既知の罠をまた踏んだ。** 1回目の実行が「`eq_sync_want�`: 未割り当ての変数です」で止まった。M5 の文言に `$eq_sync_want）` と、変数の直後に全角の括弧を書いていた。bash が全角の先頭のバイトを変数名に食って、存在しない変数を展開した。この罠は自分の memory にすでにある（heredoc で `$var` の直後に全角を置くと化ける）が、heredoc ではなくテストの中の文字列だったので、当てはまると思わずに書いた。4か所を `${…}` で囲んで直し、`$` に続く英数字の直後に ASCII 以外の文字が来る箇所が無いことを grep で確かめた。止まったのは `set -u` のおかげで、黙って空の文字列になる形ではなかった。

### I1-2: 検査の側を弱めた写しで、対応する確かめが赤になった（A9・2026-10-18）

`3ba6974` を `git archive` で scratchpad に3つ写し、テストのファイルだけを1か所ずつ弱めて bash 5 で走らせた。

| 弱め方 | 結果 | 赤になった確かめ |
|---|---|---|
| W1: 不変の検査の関数が、比べずに常に空を返す | PASS=268 FAIL=1 | M2 の「不変の検査が拾うのは own_statusline の padding と personal_keys の theme だけ」 |
| W2: sync を `"$BASH"` を前に付けて起動する | PASS=268 FAIL=1 | M5 の「sync は shebang の interpreter（主版 3）で動く」 |
| W3: check を呼ぶ箇所を、終了コード 0 と空の出力を返す形にする | PASS=256 FAIL=13 | 本物の木の書けない相手の確かめ、M1 の一覧と理由4件と書けない相手、M3 の書けない相手と「足した項目を一致と判定する」、M6 の終了コードと理由3件 |

plan の A9 が「赤になるべき」と書いたものは、3つとも赤になった。W3 では plan に書いていなかった M3 の2件も赤になったが、どちらも check の出力に頼る確かめなので、赤になるのが正しい。W1 と W2 は、赤になったのがそれぞれ1件だけで、ほかの確かめを巻き込んでいない。

### I1-3: 宣言に5項目目を足した写しで、テストを変えずに緑のままだった（A7・2026-10-18）

`3ba6974` を写し、写しの `settings.values.json` に値を、`settings.harness.json` に最上位の `replace` の項目（`/hub401Fifth`）を足した。テストのファイルは変えていない（`git show HEAD:` との diff が空）。

- `test_apply_claude_settings.sh`: `=== PASS=271 FAIL=0 ===`。確かめが2件増えたのは、M1 と M6 の「宣言の `replace` の項目すべて」に5項目目が入ったからである。
- `test_sync_output_styles.sh`: `=== PASS=18 FAIL=0 ===`。参照する正本を宣言から引いて写す形（#338 の直し）が効いている。
- `test_check_claude_settings.sh`: `=== PASS=87 FAIL=7 ===`。`build_green` が4項目を名指しで組み立てるので、5項目目が「未適用」になり、`build_green` を使う7件が落ちた。#454 が受ける。

### I1-4: 残りの受入（A8・A10・A11・A12・2026-10-18）

- A8: `test_check_claude_settings.sh`（PASS=94）・`test_sync_output_styles.sh`（PASS=18）・`test_sync_claude_statusline.sh`（PASS=17）が、bash 5 と `/bin/bash` の両方で FAIL=0。`test_apply_claude_settings.sh` は I1-1 で両方 PASS=269 FAIL=0。どれも最後の集計の行で読んだ。
- A10: shellcheck は警告0件（変更前と同じ）。
- A11: `sandbox-exec` で `~/.claude`（subpath）・`~/.claude.json`（literal）・worktree（subpath）への書き込みを拒む設定の下で走らせ、`=== PASS=269 FAIL=0 ===`（43秒）。同じ設定で worktree への `touch` が `Operation not permitted` で拒まれることを先に確かめ、設定が効いていることを見た。本物の `~/.claude` への書き込みで設定を試すことはしていない（触れないため）。前後の比較では、`~/.claude/settings.json` の shasum と mtime、`~/.claude.json` の shasum、`~/.claude` の下のリンク先の一覧の digest が同じだった。違いは worktree の `git status` の2行で、比べた間に自分の変更を commit したためである。`~/.claude` の下に #401 の worktree を指すリンクは1本も無い。
- A12: bash 5 で40秒、3.2 で36秒、sandbox の下で43秒（変更前は14秒と13秒）。60秒の照会の線には届かない。

### GATE I1: A1〜A12 を満たした（2026-10-18）

A1〜A6b はテストの [22] の PASS の行（両方の bash）、A7 は I1-3、A8 は I1-1 と I1-4、A9 は I1-2、A10〜A12 は I1-4 で確かめた。満たしていない項目は無い。

### I2-1: 実装SO の結果と採否（2026-10-18）

`oe-review --base origin/master`（既定の codex と cursor の2レーン・`SO_TIMEOUT=480`）を `9380949` に当てた。判定は `survived` で、2レーンとも material な欠陥は無いとした。依頼の文脈は `tmp/401-settings-apply-check/review-context.md`、出力は `tmp/oe-review-20261018103930BANAND21V49H/`（作業層）にある。

- Codex（`gpt-6.1-sol`・設定から読んだ値・`codex-cli 0.163.0`・66秒）: 差分と関連の本体を読み、bash 3.2 と 5 の構文の検査と shellcheck を通した。読み取りだけの制約でテストそのものは走らせていない、と開示した。
- Cursor（`composer-2.5`・指定・214秒）: テストを bash と `/bin/bash` の両方で走らせて PASS=269 FAIL=0 を確かめ、M1・M2・M6 の差し替えの行が apply の実物と一致することを照合した。残る穴として、宣言の内側で値だけ変わる場合・入れ子の pointer・写しの木に rules などが無いこと・構造の確かめが行頭の `source` と `.` しか見ないこと、を挙げた。どれも plan の DJ-6・DJ-7・DJ-5 に書いた穴と同じで、新しい穴ではない。
- Cursor は、episode の PASS=271 といまの PASS=269 の差を「記録のずれの可能性」とした。271 は I1-3 の、宣言を5項目にした写しでの数である（M1 と M6 の確かめが1件ずつ増える）。記録のずれではないので、直さない。

採る指摘が無かったので、コードは変えていない。

**`~/.claude.json` の shasum が変わっていた。** 実装SO のあと、本物の HOME の状態をもう一度比べると、`~/.claude/settings.json` の shasum と mtime と、`~/.claude` の下のリンク先の一覧は変わっていなかったが、`~/.claude.json` の shasum だけが変わっていた。更新時刻は 19:43:05 で、自分のテストを走らせ終えたあとの比較（19:38）より後で、Cursor のレーンが終わった時刻と重なる。このファイルは Claude Code の CLI が動作中に書き換えるもので、その時刻にも claude のプロセスが10個動いていた。テストが書かないことは、`~/.claude.json` への書き込みを拒んだ sandbox の下での実行（A11）で確かめてある。どの書き込みで変わったかは特定していない。中身は個人の状態を含むので、差分は取っていない。

### I2-2: PR を作り、Copilot のレビューを1ラウンド受けた（2026-10-18）

- PR #455 を作り、`--reviewer @copilot` で依頼した。timeline に `review_requested Copilot` が残っている。
- Copilot のレビュー（`copilot-pull-request-reviewer[bot]`・COMMENTED）は「Approval recommended」「No open issues」で、行ごとのコメントは0件だった。返信の要るスレッドは無く、未返信は0件である。再依頼はしていない。

### I3: knowledge の収穫と観測の書き戻し（2026-10-18）

- 収穫した item は2件で、どちらも harness の木の `docs/harness/knowledge/items/` に置き、`validate-knowledge` を通した。
  - `01M579XYN3N1XMP66YZGWHYWE2`: 陽性対照で性質を守ると書く前に、性質を壊す変化を書き出して対照がどれを見つけるかを確かめる（`本文: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）` の印から）。
  - `01M579XZNAT7EXY4VPGRM9J8JW`: bash で変数の直後に ASCII 以外の文字が来る位置は `${var}` で囲む（`本文: I1-1: [22] と [4]・[17] を書いた（2026-10-18）` から）。item を書く前に、どの bash とロケールで起きるかを確かめた。bash 5.2.37 と 3.2.57 のどちらでも、`ja_JP.UTF-8` と `en_US.UTF-8` で起き、`C` では起きなかった。作業者の memory はこの罠を「C ロケール相当で起きる」と書いていたので、memory のほうを直した。
- 注入された4件に、`ref: "#401"` の観測を1件ずつ足した。3件は `followed`、`01M486Z2ND07GQWV1GHS1SVB0J` は `externally_verified` である（後者は、宣言から導いた [4]・[17] の期待が `absent` の項目を数えてしまう打ち消しを、教訓に従って探したあとでも設計SO が見つけたため）。

## closure（2026-10-18）

tier は heavy である。設計SO と実装SO を品質ゲートとして明示的に起動し、実行中に撤回（M1 を独立性の守りとした主張）と失敗（全角の前の変数で止まった）があり、選択肢を比べて棄却した設計判断があり、knowledge への昇格がある。

### 次の消費者

- #454（check のテストの `build_green` を宣言から導く形にする作業）。新しい [22] と [4]・[17] の書き方（宣言から pointer と op だけを読む）が先例になる。`本文: I1-3: 宣言に5項目目を足した写しで、テストを変えずに緑のままだった（A7・2026-10-18）` に、`build_green` で落ちる7件の実測がある。
- 宣言に項目を足す次の作業。新しい [22] は、最上位の `replace` の項目なら書き換えずに通る。入れ子の pointer を足すときは不変の検査に規則を足す必要がある（plan の DJ-7）。
- apply か check を作り直す作業。M6 と構造の確かめが、両者を結合させる変更を赤にする。

### 事実・失敗

- 宣言はすでに4項目あり、issue の反証3の「4項目目」はそのままでは使えなかった（`本文: P1: 上流の前提とのずれ（2026-10-18）`）。
- 陽性対照 M1 を、apply と check の独立性の守りだと思い込んでいた。設計SO の反例で、1つの欠陥への感度にすぎないと分かり、M6 と構造の確かめを足した（`本文: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）`）。
- 能力4を「取り戻す」と書きすぎていた。statusLine の中の手元のキーが消える欠陥が見えなかった（同上）。
- 隔離の守りを HOME の文字列の比較で足りると考えていた。物理パス・`BASH_ENV`・実物の実行権・sandbox の4点を足した（同上）。
- 「項目を足してもテストを書き換えずに済む」の保証の範囲を広く書きすぎていた。入れ子の pointer と `absent` の項目では成り立たず、範囲を最上位の `replace` に限り、[4]・[17] の期待から `absent` を除いた（同上・設計SO の指摘3）。
- M5 が sync の側の interpreter しか見ていなかった。apply の側の記録を足した（同上・指摘5）。
- 受入 A9 の弱め方の中身と、赤になるべき確かめを決めていなかった。3つの弱め方と期待を A9 に書いた（同上・指摘6）。
- fixture の wrapped を「type が無い」と誤って要約した（同上）。
- 設計SO のレーンは、GitHub の接続エラーで issue の本文を取得できず、確定版のコメントと plan だけで照合した。本文との照合は未完のまま採否を決めた（同上）。
- テストの文言で変数の直後に全角の括弧を置き、1回目の実行が未割り当ての変数で止まった。自分の memory にある罠だった（`本文: I1-1: [22] と [4]・[17] を書いた（2026-10-18）`）。
- その memory は、罠が起きる条件を「C ロケール相当」と誤って書いていた。確かめると UTF-8 のロケールで起き、C では起きない。memory を直した（`本文: I3: knowledge の収穫と観測の書き戻し（2026-10-18）`）。
- テストを変えずに宣言を5項目にした写しで、`test_check_claude_settings.sh` が `build_green` を使う7件で落ちた。#454 の対象である（`本文: I1-3: 宣言に5項目目を足した写しで、テストを変えずに緑のままだった（A7・2026-10-18）`）。
- 実装SO の Cursor のレーンが、episode の PASS=271 といまの PASS=269 の差を記録のずれの可能性と指摘した。271 は5項目にした写しでの数なので、採らなかった（`本文: I2-1: 実装SO の結果と採否（2026-10-18）`）。
- 実装SO のあとで `~/.claude.json` の shasum が変わっていた。テストが書かないことは sandbox の実行で確かめてあり、どの書き込みで変わったかは特定していない（`本文: I2-1: 実装SO の結果と採否（2026-10-18）`）。

### 決定と根拠

- 判定の基準を旧実装から check に移し、宣言の外は前後の不変で見る（案X）。退けた案（案Y・案Z の一部・案W・案V・案U・案S・案C）と理由は plan の「ゲート1」節と DJ-1 にある（`本文: P2: plan の草稿を書いた（2026-10-18）`）。
- 入口を `sync-claude.sh` の shebang 経由にし、主張を「本番の起動の組み合わせ」に限った。版ごとの主張はこのファイルのほかの項目が持つ（plan の DJ-2）。
- 陽性対照をテストの中に常に置いた。受入のときだけ走らせる案は、apply と check の関係が後で変わったときに気づく場所が無くなるので退けた（plan の「ゲート1」節）。owner はゲート3 で、テストの時間が30〜40秒に延びることを受け入れた（`本文: GATE 3: owner の承認を受けた（2026-10-18）`）。

### わかったこと

- check は書けない相手（壊れた JSON・symlink・ディレクトリ）で理由つきの 1 を返すので、案X の「check に exit 0 を求める」は fixture の組で分ける必要がある（`本文: P1: いまのコードで確かめたこと（2026-10-18）`）。
- 新しい [22] は、宣言を5項目にしても書き換えずに通り、検査の側を弱めた3通りのそれぞれで、対応する確かめだけが赤になる（`本文: I1-2: 検査の側を弱めた写しで、対応する確かめが赤になった（A9・2026-10-18）`・`本文: I1-3: 宣言に5項目目を足した写しで、テストを変えずに緑のままだった（A7・2026-10-18）`）。
- bash が変数の直後の多バイト文字の先頭バイトを食うのは UTF-8 のロケールで、C では起きない（`本文: I3: knowledge の収穫と観測の書き戻し（2026-10-18）`）。

### 蒸留シグナル

- knowledge store: `01M579XYN3N1XMP66YZGWHYWE2`（陽性対照の主張の範囲）と `01M579XZNAT7EXY4VPGRM9J8JW`（変数の直後の多バイト文字）を収穫した（`本文: I3: knowledge の収穫と観測の書き戻し（2026-10-18）`）。
- decision: なし。判定の基準の判断は、退けた案と前提とともに committed の plan にある（下の「昇格の判定」）。
- skill・rule: なし。

### 昇格の判定

- **宣言を読む側のテストのうち、項目を名指しで並べる箇所は、項目を足すたびに書き換えが要る** — `not-required`。一般の形は knowledge item `01KYJ76D830XME16ZFXC2XRPZZ`（完全性の述語は母集団の側から書く）がすでに持ち、この枝の分（[4]・[17]）は同じ変更で直した。残る `build_green` は #454 の担当である。参照: `本文: P1: 上流の前提とのずれ（2026-10-18）`。
- **陽性対照で性質 P を守ると言うときは、P を壊す変化を書き出し、対照がそれぞれを見つけるかを確かめる** — `required`（knowledge store）。非自明で、再発しうる。次に対照を組むときの手順も変える。既存の item `01M00KCCHNMFPHP5HAGX2DZ1MK` は「期待した理由で色が出たか」までで、この穴は含まない。この枝で `01M579XYN3N1XMP66YZGWHYWE2` として収穫した。参照: `本文: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）`。
- **判定の基準を旧実装から check に移し、宣言の外は前後の不変で見る（成立条件を M6 と構造の確かめで守る）** — `not-required`。中核の判定には当たる。案X・Y・Z などの複数の解釈が live で、覆すには基準の独立性をめぐる議論が要り、apply と check が別々の実装だという前提は将来偽になりうる。それでも、判断・退けた案・前提は、この枝が入れる committed の plan（DJ-1・DJ-5・「ゲート1」節）に書いてある。成立条件はテストの [22] の冒頭のコメントと M6・構造の確かめが、破る変更を赤にして理由を示す。decision を別に立てると plan の写しになる。参照: `本文: P2: plan の草稿を書いた（2026-10-18）`。
- **bash で変数の直後に ASCII 以外の文字が来る位置は `${var}` で囲む** — `required`（knowledge store）。memory にだけあって store に無く、hub では日本語の文言を持つテストが多いので再発しうる。この枝で `01M579XZNAT7EXY4VPGRM9J8JW` として収穫した。参照: `本文: I1-1: [22] と [4]・[17] を書いた（2026-10-18）`。
- **issue の反証3の「4項目目」を「5項目目」に読み替えた** — `not-required`。この issue だけの読み替えで、plan の「上流の前提の確かめ」に理由とともに書いてある。参照: `本文: P1: 上流の前提とのずれ（2026-10-18）`。
- **sandbox-exec は受入で1回だけ使い、テストの中には置かない** — `not-required`。macOS だけの道具だという事実から決まる判断で、議論が要らない。plan の「ゲート1」節にある。参照: `本文: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）`。

### 注入された negative knowledge への観測

注入された item は4件である: `01M00KCCHNMFPHP5HAGX2DZ1MK`・`01M54X75SV448T2R5Z7MR32E0G`・`01KYJ76D830XME16ZFXC2XRPZZ`・`01M486Z2ND07GQWV1GHS1SVB0J`。4件とも `ref: "#401"` の観測を1件ずつ足した（`本文: I3: knowledge の収穫と観測の書き戻し（2026-10-18）`）。

### 認識合わせの抜け

- 確定版は、issue の反証3が「4項目目を足す」と書いていることを、いまの宣言（すでに4項目）に当て直していなかった。確定版の「文脈の置き場」には `settings.harness.json` を読んだとあるので、読んではいたが、issue 本文の数と照らしていない。行き先は `issue-intake` の固定の問い（どのリポジトリでも同じ観点）で、「issue 本文に書かれた数や状態を、いまのリポジトリに当て直したか」を足す候補になる。スキルを直す issue の起票は統括に依頼する（報告の Out-of-scope に書く）。`本文: P1: 上流の前提とのずれ（2026-10-18）`。

### follow-up

- `test_check_claude_settings.sh` の `build_green` を宣言から導く形にする → #454（統括が起票済み）。
- `issue-intake` の固定の問いに「issue 本文の数や状態を、いまのリポジトリに当て直したか」を足す候補 → 統括へ起票を依頼する（上の「認識合わせの抜け」）。
- 「check が一致と言った項目には apply が触らない」関係を宣言の契約にするか（ゲート1 の案U） → 追わない。いまの宣言の運用で困った事例が無い。困る事例が出たら、#359 の宣言の設計の issue として起こす。
- 入れ子の pointer を宣言に足すときの不変の検査の規則 → 追わない。いまは入れ子の項目が無く、足せば赤に倒れて気づける（plan の DJ-7）。
- 宣言の内側で、check の述語が見ないキーが消えずに値だけ変わる場合（能力4の残り） → 追わない。owner がゲート3 で「一部を取り戻す」扱いを承認した（Q3）。いまの handler は statusline-wrap だけで、その値の変化のうち元コマンドの扱いは、既存の [12]・[48] と `test_sync_claude_statusline.sh` の [7] が見ている。
- 写しの木に rules・skills などが無いこと → 追わない。写しの木は陽性対照のためのもので、settings の適用の経路に要るものは宣言から引いて写している。写しが本物と同じに働くことは M3 の9件で確かめている。本番と同じ木の確かめは、本物の木の9件が受け持つ。
- 構造の確かめが、行頭の `source` と `.` の読み込みしか見ないこと → 追わない。apply と check を結合させる変更のうち、期待値を apply から作る形は M6 が振る舞いで見つける。それ以外の経路で共有されたときに見えないことは、plan の DJ-5 に限界として書いてある。
- 実装SO のあとに変わった `~/.claude.json` の原因 → 追わない。テストが書かないことは sandbox の実行で確かめてあり、このファイルは Claude Code の CLI が動作中に書き換える。

### 外部チェック

`so-compare --codex-only`（`gpt-6.1-sol`・設定から読んだ値・`codex-cli 0.163.0`・60秒・初回で返答）で、closure を4つの観点（失敗の選択的な省略・follow-up の行き先・揮発する場所への依存・back-propagation）と promotion の `ref` に絞って点検した。依頼文と出力は `tmp/401-settings-apply-check/so-closure-prompt.md` と `tmp/401-settings-apply-check/so-closure-codex/`（作業層・消える）にある。結論は「要補完」で、指摘は5件、5件とも採った。

- 指摘1〜4（観点1・省略）: 設計SO の指摘3・5・6、5項目の写しで check のテストが落ちた事実、実装SO の 271/269 の指摘と不採用、memory の誤り、設計SO が issue の本文を取得できなかったこと、が「事実・失敗」に項目として無かった。足した。
- 指摘5（観点2・行き先）: 実装SO が挙げた残る穴のうち3つ（値だけの変更・写しの木の中身・構造の確かめの範囲）に処分が無かった。3つとも「追わない」と理由を follow-up に足した。
- 問題なしとされた点: 揮発する場所への参照は残るが要点は本文に写してある。memory の訂正・`issue-intake` の候補・#454 への渡し方に行き先がある。promotion の6件の `ref` は、どれも本文に実在する見出し1つに一致する。

### status

stable。達成。受入 A1〜A12 を満たし、PR #455 で設計SO・実装SO・Copilot を通した。マージ・worktree の掃除・issue の close は統括と owner に残す。
