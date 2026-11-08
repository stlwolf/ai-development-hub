---
id: "01M6WWCKYV2Q94G636P3QKY8NS"
title: "#585 canonical のスキルの文に残る「〜の確かめ」の形を #582 の規則のとおりに直す"
date: 2026-11-08
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/585"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "docs/harness/episodes/2026-11-07-episode-582-renyo-noun-rule.md"
    reason: "規則に形を足した単位。同じ形を直した前例と、この単位の対象を見つけた記録（S1-1）"
tags: [skill, japanese, harness]
---

# #585 canonical のスキルの文に残る「〜の確かめ」の形を #582 の規則のとおりに直す

## なぜこの作業が始まったか

#582 で、他動詞を1語だけ名詞にして「の」で受ける形（「結果の確かめ」「設定の戻し」）を避ける規則を、出力の規則（`canonical/rules/output-format-rule.md` §9）と出力の型（`canonical/output-styles/readable-conversation.md`）に足した。#582 の範囲は #571 で直した4ファイルに限ったので、ほかのスキルの文には同じ形が残っている。スキルの文は AI が毎回読んで文体をまねるので、規則と食い違う文を残すと、規則で避けた形がまた出てくる。owner の指示で、小さな直しとして plan なしで進める（2026-11-08「#585 は単体で進めさせて」）。

## この単位の入力

- brief: 統括の委譲の書面（gitignored の作業層）。認識合わせは owner の指示で省いた。
- 注入された knowledge item: `01M5F0CNEKA9ED9AMQ3YWGGF8W`（書き方の決まりは、関係するスキルのフォルダ全体に当てて確かめる）。
- SO モード: 設計SO は不要。実装SO は弱・Codex 1レーンと Copilot 1ラウンド。

## 作業の記録

### S1-0: 着手（2026-11-08 15:09）

- baseline: `origin/master` `ed64889`。
- worktree: `wt switch --create 'fix/#585_renyo_noun_skills' --base origin/master`。

### S1-1: 対象を数えた結果（2026-11-08 15:09 頃）

brief の grep（`grep -rnE 'の(確かめ|戻し|直し|引き取り|比べ|書き直し)([^方]|$)' canonical/`）を `ed64889` で打ち直した。当たったのは 26 行で、1行に2か所あるものがあるので 29 か所である。

- 直さないもの（2行）: `canonical/rules/output-format-rule.md:33` と `canonical/output-styles/readable-conversation.md:27`。どちらも規則の文自身が引用の中で示す例である。
- 直すもの（24行・27か所・11ファイル）: issue の表の10ファイルに `canonical/skills/orchestration-toolkit/SKILL.md:13` を足したもの。統括の数え直しの 25 か所との差は、1行に2か所ある行（`implementer-contract/SKILL.md:160`・`html-one-pager/SKILL.md:326`）を別に数えたためで、対象の行は同じである。

### S1-2: 直し方の判断（2026-11-08 15:09〜15:10）

規則のとおり、目的語と動詞の文にするか、その分野でふだん使う漢語の名詞にした。漢語の名詞にしたのは、見本の予定表の「事前の確認」「事後の確認」、例の値の「再試行の修正」、レビューの種類の例の「設計の確認・振り返りの確認」だけである。ほかは動詞の文にした。

runbook-authoring では「確認」に替えなかった。このスキルは「確認」を「対話の確認」（スクリプトが人に聞いて待つこと）の意味で使い、「確かめ」と書き分けている（`canonical/skills/runbook-authoring/SKILL.md:30` の表の「期待が1つに決まる確かめ、対話の確認」）。さらに用語集（`canonical/skills/runbook-authoring/glossary.md`）は「確かめの番号」を、スクリプトが出す確かめの行の番号という1つの意味に決めている。そこで、「スクリプトの確かめの番号」は「スクリプトが出す確かめの番号」に直し、用語集の用語を残したまま「の」で受ける形だけを外した。「1つの確かめごとに」は「1つ確かめるごとに」、「全部の確かめが通った」は「確かめが全部通った」、「別の確かめで見る」は「別の操作で確かめる」にした。

昇格の印: runbook-authoring のように、スキルが「確かめ」と「確認」を別の意味に書き分けているときは、規則の言う「漢語の名詞（確認）」に替えると意味が衝突する。規則の例外の「別の意味で定着した名詞」を使う側の注意として、規則の文に足すかは #582 の規則を扱う作業が決める

judgment-board-flow の 8節の見出し「渡す先ごとの確かめ」は「渡す先ごとに、渡して受け取りを確かめる」にした。中身は、渡す先ごとに送る操作と受け取りを確かめる操作の両方を書いているので、見出しにも両方を入れた。見出しの文字は、スキルの中では「8節」としか参照されておらず、アンカーで指す文書は `canonical/` に無い。`projects/` と `docs/` の plan・discussion がこの見出しの文字を引いているが、凍結した文書なので触らない。

description（frontmatter）を変えたのは judgment-board-flow だけで、変えたのは末尾の括弧の中（「受け取りの確かめまでが」を「受け取りを確かめるところまでが」）だけである。`git diff -U0` で `name` と `description` の行を見て、発火の語（「〜とき」で並ぶ使う場面）が変わっていないことを確かめた。

commit はスキルごとに固定した（CATALOG は1つの commit にした）。

### S1-3: 直したあとの結果（2026-11-08 15:10）

- brief の grep を `canonical/` に当てると、残るのは S1-1 の「直さないもの」の2行だけである。
- 「の」の前に英字・数字・記号が来る形（#582 の episode の follow-up 6）も `[A-Za-z0-9`)）] ?の(...)` で探し、`canonical/skills` と `CATALOG.md` に0件だった。
- `python3 canonical/skills/html-one-pager/tests/test_build.py`: 485 件 OK。
- `python3 canonical/skills/runbook-authoring/tests/test_check_runbook.py`: 95 件 OK。
- `shellcheck canonical/skills/runbook-authoring/examples/scripts/shop-config.sh`: 指摘なし。
- 古い文字列を `projects/*/tests`・`projects/*/bin`・`scripts` で探し、直した文を引くテストが無いことを確かめた。当たったのは engine の `oe-handoff` の出力の文「閉じる直前の確かめ」と、そのテスト（`test_handoff_retire.sh`）と `test_lease.sh` のコメントである。同じ形だが `projects/` は brief の範囲の外なので直さず、follow-up に回す。
