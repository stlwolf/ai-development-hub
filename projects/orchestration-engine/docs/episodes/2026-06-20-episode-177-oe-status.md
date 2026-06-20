---
id: "01KVJHAJ2N3RQ84SVNZ7BBK3YS"
title: "#177 oe-status — cockpit 観測UI（read-only 俯瞰 + 監査ログ閲覧）実装"
date: 2026-06-20
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/177"
    reason: "本 episode の対象 Issue（cockpit 観測UI: 子エージェント状態俯瞰と監査ログ閲覧）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-06-19-discussion-cockpit-observation-ui.md"
    reason: "設計探索の正本。§8 で DJ-2/DJ-3 再設計を確定（本 episode が実装）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "identity は基盤ごと・read 時相関・永続マップ無し＝本俯瞰の前提"
tags: [orchestration, cockpit, oe-status, observation, audit, read-only, episode]
---

# #177 oe-status — cockpit 観測UI 実装 episode

> 本文は作業中リアルタイム追記（reconstructed ではない）。closure は `episode-retrospective`。

## 設計フェーズ（2026-06-20）

- kickoff（`.oe/kickoff-177-oe-status.md`）+ discussion §1-7 + decision-188 + schemas を読了。当初 plan（pane_id ジョイン）は §6 で撤回済 → #188 確定後の再設計が本タスク。
- **駆動層フロー（engine 規約）**: discussion/DJ → 設計SO → 実装 → 実装SO（oe-review）→ Episode → PR。本 episode はその実行記録。
- **設計SO（predecision-exploration 兼）= `oe-refute --rubric exploration --lanes 2`（codex+cursor）を 2 ラウンド**:
  - R1（flat 1テーブル fusion + 素朴 audit-tail）→ refuted。**新カテゴリ「単一コマンド typed sections」が出現**。flat fusion の STATE/TIMELINE 列混同が判明。
  - R2（typed sections + audit-terminal reducer）→ refuted だが**カテゴリ収束**（両レーン「typed sections 有望」）。残りは grounding 詳細（verification_timeout 誤分類 / multi-pane で blocked 隠れ / interrupt 誤分類 / max_turns→blocked 写像 / CB schema↔impl drift / 優位主張の未立証 / preview 境界）。
  - 新カテゴリが出ない R2 で predecision-exploration の暫定停止条件を満たし、grounding を設計へ織り込んで**確定**（discussion §8）。証跡: `tmp/oe-refute-*`（揮発・verdict/reason は §8 へ転記）。
- **確定（DJ-2再/DJ-3再）**: 単一コマンド・typed sections（`=== ENGINE ===` / `=== DELEGATE ===`）。engine=audit-terminal reducer（severity-max）由来 state、delegate=liveness のみ（timeline:none）。read-only airtight（ペイン出力を一切読まない・preview は ENGINE=audit timeline / DELEGATE=registry メタのみ）。優位主張は取り下げ（owner 既決方向の正直な描画＝十分性で確定）。

## 実装フェーズ

- **`bin/oe-status`**（新規）: 単一コマンド typed sections。`_oe_status_reduce`（jq・severity-max audit-terminal reducer）/ `_oe_status_engine_section` / `_oe_status_delegate_section`（oe_reg_list 投影・tmux 不在 degrade）/ `_oe_status_timeline`（受入2）/ `_oe_status_preview`（fzf 用 dispatch）/ `_oe_status_interactive`（DJ-1(b)）。`OE_DATA_DIR`/`OE_AUDIT_DIR`/`OE_STATE_DIR` override。bash 3.2 互換（declare -A/mapfile 不使用）。
- **`tests/test_oe_status.sh`**（新規・27 assert）: fixture audit/state で 8 reducer ケース（success/blocked/timeout/running?/interrupted/multi-pane-blocked/verification_timeout/max_turns）/ 注記 / KVS 補足 / DJ-4 除外 / timeline start→end / 引数ハンドリング / tmux degrade。
- **`bin/README.md` / `README.md`**: oe-status の節・索引・構成ツリーを追記。
- **検証**: `shellcheck bin/oe-status tests/test_oe_status.sh` PASS。`bash tests/test_oe_status.sh` 27/27 PASS。**/bin/bash 3.2.57（macOS）でも 27/27 PASS**（ADR-005）。実 sample（`202605261208418AW8GCYGYGY6`）+ 実 tmux でも overview/timeline 動作確認。
- **設計SO 反証の反映を実装で実証**（discussion §8.3）: timeout を CB audit-only から導出（last_event=cleanup でも state=timeout）/ multi-pane で blocked が success に隠れない（severity-max）/ verification_timeout は success のまま注記 / max_turns→blocked（limit_type フォールバック）。
- **set -e バグをテストが捕捉**: `list="$(oe_reg_list)"` が tmux 不在（rc2）で abort → `|| rc=$?` で degrade に修正（reducer 抽出も `reduced='{}'` フォールバックで堅牢化）。
- **R2(g) 反映**: preview の read-only 境界統一（DELEGATE preview は tmux capture を使わず registry メタのみ＝ペイン出力を一切読まない）。

## 範囲外として routing した発見

- **CB payload schema↔impl drift**: `schemas/audit-log.schema.json` は `payload.limit_type` と記述、実装（`lib/monitor.sh`）は `payload.reason` を emit。#177（read-only 観測）の範囲外。oe-status の reducer は `reason` 優先＋`limit_type` フォールバックで両対応。**ドリフト是正は別 issue に切るべき**（producer 側 or schema 側の統一）。

## caveat routing（誤読防止・必須）

- **oe-review.jsonl 駆動率測定は #177 v1 スコープ外（DJ-4）**。よって **#177 v1 単独では #24（L3 hook）/ Stage-B を unblock しない**（それらは別途の駆動率測定に依存）。「#177 で測定経路が揃った」と読まないこと。
