---
id: "01M6WWCKYV2Q94G636P3QKY8NS"
title: "#585 canonical のスキルの文に残る「〜の確かめ」の形を #582 の規則のとおりに直す"
date: 2026-11-08
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/585"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "docs/harness/episodes/2026-11-07-episode-582-renyo-noun-rule.md"
    reason: "規則に形を足した単位。同じ形を直した前例と、この単位の対象を見つけた記録（S1-1）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/pull/595"
    reason: "この単位の PR"
tags: [skill, japanese, harness]
promotion:
  - subject: "runbook-authoring では確認に替えず、用語集の用語を残して動詞の文にする"
    verdict: not-required
    ref: "本文: S1-2: 直し方の判断（2026-11-08 15:09〜15:10）"
  - subject: "judgment-board-flow の 8節の見出しを変える"
    verdict: not-required
    ref: "本文: S1-2: 直し方の判断（2026-11-08 15:09〜15:10）"
  - subject: "1つの直しを1つの修正にする"
    verdict: not-required
    ref: "本文: S2-1: 実装SO の結果と採否 — 指摘2件をどちらも採った（2026-11-08 15:11〜15:12）"
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

brief の grep（`grep -rnE 'の(確かめ|戻し|直し|引き取り|比べ|書き直し)([^方]|$)' canonical/`）を `ed64889` で打ち直した。当たったのは 26 行である。

- 直さないもの（2行）: `canonical/rules/output-format-rule.md:33` と `canonical/output-styles/readable-conversation.md:27`。どちらも規則の文自身が引用の中で示す例である。
- 直すもの（24行・27か所・11ファイル）: issue の表の10ファイルに `canonical/skills/orchestration-toolkit/SKILL.md:13` を足したもの。統括の数え直しの 25 か所との差は、1行に2か所ある行（`implementer-contract/SKILL.md:160`・`html-one-pager/SKILL.md:326`）を別に数えたためで、対象の行は同じである。

### S1-2: 直し方の判断（2026-11-08 15:09〜15:10）

規則のとおり、目的語と動詞の文にするか、その分野でふだん使う漢語の名詞にした。漢語の名詞にしたのは、見本の予定表の「事前の確認」「事後の確認」、例の値の「再試行の修正」、レビューの種類の例の「設計の確認・振り返りの確認」だけである。ほかは動詞の文にした。

runbook-authoring では「確認」に替えなかった。このスキルは「確認」を「対話の確認」（スクリプトが人に聞いて待つこと）の意味で使い、「確かめ」と書き分けている（`canonical/skills/runbook-authoring/SKILL.md:30` の表の「期待が1つに決まる確かめ、対話の確認」）。さらに用語集（`canonical/skills/runbook-authoring/glossary.md`）は「確かめの番号」を、スクリプトが出す確かめの行の番号という1つの意味に決めている。そこで、「スクリプトの確かめの番号」は「スクリプトが出す確かめの番号」に直し、用語集の用語を残したまま「の」で受ける形だけを外した。「1つの確かめごとに」は「1つ確かめるごとに」、「全部の確かめが通った」は「確かめが全部通った」、「別の確かめで見る」は「別の操作で確かめる」にした。

昇格の印: runbook-authoring のように、スキルが「確かめ」と「確認」を別の意味に書き分けているときは、規則の言う「漢語の名詞（確認）」に替えると意味が衝突する。規則の例外の「別の意味で定着した名詞」を使う側の注意として、規則の文に足すかは #582 の規則を扱う作業が決める

judgment-board-flow の 8節の見出し「渡す先ごとの確かめ」は「渡す先ごとに、渡して受け取りを確かめる」にした。中身は、渡す先ごとに送る操作と受け取りを確かめる操作の両方を書いているので、見出しにも両方を入れた。見出しの文字は、スキルの中では「8節」としか参照されておらず、アンカーで指す文書は `canonical/` に無い。`projects/` と `docs/` の plan・discussion がこの見出しの文字を引いているが、凍結した文書なので触らない。

description（frontmatter）を変えたのは judgment-board-flow だけで、変えたのは末尾の括弧の中（「受け取りの確かめまでが」を「受け取りを確かめるところまでが」）だけである。`git diff -U0` で `name` と `description` の行を見て、発火の語（「〜とき」で並ぶ使う場面）が変わっていないことを確かめた。

commit はスキルごとに固定した（CATALOG は1つの commit にした）。

implementer-contract と doc-flow-guardrail の「1つの直しに級が混じるなら」は、最初は「一度に直す中身に級が混じるなら」にした。このスキルでは「直し」を、plan を変える1件ごとの単位の名前として使っている（「補正は…直しである」）ので、「修正」に替えると同じ節の中で語がそろわないと考えたためである。この判断は S2-1 の実装SO の指摘 A で撤回した。

### S1-3: 直したあとの結果（2026-11-08 15:10）

- brief の grep を `canonical/` に当てると、残るのは S1-1 の「直さないもの」の2行だけである。
- 「の」の前に英字・数字・記号が来る形（#582 の episode の follow-up 6）も `` [A-Za-z0-9`)）] ?の(...) `` で探し、`canonical/skills` と `CATALOG.md` に0件だった。
- `python3 canonical/skills/html-one-pager/tests/test_build.py`: 485 件 OK。
- `python3 canonical/skills/runbook-authoring/tests/test_check_runbook.py`: 95 件 OK。
- `shellcheck canonical/skills/runbook-authoring/examples/scripts/shop-config.sh`: 指摘なし。
- 古い文字列を `projects/*/tests`・`projects/*/bin`・`scripts` で探し、直した文を引くテストが無いことを確かめた。当たったのは engine の `oe-handoff` の出力の文「閉じる直前の確かめ」と、そのテスト（`test_handoff_retire.sh`）と `test_lease.sh` のコメントである。同じ形だが `projects/` は brief の範囲の外なので直さず、follow-up に回す。

### S2-1: 実装SO の結果と採否 — 指摘2件をどちらも採った（2026-11-08 15:11〜15:12）

`SO_TIMEOUT=480 so-compare --codex-only -w <worktree>` で、5つの観点（A 意味が変わっていないか・B 発火の語・C 複合語と定着した名詞・D 新しく不自然な形になっていないか・E 見出しの参照）を確かめた。Codex は `model_resolved=gpt-6.1-sol`（出所は config で、観測値ではない）、`codex-cli 0.166.0`、75秒・リトライなしで返った。依頼文と出力は master の `tmp/585-renyo-noun-skills/so-impl-r1-prompt.txt` と `tmp/585-renyo-noun-skills/so-impl-r1/`（gitignored）にある。B・C・E は「問題なし」で、A と D が「問題あり」だった。

- A（意味が変わった）: 採った。「一度に直す中身」は、同時に行う独立した複数の修正までまとめて重い級で扱う意味にも読める。元の「1つの直し」は修正1件を単位にしている。「1つの修正に級が混じるなら」に直した。S1-2 で「直し」の語をそろえるために選んだ言い方が、条件の単位を変えていた。
- D（新しく不自然な形）: 採った。judgment-board-flow の「回収の途中で確かめる1行」「この段で確かめる1行」は、「確かめる」が「1行」を修飾し、その1行自体を確かめる意味にも読める。「内容を確かめるために返す1行」に直した。

直したあとも、brief の grep で残るのは規則の文の2行だけである。

### S2-2: PR と Copilot のレビュー（2026-11-08 15:11〜15:14）

PR #595 を draft で作り（本文は `Refs #585`）、`gh pr edit 595 --add-reviewer @copilot` で依頼した。timeline に `review_requested Copilot` が出た。Copilot のレビューは `cc002df`（実装SO の指摘で直す前の commit）に付き、指摘は0件で、返信が要るスレッドも0件だった。実装SO の指摘で直した `ebd72c7` と `5f5f4ea` は Copilot に見せていない。再依頼は owner か統括の明示の指示があるときだけ行う決まりなので、ここでは再依頼しない。PR 本文に実装SO の結果を足し、ready にした。SO で直したあとも2つの検査（test_build.py・test_check_runbook.py）が OK であることを確かめた。

## closure

tier は heavy である。品質ゲートとして実装SO を意図して起動し、S1-2 で選んだ言い方を指摘 A で撤回した（`本文: S2-1: 実装SO の結果と採否 — 指摘2件をどちらも採った（2026-11-08 15:11〜15:12）`）。

- 次の消費者: PR #595 をマージする owner と、sync を行う統括。同じ形を `projects/` で直す作業が起きたら、その担当が S1-2 の直し方の判断を前例として読む。
- status: stable（達成）。受け入れ基準の3つ（grep の残りが直さないものだけ・2つの検査が通る・発火の語が変わっていない）を満たした。

### 受け入れ基準との対応

| 受け入れ基準 | 結果 | 根拠 |
|---|---|---|
| grep で残るのが「直さないもの」だけ | 満たした。残るのは規則の文の2行だけで、理由は S1-1 に書いた | `本文: S1-1: 対象を数えた結果（2026-11-08 15:09 頃）`、`本文: S1-3: 直したあとの結果（2026-11-08 15:10）` |
| 2つの検査が通る | 満たした。SO で直したあとも OK | `本文: S1-3: 直したあとの結果（2026-11-08 15:10）`、`本文: S2-2: PR と Copilot のレビュー（2026-11-08 15:11〜15:14）` |
| `name`・`description` の発火の語が変わっていない | 満たした。変えたのは judgment-board-flow の description の末尾の括弧の中だけ | `本文: S1-2: 直し方の判断（2026-11-08 15:09〜15:10）` |

### 事実・失敗

- implementer-contract と doc-flow-guardrail の「1つの直しに」を、語をそろえるつもりで「一度に直す中身に」にし、条件の単位（修正1件）を変えていた。実装SO の指摘 A で「1つの修正に」に直した（`本文: S2-1: 実装SO の結果と採否 — 指摘2件をどちらも採った（2026-11-08 15:11〜15:12）`）。
- judgment-board-flow の「確かめる1行」が、その1行自体を確かめる意味にも読める形になっていた。実装SO の指摘 D で直した（同上）。
- episode の S1-1 で、当たった数を「29 か所」と書いていた。実際には数えずに書いた値で、根拠が無かった。行の数（26 行）だけを書く形に直した。書式の崩れ（インラインコードの中のバッククォート）も同じ commit で直した（`本文なし: 本文は直したあとの文だけを残しており、commit cc002df の差分にある`）。

### 決定と根拠

- runbook-authoring では「確認」に替えず、動詞の文にした。スキルが「確認」を対話の確認の意味で使い、用語集が「確かめの番号」を用語に決めているためである（`本文: S1-2: 直し方の判断（2026-11-08 15:09〜15:10）`）。
- judgment-board-flow の 8節の見出しを変えた。参照はスキルの中の「8節」だけで、切れる参照が無いことを実装SO の観点 E でも確かめた（同上、`本文: S2-1: 実装SO の結果と採否 — 指摘2件をどちらも採った（2026-11-08 15:11〜15:12）`）。

### 昇格の判定

1. 「runbook-authoring では確認に替えず、用語集の用語を残して動詞の文にする」— `not-required`。規則の例外（別の意味で定着した名詞）と用語集の定めを当てただけで、実物を見れば決まる確認である（Q2 に当たらない）。根拠: `本文: S1-2: 直し方の判断（2026-11-08 15:09〜15:10）`。
2. 「judgment-board-flow の 8節の見出しを変える」— `not-required`。参照を grep で確かめれば決まる。根拠: 同上。
3. 「1つの直しを1つの修正にする」— `not-required`。元の条件の単位を保つための訂正で、議論の余地が無い。根拠: `本文: S2-1: 実装SO の結果と採否 — 指摘2件をどちらも採った（2026-11-08 15:11〜15:12）`。

S1-2 の昇格の印（スキルが「確かめ」と「確認」を別の意味に書き分けているときは、漢語の名詞に替えると衝突する）は、この判定に入れない。印が指すのは #582 の規則の文（`canonical/rules/output-format-rule.md` §9 と出力の型）に注意を足すかどうかで、このブランチが変えるスキルの文とは別の仕組みである。決めるのは規則を扱う作業の担当なので、follow-up 2 に行き先を書いた。

### 蒸留シグナル

- decision・skill・knowledge store への候補は無い。rule への候補として、S1-2 の印を follow-up 2 に回した。

### follow-up routing

1. engine の `oe-handoff` の出力の文「閉じる直前の確かめ」と、そのテスト `test_handoff_retire.sh` と `test_lease.sh` のコメントに同じ形がある（`本文: S1-3: 直したあとの結果（2026-11-08 15:10）`）。`projects/` は brief の範囲の外なので直さない。行き先は統括への報告（`.oe/report-585.md`）で、起票するかは統括が決める。
2. 規則の例外の文に「スキルが漢語の名詞を別の意味に使っているときは、動詞の文にする」という注意を足すか（S1-2 の印）。行き先は統括への報告で、決めるのは規則を扱う作業の担当である。
3. 実装SO の指摘で直した commit（`ebd72c7`）は Copilot に見せていない（`本文: S2-2: PR と Copilot のレビュー（2026-11-08 15:11〜15:14）`）。Copilot の再依頼は明示の指示があるときだけ行う決まりなので、追わない。必要なら統括か owner が再依頼を指示する。

### 観測の書き戻し

注入された `01M5F0CNEKA9ED9AMQ3YWGGF8W` に、`#585`・`followed` の観測を1件足した。根拠は S1-1 と S1-3 で、規則の grep を `canonical/` 全体（description・本文・見本・用語集）に当て、「の」の前に英字が来る形まで広げて確かめた。

### 形式メモ

チャネルの骨格で、SO で撤回した判断と数え違いを拾えた。皮（KPT・YWT）は使っていない。摩擦は小さく、直しの対象が多い単位でも、直し方の判断を S1-2 の1節にまとめたので closure は pointer で足りた。
