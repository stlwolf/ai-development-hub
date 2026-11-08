---
id: "01M6Y1Z16VYRBD1DKTB1C80V3B"
title: "#515 SOの重複判定と理由の取り違えを修正する"
date: 2026-11-09
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/515"
    reason: "作業対象"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-09-plan-515-unique-so-verdict.md"
    reason: "実装計画"
tags: [so-verdict, verification]
---

# #515 SOの重複判定と理由の取り違えを修正する

## なぜこの作業が始まったか

SOの回答がrefutedと書いた後、修正後の例にsurvivedを書くと、最後の行が採られて成功扱いになる。理由も別の部分から混ぜていた。ownerが認識合わせの内容を了承し、作業を進めるよう指示した。

## 実装と根拠

共有libの判定認識には既存のgrepの条件を維持し、有効な判定が1件のときだけ採る。複数なら同値でもunknownを返し、集計時のレーンはerrorとする。dissentには「VERDICT行が複数」「判定不能」と書き、回答が反証されたと断定しない。全体集計は既存の保守的なrefuted・exit 3を維持する。

一意な判定の後、次のVERDICTラベルまでの最初のREASONを採る。未記入のテンプレート例も理由を読む範囲の区切りにする。理由の本文をawk -vへ渡すとバックスラッシュを再解釈するため、引数は行番号だけとし、本文をファイルから読む。

## 検証

回帰テストを先に追加した時点ではPASS=17・FAIL=16だった。修正後は33項目すべて成功した。実際のoe-refute / oe-reviewをスタブ付きで起動する検査も追加し、重複がレーンのerrorとして記録され、全体がsurvivedにならないことを確認した。

追加したoe-reviewのCLIテストでコマンド置換と算術展開の区別が曖昧な書き方になり、ShellCheckのSC1102が出た。コマンド置換の直後に空白を入れて修正した。

関連4スイート244項目が成功した（共有抽出33・oe-refute72・oe-review73・#448の劣化判定66）。ShellCheck 0.11.0、bash -n、git diff --checkも成功。Bash 3.2はこの環境に無く未確認。実際のAIレーンは呼ばず、クラウドでのSOはownerの省略指示に従った。

## 残り

PR #606のCopilotレビューは指摘0件・Approval recommendedだった（review ID 5818798821、対象コードddf8402）。行コメント・レビューのスレッドも0件で、返信対象は無かった。ownerのレビュー・マージ判断を待つ。#516の一般的なmeta判定は範囲の外。SOを実施したとは数えない。
