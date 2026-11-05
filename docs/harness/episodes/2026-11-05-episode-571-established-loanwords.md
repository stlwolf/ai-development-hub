---
id: "01M6NHJQ0XTWT0H38MK45HGX78"
title: "#571 定着した外来語（ブランチ・バージョン・デプロイ）を和語に言い換える癖を、決まりとスキルの側で直す"
date: 2026-11-05
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/571"
    reason: "本 episode の作業対象"
  - type: derived_from
    ref: "docs/harness/plans/2026-11-05-plan-571-established-loanwords.md"
    reason: "この episode が記録する作業の計画"
tags: [rule, output-style, glossary, japanese, harness]
---

# #571 定着した外来語（ブランチ・バージョン・デプロイ）を和語に言い換える癖を、決まりとスキルの側で直す

## なぜこの作業が始まったか

owner は別のリポジトリの統括のセッションで「PHP の版なんて言わない。バージョンだ」と指摘した（2026-11-05・#571 の背景）。hub の統括も、この数日の返答で「枝の先頭」「枝で変えたファイル」と書いていた。owner の方針は、単語を並べて塞ぐのではなく、語を選ぶ基準を決まりに1つ書き、一覧は例にとどめること、そして既存の文に残っている言い換えは引っ張る元になるので直すことである。

## この単位の入力

- brief `.oe/brief-571-loanword-criterion.md`（統括のワークスペースの根の作業層）
- 確定版の認識合わせ: https://github.com/stlwolf/ai-development-hub/issues/571#issuecomment-6654658406 （owner は追加の2項目〔コードのコメントとテストの文・`runbook-authoring` の例の「版」〕も範囲に入れると答えた）
- 注入された knowledge item 3件: `01M5F0CNEKA9ED9AMQ3YWGGF8W`（書き直した決まりを、書き直したファイルとスキルのフォルダ全体にも当てる）・`01M021TFBFBFZ7Z6KW2DN1RYQQ`（一括で置き換えず、出現を1つずつ意味で分ける）・`01M579XZNAT7EXY4VPGRM9J8JW`（bash の文で変数の直後の全角を `${var}` で囲む）

## 作業の記録

### P1: worktree・確定版の照合・参照の読み（2026-11-05）

- `fix/#571_established_loanwords` の worktree を、最新の `origin/master`（`b42c541`）から `wt switch --create` で作った。
- 確定版を `issue-intake` の 1-2 の手順で照合した。最後の行は `confirmed`・見出し4で、URL は brief の「認識合わせ:」欄と文字列として一致した。確定版を前提にし、認識合わせはやり直さない。
- 参照を読んだ: `output-format-rule.md` の §8・§9、出力の型 `readable-conversation.md`、2つのスキルの `glossary.md`、`html-one-pager/SKILL.md` の用語の行、#428 の plan（用語集の2つ目の部分として和訳しない用語を置いた理由・328行目）、#467 の plan（同じ行を参照せずに写した理由・239行目）。

### P1: 確定版の数を当て直した結果（2026-11-05）

確定版の数のうち、canonical の Markdown の「枝」47回（git grep で 47。ファイルごとに document-format 22・doc-flow-guardrail 12・episode-retrospective 8・残る5ファイルに1ずつ）と、`so-compare/SKILL.md` の「CLI の版」4か所は一致した。食い違いは次の4つである。

- `scripts/so-compare.sh` の「版」は確定版の8回ではなく、16回（14行）あった。すべてコメントで、すべてソフトウェアのバージョンの意味である。
- `scripts/so-compare.sh` は、中身のハッシュを `projects/orchestration-engine/tests/test_so_compare_version.sh` の `EXPECTED_SHA` に固定している。コメントだけを直してもこのテストが落ちる（テストの冒頭の註で「仕様である」と書いてある）。直すなら `EXPECTED_SHA` の更新が同じ変更に要る。
- engine のテストの「枝」9回のうち4回は、git のブランチではなくコードの分岐（テストが通る経路）を指している（`test_handoff_retire.sh` の 496・498・518行と 745行の2つ目、`test_handoff_prepare.sh` の 299行）。
- 確定版の列挙の外にも、凍結していない場所に同じ言い換えがある。「枝」は `oe-handoff`（4）・`oe-confirm`（2）・`projects/orchestration-engine/bin/README.md`（2）。ソフトウェアのバージョンの意味の「版」は、engine の bin・lib・テストと `scripts/sync/` に数十回ある（`oe-selfcheck`・`oe-lane-explain`・`test_apply_claude_settings.sh` など）。canonical の Markdown にも、`so-compare/SKILL.md` の「CLI の版」以外に「版文字列」「実在する版」、`runbook-authoring/SKILL.md` の3か所、`canonical/hooks/README.md` の「現行版」がある。

昇格の印: 「確定版の列挙は統括の数えで、意味の基準で数え直すと範囲が広がる」ことは、範囲の判断として plan に出し、owner の答えを decision か plan に残す。

### P2: plan の初稿と、そこで下した判断の理由（2026-11-05）

- 母集団は、git の管理下のファイルから凍結した記録の置き場を除いたすべてにした。確定版の `docs/` と `projects/*/docs/` に、`ideas/`・`projects/_archived/`・`projects/orchestration-research/`・`projects/poc/` を足した（plan の N2）。最初の数えでは `git grep` の除外 `:!projects/*/docs` が効かず、凍結した文書まで数えていた。`:(glob,exclude)projects/*/docs/**` に替えて数え直した。
- 「版」は母集団に約410回あり、1件ずつ「直す（バージョン）」「残す（文書の改訂）」「残す（接尾）」に分けた。分類の全件は作業層の `tmp/571-loanwords/ban-classified.tsv` にある。行の単位で分けた表なので、1行に両方の意味がある行（`issue-intake` の 270行目など）は I1 で出現の単位に分け直す。
- コードの分岐の意味の「枝」は「分岐」にした。handoff のテストと `oe-handoff` は git のブランチも扱うので、コードの分岐まで「ブランチ」にすると同じファイルで1つの語が2つの意味になる（plan の DJ-4・N5）。
- 範囲（DJ-6）は、確定版の列挙の外まで直す案A を推奨にした。確定版はコードのコメントとテストを「種類」として範囲に入れていて、列挙は統括の数えだと読んだ。これは推測なので、owner に出す判断（N1）にした。
- §8 の例の語は、増やさずに差し替えた（N6）。逆の誤り（「確定版」まで「確定バージョン」にする）への備えとして、残す和語の例の1行を §8 に足した。ゲート1 の G5 から来た。

昇格の印: 「語を選ぶ基準は名前の側にだけ当て、性質を表す語は日本語にする」という §8 の2段の形は、rule の決まりとして decision に残すかもしれない。

### P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）

- `so-compare --codex-only`（`SO_TIMEOUT=600`）。初回で返った（`model_resolved=gpt-6.1-sol`・`timeout_status=success`・8,987 バイト）。依頼文と出力は作業層の `tmp/571-loanwords/so-design/` にある。結論は「直してから進めてよい」。
- 指摘11件と選択肢拡張1件をすべて採った（plan の「設計SO」節の表）。
- 重かったのは2件である。1つは、分類の全件の表が `issue-intake` の 270行目の「確定版」2回まで直す側に入れていたこと。行の単位で分類したので、1行に両方の意味がある行で取り違えた。P2 の初稿の節に「I1 で出現の単位に分け直す」と書いていたが、表そのものを正本のように数えていた。表を直した（直す 195・残す 217）。もう1つは、「枝」の残りの一覧を確定版の5回としていたが、§8 と出力の型に悪い例として「枝」を1回ずつ書くので7回になること。自分で書く決まりの文が、確かめの数を変えることを見落としていた。
- html-one-pager の「前の版の `purpose`」は、初稿では「番号が無いので文書の改訂」として残していた。SO の「受け付けるデータの形式の変更で、番号の有無では分けられない」を採り、直す側へ移した。境界の判断の根拠を「番号があるか」に置いたのが誤りで、「何が変わったか（文書の中身か、データの形式やプログラムか）」で分ける。
- 選択肢拡張の「同じ語の意味の対比を人の目で確かめる」は、機械の検査を作らずに逆の誤りと性質語の英語化を確かめられるので、受入に足した。

昇格の印: 「版」の境界は「番号があるか」ではなく「何が変わったか（文書の中身か、プログラムやデータの形式か）」で分ける、という分け方は、§8 の例か用語集の説明に入れるかを考える。
