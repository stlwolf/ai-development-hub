---
id: "01M5CD2SN3KK8V6W6PKYNDRA9V"
title: "#469 html-one-pager を実物の記録で直す（表の部品・本文の class・根拠の省略ほか）"
date: 2026-10-20
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/469"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/469#issuecomment-6288565815"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-20-plan-469-one-pager-real-use-fixes.md"
    reason: "この episode が記録する作業の計画"
  - type: reference
    ref: "docs/harness/decisions/2026-10-19-decision-428-human-page-format.md"
    reason: "スキルを作った単位の decision。決定1〜4（Python 3.9 以上の標準ライブラリ・スクリプトが静的に描く・保存の形・回収のあとは answers を正とする）をこの単位でも守る"
tags: [skill, artifact, html-one-pager, harness]
knowledge_observations:
  - "01KYMRE1NC7XX6N66RQ0MGGHF1"
  - "01M2DRCP3SNPTHWDV2FJ9RZ4N0"
---

# #469 html-one-pager を実物の記録で直す（表の部品・本文の class・根拠の省略ほか）

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## なぜこの作業が始まったか

2026-10-20、`html-one-pager`（#428・PR #468）をマージした直後に、別のリポジトリの統括が読み物のページを実物で作った。owner は2回「読みづらい」と指摘した（表の線が無い・番号と issue の ID が1つの欄で2行になる・番号がリンクでない）。原因は本文を素の HTML で書いたことで、スキルには本文の class の決まりも、表をデータで書く部品も無かった（#428 のコメント2件・気づき1〜9）。同じ日、hub の統括が判断のページを作ったところ、owner はさらに2点を指摘した（根拠が要らない場面でも定型文を強いられる・構造のある本文をカードの平らな要点に流し込むことになる。#469 のコメント・気づき10・11）。

## この単位の入力

- brief: 統括（cockpit 19代目）が 2026-10-20 に発行した `.oe/brief-469-one-pager-real-use-fixes.md`（作業層・消える）。plan-first で、最初の終端は P3（plan を報告して止まる）、委譲全体の終端は I3（PR を作って報告する）。マージ・worktree の掃除・issue の close はしない。baseline は master `3c00c11`。
- 認識合わせ: 確定版 https://github.com/stlwolf/ai-development-hub/issues/469#issuecomment-6288565815 。確定版の後ろに、owner が判断のページで指摘した2点（気づき10・11）がある。
- scope: `canonical/skills/html-one-pager/` の中だけ。「先に直すもの」6つ（気づき1・2／4／5／表の部品＝3・8・9／10／11）と、「次の版の候補」3つ（気づき6・7・8 の後半）の採否。#428 の decision（Python 3.9 以上の標準ライブラリ・静的に描く・保存の形 `{key, choice, note, at}`・フォルダの中に hub への参照を入れない）を守る。PR を1つにするか2つに分けるかは plan で提案し、ゲート3 で owner が決める。
- SO: 設計 weak・実装 weak（どちらも `so-compare` の Codex 1レーン。返らなければ Cursor のレーンに1回だけ切り替えてよく、切り替えたら理由をここに書く）+ Copilot 1ラウンド。
- 注入された negative knowledge: 2件（frontmatter の `knowledge_observations`）。closure で全件に観測を書き戻す。

## 作業の記録

### P1: worktree・確定版の照合・参照の読み・変更前の検査（2026-10-20）

- worktree `feat/#469_one_pager_real_use_fixes` を `wt switch --create` で作った。起点は master `3c00c11` で、`git fetch` のあとの `origin/master` と同じであることを確かめた。
- `issue-intake` の 1-2 の手順で、認識合わせのコメントを調べた。最後の行は `confirmed`・見出し4で、URL は brief の「認識合わせ:」欄と一致した。確定版を前提にし、自分では認識合わせを通していない。
- 確定版と気づき10・11 のコメントの順序は、brief の書き方と少し違う。brief は「確定のあと、owner が判断のページで指摘した2点を気づき10・11 として #469 のコメントに足してある」と書くが、気づき10・11 のコメントの投稿は 09:53Z で、確定版の 10:10Z より前である。確定版の「深掘り」の節は「提示のあと owner が判断のページで2点を指摘し、#469 の追加として記録した」と書いている。どちらにしても、brief の scope は (5)(6) として気づき10・11 を含めているので、対象は変わらない。
- 気づき4（`check` が `--body` を受け付けない）を、上流の断定を写さずに現物で確かめた（注入された negative knowledge `01KYMRE1…`）。master `3c00c11` の `build.py` の `check` は `--body` を受け付ける。`check examples/grasp.json` は `E-S1 sections: 部品が1つも無く、--body の本文も無い` で終了コード 1、`check examples/grasp.json --body examples/grasp-body.html` は終了コード 0 だった。直すのは SKILL.md のコマンドの節に `check --body` の形を載せることだけである。
- 気づき5 の原因を `page.js` で確かめた。`page.js` はカードが無いと先頭で `return` するので、動いたときに `db` を使うことは無い。ただし文字列として `claude.use("db")` を含み、`build.py` はどのページにも `page.js` の全体を入れる。公開のときの注意は、この静的な文字列から出ていると見られる（Artifact の道具が中身をどう見ているかは確かめていない・推測）。
- 変更前の検査: `python3 tests/test_build.py` は 127 件で、Python 3.13.5・3.9.23（`/opt/homebrew/bin/python3.9`）・3.9.6（`/usr/bin/python3`・macOS 付属）のどれでも失敗0件だった。
- 読んだもの: #469 の本文とコメント3件、#428 のコメント（確定版・質問フェーズのまとめ・着地・実物で使った記録2件・端から端まで通した記録）、#428 の decision、plan（DJ-11〜14・ゲート1・設計SO・受入・ステップの書き方）、episode（P1・P2 の書き方）、スキルの全ファイル（SKILL.md・build.py・page.css・page.js・glossary.md・template.html・examples/ の5つ・tests/test_build.py）。

### P2: plan の初稿と、そこで下した判断の理由（2026-10-20）

plan の初稿を書いた。判断の結論は plan の DJ-1〜DJ-8 にあり、ここには結論に至った理由のうち plan に書き切れないものを残す。

- **上流の「表の部品があれば2回の指摘はどちらも起きなかった」を、そのままの強さで写さなかった。** 1回目（表の線）は部品が線を必ず付けるので起きないが、2回目（番号と ID を1つの欄に混ぜる）は、部品があっても書く人が1つの `text` の欄に混ぜれば起きる。そこで `ref` の欄を「識別子以外は止める」形にし、逆向き（`text` の欄に混ぜる）は検証で止めず SKILL.md の決まりに置いた。`text` の欄で止めると「#212 を見る」のような普通の文まで止まるからである。plan の「上流の主張の確かめ」の表に、強さを落とした形で書いた（注入された negative knowledge `01KYMRE1…`）。
- **素の要素の見た目は `:where()` で詳細度を下げる形にした。** 二択（一覧か素の要素か）でなく両方にしたとき、いちばん怖いのは、素の要素の規則が書き手の class や部品の class に勝って、いまのページの見た目を変えることである。`:where(.hp-body) table` は要素1つ分の詳細度なので、どの class にも負ける。見本の本文（`.grasp-flow` の `ol`・`li`）の見た目が変わらないことは、I1 のブラウザの確かめで見る。
- **外部の課題管理の ID は、表だけでなくすべてのデータの文字列でリンクにする形にした。** brief の (4) は表の部品の中で書いているが、`#N` はすでにすべてのデータの文字列で変換されている。表だけで変換すると、同じ ID が表ではリンクになり、カードの要点ではならない。同じ決まり（いちばん近い送り元を使い、group に無ければページへ戻らない）にそろえた。範囲が brief の文より少し広がるので、plan のゲート3 の「知っておいてほしいこと」に書いた。
- **気づき11 を `blocks` にする理由は、SKILL.md の自分の決まりとぶつかることにある。** brief と確定版は最小の形（SKILL.md に「中身は `--body` に書く」と書くだけ）を示しているが、SKILL.md の「書くときの注意」は外から来た文を `--body` に写さないと決めている。認識合わせの中身は issue の本文から作る文なので、最小の形はこの決まりに反する使い方を勧めることになる。最小の形を対案として Q1 に置いた。

昇格の印: 本文（--body）の素の要素の見た目を :where() で詳細度を下げて当て、書き手と部品の class を常に勝たせる判断

- **「次の版の候補」は3つとも入れないことにした。** 3つとも、実物で起きた場面は今回の部品で覆えるか、手での回避が1行で済む（plan の DJ-8 の表）。3つ目（本文の `#N` の変換）は、本文の HTML を読んで書き換える処理になり、#428 の決定2 の「本文は信頼したコードとしてそのまま差し込む」の範囲を変える。入れないので、PR を2つに分ける理由も無くなった。
- **DJ-1 の2つの仮定を、試作のページで先に確かめた。** master の `build.py` で作った完全な文書に、案の CSS（`.hp-body` と `:where(.hp-body)` の規則）と本文の包みを手で足し、手元の HTTP サーバーから Playwright で開いた。試作は scratchpad に置き、リポジトリには何も足していない。結果は2つである。(1) 素の要素だけで書いた本文（6列の表・長い URL を含む）を幅 400px で開くと、ページは横に揺れず（`scrollWidth` 400・`clientWidth` 400）、表の中だけが横に送られた（表の `scrollWidth` 635・`clientWidth` 368）。素の `td` に 1px の線が付いた。(2) 見本の本文（`examples/grasp-body.html`）では、`.grasp-flow` の `padding-left` は `0px` のままで、書き手の class が `:where(.hp-body) ol` の規則に勝った。`hp-sec` の `section` の間隔も 12px のままだった。ブラウザのコンソールの誤りは favicon の 404 の1件だけだった。plan の DJ-1 の書き方は変えず、確かめた結果だけを plan に足した。
- **hub の側（CATALOG の行）と SKILL.md の description は変えない。** CATALOG の行は部品を列挙しているので表の部品が抜けるが、brief は範囲をスキルのフォルダの中に限っている。description は #428 で発火を測った言い方なので、変えると測り直しが要る。CATALOG に表を足すかは報告で統括に渡す。

### P2: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-20）

- `SO_TIMEOUT=480 so-compare -w <worktree> -f tmp/469-one-pager-real-use-fixes/so-design-prompt.md -o tmp/469-one-pager-real-use-fixes/so-design-codex --codex-only` を背景で回した。meta は `model_resolved=gpt-6.1-sol`（`model_resolved_source=config`・観測値ではない）、`cli_version=codex-cli 0.163.0`、`attempt=1`、`timeout_status=success`、`elapsed_seconds=194` だった。初回で返ったので Cursor には切り替えていない。
- 結論は「直してから進めてよい」で、指摘は7件（高3・中4）と、選択肢拡張の代替案2件だった。7件とも採り、2件の代替案は成立条件を付けて退けた。指摘ごとの採否は plan の「設計SO」節の表にある。
- **採る前に、指摘の前提を3つ自分で確かめた**（evidence-verification の消費者側の確かめ）。(1) 指摘2「`review.json` は答える部品を持たない」は、変更前の `Renderer.has_answer_part()` を見本の4つで呼び、`decide`・`bundle` が真、`review`・`grasp` が偽であることを確かめた。初稿の A9 は `review` も「1文字も違わない」としていて、自分の DJ-3 と食い違っていた。(2) 指摘6「`grep -E` の `\|` は効かない」は、`printf 'stlwolf\nlinear\n' | grep -nE 'ai-development-hub\|stlwolf\|linear'` が終了コード 1（何も拾わない）、`\` を外すと2行とも拾うことで確かめた。表の中に書いたので Markdown の都合で `\|` と書き、それを実行の形として読むと誤る、という形である（注入された negative knowledge `01M2DRCP…` の「記載形と実行形のずれ」そのもの）。直した3つの `grep` を変更前のフォルダに打ち、どれも終了コード 1 だった。(3) 指摘1 を受けて包みをやめる形にしたとき、その前提（部品が `.hp-main` の中に描く要素はすべて class を持つ）を見本の4つの出力で数えた。class を持たない要素は、指摘の一覧の表のセル（`th`・`td`）だけで、それは class を持つ `hp-table` の中にある。
- **DJ-1 の形を変えた。** 初稿は本文を `hp-body` で包み、`:where(.hp-body)` で詳細度を下げる形だった。P2 の試作では、見本の本文の `.grasp-flow` の余白が変わらないことを確かめていたが、それは `.grasp-flow` が余白を自分で決めていたからで、class の側が決めていないプロパティには素の規則が効く。試作は「同じプロパティを決めている場合」しか見ていなかった。包みは書き手の `.hp-main > section` のような CSS も効かなくする。そこで、`.hp-main` の中の class を持たない要素だけに当てる形に変えた。上の P2 の節の昇格の印は、この形で読み替える。

昇格の印: 本文の素の要素の見た目は、包みを足さず、class を持たない要素だけに当てて、class の付いた要素には1つも効かせない判断（詳細度を下げるだけでは、class が決めていないプロパティに効く）

- **A11 を作り直した。** 初稿は「変更の前の `build.py` で作った同じ表のページ」と比べる形だったが、変更の前の `build.py` は `type: table` も `trackers` も受け付けない。前後のどちらでも作れる `review.json` で比べ、表のページは別に出す形にした。公開できなかったときの扱いも決めた。
- **DJ-5 の範囲を狭めた。** 初稿の「すべてのデータの文字列」は、`build.py` の中でエスケープだけをしている文字列（ページのタイトル・ボタン・`tag`・`lane`）まで含んでいた。いま `#N` を変換している表示の文に限った。
