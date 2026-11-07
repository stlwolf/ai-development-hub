---
id: "01M6TZYRYCF6ARZ4HVNWZE7AHW"
title: "#582 他動詞を1語だけ名詞にして「の」で受ける形を、出力の規則で避ける"
date: 2026-11-07
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/582"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "docs/harness/decisions/2026-11-05-decision-571-term-choice-criterion.md"
    reason: "§8 の基準の決め方（単語の一覧で塞がず基準を書く）。この単位はその方針を変えない"
tags: [rule, output-style, japanese, harness]
---

# #582 他動詞を1語だけ名詞にして「の」で受ける形を、出力の規則で避ける

## なぜこの作業が始まったか

AI が書く日本語に、他動詞を1語だけ名詞にして「の」で受ける形（「結果の確かめ」「設定の戻し」）が多い。この形では、誰が何をするのかが文から読めなくなる。yomiyasu の試し入れ（#565）の記録では、lint が当てた候補のうちこの形が 29 件で、直訳語に次いで多かった。owner は「規則にその1観点足していい」と判断した（2026-11-07）。軽微修正として扱い、plan は書かない。設計SO も省く（brief の SO モード）。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドは通す。

## この単位の入力

- brief: 統括の委譲の書面（gitignored の作業層）。scope は issue の「やること」の4項目のうち最初の3つである。4つ目の sync は統括が行う。
- 注入された knowledge item: `01M5F0CNEKA9ED9AMQ3YWGGF8W`（書き方の決まりを足したら、直したファイルと関係するスキルの文面にもその決まりを当てる）。
- 参照: #571 の decision（上の `related`）。yomiyasu の語の一覧の註（hub の外。読むだけで写さない）。

## 作業の記録

### S1-0: 着手（2026-11-07 21:30 頃）

- baseline: master `62381f1`（`git fetch` 後の `origin/master` と一致）。
- worktree: `wt switch --create 'fix/#582_renyo_noun_rule' --base master`。
- brief の受け入れ基準が挙げるテストのパス `tests/test_sync_output_styles.sh` は、リポジトリの根には無かった。実物は `projects/orchestration-engine/tests/test_sync_output_styles.sh` である。中身は出力の型の配置（symlink と `--check` の走査対象）を確かめるもので、文の中身は見ない。このテストを受け入れ基準のテストとして扱う。

### S1-1: 受け入れ基準の grep を、文を足す前の4ファイルに当てた結果（2026-11-07 21:31 頃）

brief の grep（`[一-龠ぁ-ん]+の(確かめ|戻し|直し|引き取り|比べ|書き直し)`）を、#571 で直した4ファイルに当てた。4ファイルとも0件だった。

- `canonical/rules/output-format-rule.md`: 0件
- `canonical/output-styles/readable-conversation.md`: 0件
- `canonical/skills/html-one-pager/glossary.md`: 0件
- `canonical/skills/runbook-authoring/glossary.md`: 0件

brief の grep は6語だけを見るので、yomiyasu の語の一覧（hub の外・49語）を同じ4ファイルに当てて、取りこぼしが無いかも確かめた。当たったのは `html-one-pager/glossary.md:99` の「選ぶページの選び方のカード」の1件だけである。これは「選び方」という「方」の付いた複合語で、他動詞を1語だけ名詞にした形ではない。直さない。

同じ6語の grep を、2つのスキルのフォルダ全体と `canonical/rules`・`canonical/output-styles` に広げた（注入 item の教訓）。「〜し方」「〜め方」の複合語を除くと、この形が次のファイルに残っている。どれも #571 で直した4ファイルの外なので、この単位では直さず、follow-up として統括に伝える。

- `canonical/skills/html-one-pager/SKILL.md:89`（例の節の名前「一覧から選ぶ問いの直し」）・`:326`（「設計の確かめ・振り返りの確かめ」）
- `canonical/skills/html-one-pager/examples/decide.json:76`（「再試行の直し」）・`examples/map-tabs-body.html:74,76`（「前の確かめ」「あとの確かめ」）
- `canonical/skills/runbook-authoring/SKILL.md:63,159,191`（「1つの確かめごと」「全部の確かめ」「別の確かめ」）
- `canonical/skills/runbook-authoring/examples/scripts/shop-config.sh:157`（「前提の確かめ」）

昇格の印: 書き方の決まりを足す単位で、決まりの検査を関係するスキルのフォルダに広げると範囲外の当たりが出る。直すかどうかを範囲で切った判断の記録

### S1-2: 足した2つの文と、置き場と文面の判断（2026-11-07 21:33 頃）

- §9: telegram style を禁じる項目のすぐ下に、英語の1項目を足した。§9 の中の置き場は、語彙の項目（`Vocabulary follows §8`）より前にした。この規則は語の選び方ではなく文の形の規則で、telegram style の項目と同じ種類だからである。§8 に置かない理由は brief のとおりである（語でなく文の形の規則）。
- 出力の型: 「書き方」の「完全な文で書く。体言止めで終えない。…」の行のすぐ下に、日本語の1行を足した。§9 の末尾の項目（片方を直したら出力の型も直す）に従う。
- 文面は brief の案から2か所変えた。
  - §9 の理由の節に `so the reader cannot tell who does what` を足した。brief の案の `the actor and the object disappear` だけでは、「結果の確かめ」のように対象の語（結果）が文に残っている例と食い違って読める。issue の本文の言い方（誰が何をするかが読めなくなる）に寄せた。
  - 出力の型の行にも理由の1文（この形では誰が何をするかが読めない）を足した。§9 と出力の型で、同じ規則が同じ理由を持つようにした。出力の型のほかの行も「〜しない。〜する。」の形で理由や代わりの書き方を添えているので、形はそろう。（あとで訂正: §9 には「対象が消える」という主張が残っていて、2つの理由はそろっていなかった。実装SO の指摘 B と F で直した。`本文: S2-2: 実装SO の結果と採否 — 指摘4件をすべて採った（2026-11-07 21:38 頃）`）
- 足していないもの: issue の背景にある「ほかの和語の連用形の名詞に替えるだけでは済ませない」は、yomiyasu の語の一覧の註から来た文で、brief の案にも無い。brief の参照欄が「写さない」としているので入れなかった。
- §9 と出力の型の文を写しているファイルが他に無いことを、`telegram style` と `体言止めで終えない` の grep で確かめた（当たったのは2つの正本と、凍結した `docs/` の plan だけ）。

### S1-3: 文を足したあとの受け入れ基準の結果（2026-11-07 21:33 頃）

- brief の grep を4ファイルに当て直した結果は、4ファイルとも0件である。足した2つの文の例（「〜の確かめ」）は、「の」の前が「〜」で、grep の `[一-龠ぁ-ん]+` に当たらない。
- `projects/orchestration-engine/tests/test_sync_output_styles.sh`: `/bin/bash` 3.2.57 と `/opt/homebrew/bin/bash` 5.2.37 で、どちらも PASS=18 FAIL=0（rc=0）。
- 足した文自身を §8・§9・出力の型に当てた（注入 item）。英語の項目は §9 のほかの項目と同じく命令の形で、理由と代わりの書き方を添えた。日本語の行は完全な文で、体言止めは無い。「確認・復元」の「・」は括弧の中で名詞を並べるだけで、文の接続の代わりではない（出力の型の既存の行の「確定版・コードの分岐」と同じ使い方）。

### S1-4: commit（2026-11-07 21:34）

S1 の変更を `bf98961` として commit した（rule・出力の型・この episode）。

### S2-0: 統括の交代を受けた（2026-11-07 21:35 頃）

S2 に入る直前に、統括が22代目から23代目に交代したという知らせを受けた。brief の「報告の宛先」と起動時の親の pane の値は前任を指したままなので、以後の報告と問いの宛先は、知らせに書かれた後任の pane にする。その pane が `oe-tree` に生きた root の `cockpit` として出ていることを確かめてから、受領の1行を `oe-send` で送った（rc=0）。`oe-send` は PATH に無いので、brief の「verb 解決規約」のとおり `oe-tree` の実体のディレクトリ（engine の `bin/`）から呼んだ。作業の中身は変わらない。

### S2-1: 実装SO（弱・Codex 1レーン）を起動した（2026-11-07 21:35）

`so-compare --codex-only`（`SO_TIMEOUT=480`）を worktree に当てた。依頼文は master の `tmp/582-renyo-noun/so-impl-r1-prompt.txt`、出力は `tmp/582-renyo-noun/so-impl-r1/`（どちらも gitignored）。依頼文には作業層（`.oe/`）の中身も、別のリポジトリの情報も入れていない。観点は6つで、規則の正確さと読み過ぎの余地（A）、§9 と出力の型の一致（B）、§8 ほかとの矛盾（C）、足した文自身の違反（D）、置き場（E）、episode の主張と差分の食い違い（F）である。

### S2-2: 実装SO の結果と採否 — 指摘4件をすべて採った（2026-11-07 21:38 頃）

Codex は `model_resolved=gpt-6.1-sol`（出所は config で、観測値ではない）、`codex-cli 0.166.0`、69秒・リトライなしで返った。6観点のうち D（足した文自身の違反）と E（置き場）は「問題なし」、A・B・C・F は「問題あり」だった。4件とも採り、§9 と出力の型の文を直した。Codex は episode の未コミットの追記を判定から外していた。

- A（規則の境界と理由が不正確）: 採った。`bare noun` だけでは、複合語（見直し・選び方）や、別の意味で名詞として定着した語まで禁じるように読める、という指摘である。理由の `the actor and the object disappear` も、「結果の確かめ」では対象の語が文に残っているので食い違う。代わりに挙げた「結果の確認」も行為者を書かないので、行為者が消えることを理由にすると代案とも合わない。S1-2 では理由の後半を足しただけで、前半の食い違いは残していた。直した形は次のとおりである。
  - 対象を `turn a transitive verb by itself into a noun` と書き、「1語だけ」を英語でも明示した。
  - 理由を `the phrase blurs who does what`（日本語は「誰が何をするかがあいまいになる」）に置き換えた。
  - 最後に「複合語（見直し・選び方）と、別の意味で定着した名詞は、この形に当たらない」の1文を足した。
- B（§9 と出力の型の理由が食い違う）: 採った。A の直しを両方に同じ内容で入れた。
- C（§8 との関係があいまい）: 採った。代わりの書き方の「定着した漢語の名詞」を、§8 の基準と同じ言い方で「その分野の人がふだん使う漢語の名詞」（英語は `the Sino-Japanese noun people in the field already use`）にした。定着した名詞を外す1文（A）で、§8 が残すとした語と競合する余地も小さくした。
- F（episode の記述が現状と食い違う）: 採った。S1-2 の「同じ規則が同じ理由を持つようにした」は、当時の §9 に「対象が消える」が残っていたので正しくなかった。S1-2 の該当行の末尾に訂正の注記を足し、この節を指した。

brief の文の案からの離れ方: 例外の1文は brief の案に無い。規則の対象を狭めるのではなく、issue の言う「1語だけ名詞にして」の範囲を文に書いたもので、受け入れ基準（形と grep とテスト）は変えていない。報告で統括に伝える。例外に挙げた語は一般の語で、yomiyasu の語の一覧の註の文は写していない。

直したあとの確認: brief の grep は4ファイルとも0件のまま、`test_sync_output_styles.sh` は bash 3.2.57 と 5.2.37 でどちらも PASS=18 FAIL=0 だった。
