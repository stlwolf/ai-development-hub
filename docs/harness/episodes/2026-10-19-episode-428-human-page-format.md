---
id: "01M59P2Z7YZFQT0VSVJ053E164"
title: "#428 人向けの確認・回答用ページの形と部品を、持ち運べるスキルとして作る"
date: 2026-10-19
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/428"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6253136654"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6263379748"
    reason: "質問フェーズのまとめ（owner と統括で決めたこと11点と、plan に回すこと）。この単位はこれを前提にする"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-19-plan-428-human-page-format.md"
    reason: "この episode が記録する作業の計画"
tags: [skill, artifact, human-page, harness]
knowledge_observations:
  - "01M486Z2N7FSHRQ6EG34KT3AH9"
  - "01M2DRCP3SNPTHWDV2FJ9RZ4N0"
  - "01M00KCCHNMFPHP5HAGX2DZ1MK"
---

# #428 人向けの確認・回答用ページの形と部品を、持ち運べるスキルとして作る

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## なぜこの作業が始まったか

owner に判定や回答を求めるページ（claude.ai の artifact）は、作るたびに形がばらばらで、owner はその都度「こうしてほしい」と伝えていた（2026-10-13 起票）。10-18〜19 に「送り元が分からない」「版と更新日時が分からない」という要件が足され、owner と統括は質問フェーズで形を11点決めた。この作業は、その11点を、どのリポジトリでも使える新しいスキル（ベースの HTML の型・部品の CSS と JS・データからページを作るスクリプト・用語集）として作る。

## この単位の入力

- brief: 統括（cockpit 19代目）が 2026-10-19 に発行した `.oe/brief-428-human-page-format.md`（作業層・消える）。plan-first で、最初の終端は P3（plan を報告して止まる）、委譲全体の終端は I3（PR を作って報告する）。マージ・worktree の掃除・issue の close はしない。baseline は master `e5d6c7f`。
- 認識合わせ: 確定版 https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6253136654 と、質問フェーズのまとめ https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6263379748 。
- scope: まとめの「決まったこと」1〜11 を実装する新しいスキル。スキルのフォルダに hub の文書・リポジトリ名・issue 番号・hub の運用への参照を入れない（owner・2026-10-19）。呼ぶ側の hub の運用を変える文書の変更は最小にする。
- SO: 設計 weak（`so-compare` の Codex 1レーン）・実装 weak（`oe-review` の codex+cursor）+ Copilot 1ラウンド。Codex が返らなければ Cursor に1回だけ切り替えてよい（切り替えたら理由をここに書く）。
- 注入された negative knowledge: 3件（frontmatter の `knowledge_observations`）。closure で全件に観測を書き戻す。

## 作業の記録

### P1: worktree・確定版の照合・参照の読み（2026-10-19）

- worktree `feature/#428_human_page_format` を `wt switch --create` で作った。起点は master `e5d6c7f` で、`git fetch` のあとの `origin/master` と同じであることを確かめた。
- `issue-intake` の 1-2 の手順で、認識合わせのコメントを調べた。最後の行は `confirmed`・見出し4で、URL は brief の「認識合わせ:」欄と一致した。確定版と質問フェーズのまとめを前提にし、自分では認識合わせを通していない。
- いまの判定ページ2枚（#401 の plan 承認・#385 の許可規則の判定）を artifact の read で読んだ。保存は `db.collection("decisions").doc(key).set({key, choice, note, at})` で、`db` が無いときは「この表示では保存できません。選んだ内容は会話で伝えてください」と出す。描画は、ページに埋め込んだ配列（`GROUPS`）から JS で行い、`#N` を GitHub の issue へのリンクにしている。送り元の行は「ai-development-hub ・ cockpit 統括19代目（tmux ウィンドウ 0:2）・ issue #401 ・ 枝 … ・ 日付」で、まとめの決定4（ウィンドウ.ペイン・ブランチと書く・版の行を分ける）とはまだ違う。
- artifact の決まり（Artifact の道具の page contract と `artifact-design`・`artifact-capabilities`）を読んだ。plan に効く点は3つある。1つ目は、公開するファイルは doctype・`<html>`・`<head>`・`<body>` を書かない断片で、公開のときに骨組みで包まれることである。2つ目は、artifact の外で保存したページには `window.claude` 自体が無く、`claude.use()` は呼べないことである（`claude.d.ts`）。3つ目は、`<title>` は先頭 8KB の中に置くことである。
- 自分のペインから `tmux display-message -p -t "$TMUX_PANE"` で `0:2.2 CC:ai-development-hub` を引けた。まとめの決定4の「番号は、ページを作ったセッション自身のペインから引く」を、スクリプトが環境から取れる見込みがある。
- スキルを列挙している hub の文書は `canonical/CATALOG.md` だけだった。sync の3本は `SKILL.md` を持つディレクトリをまるごとリンクするので、新しいスキルは sync を直さずに配られる。ただし `~/.claude/skills` のリンク先は master の checkout なので、配られるのはマージと sync のあとである。

### P2: plan の初稿と、そこで下した判断の理由（2026-10-19）

plan の初稿を書いた。判断の結論は plan の DJ-1〜DJ-13 にあり、ここには結論に至った理由のうち plan に書き切れないものを残す。

- **描く場所をスクリプトに移した。** いまの判定ページは、ページに埋め込んだ配列から JS で描いている。最初はそれを引き継ぐつもりだったが、受入の「ヘッダーが決まった形で出る」「札の文言が用語集どおり」を確かめるには、JS で描くとブラウザが要る。Python が静的な HTML を描けば、標準の unittest だけで文字として確かめられ、JS が動かない表示でも中身は読める。JS は答え・保存・回答待ちの件数だけを持つ。

昇格の印: 描画をスクリプト（静的な HTML）に移し、JS は答えと保存だけにする判断

- **札の言葉の正本を用語集の1か所にした。** まとめの決定11 は用語集を1つのファイルに置くと決めている。build.py に同じ表を持つと正本が2つになり、owner が「表示を見て調整」したときに両方を直す必要が出る。build.py が描くたびに用語集の表を読む形にし、表が壊れていたら止める。
- **出力を2つの形にした。** artifact に公開する断片は文字コードの宣言を持たないので、手元で開くと日本語が化けうる。Artifact の道具の骨組みとまったく同じ形で書けば1つで済む見込みもあるが、骨組みの文字列は道具の版で変わりうるので頼らない。
- **言語は Python 3 にした。** hub の慣習は Bash だが、brief はスキルを hub の外へ持ち出せる形にすることを求めている。持ち出した先で追加のインストールを要しないことを優先した。macOS 付属の 3.9.6 で動く範囲に限る。owner の確認を plan の Q2 に置いた。

昇格の印: スキルのスクリプトを、hub の慣習（Bash）でなく持ち運びを優先して Python 3 の標準ライブラリで書く判断

- **回収のあとの表示は、入力を止める案を推奨にした。** 回収のあとに選び直しても統括には届かないので、押せる形のままだと届いたように見える。ただし owner の運用の感覚に関わるので、plan の Q3 で確かめる。
- **hub の側の変更は CATALOG の1行に絞った。** 統括の判定ページの作り方を書いた canonical の文書はいまは無く、案内をどこに足すかは統括の運用の判断である。brief の「最小にする」に従い、Q4 に置いた。

### P2: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-19）

- `so-compare --codex-only` を `-w` に worktree を渡して1回当てた。モデルは `gpt-6.1-sol`（設定から読んだ値）、`codex-cli 0.163.0`、155 秒で初回に返った。Cursor には切り替えていない。依頼文と出力は `tmp/428-human-page-format/`（作業層・消える）にある。issue のコメントの写しは、信頼できない入力として区切って渡した。
- 結論は「直してから進めてよい」で、指摘は16件（高7・中9）。16件とも採った。指摘ごとの採否と直したところは plan の「設計SO」節の表にあり、ここでは再掲しない。
- 初稿の穴は3つの系統に分かれた。1つ目は、まとめの文言を言い換えて弱めていた所で、目的が部品を縛る規則（指摘1）と、JST を「走らせたマシンの時間帯」にしていた所（指摘2）である。どちらも自分で決定の文を読み直せば分かった形で、要件の文を設計に写すときに、持ち運べる形にしようとして要件の側を動かしていた。2つ目は、保存の互換を「4つの項目が同じ」でしか見ていなかった所（指摘3・4・5）で、いまの判定ページの書き方（文書全体を書き直す）が持つ競合と、接続を待つあいだの入力の扱いが抜けていた。3つ目は、受入が偽物の `db` と API の直接の書き込みで閉じていて、公開したページの JS と本物の `db` のつながりを見ていなかった所（指摘14）である。
- 指摘3 を採ったことで、書き方を `set`（文書全体）から `update`（変えた項目だけ）に変えた。保存される文書の形は同じだが、いまの判定ページとは書き方が違う。統括に知らせておくべき違いなので、plan の GATE 3 の節に「問いにはしないが知っておいてほしいこと」として書いた。
- 選択肢拡張の2案（ブラウザで動く生成器・宣言的な HTML を正本にする）は、どちらも退けた。理由と、もう一度検討する条件は plan の「ゲート1」節の木にある。

昇格の印: 判定ページの書き込みを、文書全体の set から、変えた項目だけの update に変える判断（保存の形は同じ）

- plan を直す途中で、道具の呼び出し（Edit と Bash）に書いた JSON のエスケープの表記 `\u003c` が、ファイルに届く前に `<` という1文字に直されていた。表の中の文が「`<` を `<` に置き換える」と読める形になっていた。バックスラッシュを `chr(92)` で組み立てる Python で直し、制御文字が無いことを `grep -P` で確かめた。この episode の記録も、最初は同じ理由で化けたので、同じ方法で書き直した。

### GATE 3: owner の承認を受けた（2026-10-19）

- 統括から、owner が plan（`1a9b3ce` の版）を承認したと届いた。Q1〜Q4 はすべて推奨どおりで、名前は `human-page`、スクリプトは Python 3 の標準ライブラリ（3.9 以上）、回答済みのページは押せない状態にして回収した答えだけを見せる、hub の側の変更は CATALOG の1行だけ、である。承認の記録と baseline は統括の作業層（`.oe/decision-428-gate3.md`）にある。owner は Q4 について、統括の判定ページをこのスキルで作る案内を、マージのあとに統括が実物で試してから別に決めると言っている。
- 統括は、見本のページを公開したら URL を途中経過として送るよう求めた。owner が表示を見て調整したいと言っている。これは plan の I1-6 と同じである。

### I1-0: baseline の確認（2026-10-19）

- `git fetch` のあと、`e5d6c7f..origin/master` で `canonical/skills`・`canonical/CATALOG.md`・`scripts/sync` に動きは無かった。
- A11 の守る対象（`~/.claude/skills` のリンクの一覧30件・`~/.claude/settings.json` の shasum・master の作業ツリーの `git status --porcelain` の7行）を scratchpad の `a11/` に記録した。

### I1-1: 検証・用語集・見本・検査を書いた（2026-10-19）

- `build.py` の読み込み（同じ項目名の重なり・`NaN` を弾く）と検証（DJ-9 の規則）と、用語集の札の表を読む部分を書いた。この段の `build.py` のコマンドは `check`（検証だけ）である。描画と `build`・`source` のコマンドは I1-2 で足す。
- 見本は4つ（`decide`・`bundle`・`review`・`grasp` と本文の断片）で、架空のリポジトリ `example-org/shop`・`example-org/billing` と、`repo_url` を持たない `mobile` を使った。`mobile` は、group の送り元に `repo_url` が無いと `#N` をリンクにしない決まり（DJ-11）を確かめるために置いた。
- 検査は85件で、Python 3.13 と 3.9.6（`/usr/bin/python3`）の両方で通った。壊したデータの検査は72件で、出た誤りが期待した規則と場所の1件だけであることを主張する。DJ-9 の規則のうちデータで確かめる16の規則に、それぞれ1件以上ある（E-B1 は描画の段なので I1-2 で足す）。
- **最初に回したとき3件が落ちた。** 知らない type の部品と、配列でない `sections` で、E-S1 か E-F3 に加えて E-P2（回答待ちなのに答える部品が無い）が出た。部品を読めなかったせいで答える部品が無いように見える形で、DJ-9 の「1つの誤りから同じ原因の誤りを重ねて出さない」に当たる。部品を読めなかったときは E-P2 のこの条件を見ない形に直した。検査の期待を緩めて通したのではなく、実装の側を直した。
- A3: `build.py` の写しで E-C3 の判定を消すと、落ちたのは `test_c3_recommend_missing_option`・`test_two_independent_errors`（E-C3 を含む2つの誤り）・`test_data_error_exits_1_with_rule_line`（E-C3 の文言を見る）の3件だった。3件とも E-C3 を期待する検査で、落ちた理由は「期待した E-C3 が出なかった」ことだった（差分の表示で確かめた）。E-F2 の判定を消すと、落ちたのは E-F2 の4件だけだった。plan の A3 は「E-C3 の壊したデータの検査だけが落ちる」と書いたが、E-C3 を期待する検査は3件あったので、その3件が落ちたことで満たしたと判断した。

### I1-2: 型・CSS・JS・描画を書いた（2026-10-19）

- `template.html`・`page.css`・`page.js` と、`build.py` の描画・`build`・`source` のコマンドを書いた。見本の4つから、断片と `--standalone` の両方を作れた（断片は約2.4万〜3万バイト）。`source --git <この worktree>` は、repo を origin の URL から `ai-development-hub` と引いた。最初は作業ツリーの最上位のディレクトリの名前から引く設計だったが、worktree のディレクトリ名（`ai-development-hub.feature-#428_human_page_format`）がそのまま repo の名前になってしまうので、origin の URL の最後の区切りを先に使う形にした。
- 検査は115件になり、Python 3.13 と 3.9.6 の両方で通った。足したのは、ヘッダーの2行と、そのリンクの先、項目を省いたときの形、JST の版、group ごとのリンクの先、攻撃の文字列、page contract、E-B1、用語集の1行が静的な文字と JS に渡す言葉の両方に届くこと、回答済みのページ、`source` のコマンドである。
- 初回ですべて通ったので、検査が空回りしていないかを、描画の側を壊した写しで3つ確かめた。group のリンクをページの `repo_url` に戻すと `test_bundle_groups_link_to_their_own_repo` だけが落ちた。埋め込みの JSON で `<` を置き換えないようにすると `test_attack_strings_stay_text` だけが落ちた。送り元の行の末尾に区切りを足すと、ヘッダーの文字を見る7件が落ちた。3つとも、壊したところを見る検査が、その理由で落ちた（注入された negative knowledge `01M00KCC…`）。
- 実装の注意（plan の DJ-14）のとおり、JSON の置き換えは `chr(92) + "u%04x" % ord(c)` で実行時に組み立てた。`build.py` の中に、バックスラッシュと u と16進の4桁が並ぶ表記は無い。

### I1-3: 手元のブラウザで確かめた（A7・2026-10-19）

`--standalone` で作った見本を scratchpad の `web/` に置き、`python3 -m http.server`（127.0.0.1 のみ）で出して Playwright で開いた。偽物の `db` は `addInitScript` で、ページの JS より先に `window.claude` として差し込み、呼ばれた順と引数を記録させた。

| 場面 | 見たもの | 結果 |
|---|---|---|
| (a) `window.claude` が無い | ヘッダーの2行、押した状態、「この表示では保存できません」、返答の文、コピー | 期待どおり。押すたびに「回答待ち 3 件」が 2 件に減り、返答の文が選んだ label と補足で変わった。コピーは「コピーしました」になった |
| (b) 記録するだけの偽物の `db` | 書き込みの順と中身 | 最初の選択は `update {at, choice}` が断られ（文書が無い）、`set {at, choice, key, note}` が1回。補足は `update {at, note}` が1回。同じ文書への書き込みは重ならなかった。保存された文書は4つの項目を持った |
| (c) `use("db")` が2秒遅れる | 接続を待つあいだの選択 | 待つあいだは「保存先に接続しています」で、書き込みは0回。つながったあと、待つあいだに押した選択が (b) と同じ順で書かれた |
| (d) 書き込みが断られる | 失敗の見せ方 | 選択は押した状態のまま、カードに「保存できませんでした…」が出て、返答の文の欄が出た |
| (e) `use("db")` が `null`・例外 | 保存できない表示 | どちらも (a) と同じ形になった |
| (f) 攻撃の文字列のページ | script が動かないか | ページの外の印の変数は立たず、`img`・`b` の要素は0で、script の要素はデータと JS の2つだけだった。タイトル・見出し・なぜの欄には、文字のまま出た |
| (g) 幅 400px・暗い表示 | 横の揺れと背景 | 4つの見本すべてで `scrollWidth` が `clientWidth`（400）を超えなかった。暗い表示を真似ると背景が `rgb(21, 26, 24)` に変わり、`data-theme` の明示はどちらの向きにも勝った |
| (h) 回答済みのページ | 押せないこと・`db` を呼ばないこと | 選択肢と補足欄はすべて押せず、回収した答え（2件）だけが押された形で出て、残りの1件に「未回答」が出た。偽物の `use` は一度も呼ばれなかった |
| `file://` | 手元のファイルとして開く | 開けた。文字コードは UTF-8、描画は標準の形（`CSS1Compat`）で、選んだ内容が返答の文に入った |

- コンソールの誤りは、手元のサーバーに `favicon.ico` が無いことの 404 だけだった。
- 画面の写しを2枚（明るい表示の判断のページ・幅 400px の暗い表示のレビューのページ）見て、崩れが無いことを確かめた。

### I1-4: SKILL.md を書き、A8・A1・A1b を確かめた（2026-10-19）

- SKILL.md には、前提・いつ使うか・隣の指示（Artifact の道具の説明と `artifact-design`）との分担・作り方の流れ・目的と部品の表・データの書き方・コマンド・検証の規則・公開と回収・書くときの注意・限界を書いた。description には、判定ページ・確認や回答を集めるページ・判断待ちの束・レビューの指摘の一覧・見取り図・回答済みにして出し直す場面を名指しし、artifact を作る組み込みの指示と一緒に読み込まれたときはページの形と部品をこのスキルが決める、と順序を書いた（注入された negative knowledge `01M486Z2…`）。
- **A8 の最初の試しは、意味の無い緑だった。** SKILL.md のコードブロックを取り出し、`<…>` を `sed` で置き換えて打ったところ、6本とも `rc=0` だった。ところが `sed` は、置き換え先の worktree のパスに入っている `#` を区切り文字と取り違えて失敗しており、`bash -c` に渡ったのは空の文字列だった。空のコマンドは 0 を返すので、6本とも緑に見えた。標準エラーの `bad flag in substitute command` と、書き出した HTML が無いことで気づいた。置き換えを Python の文字列の置き換えに替えて打ち直し、6本とも実際の出力（検証の文・書き出した断片と完全な文書・送り元の JSON・検査の `OK`）を伴って通ることを確かめた。期待した色が出たときに、その理由（書き出したファイルがあるか）まで見ないと、足場の失敗を通してしまう形で、注入された negative knowledge `01M00KCC…` の形そのものだった。
- A1: 禁じた語の検索と `hub` の語の検索は、どちらも0件だった。`#` と数字の当たりは、`page.css` の36件がすべて CSS の色、`examples/` と `tests/` の当たりがすべて架空のリポジトリ（`example-org/shop`・`example-org/billing`・`mobile`）の番号で、SKILL.md と `glossary.md` には当たりが無かった。当たりの全件を一覧にして目で分けた。
- A1b: フォルダを `cp -RL` で scratchpad へ写し（写しの中に symlink は0件）、作業ディレクトリを `/` にし、PATH を Python 3.9 だけにして（tmux も git も無い）走らせた。検査は115件で、git を使う1件だけが飛ばされ、残りは通った。見本の生成は通り、送り元の tmux は「TMUX_PANE が無い」として省かれた。`TMUX_PANE` を残して tmux だけを PATH から外したときも、「tmux を呼べない」として省かれ、止まらなかった。

### I1-5・I1-6: CATALOG に足し、見本のページを公開した（2026-10-19）

- `canonical/CATALOG.md` の Skills の表に `human-page` の行を足し、見出しの件数を 29 から 30 にした。表の行数（30）と `canonical/skills/` のディレクトリの数（30）が一致することを確かめた（A10）。
- Artifact の道具の決まりどおり、最初に quickstart（intent は other）を通した。当てはまる型は無く、ふつうのページとして公開した。
- `examples/decide.json` から作った断片を、`capabilities: {db: {}}` で private の artifact に公開した。URL は https://claude.ai/artifact/S42QtFnVmKGhDujRrzYnLu である。架空のデータであることは、公開の `description` に書いた。
- A6: `ArtifactData` の list で `decisions` は空だった。見本のカードの key（`rollout`）で4つの項目の文書を1件書くと、list に version 1 で出た。消して、空に戻ることを確かめた。
- A6b: Playwright のブラウザで artifact の URL を開くと、claude.ai のサインインの画面になった。ブラウザが claude.ai に入れていないので、画面の操作は自分ではできない。plan のとおり、統括を通して owner に、見本のページの1枚のカードで選択と補足を保存してもらうよう頼む。
- 承認のあとの plan の直しを、plan の末尾の「ゲート3 のあとの変更」節に5件まとめた。どれも補正として申告する。
