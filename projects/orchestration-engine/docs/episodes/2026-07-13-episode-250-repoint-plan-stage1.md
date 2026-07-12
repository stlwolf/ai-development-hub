---
id: "01KXBG694X6G5SCXS0QQE4EMCD"
title: "#250 episode（light）— committed→plan-stage1 dead-pointer の (b) 張替"
date: 2026-07-13
type: episode
status: stable
related:
  - type: task_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/250"
    reason: "本 episode が記録する #250 の cleanup 半分（(b) 張替）"
  - type: prior_episode
    ref: "projects/orchestration-engine/docs/episodes/2026-07-12-episode-250-distill-238-proposals.md"
    reason: "蒸留半分（PR #252）。本 episode はその §残課題の dead-pointer follow-up を実施した記録"
  - type: distilled_doc
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-238-239-succession-watchdog-design-rationale.md"
    reason: "§6.1 に残件解消を記録・張替先の hub（§4/§6）"
tags: [orchestration, distillation, cleanup, repoint, dead-pointer, episode, light]
---

# #250 episode（light）— dead-pointer の (b) 張替

## Context / なぜ

PR #252（蒸留半分）で arch rationale を discussion へ昇格した後、残件として **committed docs が gitignored な `plan-stage1.md` / `ref-plan-stage1.md` を「正本」として指す dead-pointer**（docs/#238 worktree 掃除で恒久 dead-end 化）が残っていた。owner が選択肢 (a) 移設 / (b) 張替 / (c) 許容 のうち **(b) 張替**を決定。本作業はその実施記録（親統括 `%173` からの委譲・掃除の前提整備）。

## 次の消費者

- **docs/#238 worktree を掃除する親/owner**: 本張替で dead-end 化が解消したので掃除して安全（掃除自体は HG・本 PR 外）。
- 将来 succession/watchdog の committed docs を辿る読者: `.oe/` 参照が committed 正本へ解決される。

## やったこと（機械的張替 + (a)/(b) 境界の判断）

- **6 ファイルの dead-pointer を committed 正本へ張替**（詳細は commit `0d5468a` / PR 本文の表）: lean-arch decision:113 / PR-B plan:40 / board-schema decision:12・:130・:137 / PR-A・PR-C episode の related ref / discussion §6.1・:37。
- **(a)/(b) 境界の判断（gap 検証）**: owner 条件「張替先に内容が実在することを確認」に従い、各参照が指す内容が committed に在るか一次確認した。**Q3-Q8 の解消（Q3 OS cron = PR-B plan:174 / Q7 85%閾値 = PR-B plan:94 / Q8 = board-schema decision / 全 Q 要約 = lean-arch decision §open questions）・段階1 実装（PR 分割 = 各 PR episode）・設計 SO（PR-B plan §7 + discussion §4）はすべて committed に実在** → **gap なし・(b) で完結**（(a) 移設は不要）。plan-stage1 のみに残る最深部 rationale は #250 蒸留時に owner 承認で「追わない」とした「詳細」で、ポインタが約束する substance は committed で満たされる。
- **Category 2（据え置き）の判断**: 昇格元 source 名は provenance breadcrumb として保持（張替先を明示した上で「元は .oe/... に在った」注記）。**board-schema-validator episode:37 の (e) 注記は PR #244 の実行時自己レビュー記録（「事実・失敗」ログ）ゆえ verbatim 保持**（張替は履歴の改変になるため不自然 → kickoff の裁量条項に沿って据え置き、理由をここに残す）。

## status

- **stable** / 達成度: **達成**（Category 1 の全 dead-pointer を内容実在確認の上で committed 正本へ張替・gap なし・6 ファイル・SO 不要な機械変更）。

## follow-up routing

- **docs/#238 worktree + branch の掃除**: 本張替 merge 後に **親/owner が実施**（HG）。dead-end 化の前提は解消済み。子（本タスク）はやらない。
- 「追わない」: plan-stage1 の最深部 rationale の完全移設は追わない（owner 承認 scope・(b) で substance は committed 化済み）。

振り返り不要の補足: 機械的 cleanup ゆえ heavy トリガなし（外部 SO 不要・設計判断でなく張替）。closure gate（消費者明示 / status=stable / 全 follow-up routing）は上記で充足。
