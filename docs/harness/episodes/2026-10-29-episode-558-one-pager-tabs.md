---
id: "01M633STQAH97998QM52K0STQD"
title: "#558 html-one-pager に、1枚のページを長さや中身で分けるタブの部品を足す"
date: 2026-10-29
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/558"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/558#issuecomment-6489170251"
    reason: "#558 の着手時の認識合わせの確定版（統括が投稿・owner が「推奨で進めて」で決めた9項目）"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-29-plan-558-one-pager-tabs.md"
    reason: "この episode が記録する作業の計画"
  - type: reference
    ref: "docs/harness/decisions/2026-10-19-decision-428-human-page-format.md"
    reason: "スキルを作った単位の decision。決定2（スクリプトが静的に描き、ページの JS は答え・保存・回答待ちの件数だけを持つ）を、この単位でタブの切り替えまで広げる"
  - type: reference
    ref: "docs/harness/decisions/2026-10-23-decision-478-one-pager-kinds.md"
    reason: "種別と識別子の decision。種別の閉じた許可の表に、タブを置ける種別を足す"
  - type: reference
    ref: "docs/harness/decisions/2026-10-24-decision-536-one-pager-question-cards.md"
    reason: "問いのカードと畳む表示の decision。畳む表示の開閉はブラウザが受け持つ形を、タブの切り替えでも崩さない"
tags: [skill, artifact, html-one-pager, harness]
---

# #558 html-one-pager に、1枚のページを長さや中身で分けるタブの部品を足す

## なぜこの作業が始まったか

2026-10-26 に owner が、判断ボードが長くなったときの分け方として「URL 1枚にしつつ、タブでページの粒度自体を分割する」案を出した（#539 のコメント）。2026-10-28 には、ある統括の見取り図（13の節・約100KB）で owner が「下に長いからタブ形式にできるか」と言い、統括が `--body` に CSS だけのタブを手で書き、余白の直しが2回来た（同じく #539 のコメント）。owner によると長いページは頻繁に出る。`html-one-pager` の SKILL.md の「限界」には「長いページのタブの部品は、まだ無い」とある。

## この単位の入力

- brief: 統括（21代目）が 2026-10-29 に書いたもの（作業層・git の対象外）。形は plan-first で、P3 と I3 で止まる。ゲート3 は、owner の指示（「推奨で進めて」）で、統括が確定版と照らして代える。
- 確定版: 上の related の2つ目。「決めたこと」の9項目を設計の前提にする。
- 注入された knowledge item 2件:
  - `01M5JEBC72EH20XR8E8M3M5VKX`（見せる先が貼り付く帯に隠れていないかで確かめる）。タブの帯は上に貼り付き、隠れたタブを指すリンクで移った先が帯の下に隠れうる。
  - `01M5PTAXJ7H0WFZ5C83HXD4RZ4`（利用者の key をつないで識別子を作るときは、key に使えない文字で区切るか重なりを検査する）。タブの `#` の名前と要素の id を、書き手の書く名前から作る。
- 参考: owner が 2026-10-28 に作った資料のページの元のファイル（統括のワークスペースの根の作業層）。中身に業務のリポジトリの名前が入っているので、作り（CSS と JS の形）だけを読み、文言はこの episode・plan・PR・SO の依頼文に写さない。

## 作業の記録

### P1: worktree・確定版の照合・参照の読み・変更前の検査（2026-10-29）

- worktree は `wt switch --create 'feature/#558_one_pager_tabs'` で `origin/master` の `3a773ab` から作った。
- 確定版の照合は `issue-intake` の 1-2 の手順で行った。認識合わせの印のあるコメントは1件で、`confirmed`・見出し4・URL が brief の「認識合わせ:」欄と文字列として一致した。自分では認識合わせを通し直していない。
- 変更前の検査は、Python 3.13.5 と 3.9.6（macOS 付属）の両方で 415件が通った。node は v18.17.1 で、`page.js` の振る舞いの検査も走っている。
- 確定版の「本文の数と状態」の行は「テストは169件」と書いている。この worktree では、`def test_` の行が 167、壊したデータの検査（`BROKEN` の行）が 248 で、走る件数は 415件だった。169 は数え方の違い（検査の関数の数を数えたもの）と見ていて、受け入れ基準（足した検査が2つの Python で通る）には効かない [verified]（`canonical/skills/html-one-pager/tests/test_build.py` の `grep -c`）。
- SKILL.md の「限界」の最後の行に「図・長いページのタブ・読み比べ・「何もしなければ受け入れ」の印付けの部品は、まだ無い」があることを確かめた（`canonical/skills/html-one-pager/SKILL.md:524`）。
- 読んだ参照: SKILL.md・`build.py`（全体）・`page.css`・`page.js`・`template.html`・`glossary.md`・`tests/test_build.py` の作り（壊したデータの表・`PageScript` の node の台）・見本（`grasp`・`table`・`board`）・#428・#478・#536 の decision・#539 のコメント2件・knowledge item 2件。
- 参考のページから読んだ作り: タブの帯は `position: sticky` で上に貼り付き、段ごとに1行で、左に段の名前、段の中は横に送る。選んだタブは下線で示す。JS は `location.hash` に名前を書き、左右の矢印キーで隣のタブへ移る。`build.py` が描いた部品を、JS がタブの中へ移していた（データの部品と本文のタブを1つのページで混ぜる使い方が実際にあった）。

#### P1 で見つけた、設計に効く事実

- 答える部品のあるページには、上に貼り付く帯（`.hp-bar`・全部推奨どおりの案内と保存の状態）がすでにある。タブの帯も貼り付くので、2つの帯が重ならない作りが要る [verified]（`page.css` の `.hp-bar`・`build.py` の `Renderer.bar`）。
- 答える部品の無いページ（見取り図など）は JS を持たず、`page.js` はカードが無いと何もしない。タブの切り替えの JS は、`page.js` とは別に、タブのあるページにだけ入れる必要がある [verified]（`build.py` の `render` の `scripts`・`page.js` の先頭の `if (!cards.length) { return; }`）。
- 描いた要素の id はすべて `hp-` で始まり `-` を含む（`hp-card-<key>`・`hp-row-…`・`hp-fold-<key>` など）[verified]（`build.py` の `Renderer`）。タブの `#` の名前に `-` を使えなくすれば、名前から作る要素の id は、描いた要素のどの id とも重ならない（knowledge item `01M5PTAXJ7H0WFZ5C83HXD4RZ4` の「key に使えない文字で区切る」の形）。
- `page.js` の検査の台（`PAGE_DRIVER`）の偽物の document は `getElementById` しか持たない [verified]（`tests/test_build.py` の `PAGE_DRIVER`）。タブの JS も id だけで要素を引く形にすれば、同じ形の台で振る舞いを検査できる。
- 範囲の外の気付き: `build.py` の `display_texts` は、`return out` のあとに古い版の本体が残っていて、走らない（`build.py:1529-1567`）。振る舞いには効かないので、この単位では直さず、PR の報告で知らせるだけにする。

### P2: plan の初稿と、そこで下した判断の理由（2026-10-29）

plan の初稿を `docs/harness/plans/2026-10-29-plan-558-one-pager-tabs.md` に書いた。設計判断は DJ-1〜DJ-16、確定版に無い判断は N1〜N10 で、ゲート1 の木は plan の「ゲート1」節にある。探索を止める条件は、書き始める前に「各設計判断に、確定版と参考のページに無い案を1つ以上当て、設計SO の選択肢拡張の結果を足す」と決めた。

初稿で迷ったところと、選んだ理由を残す。

- **タブの定義をどこに置くか（DJ-1・DJ-2・N1）**: 最初は、本文のパネルに名前と段を属性で書かせ、`build.py` が本文を読んで帯を描く形を考えた。確定版の「本文に決まった class の組を書けばタブになる」に文字どおり合うためである。ところが、参考のページは本文のタブとデータの表のタブを1つのページで混ぜていて、混ぜると定義が本文とデータの2か所になる。さらに帯を本文のどこに入れるかで、`build.py` が信頼したコードである本文の HTML を書き換えることになる。定義をデータの `tabs` に1つだけ置けば、帯はデータから描け、段の上限もデータだけで検査できる。代わりに、本文だけの見取り図でもデータに `tabs` を書く手間が増える。確定版の文の読み方を狭めるので、N1 として統括に分けて渡す。
- **束のタブ（DJ-3・N3）**: 束のページは束の部品が1つしか置けないので、部品をタブに割り当てる形のままでは分けられないことに、種別の検査（`kind_bundle` の `only_one`）を読んで気付いた。group にタブを付ける形も考えたが、タブの単位が種別で変わり、束の題がタブの外に残る。タブのある束のページでは部品をタブごとに1つまで置けるようにする形を推した。
- **貼り付く帯を1つにする（DJ-6・N7）**: 答える部品のあるページの上の帯の高さは、保存の状態の文で 84〜128px に変わる（knowledge item `01M5JEBC…` の本文）。タブの帯を別に貼り付けると、上の帯の高さが変わるたびに下の帯の位置を JS で合わせ直すことになる。同じ箱に入れれば、重ならないことが CSS だけで決まる。
- **`#` の名前に `-` を使わせない（DJ-5）**: knowledge item `01M5PTAX…` の教訓をそのまま当てた。描く id はすべて `hp-` で始まり `-` を含むので、`-` を含まない名前から作るパネルの id は、それらと重なりようがない。カードの key と同じ形にすると、`hp-card-x` という名前のタブのパネルが、カード `x` の id と重なる。
- **件数を数える場所（DJ-9）**: `tabs.js` が `aria-pressed` を見て数えれば `page.js` を変えずに済み、タブの無いページの HTML を1文字も変えずにできる。しかし答えの状態を2か所で持つことになり、`page.js` の描き方に `tabs.js` が頼る。回答待ちの件数を持つのは `page.js`（#428 の決定2）なので、そちらに足した。その代わり、答える部品のあるページの埋め込みの JS の文字が変わるので、既存のページの確かめ（DJ-12）は「style と script を除いた HTML の一致」にした。

昇格の印: タブの定義をデータに1つだけ置き、本文はパネルだけにする判断（本文だけで宣言する形と、帯も本文に手で書く形を退けた理由）
昇格の印: #428 の決定2（ページの JS は答え・保存・件数だけ）をタブの切り替えまで広げる判断

### P2: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-29）

- `so-compare --codex-only`（`SO_TIMEOUT=600`）。`gpt-6.1-sol`（設定から読んだ値）・`codex-cli 0.164.0`・280秒・初回で返答。Cursor には切り替えていない。依頼文と出力は `tmp/558-one-pager-tabs/` にある（作業層）。
- 結論は「直してから確定するべき」。指摘11件と注意1件を、すべて採った（7 と 9 は一部）。採否の表は plan の「設計SO」節にある。

採る前に自分で確かめたこと:

- 指摘3（本文の読み取りがブラウザとずれる）は、`html.parser` に反例を当てた。`<p class="hp-tabpanel" id="a"><div>x</div></p>` は `p` の開始・`div` の開始と終わり・`p` の終わりの順に読まれ、`p` の中の `div` になる。ブラウザは `div` の前で `p` を閉じるので、ずれる。`<section …><div/>y</section>` の `<div/>` は空の要素（開始と終わりを1つ）として読まれ、ブラウザは開いたままにする。`<section id="a" class="x" class="y">` は属性が2つとも渡り、辞書にすると後ろの値が残る（ブラウザは前の値を使う）[verified]（P2 で走らせた Python の出力）。
- 指摘10（`check --answers` は `validate` を通らない）は、`build.py` の `check_collected` が `Validator` を直接作っていることを確かめた [verified]（`build.py:1570-1582`）。
- 指摘7（貼り付く箱の上端に safe-area の分がある）は、`.hp-bar` の `top: env(safe-area-inset-top, 0px)` を確かめた [verified]（`page.css` の `.hp-bar`）。

#### 初稿から大きく変わったところ

- **読み上げの作り**: 初稿は段ごとに別のタブの並び（`role="tablist"`）にしていた。選ぶものは全体で1つ、左右の矢印キーは段をまたぐのに、読み上げでは別の集まりに聞こえる、という指摘で、意味の上では1つのタブの並びにし、段の名前は各タブの説明で伝える形に変えた。初稿で段ごとに分けたのは、見た目の1段をそのまま1つの並びにしてよいと思い込んでいたためで、SO はこれを「隠れていた前提」と呼んだ。
- **リンクの入口**: 初稿は `hashchange` だけで隠れたパネルを開くつもりだった。`#` が変わらない操作（`replaceState` が投げたあとに同じリンクを押す）で何も起きない反例を受け、`document` の `click` を入口に足し、すべての入口を1つの関数に通す形にした。初稿で「タブを押せば `#` がタブの名前に置き換わるので、次にリンクを押せば必ず `#` が変わる」と考えていたのは、`replaceState` が成功する前提に頼っていた。
- **本文の id**: 初稿は `key` と本文の id の重なりだけを止めていた。描く id どうしが重ならないことと、本文の自由な id が描く id と重ならないことは別の保証で、後者には `hp-` の頭を本文に使わせない決まりで答えた。

follow-up（この単位では決めない）:

- タブの無いページの本文でも、`id="hp-store"` のような id は JS の操作する要素と取り違えられる。今の単位では、タブのあるページにだけ `hp-` の頭を止める。タブの無いページに当てるかは、`html-one-pager` の本文の検査を扱う単位で決める。行き先は PR の報告と、I3 の closure の follow-up の欄である。

### P3: commit・push・報告（2026-10-29）

- plan と episode を `97c5d74` で commit し、`feature/#558_one_pager_tabs` を push した。PR はまだ作っていない。
- 報告の宛先は brief の「報告の宛先」の統括（21代目）で、`oe-tree` に生きた root の `cockpit` として出ていて、このセッション（`#558 one-pager-tabs`）がその子であることを確かめてから送った。`projects/orchestration-engine/bin/oe-send` は終了コード 0 で、送った旨が出た（取り込まれたかは受領印の層で、ここでは確かめていない）。
- 送った1行には、plan のパスと、確定版に無い判断のうち owner に見せたほうがよいと見る3つ（N1・N3・N5）を書いた。ゲート3（統括が確定版と照らして代える）を待つ。
