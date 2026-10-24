---
id: "01M5PNMC4B28G9Q1TX2Q0YB6KH"
title: "#536 html-one-pager の問いのカードの書き方・答えたカードを畳む・一覧から選ぶ問いを同じページに置く"
date: 2026-10-24
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/536"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/536#issuecomment-6382793397"
    reason: "#536 の着手時の認識合わせの確定版（統括が投稿・深掘りなし）"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-24-plan-536-one-pager-question-cards.md"
    reason: "この episode が記録する作業の計画"
  - type: reference
    ref: "docs/harness/decisions/2026-10-19-decision-428-human-page-format.md"
    reason: "スキルを作った単位の decision。決定1〜3（Python 3.9 以上の標準ライブラリ・スクリプトが静的に描き JS は答えだけを持つ・保存の形）をこの単位でも守る"
  - type: reference
    ref: "docs/harness/decisions/2026-10-23-decision-478-one-pager-kinds.md"
    reason: "種別・識別子・判断ボード・一覧の行の選択の decision。決定4・5 の前提（判断ボードは表の行を正とする・1ページに選ぶ組は1つ）をこの単位で広げる"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-10-24-decision-466-page-lifecycle-in-flow.md"
    reason: "判断ボードを使い続ける流れの decision。決定12（答え方の形でページを分けない・一覧から選ぶ問いの直しを #536 に入れる）の実装がこの単位"
  - type: reference
    ref: "projects/orchestration-engine/docs/discussions/2026-10-24-discussion-466-page-lifecycle-in-flow.md"
    reason: "13.5 節の9項目（一覧から選ぶ問いを同じページに置く直し）がこの単位の範囲"
tags: [skill, artifact, html-one-pager, harness]
---

# #536 html-one-pager の問いのカードの書き方・答えたカードを畳む・一覧から選ぶ問いを同じページに置く

## なぜこの作業が始まったか

2026-10-24、#466 の判定ページ（26問・承認）を見た owner が「何を聞いているのか分かりづらい。今までのは判断できていたが、これは判断できない」と指摘した。題が問いの形でなく、推奨の選択肢が「推奨どおり」で、discussion の符号を縮めた言葉が並んでいた。統括が同じ URL に出し直した版2（題を問いの形・「何を決めるか」「推奨の中身」「ほかの案」の3つの塊・ボタンを中身の言葉）で、owner は26問と判断ボードの9問に答えた。あわせて owner は、問いが多いと縦に長いので答えたカードを畳めるとよいと述べ、#466 の判定（Q32）で、一覧から行を選ぶ問いを同じページに置く直しもこの issue に入れると決めた。

## この単位の入力

- brief: 統括（20代目）の委譲の書面（作業層 `.oe/brief-536-one-pager-question-cards.md`）。形は plan-first（P3 で停止）→ 実装（I3 で停止）。
- 認識合わせ: 確定版のコメント（frontmatter の2つ目の参照）。
- negative knowledge（注入4件）: `01M5JEBC72EH20XR8E8M3M5VKX`（見せる先は帯に隠れていないかで確かめる）・`01M5CFZVG82GHHBQYWZXNDP427`（抑止を足したら「隠さない」検査も足す）・`01M5F0CNEKA9ED9AMQ3YWGGF8W`（書き方の決まりはスキル自身の文面にも当てる）・`01M5PKRS6WECYZTYFC4WXANW50`（前提にした decision は本文に1文ずつ当て直す）。
- SO モード: 設計・実装とも弱（`so-compare` の Codex 1レーン）・実装のあとに Copilot 1ラウンド。

## 作業の記録

### P1: worktree・確定版の照合・参照の読み・変更前の検査（2026-10-24）

- `wt switch --create feature/#536_one_pager_question_cards --base master` で worktree を作った（`origin/master` の `4d5bf68` から）。
- `issue-intake` の 1-2 の手順で、認識合わせの印のあるコメントを全件読んだ。最後の1件は `confirmed`・見出し4で、URL は brief の「認識合わせ:」欄と文字列として一致した。確定版を前提にし、認識合わせは通し直さない。
- 変更前の検査: `python3 tests/test_build.py` は Python 3.13.5 と 3.9.6（`/usr/bin/python3`）の両方で 318件・失敗0件。node は v18.17.1 で、`page.js` の振る舞いの検査（`PageScript`）も走る。
- 確定版の「本文の数と状態」を当て直した。13.5 節は9項目で、master の discussion にある [verified]（discussion の 13.5 節）。`select` を一覧から選ぶページの外に置くと E-K2 で止まる [verified]（`build.py` の `pick_rows`）。番号の列を置ける種別は `pick`・`map`・`board` だけで [verified]（`build.py` の `ROW_NUMBER_KINDS`）、束には表を置けない [verified]（`build.py` の `kind_bundle`）。食い違いは無かった。

#### 見本と実物を、問いのカードの書き方に当てた結果（P2 の材料）

統括の作業層の版2 のデータ（承認の26問）と、スキルの `examples/` の全データに、仮の決まり（題が「か」「？」で終わる・選択肢の名前の括弧の外に「推奨」を含まない・塊の題の並び）を当てた（スクリプトは scratchpad の `calib.py`）。

- 版2 の26問は、題がすべて問いの形で、選択肢の名前に「推奨」を含むものは0件だった。塊の題は「何を決めるか・推奨の中身・ほかの案」が21枚、「何を決めるか・推奨の中身」が5枚で、`points` を持つカードは0枚だった。
- 版2 の前に作られた判定ページ（#478 の H8・3問）は、3問とも題が問いの形でなかった（「一覧から選ぶページで、表の行ごとにチェックで選べるようにする」など）。
- スキルの見本は、認識合わせ（`confirm.json`）と一覧から選ぶ（`pick.json`）のほかは、題がすべて問いの形でなかった（承認4枚・承認2つ目の見本3枚・判断ボード3枚・束2枚）。どれも `points` で中身を書き、塊を持たない。**決まりを入れるなら、見本はほぼ全部を書き直すことになる。**
- 判断ボードの版1（統括の作業層の作り方のスクリプト）には、選択肢の名前「答えない（Q27 で推奨の形を選ぶ）」がある。別のカードの推奨を指す正当な使い方で、括弧の中の「推奨」を数えない形にすると止まらない。

### P2: plan の初稿と、そこで下した判断の理由（2026-10-24）

plan の DJ-1〜DJ-16 に書いた。ここには、初稿を書くときに迷ったところと、その場で決めた理由だけを残す。

- **書き方の決まりを検査で止める側に寄せた（DJ-2・Q1）。** 確定版の「暗黙の工程」に、統括が版2 の書き方を memory を頼りに守っているとある。決まりを SKILL.md だけに書くと、次に作る統括や子が版2 の前の書き方に戻っても止まらない。P1 の当てはめで、版2 の前のページとスキルの見本が同じ形で外れていたことも、文だけでは戻りうることを示している。
- **専用の欄を足さなかった（DJ-2）。** 塊の題を書き間違えないことだけを見れば欄のほうが強いが、#478 の decision の決定1 が「同じ部品に2つの書き方ができる形」を退けている。塊のまま、題の語を用語集に置いて検査で比べれば、書き間違いは止まる。
- **`<details>` を選んだのは、#428 の決定2 に当て直したからである（DJ-5）。** 最初は JS で開閉のボタンを描く形を考えた（答えの無いカードを畳めなくできる）。#478 の plan の DJ-7 が「JS でクリックを拾ってスクロールする」を決定2 を崩すとして退けていたのを見て、開閉もブラウザに任せる形に変えた。knowledge item `01M5PKRS6WECYZTYFC4WXANW50` の当て直しが効いた箇所である。
- **それでも「開いたときに畳む」は JS が要る（DJ-6・Q2）。** 判断ボードは答えてから回収するまで残るので、読み込み直すたびに開き直すと畳む意味が薄い（#466 の discussion の場面 i）。決定2 を広げることになるので、黙って入れず承認の問いにした。
- **束の選ぶ表を group の中に置いた（DJ-10）。** 13.5 の3 は中か外かを決めるとだけ書いていた。外に置くと、別のリポジトリの group の候補の `#N` がページの送り元のリポジトリを指す。今の束の「group の中は group の送り元でリンクにする」決まりと合わせると中しか無かった。
- **承認・束・判断ボードの選ぶ表は番号を必ず書かせる（DJ-8）。** 行の答えの doc id が番号の数字を含むので、表を足し除きして番号が振り直されると、保存された答えが別の行を指す。判断ボードでカードを移すたびに残りの番号がずれる問題（#478 の決定4 で番号を必ず書かせた理由）と同じ形である。
- **回収の手順には入らない（DJ-12）。** 13.5 の8 は「回収のときの書き方と検査を決める」で、手順は #538 である。境目を、ページの決まり（表を除く・行の書き方・確かめのコマンド）と、手順（いつ読み、どの順に移すか）で引いた。

### P2: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-24）

- `so-compare --codex-only`（`SO_TIMEOUT=600`）。Codex `gpt-6.1-sol`（設定から解決）・`codex-cli 0.163.0`・254 秒・初回で返答した。切り替えは無い。依頼文に実物のページのデータと作業層の中身は入れていない。依頼文と出力は worktree の `tmp/536-one-pager-question-cards/`（作業層）にある。
- 結論は「直してから確定するべき」。指摘10件（高3・中6・低1）を10件とも採った。指摘ごとの採否と直した箇所は plan の「設計SO」節の表にある。
- 採る前に根拠の行を開いて確かめたもの: 指摘1（`build.py:68` の `KEY_RE` は `-` を許し、`page.js:19` でカードを、`:25` で行を同じ `byKey` に入れる）・指摘2（`build.py:1072` がページに無い key を E-A1 で止める）・指摘3（`build.py:1719` が `page.js` を埋め込む）・指摘9（`test_build.py:1297` で `blocks` を `select` より先に見る）。4件ともコードのとおりだった。

#### 初稿から大きく変わったところ

- **カードの key と行の答えの key の衝突（指摘1）は、自分では見えていなかった。** 一覧から選ぶページにはカードが1枚しかないので、今まで起きようがなかった。ほかの問いと混ぜる今回の直しで初めて届く形で、「保存の形を変えない」を決めた時点で安心して、保存の key の名前空間を見直していなかった。
- **`check --answers` の入力（指摘2）は、判断ボードの保存先に前の回収の答えが残り続けることを見落としていた。** 判断ボードを「1枚を使い続ける」ページとして扱いながら、確かめのコマンドを1回答えるページの `answers` の検査と同じ形で考えていた。保存先の全部を渡し、ページに無い key は数だけ出す形にした。
- **畳む表示の作り（指摘6）は、頭を `<summary>` に入れる初稿から、頭を外に置く形に変えた。** 題に `#N` のリンクが入ることを、`<details>` の利点（JS なしで動く）を考えているあいだ見落としていた。
- **選択肢の名前の検査（指摘4）は、「括弧書きの外に推奨の語を含む」から「推奨の語で始まる」に変えた。** 初稿は「非推奨」を止める。「実施する（推奨どおり）」は通すことになるが、中身の語（「実施する」）があるので、owner が指摘した形（中身の無いボタン）ではない。限界に書く。
- **束の候補の番号をアンカーにした（指摘8）。** 初稿は「group は今もページの中へのリンクを持たない」を理由にアンカーにしない形だったが、それは「group が識別子を定義しない」ことの帰結で、選ぶ表の番号を定義する以上、#478 の決定3 に例外を作ることになる。
- 選択肢拡張の2案（HTML のフォームを正本にする・履歴を正本にしてページを作る）は採らなかった。後者は #478 でも退けた案で、そのあと #466 で「判断ボードのページそのものを台帳から作るか」が #540 に預けられている。この単位で選ぶものではないと判断し、plan のゲート1 の木に理由と成立条件を書いた。

昇格の印: 保存の形を変えずに「同じ仕組みに別の種類の答えを載せる」ときは、doc id の名前空間が重ならないかを、今は起きない組み合わせ（ほかの問いと混ぜる）まで含めて見直す

### P3: commit・push・報告（2026-10-24）

- plan と episode を `9e16a57` で commit し、`feature/#536_one_pager_question_cards` を push した。PR はまだ作っていない。
- 報告の宛先（brief の「報告の宛先」の統括）が `oe-tree` に root `cockpit` として生きて出ること、このセッションがその子として出ることを確かめてから、`oe-send` で plan のパスを1行送った（exit 0）。ゲート3 の承認を待って止まる。

### GATE 3: owner の承認を受けた（2026-10-24）

- 統括から「ゲート3 承認」が届いた。owner が統括の判断ボードで答え（10:28〜10:30 UTC）、Q1〜Q4 と plan 全体の承認の問いのすべてで推奨を選んだ。補足は無い。承認時点の plan は `9e16a57`。統括が回収した答えの写し（作業層）で、5つの問いの `choice` がすべて推奨の key であることを確かめた。
- plan の GATE 3 節に結果を書き、frontmatter の status を `in-development` にした（記録の級）。

### I1-0: baseline の確認（2026-10-24）

- `origin/master` は `4d5bf68` のままで、スキルのフォルダに変更は入っていない。
- `git archive 4d5bf68 canonical/skills/html-one-pager` を worktree の `tmp/536-one-pager-question-cards/base/` に取り出し、9つの見本を `--now 2026-10-19T09:05:00+00:00 --tmux off` で `tmp/536-one-pager-question-cards/baseline/` に作った（A3・A10 の比べる元）。

### I1-1: 問いのカードの書き方（2026-10-24）

- 用語集に「問いのカードの塊の題」の節を足し、`build.py` の `load_words` がこの節の語と推奨の札の言葉（`recommend`）も読むようにした。検証に渡す語の辞書を1つに保つためで、`check` と `build` の呼び方は変わらない。
- `build.py` に E-Q1（題の形）・E-Q2（選択肢の名前）・E-Q3（塊の題の並びと `points`）を足した。E-Q2 は選択肢の検査の中に置いた（種別に頼らないため、種別が壊れていても出る）。E-Q1 と E-Q3 は、種別が決まった値のときだけ、すべてのカード（束の group の中も）に当てる。
- 見本5つ（`approve`・`decide`・`board`・`bundle`・`pick`）のカードを書き直した。`points` の中身は、問いの前提を「何を決めるか」へ、推奨の説明と出典を「推奨の中身」へ移し、弱いところの説明があったものは「ほかの案」にした。`decide.json` の推奨の選択肢「この形で進める」は、中身を書いた「冪等キーを付けて3回までにする」にした（E-Q2 では止まらないが、決まりの趣旨に合わせた）。
- 今の検査のうち、見本のカードの `points[0]` に文を入れて変換を確かめる検査（12か所）は、文を入れる場所を「何を決めるか」の塊の最初の要点に移した。ページの最初の `<li>` を読む作りなので、1つ目の塊でないと別の文を読む。種別の検査で足すカード（`CONFIRM_CARD`）は、認識合わせとしても問いのカードとしても誤りの無い形にした。
- `SkillMdExamples` の振り分けを、例の中身から推し量る形から、カードの例の key ごとに入れる見本を決めた対応（`CARD_EXAMPLES`）に直した（設計SO の指摘9）。
- 足した検査: 壊したデータ 24件（E-Q1 4・E-Q2 5・E-Q3 9・重ねない 3・隠さない 3）、通る形と見本への当てはめ 5件（`QuestionCardWriting`）、用語集 2件（新しい節が壊れたら終了コード 2・語を変えると `check` が変わる）。検査は 318件から 349件になり、3.13.5 と 3.9.6 の両方で失敗0件。9つの見本がすべて `check` と `build` を通る。
- A15 の3つの `grep` は当たり無し（終了コード 1）。「推奨どおり」の `grep` の当たりは、用語集の `text.all_recommended`・SKILL.md の「答えを受け取る」節の会話の一言（同じ「全部推奨どおり」）・限界の行・検査のデータ（壊したデータ4件と通る例1件）だった。分類は I1-7 の A5 で書き直す。

### I1-2: 答えたカードを畳む（2026-10-24）

- `build.py` のカードの描画を、頭（札・題・確かめた度合いの札）を外に、残りを `details.hp-fold` の中の `div.hp-fold-body` に置く形にした。`summary` は「答え: …」「開く」「畳む」の3つの `span` だけで、どれを見せるかは CSS（`details` の `open` の有無）で決める。回答済みのページでは、答えのあるカードを `open` 無しで描く。
- `page.js` に足したのは2つだけである。`paint` で答えの行の文字を書き換えること（`foldedAnswer`）と、保存先の最初の答えを読み終えたときに1回だけ答えのあるカードを畳むこと（`foldAnswered`）。手元で変えた回数（`rev`）が0でないカードと入力中のカードは畳まない。保存の処理（`write`・`queue`・`onSnapshot` の答えの取り込み）は変えていない。
- 用語集に `text.folded_answer`・`text.unfold`・`text.fold` を足した（「札の言葉と固定の文」の表なので、答える部品のあるページの埋め込みデータに入る）。
- 検査の台（偽の document）に `details` の `open` を持たせ、`page.js` の検査を3件足した（最初の答えで答えのあるカードだけ畳む・あとから届いた答えでは畳まない／手元で選んだカードと補足を書いたカードは畳まない／保存できない表示では畳まない）。描画の検査を5件足した（`FoldedCards`）。357件・2つの Python で失敗0件。
- 検査を書いている途中で、手元で選んだカードの検査が「保存先の答えで手元の選択が上書きされる」形で落ちた。偽の保存先は、手元の書き込みが通ったあとに、手元と違う答えを届けていた。実物では、手元の書き込みが通れば保存先の答えはその値になるので、偽の保存先が届ける答えを手元の書き込みと同じ値に直した。`page.js` の取り込みの決まり（書き込み済みなら保存先の値を採る）は今のとおりで、この単位では変えていない。
- SKILL.md に「答えたカードを畳む表示」の節を足した。

### I1-3: 一覧から選ぶ問いを承認と判断ボードに置く（2026-10-24）

- 検証: 表の部品に任意の `key`（E-S3 で形と重なりを見る）、選び方に `tables`（形の誤りは E-F3、空・二重の名指しは E-C7）を足した。名指しの解決（`resolve_selects`）を、種別の部品の判定と識別子の判定より前に置き、選ぶ表の場所と名指したカードを記録する。種別の部品の判定（番号の列を置けるか・並び）と識別子の判定（接頭辞と振り方）は、その記録を使う。
- 番号: 一覧から選ぶページと見取り図は今のとおり（書かなければ振る）。判断ボードは、選ぶ表でない番号の列を `Q`、選ぶ表を `候補` で、どちらも必ず書く。承認と束は、選ぶ表だけを `候補` で必ず書く。番号を3つ以上並べる書き方（E-I3）は、ページで定義された接頭辞をすべて見るようにした（種別ごとの表から引く形をやめた）。
- 選ぶ表ごとの判定（推奨の行がその組の表にあるか・`min` が選べる行の数を超えないか・行の答えの key の登録）は、カードごとに行う（`select_rows`）。行の答えの key がほかのカードの key と重なれば E-C1 で止める（設計SO の指摘1）。
- 並び: 承認と判断ボードで、判定カードの節の直後に、その節の選び方のカードが名指した表をカードの順・`tables` の順で続けて置く（`select_runs`）。選ぶ表でない表は今のとおり最後の判定カードの節のあと。
- 描画: `pick_info`（1組）を `picks_info`（カードごとの組の並び）にした。選び方の行・チェック・埋め込みの `picks` は組ごとに出る。行の位置を `(部品の順, 行の順)` の組で持ち、束の group の表（I1-4）を足せる形にした。`page.js` の一覧の行の扱いは変えていない（`picks` を配列で回していたため）。
- 1枚の `tables` に同じ表を2回書いたとき、初めは名指しの解決を全部やめていたので、名指された表が「名指されていない番号の列」として E-K2 でも止まった。読める名前で解決は続け、表に頼る判定だけを省く形に直した（knowledge item `01M5CFZVG82GHHBQYWZXNDP427` の「重ねない」）。
- 名指しが空（`tables: []`）や配列でないときは、どの表も名指されないので、承認の選ぶ表は「名指されていない番号の列」として E-K2 でも止まる。名指しの両端を指す2件として、そのまま検査に書いた。
- `board.json` に、2つ目の節の選び方のカード（Q7）と、その直後の選ぶ表（`trial_shops`）を足した。判断ボードの部品の位置が1つずれたので、位置を書いた今の検査（6件）を直した。カードを全部表へ移したページの検査は、選ぶ表も一緒に除く形にした（除かないと E-I1 で止まる。DJ-12 のとおり）。承認に `select` を置いたときの誤りは、E-K2 から E-C7（`tables` が無い）に変わった。
- 足した検査: 壊したデータ 21件（E-K2・E-C7 7・E-K3 2・E-I1 4・E-I2・E-C6・E-S3 2・E-C1・E-A1・隠さない 2）、描画と書き方 4件（`SelectOnAnyKind`。今の一覧から選ぶページの書き方6つが通ることを含む）、`page.js` 2件（2つの組の上限と返答の文・カードと行が別の doc id に書かれる）。385件・2つの Python で失敗0件。9つの見本がすべて `check` と `build` を通る。

### I1-4: 束の group の選ぶ表（2026-10-24）

- group に任意の `tables` を足した。中身は表の部品と同じ形で、`key` は必須（無ければ E-F3）、`type` が `table` でなければ E-S1。名指されていない group の表は E-K2、並びが group の中の選び方のカードの順・`tables` の順でなければ E-K3。別の group の表を名指すと E-C7。
- 描画: group のカードのあとに表を描く（見出しは `h4`）。表の中の `#N` などは group の送り元でリンクにし、候補の番号のアンカーはページのもの（送り元に頼らない）を使う。行の id は `hp-row-<部品>-g<group>-t<表>-<行>`。番号を並べる書き方（E-I3）の検査に、group の中の文（題・目的・カード・表の欄）も入れた（`display_texts` を group まで広げた）。
- `bundle.json` の1つ目の group に、選び方のカード（書体を選ぶ）と group の中の選ぶ表を足した。group の回答待ちの件数が1から2に変わったので、その検査を直した。
- group のカードを空にする今の検査（E-S1）で、名指すカードが無くなった group の表が E-K2 でも止まった。カードが無い group では名指されていないことを重ねて出さない形に直した（「重ねない」）。
- 足した検査: 壊したデータ 9件（E-C7・E-K2・E-S1・E-F3 2・E-I1・E-I2・E-K3・E-I3）、描画 1件。395件・2つの Python で失敗0件。9つの見本がすべて `check` と `build` を通る。

### I1-5: 回収の確かめと空の判断ボード（2026-10-24）

- `check --answers <ファイル>` を足した（`check_collected`）。渡した答えのうちページにある key は `answers` の検査（E-A1・選び方のカードごとの上限）で見て、ページに無い key は数えて標準エラーに「ページに無い key N 件は見なかった」と出す。ページの状態には関係なく見る。ページに `answers` があれば、それは今の決まりで別に見る。ファイルが JSON として読めなければ終了コード 2。
- 判断ボードの E-K1 を、判定カードの節も表も無いときだけにした（開いた問いが0枚で、番号の列の無い表だけのページが通る）。部品が1つも無いページは今のとおり E-S1 だけ。
- 今の検査のうち「判定カードが無く決まったことの表も無い判断ボードは E-K1」は、決めた変化なので「判定カードの節も表も無い（指摘の一覧だけの）判断ボードは E-K2 と E-K1」に直した。
- 足した検査: 壊したデータ 1件（部品が0の判断ボードは E-S1 だけ）、空の判断ボード 1件、`check --answers` 7件（上限を超える・超えない・2回目の回収・除いたあとに当てると数えるだけ・選択肢でない・オブジェクトでない・ページの `answers` と別に見る・コマンドの終了コードと出力）。404件・2つの Python で失敗0件。

### I1-6: SKILL.md の仕上げと CATALOG（2026-10-24）

- SKILL.md: 作り方の流れ（答え方の形でページを分けない）・種別と部品の表（承認と判断ボードの選ぶ表・束の group の選ぶ表・空の判断ボード）・札と番号の表（選ぶ表の `候補` と必ず書く理由）・見本の説明・データの書き方の表（表の `key`・`select` を置ける種別・group の `tables`）・表の部品の書き方（番号の列を置ける表・表の key）・番号と識別子の書き方（group の選ぶ表の番号はアンカー）・「一覧から選ぶ問いの行の選択」の節（名指し・並び・束・行の答えの key の重なり）・判断ボードの更新のしかた（選び方のカードを移すときに表も除く・行の書き方・`check --answers`・候補の番号を使い直さない・空の判断ボード）・判断待ちの束・コマンド（`check --answers`）・検証の規則の表（E-C1・E-C6・E-C7・E-S1・E-S3・E-K1〜E-K3・E-I1・E-I2・E-A1）を直した。「答えを受け取る」節と「回答済みにして出し直す」節は触っていない（#538 の範囲）。
- 用語集の `prefix.candidate` の説明を、選ぶ表の接頭辞に直した。
- CATALOG の html-one-pager の行に、問いのカードの書き方・一覧から選ぶ問いを承認と束と判断ボードに置けること・畳む表示・`check --answers` を足した（`git diff 4d5bf68 -- canonical/CATALOG.md` は1行の差し替えだけ）。
- A15 の3つの `grep` は当たり無し。404件・2つの Python で失敗0件。

### I1-7: 受入の確かめ（2026-10-24・`ca5071a`）

- **A1**: 404件・3.13.5 と 3.9.6 で失敗0件。変更ごとの検査の対応は下の表。
- **A2**: 新しい規則（E-Q1〜E-Q3・E-C7）を `EveryRuleIsCovered` に足し、壊したデータの検査で、期待した規則と場所の1件だけ（「隠さない」検査は2件とも）出ることを確かめた。I1-1・I1-3・I1-4・I1-5 の節の件数のとおり。
- **A3**: `4d5bf68` のスキルのフォルダに新しい検査と見本を入れて走らせた。新しい検査の項目 88件のうち 77件が落ち、11件が通った。通った11件は、どれも今の振る舞いを保つことを確かめる比べの元である（重ねない検査3件・部品が0の判断ボードは E-S1 だけ・指摘の一覧だけの判断ボードは E-K2 と E-K1・認識合わせとレビューのカードの `select` は E-K2・通る名前と通る題・認識合わせの題は見ない・全体の承認のカードは塊が要らない）。
- **A4**: 9つの見本がすべて `check` と `build` を通る（終了コード 0）。
- **A5**: (a)(b) は `SkillMdExamples` と `QuestionCardWriting.test_examples_and_skill_md_follow_the_writing` で確かめた。(c) の「推奨どおり」の `grep` の当たりは8件で、用語集の `text.all_recommended`（会話で言う一言・1件）、SKILL.md の「答えを受け取る」節の同じ一言（1件・#538 の範囲なので触らない）、SKILL.md の限界の行（止まらない書き方を挙げる行・1件）、検査の壊したデータ（4件）、検査の通る例（`実施する（推奨どおり）`・1件）だった。plan の A5 が挙げた3つの分類に、「会話で言う同じ一言」と「検査の通る例」を足して読む（補正。下の「ゲート3 のあとの変更」の H1）。
- **A6〜A8**: 検査で確かめた（`FoldedCards`・`PageScript` の畳む検査3件・`SelectOnAnyKind`・`CollectedAnswers`・`EmptyBoard`）。
- **A9**: `page.js` の差分は、先頭の説明・`foldedAnswer`・`foldAnswered`・`paint` の1行・`onSnapshot` の1行（最初の答えのときに `foldAnswered` を呼ぶ）だけで、保存の処理（`write`・`queue`・`onSnapshot` の答えの取り込み）の行の変更は無い。今の `PageScript` の7件は通る。混ぜたカードと行が別の doc id に書かれることも確かめた。`build.py` の差分に E-B1 の関数とその補助の行は無く、`ExternalLoads` の class の中身は `4d5bf68` と同じ。`template.html` の差分は空。
- **A10**: 作り・埋め込みデータ・JS・CSS に分けて比べた。`review.json`・`table.json`・`grasp.json` は CSS のほかは同じ。`confirm.json` は、作りでは2枚のカードの開閉の要素と答えの行だけ、埋め込みデータでは `labels` の新しい key（`text.fold`・`text.folded_answer`・`text.unfold`）だけ、JS では畳む処理だけが違う。データを直した5つの見本は、カードの文・選ぶ表・`labels` が違い、`pick.json` の埋め込みの `picks` は変わらない。
- **A11**: 統括の作業層の版2 の承認のページ（26問）と判断ボードのデータは、最後のコミットの `check` を通った。版2 の前の判定ページ（3問）は前の版の形（`purpose`）なので E-F3 と E-F2 で止まり、`kind` を足した写しでは E-Q1 3件・E-Q3 6件（と #478 からの札の形の E-I1 3件）で止まった。実物のデータとその写しはコミットに入れていない（写しは worktree の `tmp/` の下）。
- **A12**: 手元の HTTP サーバーと Playwright で確かめた。(a) 偽の保存先で答えのある Q1・Q2 が開いたときに畳まれ、Q3・全体の承認は開いたまま。開閉の行を押すと開き、もう一度押すと畳まれる。関連リンクの最後から Tab 1回で Q1 の開閉の行に移り、Enter と Space で開け閉めできた。(b) 幅 900px で目的の文の `Q2` から畳んだ Q2 へ飛ぶと、頭の上端 121px・帯の下端 81px で、頭の中の点を `elementFromPoint` で当てると頭が返った。そこで開いても上端は 121px のまま。幅 400px・保存できない表示（帯がいちばん高い 128px）で手で畳んだ Q2 へ飛ぶと、頭の上端 163px で帯の下端 128px より下だった（knowledge item `01M5JEBC72EH20XR8E8M3M5VKX`）。(c) 題はすべて `summary` の外にあり、`summary` の中に見出しは無い。(d) 判断ボードで候補1 と 候補3 を選ぶと候補2 が押せなくなり、「選んだ行（2）: 候補1、候補3」が出て、畳むと「答え: 選んだ店舗で試す（選んだ行: 候補1、候補3）」が出た。(e) 回答済みのページから script を除いた写しでも、答えのある Q1 は畳まれて描かれ、押すと開いた。(f) 幅 400px で5つのページとも `scrollWidth` が `clientWidth`（400）を超えない。見た目は画面の写しで1回確かめた（worktree の `tmp/` の下）。
- **A14**: `git diff 4d5bf68 -- canonical/CATALOG.md` は html-one-pager の行1つだけ。
- **A15**: 3つの `grep` は当たり無し（終了コード 1）。

#### 変更ごとの検査の対応（A1）

| DJ | 検査 |
|---|---|
| DJ-1〜DJ-3 問いのカードの書き方・E-Q1〜E-Q3 | `BrokenData` の `q1_*`・`q2_*`・`q3_*`・`q_*`、`QuestionCardWriting`、`LoadStage.test_block_words_broken_exit_2`・`test_changed_block_words_and_recommend_word_change_check` |
| DJ-4 長い文書の節へのリンク | 検査なし（SKILL.md の決まり。限界に書いた） |
| DJ-5・DJ-6 畳む表示・いつ畳むか | `FoldedCards`、`PageScript.test_first_answer_folds_answered_cards_only`・`test_cards_touched_before_the_first_answer_stay_open`・`test_unavailable_display_folds_nothing` |
| DJ-7 置ける種別とカードと表の結び付き | `BrokenData` の `k2_select_on_*`・`c7_*`・`f3_tables_not_array`、`SelectOnAnyKind.test_two_pairs_on_an_approve_page`・`test_pick_page_forms_still_pass` |
| DJ-8 番号の列・接頭辞・アンカー | `BrokenData` の `i1_select_*`・`i2_candidate_numbers_overlap_across_pairs`・`i1_select_number_missing_on_board`、`Identifiers.test_board_keeps_written_numbers_and_links_to_decided_rows`、`SelectOnAnyKind.test_board_example_has_a_pair_right_after_its_section`・`test_listed_candidate_numbers_are_stopped_on_an_approve_page` |
| DJ-9 並び | `BrokenData` の `k3_select_table_not_right_after_its_section`・`k3_select_tables_out_of_card_order` |
| DJ-10 束の選ぶ表 | `BrokenData` の `c7_table_of_another_group`・`k2_group_table_not_named`・`s1_group_table_not_a_table`・`f3_group_table*`・`i1_group_*`・`i2_group_*`・`k3_group_*`・`i3_group_*`、`SelectOnAnyKind.test_group_pair_renders_inside_its_group` |
| DJ-11 描画と埋め込み | `SelectOnAnyKind`、`PageScript.test_two_pairs_have_their_own_limits_and_reply_lines`・`test_cards_and_rows_are_saved_to_their_own_documents` |
| DJ-12 回収と止め方・`check --answers` | `CollectedAnswers`、`Identifiers.test_board_with_every_card_moved_has_no_save_code` |
| DJ-13 検査の規則（E-C1・E-C6・E-S3・E-A1） | `BrokenData` の `c1_card_key_is_a_row_answer_key`・`c6_select_min_over_its_rows`・`s3_table_key_*`・`a1_rows_over_max_per_pair`・`c7_and_*` |
| DJ-14 空の判断ボード | `EmptyBoard`、`BrokenData` の `k1_board_without_cards_or_tables`・`s1_board_without_parts_is_only_s1` |
| DJ-15 見本・SKILL.md・用語集 | `ExamplesPass`、`SkillMdExamples`（例ごとの対応）、`QuestionCardWriting.test_examples_and_skill_md_follow_the_writing`、`PrefixWordsAcrossTheFolder` |
