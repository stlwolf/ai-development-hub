---
id: "01M6Y1Z16T5H4RBCWWZCT1J6QM"
title: "#515 SOの判定を1件に限定して理由と組にする"
date: 2026-11-09
type: plan
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/515"
    reason: "対象issue"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/515#issuecomment-6723097237"
    reason: "ownerが内容を了承し、作業を進めるよう指示した認識合わせ"
tags: [so-verdict, verification]
so:
  design: weak
  impl: weak
  reason: "共有の判定抽出と回帰テストに範囲を限定する。クラウドでのSOはownerの明示指示により省略する"
---

# #515 SOの判定を1件に限定して理由と組にする

## Contextと範囲

反証の後の例に書かれたsurvivedが採用され、判定と理由も別々の部分から取られていた。認識合わせで「有効なVERDICTが複数なら同値でもerror」「一意な判定に続くREASONを採る」と定め、ownerから内容の了承と作業を進める指示を受けた。SOはクラウドでの省略指示を引き継ぐ。

## 作業と検証

- [x] 確定版の認識合わせを#515へ投稿する。
- [x] 反証→成功・逆順・同値の繰り返しと、理由の取り違えを回帰テストにする。
- [x] 共有の判定・理由の抽出をそろえ、複数の判定を判定不能と説明する。
- [x] 正常な大小文字・末尾の補足・未記入のテンプレート例の許容を維持する。
- [x] 実際のoe-refute / oe-reviewをスタブ付きで起動し、error・集計結果・終了コードを確認する。
- [x] #448の劣化判定も含む4スイート244項目、ShellCheck、bash -n、git diff --checkを確認する。
- [x] PR #606を作成し、Copilotの1ラウンドを確認した（指摘0件・Approval recommended）。
- [x] macOSのawkについてのローカルレビューに対応し、mawkとOne True Awk 20200816の双方で各244項目を確認した。
- [x] ローカルの統括で再確認して問題なしとの報告を受け、ownerからマージ・後片付けの指示を受けた。

検証コマンドは `bash projects/orchestration-engine/tests/test_so_verdict.sh`、同じtests配下の `test_oe_refute.sh`・`test_oe_review.sh`・`test_so_compare_tool_status.sh`。変更したシェルファイルに `shellcheck -x -P SCRIPTDIR` と `bash -n` を実行する。

## 契約と範囲の外

有効な判定の認識条件は既存のgrepを維持し、行番号を使って理由を同じ判定部分から読む。理由の本文はawkの引数にしない。重複時のレーンはerrorだが、既存の保守的な全体集計ではrefuted・exit 3になる。これは回答内容が反証されたという意味ではないため、dissentのnoteには判定不能と書く。

#516の一般的なmeta・終了状態の扱い、nonce方式や出力形式全体の変更は含めない。Bash 3.2での実行は環境に無いため未確認として記載する。
