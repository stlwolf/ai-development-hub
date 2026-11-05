---
id: "01M6NHJQ0XABCW7SY2QZ0XZYK7"
title: "#571 定着した外来語（ブランチ・バージョン・デプロイ）を和語に言い換える癖を、決まりとスキルの側で直す"
date: 2026-11-05
type: plan
status: stable   # 実装完了（2026-11-05・PR #573）。受入の表をすべて満たした。ゲート3 の承認は 600f666 の版で、承認のあとの補正は末尾の「ゲート3 のあとの変更」節（H1〜H3）
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/571"
    reason: "本 plan の issue。確定版の認識合わせ（issuecomment-6654658406）が範囲の正本"
  - type: reference
    ref: "docs/harness/episodes/2026-11-05-episode-571-established-loanwords.md"
    reason: "この plan の実行記録"
  - type: reference
    ref: "docs/harness/plans/2026-10-19-plan-428-human-page-format.md"
    reason: "html-one-pager の用語集に「和訳しない用語」を置いた理由（328行目・まとめの決定5）"
  - type: reference
    ref: "docs/harness/plans/2026-10-21-plan-467-runbook-skill.md"
    reason: "runbook-authoring に同じ表を参照せずに写した理由（239行目・スキルどうしを参照しない）"
tags: [rule, output-style, glossary, japanese, harness]
so:
  design: weak
  impl: weak
  reason: "配布物の決まりの文で可逆だが、常に読み込まれる rule と出力の型に効く。brief の指定で設計SO・実装SO とも so-compare の Codex 1レーン（返らなければ Cursor に1回だけ切り替える）、実装のあとに Copilot 1ラウンド"
---

# #571 定着した外来語（ブランチ・バージョン・デプロイ）を和語に言い換える癖を、決まりとスキルの側で直す

## 背景

owner は別のリポジトリの統括のセッションで「PHP の版なんて言わない。バージョンだ」と指摘した（2026-11-05）。hub の統括も「枝の先頭」と書いていた。いまの `output-format-rule.md` の §8 は「英語か日本語か」の軸で書かれていて、「日本語が入る位置に英語を落とさない」を読んだモデルが、カタカナの外来語まで英語の側に数えて和語に置き換えている、というのが統括の見立てである（推測: どちらを強く読んだかは測っていない）。owner の方針は、単語を並べて塞がず、語を選ぶ基準を1つ決まりに書き、一覧は例にとどめること、そして既存の文に残っている言い換えは引っ張る元になるので直すことである。

## この plan の範囲

- やること: 確定版の「この issue でやること」と「issue に書いていないが要ること」のすべて。§8 と出力の型の語の決まりを基準1つに書き直す。2つのスキルの「和訳しない用語」の表を例に下げ、基準の1文を各スキルに書く。凍結していない文に残る、git のブランチの意味の「枝」とソフトウェアのバージョンの意味の「版」を直す。
- 守ること: 一括で置き換えない。出現を1つずつ意味で分ける（knowledge item `01M021TFBFBFZ7Z6KW2DN1RYQQ`）。スキルの中に §8 やほかのスキルへの参照を入れない（#467 の決まり）。表の行を増やさない。
- 入れないもの: `docs/` と `projects/*/docs/` の既存の文書（凍結した記録）。`ideas/`・`projects/_archived/`・`projects/orchestration-research/`・`projects/poc/` も記録として書き換えない（確定版に無い判断 N2）。単語の一覧で止める機械の検査。「配置」の直し（置き場の意味でデプロイの言い換えではない・確定版）。マージのあとの sync と memory の整理（確定版の「暗黙の工程」。ゲート6 の統括の仕事）。

## 確定版の数を当て直した結果

母集団は、git の管理下のファイルから、上の「入れないもの」の置き場を除いたすべてである。数は `git grep -o` で取った（2026-11-05・`b42c541`）。分類の全件は作業層の `tmp/571-loanwords/ban-classified.tsv` にあり、直したあとの残りの一覧は episode に載せる。

| 確定版の数 | 当て直した結果 |
|---|---|
| canonical の Markdown の「枝」47回・うち直すもの42回 | 一致した（47回。残す5回も確定版のとおり） |
| `so-compare/SKILL.md` の「CLI の版」4か所 | 一致した。ほかに同じ意味の「版文字列」「実在する版」が2回ある（N1） |
| `handoff-state.sh` の「枝」3 | 一致した（3回ともブランチの意味） |
| engine のテストの「枝」9 | 一致した。ただし5回はコードの分岐を指す（DJ-4） |
| `scripts/so-compare.sh` の「版」8 | 16回（14行）あった。すべてバージョンの意味のコメントである。直すとハッシュを固定したテストが落ちる（DJ-7） |
| 列挙の外 | 「枝」は `oe-handoff` 4・`oe-confirm` 2・engine の `bin/README.md` 3・hook のスクリプト 2。バージョンの意味の「版」は canonical の Markdown に7回、engine と `scripts/sync/` に約70回ある（N1） |

## 設計判断

### DJ-1 §8 の新しい英文

§8 の見出しの文と、最初の2つの下位の項目（Test・Naming/Describing）を次の文に替える。残りの項目（English+する、Scope、Why documents too）は文を変えない。

```text
8. Japanese wording: write plain Japanese, and name each thing the way people in its field usually name it.
   - Names follow the field's usage. Write the name of a work object (a tool, an operation, an artifact, a concept) in the form practitioners use. Katakana loanwords are Japanese words: if the field says ブランチ / バージョン / デプロイ, write that — do not coin a native-word substitute (枝 for a git branch, 版 for a software version, 打つ for a deploy). A coined name makes the reader translate it back and cannot be searched for.
   - When unsure: search for the word and see whether documents from that field come up, or ask whether a colleague would say it that way out loud.
   - Names the field writes in Latin letters stay as written: `git`, `PR`, `hook`, `engine`, `malform`, `oe-*`.
   - Words that describe quality / degree / manner (adjectives, adverbs, connectives) go in Japanese; do not drop raw English into those slots: genuine→本当の, pivotal→肝心の, contained→収まっている, behavioral に→振る舞いとして. This, not technical vocabulary, is the main readability problem.
   - The words above are examples of the criterion, not a list to extend. Decide a word that is missing from them by the criterion.
   - A native word stays when it is the field's usual word or carries a different meaning: 確定版 / 前の版 (a revision of a document), 分岐 (a path in code), 配置 (placement).
```

- 基準の文は1つ（「その分野の人がふだん何と呼ぶか」）にし、迷ったときの決め方を2つ（検索・口頭）添える。issue の案のとおりである。
- 「名前か、性質を表す語か」の区別は残す。名前の側に基準を当て、性質を表す語の側は今までどおり日本語にする。
- 例の語は、今回の指摘の3つ（ブランチ・バージョン・デプロイ）と、それぞれの言い換え（枝・版・打つ）にする。いまの例のコンフリクト・レビュー・コミットは外す。例を増やさず差し替えるのは、一覧を伸ばさない方針に合わせるためである。
- 残す和語の例（確定版・分岐・配置）を1行置く。基準を「カタカナにせよ」と読み違えて、文書の改訂の「確定版」まで「確定バージョン」にする逆の言い換えを防ぐためである。

### DJ-2 出力の型の日本語の文

`readable-conversation.md` の「書き方」の1つ目の項目（いまの24行目）を、次の2つの項目に替える。§9 の末尾の決まり（§8 を直したら出力の型も直す）に従う。

```text
- 一般的な語で書く。作業対象の名前（道具・操作・成果物・概念）は、その分野の人がふだん呼んでいる形で書く。カタカナの外来語も日本語であり、ブランチ・バージョン・デプロイを、枝・版・打つのような独自の和語に言い換えない。迷ったら、その語で検索してその分野の文書が出てくるか、同僚が口頭でそう言うかで決める。git・PR・コマンド名のように英字で書く名前は、英字のまま書く。
- 性質・程度・様子を表す語は日本語にする。日本語が入る位置に英語を落とさない。
```

- 例の言い換え（枝・版・打つ）は、ブランチ・バージョン・デプロイと同じものを指すときの話である。1つ目の項目の終わりに「別のものを指す和語（文書の改訂の確定版・コードの分岐など）は、そのまま書く。」を足す（設計SO の指摘1）。

- いまの「同じことを言える普通の言葉があるなら、そちらを使う」は外す。「普通の言葉」を和語と読むと、今回の言い換えを引っ張る元になるからである。「一般的な語で書く」は残し、何が一般的かを基準の文で決める。
- §8 の「残す和語の例」の行は出力の型に入れない。出力の型は会話の書き方の要点だけを持つ形なので、例外の行まで写すと長くなる。ここだけは §8 と同じ文にならない（N3）。

### DJ-3 2つの用語集の位置づけと、各スキルに書く基準の1文

両方の `glossary.md` の「和訳しない用語」の節を、次の形にする。表の行は変えない（増やさない・減らさない）。

- 節の最初の段落を次の文に替える（html-one-pager は「人が読むページでは、」を頭に残す）。

  ```text
  用語は、その分野の人がふだん呼んでいる形で書く。カタカナの外来語も日本語であり、和語に言い換えて独自の呼び名を作らない。言い換えると、読む人が元の用語を思い浮かべ直す手間が増え、検索もできなくなる。迷ったら、その語で検索してその分野の文書が出てくるか、同僚が口頭でそう言うかで決める。次の表は、この基準を当てた例である。「書かない形」は、左の用語と同じものを指すときに書かない形で、別のものを指す普通の日本語（コードの「分岐」など）まで避けるものではない。
  ```

- 表のあとの「表に無い用語も、同じ考え方で扱う。そのリポジトリやチームがすでに使っている呼び方があれば、それに合わせる。」は残し、「用語を増やすときは、この表に行を足す。」を「表に無い語も、行を足さずにこの基準で決める。」に替える。
- `html-one-pager/glossary.md` の冒頭の説明（11行目）を「「和訳しない用語」は、語を選ぶ基準と、それを当てた例である。人とモデルが読むためのもので、`build.py` は読まない。」に替える。
- `html-one-pager/SKILL.md` の用語の行（145行目）の「用語は `glossary.md` の「和訳しない用語」に合わせる（ブランチを「枝」と書かない、など）。」を「用語は、その分野の人がふだん呼んでいる形で書く（基準と例は `glossary.md` の「和訳しない用語」。ブランチを「枝」と書かない、など）。」に替える。
- `runbook-authoring/glossary.md` の冒頭（3行目）の「この表の言葉を使う」は、語を1つの意味に固定する表と、和訳しない用語の基準の例とで役目が違う。冒頭の文を「手順書を書く人もモデルも、「使う語と、その1つの意味」と「使わない語」の表の言葉を使う。「和訳しない用語」は、語を選ぶ基準とその例である。」に替える（設計SO の指摘2）。
- `runbook-authoring/SKILL.md` の「用語」の節（207行目）の「和訳しない用語の表」は、「和訳しない用語の基準と例」に替える。
- 基準の1文は各スキルの中に書き、§8 もほかのスキルも参照しない（#467 の決まり・確定版）。2つの用語集は同じ文を持つことになる。片方を直したらもう片方を見る、は hub の側の episode に残す（#467 と同じ扱い）。

### DJ-4 「枝」の分け方

出現を1つずつ意味で分ける。全件は次のとおり（70回）。

| 置き場 | 回 | 意味 | 扱い |
|---|---|---|---|
| `canonical/orchestration-spec/document-format.md` | 22 | git のブランチ（「枝の作業から出た昇格」「同じ枝で作った」「作業の枝」） | ブランチに直す |
| `canonical/skills/doc-flow-guardrail/SKILL.md` | 11 | git のブランチ（委譲の固定節の②を含む） | ブランチに直す |
| 同上 184行目「ペインを起こしたあとの枝は2つ」 | 1 | 条件の分かれ目 | 残す（確定版） |
| `canonical/skills/episode-retrospective/SKILL.md` | 8 | git のブランチ | ブランチに直す |
| `canonical/skills/unmet-gate-check/SKILL.md` | 1 | git のブランチ | ブランチに直す |
| `canonical/skills/question-driven-design/SKILL.md`「枝分かれ」 | 1 | 木の比喩 | 残す（確定版） |
| 2つの `glossary.md` の表・`html-one-pager/SKILL.md` 145行目 | 3 | 使わない語として挙げた行 | 残す（確定版） |
| `projects/orchestration-engine/lib/handoff-state.sh` | 3 | git のブランチ | ブランチに直す |
| `test_handoff_prepare.sh` の 195・241行目 | 2 | git のブランチ | ブランチに直す |
| `test_handoff_prepare.sh` の 299行目「この枝だけ rc=0」 | 1 | コードの分岐 | 分岐に直す |
| `test_handoff_retire.sh` の 745行目の1つ目と3つ目 | 2 | git のブランチ | ブランチに直す |
| `test_handoff_retire.sh` の 496・498・518行目と 745行目の2つ目 | 4 | コードの分岐（テストが通る経路） | 分岐に直す |
| `oe-handoff` の 993・1027・1030行目 | 3 | git のブランチ（1030行目は出力の文） | ブランチに直す |
| `oe-handoff` の 774行目「この枝はテストで踏めていない」 | 1 | コードの分岐 | 分岐に直す |
| engine の `bin/README.md` の 199行目「枝と HEAD」 | 1 | git のブランチ | ブランチに直す |
| engine の `bin/README.md` の 606行目・`oe-confirm` の 64・66行目「検査枝」 | 4 | `oe-selfcheck` の中の検査の1つ | 「検査」に直す（N4） |
| `canonical/hooks/scripts/` の2本「いちばん多く通る枝なので」 | 2 | コードの分岐 | 分岐に直す（brief の指定どおり plan で決めた） |

- 直したあとに残るのは、確定版の5回と、DJ-1・DJ-2 で決まりの文に足す言い換えの例の2回（§8 と出力の型に1回ずつ）の、合わせて7回になる（設計SO の指摘6）。
- コードの分岐を「ブランチ」にしないのは、同じファイルが git のブランチを扱っていて（handoff のテストと `oe-handoff`）、同じ語が2つの意味になるからである。プログラムの経路は「分岐」と呼ぶのがふつうである（「条件分岐」「分岐網羅」）。用語集の表の「書かない形」に「分岐」があるのは git のブランチの意味についての行なので、コードの分岐を「分岐」と書くことと食い違わない。
- 「枝」を `git grep` で引く確かめに、「分岐」は混ざらない（違う字）ので、残りの一覧は7回になる。

### DJ-5 「版」の分け方

意味で3つに分ける。

- 直す（バージョン）: ソフトウェア・道具・データの形式・反映した設定の、番号や識別子で呼ぶバージョン。例: CLI の版・bash の版・jq 版・so-compare 自身の版・版文字列・書式の版（`v1`）・版管理・主版番号（メジャーバージョン）・版差（バージョンの違い）・版依存（バージョン依存）・`runbook-authoring` の見本の設定の版。
- 残す（文書の改訂）: 確定版・深掘り中の版・承認時の版・有効な版・ゲート表の版・判断ボードやページの版（ヘッダーの「版」の行を含む）・前の版（plan・書面・スキルの前の改訂）・初版（設計の最初の形）・置き換え直前の版（ファイルの中身の写し）・最新版。
- 残す（決まりの中の言い換えの例）: DJ-1・DJ-2 で §8 と出力の型に書く「版」の2回。
- 残す（接尾）: Web 版・WASM版・1M 版・hard 版・1行版・完全版・手動版・トポロジ版・劣化版・安定版・Homebrew版・5 件版・使わない語の表の「公開版」。

直すファイルと回数（DJ-6 で範囲を広げる案のとき。確定版の列挙に入っているものに「確定版」と書く）。

| 置き場 | 回 | 備考 |
|---|---|---|
| `canonical/skills/so-compare/SKILL.md` | 6 | 確定版は4（「CLI の版」）。残る2は N1 |
| `canonical/skills/runbook-authoring/examples/`（`docs/shop-config.md` 8・`docs/runbooks/shop-config-apply.md` 33・`docs/runbooks/README.md` 3・`scripts/shop-config.sh` 35） | 79 | 確定版。見本の手順書・用語・スクリプトの出力の文を一緒に直し、見本の中で語をそろえる |
| `canonical/skills/runbook-authoring/tests/test_check_runbook.py` | 9 | 見本の出力を確かめる期待値（8）と bash のバージョン（1）。見本を直すと期待値も変わる |
| `canonical/skills/runbook-authoring/SKILL.md` 133・149・160行目 | 4 | 見本と同じ意味の決まりの文（N1） |
| `canonical/skills/issue-intake/SKILL.md` 270行目「書式の版」 | 1 | N1。同じ行の「確定版」2回は残す |
| `canonical/skills/html-one-pager/`（`SKILL.md` 2・`build.py` 2・`tests/test_build.py` 2）「前の版」 | 6 | N1。受け付けるデータの形式の前のバージョン |
| `canonical/skills/doc-flow-guardrail/SKILL.md` 177行目「版管理」 | 1 | N1 |
| `canonical/skills/orchestration-toolkit/SKILL.md` 16行目 | 1 | N1 |
| `canonical/hooks/README.md` 8行目「現行版」・`canonical/hooks/scripts/oe-prompt-receipt.sh` 24行目「版依存」 | 2 | N1 |
| `scripts/so-compare.sh` | 16 | 確定版（数は8と書かれていた） |
| `scripts/sync/apply-claude-settings.sh` 351行目・`scripts/sync/check-orphan-links.sh` | 6 | N1。`check-orphan-links.sh` の5回は realpath の実装の違い（macOS と GNU）なので「実装」に直す |
| engine の `README.md`・`bin/README.md`・`oe-handoff`・`oe-lane-explain`・`oe-selfcheck`・`lib/sanitize.sh`・`scripts/knowledge-list.sh` | 40 | N1。`oe-selfcheck` の出力の文（165・168・377行目）を含む |
| engine のテスト（`test_apply_claude_settings.sh` 8・`test_oe_lane_explain.sh` 4・`test_prompt_receipt.sh` 2・`test_sanitize.sh` 1・`test_so_compare_version.sh` 7・`test_sync_output_styles.sh` 1・`fixtures/so-lane-failures/SOURCE.md` 1） | 24 | N1 |

- 分け方に迷った境界は2つある。`html-one-pager` の「前の版の `purpose`」（`SKILL.md` の 111・460行目・`build.py` の 74・493行目・`tests/test_build.py` の 264・271行目の6回）は、初稿では文書の改訂の側に置いた。設計SO の指摘3（`purpose` を `kind` に替えたのは受け付けるデータの形式の変更で、文書の改訂ではない）を採り、「前のバージョン」に直す側へ移した（N1 に入る）。`runbook-authoring` の見本の「版」は、中身から作る12桁の識別子で、owner がバージョンに直すと答えた（確定版）。
- 直す語の形: 「〜の版」は「〜のバージョン」、「版文字列」は「バージョン文字列」、「主版番号」は「メジャーバージョン」、「版差」は「バージョンの違い」、「版依存」は「バージョン依存」、「版管理」は「バージョン管理」にする。見本の `releases/<版>/` は `releases/<バージョン>/` にする。
- 見本のスクリプトの出力の文（「今の版:」「反映した: 版」など）を変えると、見本の手順書の「期待する出力」とテストの期待値も変わる。3つを同じコミットで直し、テストで揃っていることを確かめる。

### DJ-6 コードとテストの範囲（確定版の列挙の外をどこまで直すか）

確定版はコードのコメントとテストの文を範囲に入れ、統括の数えでファイルと回数を挙げた。意味の基準で数え直すと、列挙の外にも同じ言い換えがある（上の表の N1・N4）。

- 案A（推奨）: 凍結していない母集団のすべてを、DJ-4 と DJ-5 の基準で直す。「枝」70回のうち65回と、「版」約195回を直す。owner の方針（引っ張る元になるので直す）と、確定版がコードのコメントとテストを「種類」として範囲に入れたことに合う。列挙は統括の数えで、範囲を区切る意図ではないと読んだ（推測。owner に確かめる）。
- 案B: 確定版の列挙のファイルだけを直す（canonical の Markdown の「枝」42・`so-compare/SKILL.md` の4・`runbook-authoring` の見本とそのテスト・`handoff-state.sh`・handoff の2つのテスト・`scripts/so-compare.sh`）。列挙の外は follow-up の issue に残す。PR は小さくなるが、engine の作業で AI が読むコメントに言い換えが残る。
- 案C: canonical（配布物・常に読まれる）は列挙の外まで直し、engine と `scripts/` は確定版の列挙だけにする。

案A の差分は大きいが、すべてコメント・テストの文・表示の文である。終了コード・処理・データの形式は変えず、表示の文だけを変える。確定版の範囲は「ドキュメント・コメント・テストの文」なので、表示の文を変えることは案A の一部として owner の承認に含める（設計SO の指摘5）。表示の文が変わるのは次のとおりで、確かめるテストがあれば期待値も直す。

- `oe-selfcheck`: 結果の detail（165・168行目）・見出し（377行目）・ヘルプ（60行目）
- `oe-lane-explain`: ヘルプ（74行目）
- `oe-handoff`: 申告の確かめの行（1030行目）
- `shop-config.sh`（見本）: 出力の行のすべての「版」
- `test_*.sh` の項目名と NOTE の行（テストの出力）

### DJ-7 `scripts/so-compare.sh` のハッシュ

`test_so_compare_version.sh` は `so-compare.sh` の中身のハッシュを固定している。テストの註は「振る舞いが変わったなら `SO_COMPARE_VERSION` を上げ、`EXPECTED_SHA` を更新する。コメントの修正だけでも落ちるのは仕様」と書いている。今回はコメントだけの変更なので、`EXPECTED_SHA` だけを新しい値に更新し、`SO_COMPARE_VERSION`（`2026-09-14b`）は上げない。上げると、meta の観測を版で層別する #303 の用途で、振る舞いが同じ実行が別の版に分かれるからである。

### DJ-8 確かめ方

- 「枝」の残り: 母集団で `git grep -n '枝'` を引き、確定版の5行だけであることを全件の一覧で episode に残す。
- 「版」の残り: 母集団で `git grep -n '版'` を引き、残りの全件を DJ-5 の「残す」の2つの種類に1件ずつ当てた一覧を episode に残す。
- 直した bash のスクリプトとテストに、変数の直後の全角の検査を当てる（knowledge item `01M579XZNAT7EXY4VPGRM9J8JW`）。macOS の `grep` は `-P` を持たないので（設計SO の指摘7）、`rg --pcre2 -n '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' <ファイル>` を使う。終了コードで分け、1（該当0件）を合格、2（検査の失敗）を不合格とする。
- 直したシェルスクリプトすべてに、直す前と後で `shellcheck` を回し、出力の差に新しい警告が無いこと（数ではなく中身で比べる）。
- テスト: 直したテストと、直したスクリプトを確かめるテストを、bash 5 と bash 3.2 の両方で走らせ、結果の行（`=== Results:` か `=== RESULT:`）で失敗0を確かめる。bash 3.2 の回では、`/bin/bash` を指す `bash` だけを置いた一時のディレクトリを PATH の先頭に足す。テストが `#!/usr/bin/env bash` のスクリプトを直接起動しても、子が bash 3.2 で動くようにするためである（設計SO の指摘8）。SKIP の行が出たら数と理由を書き、SKIP で通ったものを合格に数えない（指摘9）。テストが比べていない表示の文（`oe-selfcheck` の detail とヘルプ・`oe-lane-explain` のヘルプ）は、実際に走らせた出力を読んで確かめる。Python のテストは既存の呼び方（`python3 <スキルのフォルダ>/tests/test_check_runbook.py`・`python3 <スキルのフォルダ>/tests/test_build.py`）で走らせる。`test_check_runbook.py` の書き換え箇所を探す文字列（656行目）も直す（指摘10）。対象は handoff の2つ・`test_so_compare_version.sh`・`test_apply_claude_settings.sh`・`test_oe_lane_explain.sh`・`test_prompt_receipt.sh`・`test_sanitize.sh`・`test_sync_output_styles.sh`・`test_check_orphan_links.sh`・`test_hook_judgment.sh`・`test_hook_firing.sh`・`runbook-authoring` の `tests/`（Python）・`html-one-pager` の `tests/`（用語集の文を変えるので）。テストの期待値を変えたときは、変更前のスクリプトとの差を episode に書く。
- 同じ語の意味の対比を、人の目で確かめる受入の例にする（設計SO の選択肢拡張・機械の検査は作らない）: git の枝はブランチ・条件の分岐は分岐のまま／PHP の版はバージョン・文書の確定版は確定版のまま／behavioral には振る舞いとして。書き直した §8 と出力の型の文だけで、この3組を同じ基準で説明できることを episode に書く。
- 書き直した §8・出力の型・2つの用語集・`html-one-pager/SKILL.md` の行の文を、書き直した決まりに当てる。対象は、書き直したファイルと、2つのスキルのフォルダ全体の文面である（knowledge item `01M5F0CNEKA9ED9AMQ3YWGGF8W`）。例外は使わない語を挙げる表の行だけにする。

## ゲート1（ゼロベースの代替探索）

確定版の方針（基準を1つ書き、一覧は例にとどめる）をいったん外して、別の形を考えた。

| 案 | 中身 | 採否 |
|---|---|---|
| G1 | 基準を書かず、§8 の例に ブランチ・バージョン・デプロイ を足すだけ | 採らない。owner の方針（一覧を増やしても同じことが起きる）に反する |
| G2 | 用語集を1か所（canonical の共通の文書）にまとめ、スキルからそこを参照する | 採らない。スキルは持ち運べる形で、ほかを参照しない（#467） |
| G3 | §8 を2つに割り、語の選び方の決まりを独立した番号にする | 採らない。§9 と出力の型が §8 を番号で指していて、番号を変えると参照が増える。§8 の中で基準を先頭に置けば足りる |
| G4 | 和語に言い換えた語を見つけたら止める hook | 採らない。確定版が「機械の検査は作らない」と決めている |
| G5 | 基準を「カタカナで書け」にする | 採らない。文書の改訂の「確定版」や「分岐」まで言い換える逆の誤りを生む。DJ-1 の「残す和語の例」の行はこの誤りへの備えとして入れた |

ゼロベースの案は確定版の方針と同じところに落ちた。違いとして拾ったのは G5 の逆の誤りで、DJ-1 の最後の行に入れた。

## 設計SO（ゲート2・弱・Codex 1レーン）

- `so-compare --codex-only -w <worktree> -f tmp/571-loanwords/so-design/prompt.txt`（`SO_TIMEOUT=600`）。初回で返った（meta: `model_resolved=gpt-6.1-sol`・`timeout_status=success`・回答 8,987 バイト）。切り替えは要らなかった。結論は「直してから進めてよい」。
- 指摘は11件と選択肢拡張1件で、すべて採った。

| # | 重さ | 指摘 | 採否と直した場所 |
|---|---|---|---|
| 1 | 中 | DJ-2・DJ-3 にも、例が同じものを指すときの話だと限定する文が要る（表だけ読むとコードの「分岐」まで避けうる） | 採る。DJ-2 と DJ-3 に1文ずつ足した |
| 2 | 低 | runbook の用語集の冒頭「この表の言葉を使う」が、表を例に下げることと合わない | 採る。DJ-3 に冒頭の文の直しを足した |
| 3 | 中 | html-one-pager の「前の版の `purpose`」はデータの形式の変更で、文書の改訂ではない | 採る。DJ-5 で直す側へ移した（6回） |
| 4 | 高 | 分類の全件の表が `issue-intake` の 270行目の「確定版」2回まで直す側にしていた | 採る。表を直した（直す 195・残す 217） |
| 5 | 中 | 表示の文の変更の一覧が足りない（ヘルプ）。「振る舞いは変えない」ではなく、表示の文を変えると書く | 採る。DJ-6 に一覧と書き方を足した |
| 6 | 高 | 「枝」の残りは、決まりに足す例の2回を入れて7回になる。「版」にも「決まりの中の例」の種類が要る | 採る。DJ-4・DJ-5 を直した |
| 7 | 中 | macOS の `grep` に `-P` が無い | 採る。`rg --pcre2` にし、終了コードで分けた |
| 8 | 中 | テストを bash 3.2 で起動しても、`env bash` の子は bash 5 で動く | 採る。PATH の先頭に bash 3.2 を置く形にした |
| 9 | 中 | SKIP で通るテストがあり、detail・ヘルプはテストが比べていない | 採る。SKIP を数えず、表示は実物の出力で確かめる |
| 10 | 低 | Python のテストの呼び方と、書き換え箇所を探す文字列 | 採る。DJ-8 に書いた |
| 11 | 低 | engine のテストの分岐の意味は4回ではなく5回 | 採る。数を直した |
| 拡張 | 低 | 同じ語の意味の対比を、人の目で確かめる受入の例にする | 採る。DJ-8 と受入に足した |

## 確定版に無い判断

ゲート3 で owner に出すかは統括が決める。

- N1: 範囲を確定版の列挙の外まで広げ、表示の文も変える（DJ-6 の案A）。html-one-pager の「前の版」6回もここに入る。canonical の Markdown の「版」7回・hook の「枝」2回と「版」1回・engine と `scripts/sync/` の「枝」9回と「版」約70回が加わる。
- N2: 凍結した記録として書き換えない置き場に、`docs/` と `projects/*/docs/` のほか、`ideas/`・`projects/_archived/`・`projects/orchestration-research/`・`projects/poc/` を入れる。
- N3: 出力の型には §8 の「残す和語の例」の行を入れない（DJ-2）。§9 の末尾の決まりは「同じ変更を入れる」なので、文が完全には一致しない。
- N4: `oe-selfcheck` の「検査枝」を「検査」に直す（git のブランチでもコードの分岐でもない、独自の呼び名である）。
- N5: コードの分岐の意味の「枝」を、ブランチではなく「分岐」に直す（DJ-4）。確定版は engine のテストの「枝」9回をまとめて言い換えとして数えていた。
- N6: §8 の例の語を差し替える（コンフリクト・レビュー・コミットを外し、ブランチ・バージョン・デプロイにする）。

## 受入

| 確定版の項目 | 満たす場所 | 結果（I3 で埋める） |
|---|---|---|
| §8 を「その分野の人がふだん何と呼ぶか」の基準1つに書き直す（英語で） | `canonical/rules/output-format-rule.md` の §8（DJ-1） | 満たした（8ea21a7） |
| 「名前か、性質を表す語か」の区別を残す | 同上 | 満たした（8ea21a7・性質を表す語の項目） |
| 出力の型に同じ変更を入れる（§9 の末尾） | `canonical/output-styles/readable-conversation.md`（DJ-2） | 満たした（8ea21a7・Q61 のとおり要点の1文） |
| 2つの表を例に下げる・行を増やさない・「表に行を足す」を直す | 2つの `glossary.md`（DJ-3） | 満たした（8ea21a7・表の行は変えていない） |
| 基準の1文を各スキルに書く（参照だけにしない・スキルどうしも参照しない） | 2つの `glossary.md`（DJ-3） | 満たした（8ea21a7） |
| `html-one-pager/SKILL.md` の用語の行と `glossary.md` の冒頭の説明を合わせる | 同ファイル（DJ-3） | 満たした（8ea21a7・runbook の冒頭は 1c808c1 で補正 H2） |
| canonical の「枝」42回をブランチに・5回を残す・固定節の②も直す | DJ-4 の表 | 満たした（e88f38d・残りの7行は episode の I1-5） |
| 「CLI の版」4か所をバージョンに | `so-compare/SKILL.md`（DJ-5） | 満たした（e88f38d・同じ意味の2回も直した） |
| `runbook-authoring` の例の「版」をバージョンに | `examples/` とそのテスト（DJ-5） | 満たした（aff6643・テスト 95 で失敗0） |
| `handoff-state.sh` の「枝」3・engine のテストの「枝」9・`so-compare.sh` の「版」 | DJ-4・DJ-5・DJ-7 | 満たした（0849242・EXPECTED_SHA を更新） |
| hook のスクリプトの「枝」2を意味で分けて決める | DJ-4 の表 | 満たした（0849242・分岐に直した） |
| `docs/` と `projects/*/docs/` を書き換えない | `git diff --stat` に出ないこと | 満たした（この plan・episode・decision・knowledge のほかは変わっていない） |
| 機械の検査を作らない | 新しい検査のファイルが無いこと | 満たした |
| 同じ語の意味の対比を、書き直した決まりで説明できる | episode（DJ-8） | 満たした（episode の I1-5） |
| 「枝」の残りの全件の一覧 | episode | 満たした（episode の I1-5・7行。「版」の残りの全件は episode の末尾の表） |
| テストが bash 5 と bash 3.2 で失敗0・期待値を変えたら差を書く | episode（DJ-8） | 満たした（episode の I1-5。test_oe_confirm の2件は master でも失敗する既存の失敗） |
| `shellcheck` | episode（DJ-8） | 満たした（22本で警告が前後で同じ） |
| 書き直した文が書き直した決まりに反していない | episode（DJ-8） | 満たした（episode の I1-5・実装SO の指摘3を H2 で直した） |

## ステップ

### P1: worktree・確定版の照合・参照の読み（完了）

- worktree を作り、確定版を照合し、episode の枠を置き、参照を読んだ（episode の「P1」の節）。

### P2: plan を書き、ゲート1 と設計SO を当てる

- この plan を書く。ゲート1 は上の節。設計SO は `so-compare --codex-only`（返らなければ `--cursor-only` に1回だけ切り替える）。依頼文に `.oe/` の中身と業務のリポジトリの情報を入れない。採否を plan と episode に書く。

### P3: plan と episode を commit して push し、報告して止まる

- plan と episode を commit して push する（PR は作らない）。plan のパスを報告の宛先へ `oe-send` で1行送り、exit code を確かめて止まる。

### GATE 3: owner の plan 承認（統括が判断ボードに載せる）

- DJ-6 の案と「確定版に無い判断」N1〜N6 の答えを、承認のあとに plan へ写す。
- 結果（2026-11-05）: owner が判断ボードの Q59〜Q64 で、すべて推奨どおりに答えた。N1 は案A（挙げていない置き場まで全部直し、表示の文も変える）、N2 は4つの置き場も書き換えない、N3 は出力の型に要点の1文だけ入れる（DJ-2 の2つの項目と、例を限定する1文。§8 の「残す和語の例」の行は入れない）、N4・N5 は「検査」と「分岐」に直す、N6 は例の語を差し替える。承認した plan の版は `600f666`。

### I1-1: §8・出力の型・2つの用語集・2つのスキルの用語の行（DJ-1〜DJ-3・1コミット）

### I1-2: canonical の Markdown の「枝」と「版」（DJ-4・DJ-5・1コミット）

### I1-3: `runbook-authoring` の見本・手順書・テスト（DJ-5・1コミット）

### I1-4: engine と `scripts/` のコメント・テスト・出力の文・`EXPECTED_SHA`（DJ-4〜DJ-7・DJ-6 の答えの範囲・1コミット）

### I1-5: 確かめ（DJ-8）

### GATE I1: 受入の表の行がすべて満たされている

### I2: 実装SO（弱・Codex 1レーン）・Copilot 1ラウンド・PR

- 実装SO と Copilot の指摘への対応で未返信を0件にし、PR を作る（`pr-conventions`・本文は `Refs #571`）。

### I3: episode を閉じ、報告して止まる

- 注入した knowledge item 3件すべてに観測を書き戻す。`.oe/report-571.md` に報告を書き、報告の宛先へ `oe-send` で送って止まる。

## リスク・未確認事項

- §8 は常に読み込まれる rule である。例の語を差し替えると、コンフリクト・レビュー・コミットが例から消える。基準で決まる語なので問題は無いと見ているが、効き目は測っていない（推測）。
- 出力の型は #348 の観察中の対象（暫定採用の v4）である。今回の直しは「書き方」の節の1項目で、観察の止める条件（owner が「やめてほしい」と言う応答）には触れない。
- 「版」の境界（DJ-5）は判断が入る。`html-one-pager` の「前の版」は、初稿では残す判断だったが、設計SO の指摘3で直す側へ移した（DJ-5 の境界の項目）。前の実装を指す「版」も実装SO の指摘で直した（「ゲート3 のあとの変更」の H1）。
- 案A では差分が数十ファイルにわたる。I1 のコミットを置き場ごとに分け、レビューで追えるようにする。

## ゲート3 のあとの変更

| # | 級 | 対象 | 中身と理由 |
|---|---|---|---|
| H1 | 補正 | DJ-5 | 実装SO の指摘1で、前の実装やコードの状態を指す「版」6回（engine の `bin/README.md` 70・528・529行目・`oe-tree` 458行目・`register-metrics` の2回）を、「残す（文書の改訂）」から直す側へ移した。語は「バージョン」ではなく、指すものを直接書いた（変更前のコード・前の実装）。承認した範囲（案A・凍結していない母集団のすべてを DJ-5 の基準で直す）と基準は変えず、分類の誤りを直した |
| H2 | 補正 | DJ-3 | 実装SO の指摘3で、`runbook-authoring/glossary.md` の冒頭の文を「「使う語と、その1つの意味」の表の語を使い、「使わない語」の表の語は代わりの語に替える。」に直した。DJ-3 の役目（表の役目を分ける）は変えず、文言を直した |
| H3 | 補正 | DJ-5 | 「残す（決まりの中の言い換えの例）」を「版」の2回と書いていたが、§8 の残す和語の例「確定版 / 前の版」と出力の型の「確定版」を含めて5回だった。数の記述の訂正 |

確かめた8項目（H1〜H3 共通）: (1) ステップ節の見出しは消えていない (2) 各 step の要件は弱めていない (3) SO・テスト・レビュー・closure のゲートは消えていない (4) 終端は I3 のまま (5) 受入の行は減っていない (6) owner が選んだ案（Q59〜Q64）は変わっていない (7) 範囲の内の項目を範囲の外へ移していない (8) 新しい結果・範囲・作業義務・設計判断を足していない（H1 で直した6回は、承認した基準と範囲の中の出現である）。
