---
id: "01M6JG4A2WZA09BMR7TNDHRYFV"
title: "#565 humanizer の規則を URL で読んで当てる推敲のスキルを canonical に足す"
date: 2026-11-04
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/565"
    reason: "本 episode の作業対象"
  - type: derived_from
    ref: "docs/harness/plans/2026-11-04-plan-565-humanize-ja-skill.md"
    reason: "この episode が記録する作業の計画"
  - type: reference
    ref: "docs/research/2026-11-04-ja-readability-skills.md"
    reason: "前段の調査ノート（PR #566）"
tags: [skill, readability, japanese, harness]
promotion:
  - subject: "（closure が埋める）"
    verdict: unknown
    ref: "本文: （closure が埋める）"
---

# #565 humanizer の規則を URL で読んで当てる推敲のスキルを canonical に足す

## なぜこの作業が始まったか

owner は AI が書いた日本語を読みやすくしたい（#565）。調査の単位で humanizer（いもす研）と yomiyasu（nanaism）を一次情報で読み、owner は yomiyasu を user 層に試し入れすると決めた（Q55・2026-11-04）。humanizer は規則の文にライセンスの明示が無く本文を写せないので、URL で読んで当てる hub のスキルにする案で進めることになった（追補の brief）。この episode は、その plan を書いて止まるまで（P1〜P3）と、承認のあとの実装の記録である。

## この単位の入力

- 元の brief `.oe/brief-565-ja-readability.md`（調査の単位）と追補 `.oe/brief-565-r2.md`（R5〜R7）
- owner の答え: Q55 = 試し入れ（engine には盛り込まない・置き場は user 層・開発以外でも使えるか確かめる）、Q56 = lint を待たずに決める
- 調査ノート `docs/research/2026-11-04-ja-readability-skills.md`（PR #566）

## 作業の記録

### P1: worktree・調査ノートと brief の照合（2026-11-04）

- `feature/#565_humanize_ja_skill` の worktree を作った。R5（yomiyasu を `~/.claude/skills/` に入れる）と R6（記録 `~/.claude/yomiyasu-trial/log.md`）は、この枝の前に hub の外で済ませた（報告 `.oe/report-565-r2.md`）。
- lint の実行は、調査の単位から続けてハーネスの許可で止まったままである。owner は Q56 で「待たずに決める」と答えた。

### P2: plan の初稿と、そこで下した判断の理由（2026-11-04）

- 名前（DJ-1）は統括の案 `humanize-ja` を推奨にした。汎用の形（規則の URL を引数で受ける・案C）は、入力の (4) として取り込みつつ、名前は既定の対象で付ける。
- 「伝えたい点」を1回聞く（DJ-2）は、規則の著者の注意から入れた。聞けない環境では聞かずに進む形にして、委譲の子（答える人がいないペイン）でも止まらないようにした。
- 規則の更新の知らせ（DJ-3）は、ページの最終更新日を控えと比べる形にした。自動で要点を直さないのは、要点が hub の言葉での要約で、人が読み直して書くものだから。

昇格の印: 「ライセンスの明示が無い規則を URL で読んで当てるスキルは、本文を写さないので配布に当たらない」という判断は、ほかの外部の規則にも当てはまるかもしれない。

### P2: 設計SO（ゲート2・弱）の結果と採否（2026-11-04）

- `so-compare --codex-only -w <worktree> -f tmp/565-so/prompt-design.txt`（`SO_TIMEOUT=600`）。初回で返った（238秒・model_resolved `gpt-6.1-sol`・17,982 バイト）。切り替え（Cursor）は要らなかった。
- 指摘は9つで、すべて採った（plan の「設計SO」節の表）。重かったのは3つである。DJ-2 の「構造を保つ」と「構成を直す」の衝突（機能を持つ記法と構成を分けて解いた）、DJ-3 の「読めた」の定義と、別の URL や英語の規則が読めないときに日本語の要点で代用してはいけないこと、A2 の行一致の検査では転載を見逃すこと（フォルダ全体の連続部分文字列と目視に変え、合格の意味を限定した）。
- ライセンスについて、SO は「URL なら配布ではない」を未検証の仮定と指摘し、実行時の取得と要約の配布を分けて評価するよう求めた。plan の初稿は「配布に当たらないと判断した」と書いていたので、未検証に書き直し、著者に確かめるかをゲート3 で owner に出す判断に足した。
- 選択肢拡張で案F（人が規則を読む）・案G（レビューと編集の文脈を分ける）・案H（自前の検査プログラム）が出た。案G は、編集側の環境が URL を読めないときの形として条件付きで残した（A5 の結果で再訪）。
- SO が「調査ノートが無い」と書いたのは、ノートが PR #566 の枝にあってこの worktree に無いため。SO は P-6〜P-8 を直接は確かめていない。

昇格の印: 「読めた」を全文・途中・不可の3つに分け、途中は当てたことにしない、という線は、URL を読んで当てるほかのスキル（研究の取り込みなど）にも効くかもしれない。

### 観察: 試し入れした yomiyasu の description が変わっていた（2026-11-04）

- `~/.claude/skills/yomiyasu/SKILL.md` の description が、入れた 14:20 のあと 14:25 に書き換わっていた（この単位の作業ではない）。変わったのは発火の条件で、「人に読ませる文の下書きを頼まれたとき（Slack や Notion に書く文・issue や PR の本文・報告や説明の文書）も、名前が無くても使い、書き上げたあとに当ててから渡す」が足され、使わない対象が「会話の返答そのもの・コード・設定・仕様や手順の文書の更新」になった。
- これは owner の補足「自分たちの解釈を入れる方向」の最初の形と見られる。試用の記録（hub の外）に、変えた日付と中身を書き添える。このスキル（humanize-ja）の DJ-1 の発火の条件（呼んだときだけ）とは違う線になるので、ゲート3 で統括に揃えるかを確かめてもらう。
