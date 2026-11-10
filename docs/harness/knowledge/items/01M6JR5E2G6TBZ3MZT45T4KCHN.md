---
id: "01M6JR5E2G6TBZ3MZT45T4KCHN"
type: knowledge
status: active
date: 2026-11-04
trigger: "ゲート3 の承認で owner の答えが plan の設計判断を変え、その答えを plan に写してから実装に入るとき"
prediction: "答えで変わる「設計判断の文」だけを直し、その判断を写した先（description・SKILL.md の「いつ使うか」・受入の条件・CATALOG の行）を突き合わせないと、旧条件が実装に残る。受入は旧条件のまま合格し、ずれは実装SO か人のレビューまで見つからない"
exclusions:
  - "答えが設計判断の文に閉じていて、ほかの文（description・受入・CATALOG）に写されていないとき"
  - "答えを写す前に、plan の全文を答えの語で grep して当たりを全部直したとき（そのときはこの item の行動をすでに取っている）"
source:
  ref: "docs/harness/episodes/2026-11-04-episode-565-humanize-ja-skill.md"
landing: nl
observations:
  - date: 2026-11-09
    ref: "#623"
    state: followed
    note: "ほかのリポジトリの委譲 A（ローカルの開発環境の言語のバージョンを上げる作業）。GATE 3 の答えと、そのあとの owner の答えを plan に写す前に、答えで変わる語で plan を grep して全体を直した。完了前の照合（unmet-gate-check）では、plan を直した commit が実装のブランチを作るより前にあることは確かめられたが、grep を打ったこと自体は確かめられなかった。state は子の申告のまま"
  - date: 2026-11-09
    ref: "#623"
    state: followed
    note: "ほかのリポジトリの委譲 B（依存の脆弱性を直す作業）。GATE 3 の答えを plan に写す前に、答えで変わる語で plan の全文を grep し、設計判断の節の外（step と条件の言い回し）も直した。その統括の判断ボードで owner が hub の store への書き戻しを認め、hub の統括が代わりに書いた"
---

**ゲート3 の答えを plan に写すときは、答えで変わる判断の語（発火の条件・対象・置き場など）で plan の全文を grep し、設計判断の節だけでなく description・受入の条件・CATALOG の行・SKILL.md の「いつ使うか」まで当たりを全部直してから実装に入る。**

#565 の humanize-ja で、owner の答え（試用のあいだは名前で呼んだときだけ使う）を plan の DJ-1 に写したとき、発火の条件の行に「推敲をはっきり頼んだ依頼」も含む旧条件が残った。description・CATALOG の行・受入 A1 も旧条件のままで、A1 は旧条件で合格した。ずれは実装SO が拾い、description・CATALOG・A1 を直して A1 を回し直した。

## なぜ非自明か

**答えを写した本人は「写した」と思っている。** DJ-1 の文には答えの要約を足したので、読み返しても直したように見える。旧条件は同じ段落の別の文と、別の節（受入・CATALOG）に散っていて、答えの語で探さないと見つからない。受入の合格は旧条件との一致を示すだけで、答えとの一致は示さない。

## 行動をどう変えるか

**写す前に grep する。** 答えが変える判断の語を決め、plan と実装のファイルを横断して当たりを列挙し、1つずつ直す。受入の条件が旧条件で書かれていたら、条件を書き直してから回す。回し直した結果は、旧条件の合格とは別の行として記録する。
