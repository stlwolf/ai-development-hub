---
id: "01M6Y25YN1EB47B252ZCP60CKR"
title: "#607 規則の例外の文に、漢語の名詞が別の意味で使われているときの注意を足す"
date: 2026-11-09
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/607"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "docs/harness/episodes/2026-11-07-episode-582-renyo-noun-rule.md"
    reason: "注意を足す先の規則（他動詞を1語だけ名詞にして「の」で受けない）を足した単位"
  - type: reference
    ref: "docs/harness/episodes/2026-11-08-episode-585-renyo-noun-skills.md"
    reason: "この注意のきっかけになった前例（S1-2: runbook-authoring で「確認」に替えなかった判断）"
tags: [rule, output-style, japanese, harness]
---

# #607 規則の例外の文に、漢語の名詞が別の意味で使われているときの注意を足す

## なぜこの作業が始まったか

#582 で足した規則（他動詞を1語だけ名詞にして「の」で受けない）は、直し方として「目的語と動詞で書くか、その分野の人がふだん使う漢語の名詞にする（確認・復元）」を挙げている。#585 で runbook-authoring の文を直したとき、このスキルは「確認」を対話の確認（スクリプトが人に聞いて答えを待つこと）の意味で使っていたので、「〜の確かめ」を「〜の確認」に置き換えると意味がぶつかった。子は動詞の文に直した（PR #595・#585 の episode の S1-2）。同じ場面でまた漢語の名詞に置き換えないように、規則に注意を1文足す。owner が判断ボードで「小さな直しとして子に任せる」を選んだ（2026-11-09）。

## この単位の入力

- brief: 統括の委譲の書面（gitignored の作業層）。認識合わせは owner の判断で省いた。plan は作らない。
- 注入された knowledge item: `01M5F0CNEKA9ED9AMQ3YWGGF8W`（書き方の決まりは、関係するファイル全体に当てて確かめる）。着手時に `knowledge-list --strict` で在ることを確かめた。
- SO モード: 設計SO は不要。実装SO は弱・Codex 1レーンと Copilot 1ラウンド。

## 作業の記録

### S1-0: 着手（2026-11-09 02:09）

- baseline: `origin/master` `6dcbeef`。
- worktree: `wt switch --create 'fix/#607_rule_kango_note' --base origin/master`。

### S1-1: 足した文と置き場所（2026-11-09 02:10 頃）

2つのファイルの該当の項目の末尾（例外の文「複合語……この形に当たらない」のすぐあと）に、同じ中身の1文を足した。

- `canonical/output-styles/readable-conversation.md` の「書き方」: 「置き換える漢語の名詞が、書いているスキルや文書の中で別の意味に使われているときは、置き換えず、目的語と動詞で書く（たとえば「確認」を、人に聞いて答えを待つ意味で使っている文書）。」
- `canonical/rules/output-format-rule.md` §9: "If that Sino-Japanese noun already carries a different meaning in the skill or document being written (for example, one that uses 確認 for asking a person and waiting for the answer), do not substitute it; write the verb with its object."

判断の why:

- 例を括弧で1つ添えた。抽象的な条件だけだと、どの場面を指すかが読み手に伝わりにくい。例は #585 の前例（対話の確認）を、hub 固有の名前を出さない形で書いた。
- 直し方は「目的語と動詞で書く」に限った。規則が挙げる2つの直し方のうち、残るのはこれだけだからである。
- 例外の文とは対象が違うので矛盾しない。例外の文は「この形に当たらないもの」（複合語・別の意味で定着した名詞）を決め、足した文は「この形に当たるものを直すときに、漢語の名詞を選ばない場合」を決める。

### S1-2: ほかの文が変わっていないことを確かめた結果（2026-11-09 02:11 頃）

`origin/master` の版と行ごとに比べた。どちらのファイルも行数は変わらず（37 行と 45 行）、変わった行は1行だけで、元の行は新しい行の先頭にそのまま残っている（足しただけ）。

```text
canonical/rules/output-format-rule.md lines 37 37 changed 1 old-is-prefix True
canonical/output-styles/readable-conversation.md lines 45 45 changed 1 old-is-prefix True
```

### S1-3: knowledge item の教訓を当てた結果（2026-11-09 02:11 頃）

- 規則の正規表現（`の(確かめ|戻し|直し|引き取り|比べ|書き直し)([^方]|$)`）を足した差分に当てた。当たったのは、規則の文自身が引用で示す例を含む既存の行だけで、足した文には当たらない。
- この規則の文を持つファイルを `canonical/` 全体で探した（`grep -rln "の確かめ\|transitive verb by itself" canonical/`）。規則の文を持つのは今回の2ファイルだけである。もう1件当たる `canonical/skills/runbook-authoring/SKILL.md` は規則の写しではなく、用語集の用語（確かめの番号）を使っている文なので、範囲の外である。

### S2-1: 実装SO の結果（2026-11-09 02:10〜02:11）

Codex 1レーン（`gpt-6.1-sol`・20秒・exit 0）の答えは「問題なし」だった。観点の (1) 例外の文との矛盾については、足した文は「漢語に置き換えると文書の中の別の意味とぶつかる場合に、既存の直し方の『目的語と動詞』を選ぶ条件」で、例外の文と矛盾しないと答えた。(2) 2つのファイルの一致については、条件・「確認」の例・直し方が一致していると答えた。meta の `tool_status` は `not_observed` だったが、events の記録で Codex が `git show HEAD` と2ファイルの `nl -ba` を実行していることを確かめたので、ファイルを読まずに答えたものではない。

Codex は、英語の §9 にだけ既存の例「〜の直し」「修正」があり日本語の出力の型には無いことも挙げた。これは今回の変更より前からある例の数の違いで、規則の意味は食い違っていないとしている。今回の範囲（足す1文）の外なので触らない。
