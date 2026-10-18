---
id: "01M575BADF09N8GPWRP195C2PD"
title: "#401 宣言駆動 settings の検査を、撤去した等価性 fixture の代わりに立て直す"
date: 2026-10-18
type: episode
status: in-development
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
