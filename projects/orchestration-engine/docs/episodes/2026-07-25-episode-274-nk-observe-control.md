---
id: "01KYCGNS8VFW56AM6BBAHHJTJK"
title: "negative knowledge ループ 段5+6 — 観測記録の要素スキーマと制御候補の提示"
date: 2026-07-25
type: episode
status: draft
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/pull/282"
    reason: "本実装の PR（plan は作業層 `.oe/` にあり非永続なので、確定内容と SO の要点は PR 本文と本 episode へ転記した）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/274"
    reason: "実装対象 issue（段5 観測記録 + 段6 制御）"
  - type: discussion
    ref: "projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md"
    reason: "設計正本（§4 DJ-4 の段5/段6・§6.4/6.10/6.11/6.14/6.16）"
tags: [orchestration-engine, negative-knowledge, "#274"]
---

# negative knowledge ループ 段5+6 の実装記録

## なぜこの作業が始まったか

negative knowledge ループ（収穫 → 保存 → 突合 → 注入 → 観測 → 制御）のうち、#272 で段1+2（型付き store と `validate-knowledge`）、#273 で段3+4（`knowledge-list` と brief の注入 slot）が着地した。本単位（#274）は残る段5（観測記録）と段6（制御）を v0 として実装し、ループを一周閉じる。v0 の観測は意思決定に使わない placeholder であり、段5 は「検証」を名乗らない。

## 経緯（リアルタイム追記）

- 2026-07-25: brief `.oe/brief-274-nk-observe-control.md` を受け、plan-first で `.oe/plan-274-nk-observe-control.md` を作成。gate 1 の探索木（DJ-A〜G）を §3 に外部化した。DJ-F（supersede の後継 id の記録先）は gate 0 の「note に」の解釈が2通りあったため、案B（本文 prose）を推奨として owner へ1点確認に出した。
- 2026-07-25: gate 3（owner HG）通過。plan 承認。DJ-F は案B（item 本文 prose に `superseded by <後継 ULID>`・スキーマ不変）で裁定され、遷移規則に「後継チェーンの機械照会が必要になったら typed フィールド `superseded_by` へ昇格する」という昇格条件を1行添える条件が付いた。他の DJ は recommend どおり採用。
- 2026-07-25: worktree `feat/#274_nk-observe-control` を子が自作し、本 episode の枠を作成。gate 2 設計SO（`so-compare` 弱・3レーン = codex / claude opus-high / cursor）を起動。反証面は owner 指定の DJ-B/C の縁（ref の揮発層拒否・note の1行制約・集計表示形式・`invalid` バケット）で、gate 0 の決定は反証外。ゼロベース拡張を折り込み gate 1 の実 SO と兼ねる。

- 2026-07-25: gate 2 設計SO の結果。**実返却は2レーン**（codex 410秒 / cursor 107秒）で、**claude レーンは 720 秒のリトライ後も空返却**（`timeout_empty`）。弱 SO の終了条件では実返却が1レーン以上あれば disclose して進めるため SO 未実施扱いにはしないが、3レーン想定に対して1レーン欠けた partial である。2レーンが独立に収束し、material な欠陥を6件検出した（`ref` hygiene の対称コピーによる偽陽性 / 制御候補が status を見ない sticky さ / 不正な observation から候補が立ち human で黙殺される / jq `strptime` がカレンダー妥当性を保証しない実測 / JSON 回帰契約の未定義 / 書き戻しの完全性が機械検知不能）。要点と改訂内容は plan §9 に転記した（生出力 `tmp/so-274-design/` は非永続）。
- 2026-07-25: owner 指示（material が出たら差し戻し）に従い、実装に入らず親統括へ差し戻した。owner 判断を仰ぐ点は3つ（`schema_version` の bump / `--strict` の意味論を広げるか / item の top-level `date` にも厳密なカレンダー検査を広げるか）。

- 2026-07-25: owner が material 6件の改訂をすべて採用し、判断3点を裁定（#274 コメントが正本）。schema_version は据え置き（additive・回帰テストで既存キー不変を機械固定）/ `--strict` は広げず meta の `integrity_issues` と二段チェックの明文化で可視化 / top-level `date` も同じ純 jq ヘッダで暦厳密化（同一ファイルの同一バグの片割れを残さない）。gate 3 GO を受けて実装に着手した。
- 2026-07-25: 実装。`validate-knowledge` の observations 検査を要素スキーマへ差し替え（jq 1 パスで違反1行・here-string で受けて warn に積む）、暦検査を純 jq の `cal_ok` にして observations.date と top-level date の両方へ適用、`knowledge-list` に集計・制御候補フラグ・`integrity_issues` を additive で追加。spec の knowledge 節に要素スキーマと status 遷移規則、`episode-retrospective` に観測書き戻しの Step、`doc-flow-guardrail` に往復の締めと二段チェックを追加した。
- 2026-07-25: 実測での確認。テストは `test_validate_knowledge` 138 assertion / `test_knowledge_list` 117 assertion がすべて green。`shellcheck` は 4 ファイルとも clean（jq プログラムの単一引用は SC2016 を意図的に disable）。本番 store に対する human 出力は master 版と **byte 一致**（`diff` で確認）、`--json` も追加5フィールドを除けば master と一致した。本番 store の実 item 3件には観測を書き込んでいない。
- 2026-07-25: 途中で踏んだ非自明な失敗を2件記録する。(1) テスト内で `"exit 1（暦不正 $bad_date）"` のように**変数名の直後に全角括弧**を置くと `set -u` 下で「未割り当ての変数」として落ちた（`${bad_date}` で回避）。(2) 最初に書いた smoke fixture が閉じ `---` と本文を欠いており、validator の「frontmatter block not found」を実装バグと誤読しかけた（fixture 側の不備だった）。

- 2026-07-25: gate 4 実装SO（`oe-review` 弱・2レーン・diff バインド・reviewed_sha `3b34810`）。**verdict は refuted**（codex が material 検出・cursor は survived。conservative 集約で全体 refuted）。codex の指摘は正しく、実測で再現した: `ref_bad` が URL と issue/PR 形式の免除を絶対パス・揮発層・`..` の検査より**先**に見ていたため、末尾に `#N` を付けるだけで hygiene を迂回できた（`../../repo#274` / `/tmp/evidence.md#274` / `/tmp/evidence.md://x`）。その ref を持つ harmful レコードが「valid な adverse 観測」として集計され、**誤った制御候補**を生成できていた。gate 2 設計SO で C1（対称コピーの偽陽性）を直した結果、逆側に穴が空いていたことになる。
- 2026-07-25: 修正。判定順を入れ替え、scheme 始まりの URL だけを hygiene 対象外にして、残りは絶対パス・先頭一致の揮発層・`..` セグメントで拒否する形にした。issue/PR 参照は hygiene のどの条件にも触れないので**免除分岐そのものが不要**で、持たせること自体が迂回路だった。迂回入力5件を validator（exit 1）と lister（invalid 集計・候補を立てない）の両方に回帰として固定し、148 + 121 assertion green。修正後の diff で実装SO を再実行した。

- 2026-07-25: 実装SO 2周目（reviewed_sha `28a18d3`）も **refuted**。codex が「`note: null` が要素スキーマをすり抜け、不正な harmful/contradicted レコードから制御候補を生成できる」と指摘（cursor は survived）。実測で確かめると、**両コマンドの判定は一致していた**（validator も lister も valid 扱い）ので、指摘にあった「契約の分裂」ではなかった。ただし spec の文言は「任意・存在時は string」であり present-but-null はそれに反するので、**厳しくする側に倒した**（書き手が note を書いたつもりで空になった記録が黙って通る余地を消す）。両方を同時に直し、contract テストの fixture に `note: null` を足して判定集合の一致で縛った。
- 2026-07-25: 実装SO 3周目を修正後の diff（`note` 修正込み）で実行。**iterate はここで止める**方針を先に決めた（弱 SO の終了条件は1周で足り、レーンが毎周新しい nit を出す構造に引きずられない）。3周目でさらに material が出た場合は自分で直さず親へ上げる。

- 2026-07-25: 実装SO 3周目（reviewed_sha `564b91c`）は **2/2 レーンが独立に同じ欠陥へ収束**した。`ref_bad` が生の文字列に先頭一致をかけていたため、先頭に空白を入れるか `./` を付けるだけで揮発層の検査を外せた。実測で ` .oe/plan.md` / `  tmp/scratch.md` / `./tmp/scratch.md` はいずれも validator が exit 0 になり、その harmful レコードが制御候補として立っていた。判定前に `ref_norm`（前後の空白除去・`\` を `/` へ・先頭 `./` 除去）を通す形にし、正規化は判定にだけ使って記録値は原文のままにした。偽陽性が増えていないことも実測で再確認した。
- 2026-07-25: 宣言どおり4周目は回さず、gate 4 を閉じた。テストは 164 + 124 assertion green、shellcheck clean。PR #282 を作成し Copilot にレビュー依頼を出した。

（以降、Copilot・closure の記録を追記する）
