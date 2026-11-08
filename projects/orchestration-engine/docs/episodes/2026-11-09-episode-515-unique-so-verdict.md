---
id: "01M6Y1Z16VYRBD1DKTB1C80V3B"
title: "#515 SOの重複判定と理由の取り違えを修正する"
date: 2026-11-09
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/515"
    reason: "作業対象"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-09-plan-515-unique-so-verdict.md"
    reason: "実装計画"
tags: [so-verdict, verification]
promotion:
  - subject: "一意な判定と対応する理由だけを採用する"
    verdict: not-required
    ref: "本文: 実装と根拠"
  - subject: "Mac系awkで判定抽出を検証できるようにする"
    verdict: not-required
    ref: "本文: macOSのawkについてのローカルレビューと修正"
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

PR #606のCopilotレビューは指摘0件・Approval recommendedだった（review ID 5818798821、対象コードddf8402）。行コメント・レビューのスレッドも0件で、返信対象は無かった。その後のローカルレビューと再確認の結果は末尾のclosureに記録した。#516の一般的なmeta判定は範囲の外。SOを実施したとは数えない。


## macOSのawkについてのローカルレビューと修正

PR #606の[ローカルレビュー](https://github.com/stlwolf/ai-development-hub/pull/606#issuecomment-6724571818)で、macOSのawk version 20200816が通らないと報告された。`print` に渡す比較・条件式の括弧が無く、行番号を改行入りの `-v` 引数で渡していた。mawkだけで検証したため、この違いを拾えていなかった。

One True Awkのupstream commit `9804285af0866f90731a6e0ce767ab0e7b23b6c6`（version 20200816）をLinux上でビルドした。yaccが無かったため、byaccのupstream mirror commit `7856d035dd27104782612818630adc5011214c31` も一時ディレクトリでビルドした。公開アーカイブの取得先が403を返したのでGitHub上の公開ソースから取得した。これらは作業用の一時ファイルで、repoへソースやバイナリを追加していない。

修正前はレビューと同じ2種類の構文エラーを再現し、抽出テストPASS=18・FAIL=15、oe-refute pass=55・fail=17、oe-review pass=62・fail=11だった。

行番号を空白でつなぎ、splitも空白を使い、printの式全体を括弧で囲んだ。3つのテストに `SO_TEST_AWK` で実行ファイルを指定する手段を追加した。CLIテスト内でPATHを作り直す場合も、選んだawkを使わせる。手順は `tests/README-so-verdict.md` に残した。

修正後はmawk 1.3.4とOne True Awk 20200816のそれぞれで、関連4スイート244項目すべてが成功した（抽出33・oe-refute72・oe-review73・#448の劣化判定66）。後者の#448テストには選んだawkへのリンクをPATHの先頭に置いて実行した。ShellCheckと構文検査も成功した。

One True Awkは同じ由来・同じ版のLinuxビルドであり、Appleの実バイナリではない。最新修正をmacOS実機のBash 3.2 / 5で再確認する作業はローカルの統括へ返す。Copilotの旧レビューは修正前のコードに対するもので、再レビューは依頼していない。


## closure

- 達成度: 達成。最新修正をローカルの統括で再確認して問題なしとの報告を受け、ownerからマージ・後片付けの指示を受けた。Bashの版別の追加件数など、報告されていない数値は補わない。
- tier: heavy。実装中の失敗と、awkの互換性についてのローカルレビューで修正が発生した。
- 次の消費者: SOの判定を読む人と、Mac/Linuxで共有libを保守する人。
- 事実・失敗: 初期回帰テストで16項目が失敗した。CLIテストのSC1102を直し、mawkでの成功だけでは検出できなかったMac系awkの2種類の構文エラーも修正した。`本文: 検証` / `本文: macOSのawkについてのローカルレビューと修正`
- 昇格の判定「一意な判定と対応する理由だけを採用する」: not-required。出力形式と機械契約で、コード・テスト・so-compareスキルだけを読んで正しく使えるため、1段目で対象外。`本文: 実装と根拠`
- 昇格の判定「Mac系awkで判定抽出を検証できるようにする」: not-required。実装の互換性と検証手段で、tests/README-so-verdict.mdに手順・検証した実装・限界を残した。独立したADRを要しない。`本文: macOSのawkについてのローカルレビューと修正`
- 残課題の行き先: 一般的なmetaの判定は#516。クラウドでのMac実機・Bash 3.2の実行は追わず、クラウドでの結果とローカルから受けた再確認の報告を区別して残す。
- Step 4の外部チェック: クラウドでSOを省略してよいというownerの明示指示に従い省略。SOを実施したとは数えない。
- status: stable。検証数・元の失敗・修正内容・ソースの版は本文にあり、一時ファイルだけを根拠にしていない。
