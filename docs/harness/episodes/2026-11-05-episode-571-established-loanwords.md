---
id: "01M6NHJQ0XTWT0H38MK45HGX78"
title: "#571 定着した外来語（ブランチ・バージョン・デプロイ）を和語に言い換える癖を、決まりとスキルの側で直す"
date: 2026-11-05
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/571"
    reason: "本 episode の作業対象"
  - type: derived_from
    ref: "docs/harness/plans/2026-11-05-plan-571-established-loanwords.md"
    reason: "この episode が記録する作業の計画"
  - type: reference
    ref: "docs/harness/decisions/2026-11-05-decision-571-term-choice-criterion.md"
    reason: "この単位から昇格した decision（決定1〜4）"
  - type: reference
    ref: "docs/harness/knowledge/items/01M6NTS9MJV4XGMCF1M1EXC8J4.md"
    reason: "この単位から収穫した negative knowledge（perl の1行の置き換えが日本語で黙って何もしない）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/pull/573"
    reason: "この単位の PR"
tags: [rule, output-style, glossary, japanese, harness]
promotion:
  - subject: "確定版の列挙は統括の数えで、意味の基準で数え直すと範囲が広がる"
    verdict: not-required
    ref: "本文: P1: 確定版の数を当て直した結果（2026-11-05）"
  - subject: "語を選ぶ基準は名前の側にだけ当て、性質を表す語は日本語にする"
    verdict: required
    ref: "本文: P2: plan の初稿と、そこで下した判断の理由（2026-11-05）"
  - subject: "「版」の境界は番号の有無ではなく「何が変わったか」で分ける"
    verdict: required
    ref: "本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）"
  - subject: "perl の1行の置き換えは use utf8 が無いと日本語で黙って何もしない"
    verdict: required
    ref: "本文: I1-3: 置き換えの道具の失敗と撤回（2026-11-05）"
  - subject: "so-compare.sh のコメントだけの変更は EXPECTED_SHA だけを更新し、SO_COMPARE_VERSION は上げない"
    verdict: not-required
    ref: "本文: I1-5: 確かめの結果（2026-11-05）"
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

### GATE 3: owner の承認（2026-11-05）

- owner は統括の判断ボードの Q59〜Q64 に、すべて推奨どおりに答えた（plan の「GATE 3」の結果の行）。承認した plan の版は `600f666`。
- Q63 の補足で owner は「途中で話した例ではなく、本質的な部分で、似た状態にならないことへの対応は入っているか」と聞いた。統括は、基準の文は DJ-1 と DJ-3 に入っていて、マージのあとに言い換えが再び出ないかを確かめる工程は plan に無いと答えた。答えは承認の条件ではない。この点は closure の follow-up の行き先に残す。

### I1: 実装のコミット（2026-11-05）

- I1-1 `8ea21a7`: §8・出力の型・2つの用語集・2つのスキルの用語の行（DJ-1〜DJ-3）。
- I1-2 `e88f38d`: canonical の Markdown の「枝」42回と「版」17回（DJ-4・DJ-5）。42回は置き換えのあとに前後の文脈を1件ずつ読み、すべて git のブランチの意味だと確かめた。
- I1-3 `aff6643`: `runbook-authoring` の見本・手順書・テストの「版」88回（DJ-5）。
- I1-4 `0849242`: canonical のコード・engine・`scripts/` の「枝」と「版」と `EXPECTED_SHA`（DJ-4〜DJ-7）。

### I1-3: 置き換えの道具の失敗と撤回（2026-11-05）

- 見本の「版」を `perl -CSD -pi -e 's/版/バージョン/g'` で置き換えようとしたが、1件も変わらなかった。`-CSD` で入出力は文字として読むが、スクリプトの中の `版` は `use utf8` が無いのでバイト列のままで、一致しない。コマンドは終了コード0で返り、ループの表示は置き換えの前に数えた回数だったので、変わったように見えた。`git grep` が新しい語を1件も返さなかったことで気づき、Python の置き換えに替えた。
- 以後は置き換えのたびに `git diff --stat` で変わった行の数を見て、数えた回数と合わせた。

### I1-5: 確かめの結果（2026-11-05）

- 「枝」の残り（母集団・`git grep -n '枝'`）は次の7行で、残すと決めたものだけである。
  - `canonical/output-styles/readable-conversation.md:24`（決まりの中の言い換えの例）
  - `canonical/rules/output-format-rule.md:21`（決まりの中の言い換えの例）
  - `canonical/skills/doc-flow-guardrail/SKILL.md:184`（条件の分かれ目の「枝は2つ」）
  - `canonical/skills/html-one-pager/SKILL.md:145`（書かない形の例）
  - `canonical/skills/html-one-pager/glossary.md:158`（表の書かない形）
  - `canonical/skills/question-driven-design/SKILL.md:42`（枝分かれ）
  - `canonical/skills/runbook-authoring/glossary.md:41`（表の書かない形）
- 「版」の残りは、I1 の直後には222回で、すべて残す種類に当たったと書いた。実装SO の指摘1で、前の実装やコードの状態を指す6回（engine の `bin/README.md` の 70・528・529行目、`oe-tree` の 458行目、`register-metrics` の2回）を取りこぼしていたと分かり、直した（I2 の節）。直したあとの残りの全件と種類は、この節の末尾の表にある。
- 凍結した置き場（`docs/`・`projects/*/docs/`・`ideas/`・`projects/_archived/`・`projects/orchestration-research/`・`projects/poc/`）は、この plan と episode のほかに1行も変わっていない（`git diff --stat 600f666~1..HEAD`）。新しい検査のファイルも足していない。
- 変数の直後の全角（`rg --pcre2`）: 直した bash のファイルで、新しい該当は0件。`oe-handoff` の 73行目に既存の1件があるが、引用付きの heredoc の中のヘルプの文で展開されない（`--help` の出力で `$OE_BOARD_FILE` が文字のまま出ることを確かめた）。
- `shellcheck`: 直したシェルスクリプト21本で、直す前と後の警告の中身が同じだった。
- テスト（bash 5.2.37 と bash 3.2.57。3.2 の回は `/bin/bash` を指す `bash` を PATH の先頭に置いた）: `test_handoff_prepare` 81・`test_handoff_retire` 206・`test_handoff_take` 125・`test_so_compare_version` 4・`test_apply_claude_settings` 269・`test_oe_lane_explain` 73・`test_prompt_receipt` 62・`test_sanitize` 31・`test_sync_output_styles` 18・`test_check_orphan_links` 87・`test_hook_judgment` 297 が、両方の bash で失敗0。`test_hook_firing` は bash 5 で 80、bash 3.2 で 76 が通り失敗0で、3.2 の回の SKIP 1件は「この bash に inherit_errexit が無い（4.4 未満）」である。Python は `html-one-pager` 485・`runbook-authoring` 95 で失敗0（`runbook-authoring` のテストは中で bash 3.2 と PATH の bash の両方を回す）。
- テストの期待値を変えたのは、`runbook-authoring` の見本の出力の文（「今の版:」→「今のバージョン:」など8か所）と `EXPECTED_SHA` である。見本のスクリプトの変更は表示の文の「版」だけで、処理は変えていない。`so-compare.sh` の差分はコメントの行だけである。
- `test_oe_confirm` は両方の bash で2件失敗した（古いロックを回収する項目）。変えたのはコメントの2行だけで、変更前の master（`b42c541`）でも同じ2件が失敗するので、この変更の結果ではない。範囲の外として報告に書く。
- テストが比べていない表示の文は、実際に走らせて読んだ。`oe-selfcheck --help` の1行目と見出しの行、`screen-marker` の detail、`oe-lane-explain --help` の `--summary` の行が、新しい語で出た。
- 書き直した決まりを、書き直したファイルと2つのスキルのフォルダ全体に当てた（knowledge item `01M5F0CNEKA9ED9AMQ3YWGGF8W`）。残ったのは、表の書かない形、シェルの「展開」（分野の語）、`html-one-pager/SKILL.md` の 393行目の「置き換えて打つ」（キーで入力する意味で、外来語の言い換えではない）だけだった。
- 同じ語の意味の対比（設計SO の選択肢拡張）: git の枝はブランチ（§8 の1つ目の項目）、条件の分岐は分岐のまま（§8 の残す和語の例）、PHP の版はバージョン（1つ目の項目）、文書の確定版は確定版のまま（残す和語の例）、behavioral には振る舞いとして（性質を表す語の項目）。書き直した §8 の文だけで、3組とも同じ基準で説明できる。出力の型でも、1つ目の項目の「別のものを指す和語はそのまま書く」と2つ目の項目で同じ3組を説明できる。

### I2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-11-05）

- `so-compare --codex-only`（`SO_TIMEOUT=600`）。初回で返った（`model_resolved=gpt-6.1-sol`・`timeout_status=success`・4,940 バイト）。依頼文と出力は作業層の `tmp/571-loanwords/so-impl/` にある。結論は「直してから PR にしてよい」で、高の指摘は無かった。
- 指摘1（中）: 前の実装やコードの状態を指す「版」が残っていた。採った。DJ-5 の「残す（文書の改訂）」に「拍動なしの版」「切っていた版」を入れていたのは、何が変わったか（プログラム）で分けるという設計SO の指摘3の考えを、自分の分類に当て直していなかったためである。SO の選択肢拡張に従い、「バージョン」ではなく指すものを直接書いた（「変更前のコード」「拍動を足す前の実装」「200 字で切っていた実装」）。同じ種類を `register-metrics` で2回見つけて一緒に直した。`select-firing-prompts.py` の 146行目「切り詰めた版を書く」と `verify-style-injection.py` の「古い版」は、文の中身の改訂を指すので残した。
- 指摘2（中）: 残った「版」を1件ずつ分類した一覧が episode に無かった。採った。下の表を足した。
- 指摘3（低）: `runbook-authoring/glossary.md` の冒頭が、使わない語の表の語まで使うように読めた。採った。「「使う語と、その1つの意味」の表の語を使い、「使わない語」の表の語は代わりの語に替える。」に直した。
- 直したあとに、`test_oe_tree.sh`（bash 5・3.2 とも 88 で失敗0）・`runbook-authoring` のテスト（95・OK）・`oe-tree` の `shellcheck`（前後とも警告0）・2つの Python の構文の確かめを回した。

### 直したあとに残った「版」の全件（2026-11-05）

種類は「改訂」（文書・ページ・記録・文の中身の改訂）、「接尾・定着」（Web 版・確定版・初版・最新版のような接尾と定着した語）、「例」（§8 と出力の型の中の言い換えの例）である。行の番号は直したあとのファイルのもの。

合計 216 回（改訂 106・接尾・定着 105・例 5）

| ファイル | 種類と行（同じ行に複数あれば重ねて書く） |
|---|---|
| `canonical/CATALOG.md` | 改訂: 25／接尾・定着: 26,29,39 |
| `canonical/claude/statusline/statusline-oe-heartbeat.sh` | 接尾・定着: 27 |
| `canonical/commands/review/pr-review-checklist.md` | 接尾・定着: 114 |
| `canonical/hooks/scripts/oe-prompt-receipt.sh` | 接尾・定着: 142 |
| `canonical/orchestration-spec/document-format.md` | 改訂: 211／接尾・定着: 614,636,742 |
| `canonical/output-styles/readable-conversation.md` | 例: 24,24 |
| `canonical/rules/output-format-rule.md` | 例: 21,26,26 |
| `canonical/skills/branch-naming/SKILL.md` | 接尾・定着: 17,19 |
| `canonical/skills/code-path-exhaustion/SKILL.md` | 接尾・定着: 75 |
| `canonical/skills/doc-flow-guardrail/SKILL.md` | 接尾・定着: 94,124,195／改訂: 207,207,208,209,209,209,209,209,209,209,209,210,210 |
| `canonical/skills/episode-retrospective/SKILL.md` | 接尾・定着: 82 |
| `canonical/skills/html-one-pager/SKILL.md` | 改訂: 3,40,87,87,87,338,339,447 |
| `canonical/skills/html-one-pager/build.py` | 改訂: 1901,2802 |
| `canonical/skills/html-one-pager/glossary.md` | 改訂: 42,58,93,95／接尾・定着: 166 |
| `canonical/skills/html-one-pager/page.css` | 改訂: 1 |
| `canonical/skills/html-one-pager/tests/test_build.py` | 改訂: 1600,1608,1644,2214 |
| `canonical/skills/humanize-ja/SKILL.md` | 接尾・定着: 93 |
| `canonical/skills/humanize-ja/paste-prompt.md` | 接尾・定着: 1,3 |
| `canonical/skills/implementer-contract/SKILL.md` | 改訂: 164,170,170 |
| `canonical/skills/issue-intake/SKILL.md` | 接尾・定着: 3,16,17,26,26,26,68,75,77,84,85,90,258,260,265,267,268,270,270,274,294,294,302,303,303,303,303,305,308,309,325,343,344／改訂: 75,88,264,266,268,268,268,294,308 |
| `canonical/skills/judgment-board-flow/SKILL.md` | 接尾・定着: 32,44,56,74,275,275,275,275,275,275,275,294,296／改訂: 44,121,223,266,274,275,289,289,290,355 |
| `canonical/skills/judgment-board-flow/ledger.py` | 改訂: 473 |
| `canonical/skills/kickoff-to-plan/SKILL.md` | 接尾・定着: 223,230 |
| `canonical/skills/predecision-exploration/SKILL.md` | 接尾・定着: 17,57,80 |
| `canonical/skills/question-driven-design/SKILL.md` | 改訂: 12,62／接尾・定着: 62,62 |
| `canonical/skills/runbook-authoring/glossary.md` | 接尾・定着: 49 |
| `canonical/skills/unmet-gate-check/SKILL.md` | 改訂: 43,43,43,44,45,47,47,146,152,152,153,153,153,153,153,157,157,157,159,159,159,159,159,159,159,166,166,166,187,188,194,194,194,194,195,197,197,197,197,197 |
| `canonical/skills/worktrunk-worktrees/SKILL.md` | 接尾・定着: 35 |
| `projects/claude-safe/README.md` | 接尾・定着: 61 |
| `projects/orchestration-engine/README.md` | 接尾・定着: 120 |
| `projects/orchestration-engine/bin/README.md` | 接尾・定着: 471,553 |
| `projects/orchestration-engine/bin/oe-confirm` | 接尾・定着: 17 |
| `projects/orchestration-engine/bin/oe-selfcheck` | 接尾・定着: 107,174,234,260 |
| `projects/orchestration-engine/bin/oe-threads` | 接尾・定着: 40 |
| `projects/orchestration-engine/bin/oe-tree` | 接尾・定着: 14 |
| `projects/orchestration-engine/bin/oe-undelivered` | 接尾・定着: 339,400 |
| `projects/orchestration-engine/bin/oe-vitals` | 接尾・定着: 21 |
| `projects/orchestration-engine/lib/attach.sh` | 接尾・定着: 8 |
| `projects/orchestration-engine/lib/event-bus.sh` | 接尾・定着: 104 |
| `projects/orchestration-engine/scripts/knowledge-list.sh` | 接尾・定着: 25 |
| `projects/orchestration-engine/scripts/measure-delivery-arrival.py` | 接尾・定着: 220 |
| `projects/orchestration-engine/scripts/register-metrics/select-firing-prompts.py` | 改訂: 146 |
| `projects/orchestration-engine/scripts/register-metrics/verify-style-injection.py` | 改訂: 5,39 |
| `projects/orchestration-engine/tests/e2e_real_agent/self_verify_attach.sh` | 接尾・定着: 46 |
| `projects/orchestration-engine/tests/test_apply_claude_settings.sh` | 改訂: 843,855 |
| `projects/orchestration-engine/tests/test_oe_threads.sh` | 接尾・定着: 168 |
| `projects/orchestration-engine/tests/test_oe_undelivered.sh` | 接尾・定着: 153 |
| `projects/orchestration-engine/tests/test_prompt_receipt.sh` | 接尾・定着: 132,140,189,289,355 |
| `projects/orchestration-engine/tests/test_verify.sh` | 接尾・定着: 428 |
| `projects/ruler-agent-verification/README.md` | 接尾・定着: 54,54 |
| `projects/wezterm-ai-mode/CONVENTIONS.md` | 接尾・定着: 157 |
| `scripts/sync/apply-claude-settings.sh` | 改訂: 425,430 |

## closure（2026-11-05）

tier は heavy である（意図して起動した設計SO と実装SO・置き換えの道具の失敗と撤回・棄却した選択肢がある）。

- 次の消費者: §8・出力の型・2つの用語集を次に直す人と、語の選び方で迷うモデル（decision を読む）。日本語を perl で置き換える作業（knowledge item）。マージのあとの sync と memory の整理をする統括（ゲート6）。
- 達成度: 達成。受入の表の行はすべて満たした（plan の受入の表）。
- 注入された knowledge item（期待集合）: `01M5F0CNEKA9ED9AMQ3YWGGF8W`・`01M021TFBFBFZ7Z6KW2DN1RYQQ`・`01M579XZNAT7EXY4VPGRM9J8JW`。3件とも `followed` の観測を足した。

### 事実・失敗

- 置き換えの道具が黙って何もしなかった。`本文: I1-3: 置き換えの道具の失敗と撤回（2026-11-05）`
- 分類の表を行の単位で作り、1行に2つの意味がある行で「確定版」を直す側に入れていた。設計SO が拾った。`本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）`
- 自分が決まりの文に足す悪い例の「枝」を、残りの数に入れていなかった。`本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）`
- 前の実装を指す「版」6回を残す側に入れていた。設計SO の指摘（何が変わったかで分ける）を、自分の分類に当て直していなかった。実装SO が拾った。`本文: I2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-11-05）`
- 確かめのコマンドとして brief と plan に写した `grep -nP` は macOS の grep で動かない。knowledge item `01M579XZNAT7EXY4VPGRM9J8JW` の前の観測（#467）が同じことを書いていたのに、本文の確かめのコマンドをそのまま写していた。設計SO が拾った。`本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）`
- `test_oe_confirm.sh` の2件の失敗は、変更前の master でも出る。`本文: I1-5: 確かめの結果（2026-11-05）`
- 数えの検査そのものに不備があった。`git grep` の除外の指定が効かず、凍結した文書まで数えていた。`本文: P2: plan の初稿と、そこで下した判断の理由（2026-11-05）`
- 確かめ方（DJ-8）の初稿に3つの穴があり、設計SO が拾った。テストを bash 3.2 で起動しても子のスクリプトは bash 5 で動くこと、SKIP で通るテストがあること、テストが比べていない表示の文（ヘルプ・detail）があることである。`本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）`
- 設計判断の文の初稿にも、設計SO が拾った不足が3つあった。例の言い換えが同じものを指すときの話だと限定していなかったこと、runbook の用語集の冒頭が表を例に下げることと合っていなかったこと、表示の文の変更の一覧が足りなかったこと（ヘルプ）である。`本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）`
- 実装SO が拾った不足が2つあった。残った「版」を1件ずつ分類した一覧が episode に無かったこと、runbook の用語集の冒頭の直した文が、使わない語の表の語まで使うように読めたことである。`本文: I2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-11-05）`
- 数え違いの訂正が2つあった。engine のテストのコードの分岐の意味の「枝」は4回ではなく5回（設計SO）、決まりの中の例の「版」は2回ではなく5回（plan の H3）である。`本文: I1-5: 確かめの結果（2026-11-05）`
- closure の外部チェック（Step 4）が、この節の初稿の採録漏れ（上の4項目）と、follow-up の行き先の不足と、plan のリスク節の撤回済みの判断の書き戻し漏れを拾った。`本文: closure の外部チェック（Step 4）の結果と採否（2026-11-05）`

### 決定と根拠

- 範囲（案A）・凍結した置き場・出力の型の1文・分岐と検査・例の差し替えは、owner が Q59〜Q64 で決めた。`本文: GATE 3: owner の承認（2026-11-05）`
- 長く効く判断（基準1つ・名前の側にだけ当てる・一覧は例・境界は何が変わったか）は decision に昇格した（`docs/harness/decisions/2026-11-05-decision-571-term-choice-criterion.md`）。`本文: P2: plan の初稿と、そこで下した判断の理由（2026-11-05）`

### 昇格の判定

- 「確定版の列挙は統括の数えで、意味の基準で数え直すと範囲が広がる」: `not-required`。この単位の範囲の答えは plan の GATE 3 にある。一般の教訓（issue 本文の数を当て直す）は、`issue-intake` の固定の問いの4つ目がすでに持っている。`本文: P1: 確定版の数を当て直した結果（2026-11-05）`
- 「語を選ぶ基準は名前の側にだけ当て、性質を表す語は日本語にする」: `required`（decision の決定1〜3・この PR に入れた）。棄却した案（G1・G2・G4・G5）があり、覆すには同じ議論が要り、前提（モデルが一覧を決まりとして読む）が将来偽になりうる。`本文: P2: plan の初稿と、そこで下した判断の理由（2026-11-05）`
- 「「版」の境界は番号の有無ではなく「何が変わったか」で分ける」: `required`（decision の決定4・この PR に入れた）。番号の有無で分ける案が2回誤った。`本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）`
- 「perl の1行の置き換えは use utf8 が無いと日本語で黙って何もしない」: `required`（knowledge item `01M6NTS9MJV4XGMCF1M1EXC8J4` に収穫・この PR に入れた）。非自明（終了コードが 0）・再発しうる（日本語の置き換えは繰り返す）・行動を変える（道具と確かめ方が変わる）。既存の item に同旨は無かった。`本文: I1-3: 置き換えの道具の失敗と撤回（2026-11-05）`
- 「so-compare.sh のコメントだけの変更は EXPECTED_SHA だけを更新し、SO_COMPARE_VERSION は上げない」: `not-required`。`test_so_compare_version.sh` の冒頭の註がすでに決まりとして書いている。`本文: I1-5: 確かめの結果（2026-11-05）`

### わかったこと

- 「枝」「版」のように同じ字が2つの意味を持つ語は、行の単位では分けられない。出現の単位で、何を指すかで分ける。`本文: I2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-11-05）`
- 決まりの文そのものが、確かめの数を変える（悪い例として語を書くと、残りに数が足される）。`本文: P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-05）`

### 残課題（follow-up routing）

- マージのあとに、統括や子の返答で言い換えが再び出ないかを確かめる工程が無い（owner が Q63 の補足で聞いた点）。行き先: PR #573 の本文の「範囲の外の気づき」の節（https://github.com/stlwolf/ai-development-hub/pull/573 ）。統括が起票するかを決める。
- `test_oe_confirm.sh` の古いロックの回収の2項目が master でも失敗する。行き先: PR #573 の本文の「範囲の外の気づき」の節。統括が起票するかを決める。
- knowledge item `01M579XZNAT7EXY4VPGRM9J8JW` の本文の確かめのコマンド（`grep -nP`）が macOS で動かない。item の本文や status の変更は段6 の別 PR の仕事なので、この単位では直さない。行き先: PR #573 の本文の「範囲の外の気づき」の節。統括が段6 で扱うかを決める。
- 2つの用語集は同じ基準の文を持つ。片方を直したらもう片方を見る（#467 と同じ扱い・スキルの中には書かない）。行き先: この episode と decision の決定3 に残した。追わない。
- マージのあとの `./scripts/sync.sh` と、memory の「定着した用語を独自に和訳しない」を由来だけに縮めること。行き先: ゲート6 の統括の仕事（確定版の「暗黙の工程」）。
- 認識合わせの抜け: 確定版の列挙の外に同じ言い換えがあったことは、issue 本文の数の食い違いで、`issue-intake` の固定の問いの4つ目が拾う種類である。確定版は「本文の数と状態」で canonical の数は当て直したが、コードの数は当て直していなかった。行き先: `issue-intake` の行き先1（固定の問い）にはすでに入っているので、足さない。

### 形式メモ

- 出力型の骨格で拾えたもの: 失敗が5つと、昇格が3つ（decision 2件の決定・knowledge 1件）。拾えなかったもの: 特になし。KPT と YWT の皮は使っていない。摩擦: 分類の全件の表が大きく、episode に載せる量が増えた。

## closure の外部チェック（Step 4）の結果と採否（2026-11-05）

- `so-compare --codex-only`（`SO_TIMEOUT=600`）。初回で返った。出力は作業層の `tmp/571-loanwords/so-closure/` にある。結論は「closure は未充足」で、指摘は中3件と低2件だった。すべて採った。
- 指摘1〜3（事実・失敗の採録漏れ・数え違いの訂正）: 「事実・失敗」節に5項目を足した。
- 指摘4（follow-up の行き先が作業層の報告で、追えない）: 3件の行き先を PR #573 の本文の「範囲の外の気づき」の節にし、PR の本文に3件を書いた。
- 指摘5（plan のリスク節に、撤回した「前の版を残す」判断が残っていた）: plan のリスク節を、直す側へ移したことと DJ-5 への参照に書き直した。
