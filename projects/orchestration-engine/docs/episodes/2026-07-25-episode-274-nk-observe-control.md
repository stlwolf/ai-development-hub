---
id: "01KYCGNS8VFW56AM6BBAHHJTJK"
title: "negative knowledge ループ 段5+6 — 観測記録の要素スキーマと制御候補の提示"
date: 2026-07-25
type: episode
status: draft
related:
  - type: derived_from
    ref: ".oe/plan-274-nk-observe-control.md"
    reason: "本実装の plan（gate 3 owner 承認済み・DJ-F は owner 裁定で確定）"
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

（以降、owner 裁定後の実装・gate 4 の記録を随時追記する）
