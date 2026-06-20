---
id: "01KVHMVQDN1H7284YYGD4NDSY4"
title: "#175 spawn.sh 盤面構築の wez layout 化（機械1サイクル正規化）実装"
date: 2026-06-20
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/175"
    reason: "本 episode の対象 Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-06-20-discussion-175-spawn-layout.md"
    reason: "設計探索・DJ 確定・oe-refute 2 回の反証トレース"
  - type: depends_on
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md"
    reason: "DJ-9 layout 規約（pane_id map 契約・非冪等）/ DJ-8 split targeting を消費"
  - type: depends_on
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-005-bash-shell-standards.md"
    reason: "bash 3.2/5.2 両対応（empty-array 展開・local -n 禁止）"
  - type: source_material
    ref: "projects/wezterm-ai-mode/docs/episodes/2026-06-20-episode-wez-layout.md"
    reason: "#191（消費する layout 本体）の実装 episode"
tags: [orchestration-engine, wez-layout, spawn, board, cockpit, episode]
---

# #175 spawn.sh 盤面構築の wez layout 化

> `reconstructed`: 本 episode は作業中のリアルタイム追記ではなく closure 時に 1 パスで記述（証拠アンカー = oe-refute audit_id / テスト件数 / git stash 実証は直接取得）。リアルタイム追記ログと同列の証拠価値は持たない。

## Context / なぜ

orchestration-engine の `lib/spawn.sh` は盤面構築を `wez pane split --bottom --percent 30 --wait-ready` でハードコードし、`oe_spawn_prepare_pane` が都度ペインを作っていた。#191 で `wez layout apply --json`（宣言的盤面・pane_id map 返却・非冪等）が landed したので、engine の機械1サイクル（envelope → spawn → monitor → verify → cleanup）を「規約ベース盤面」で再現的に成立させる（#169 cockpit 本線の機械オーケストレ層整備）。

## 次の消費者

- **#177（観測 UI）/ cockpit 本線**: 規約ベース盤面の上で 1 サイクルが回る前提を引き継ぐ。
- **将来 multi-agent board**: 本 PR の `OE_BOARD_LAYOUT` / pool 機構 + fallback split を土台に拡張（preset 差し替え・engine 専用 preset 化）。
- **親 %32**: compliance review（ADR-005/bash 互換）+ Copilot を回す消費者。

## やったこと（要件 → 実装）

- `oe_board_apply()`（spawn.sh 新規）: `wez layout apply "$OE_BOARD_LAYOUT" --json` を **1 回**呼び、pane_id map を pool（`OE_BOARD_PANE_IDS`）化。全 board ペインを `OE_BOARD_MANAGED_PANES` に登録（cleanup 回収）。max-panes ガード / partial-apply orphan 回収 / 失敗時の board 無効化（fallback）。
- `oe_spawn_prepare_pane()` 改修: pool から FIFO pop（空なら従来 split にフォールバック）。`OE_SPAWN_PANE_ID` の意味は不変。
- `oe_board_wait_ready()`（新規）: layout 経路に無い `--wait-ready` を engine 側で補う readiness poll（best-effort）。
- `bin/oe`: spawn 前に `oe_board_apply` を 1 回（盤面初期化と都度 spawn の責務分離）。
- `cleanup.sh`: 3 配列（MANAGED + VERIFY + BOARD）の dedup union を kill + killed_pane_ids 化。
- パラメータ化: `OE_BOARD_LAYOUT`（既定 parent-children・空で kill switch）、`OE_SPAWN_PERCENT`（既定 30）。
- `test_e2e_smoke.sh`: mock に `wez layout apply --json` 追加 + board 適用/fallback 不使用のアサーション。

## 決定と根拠（→ discussion 2026-06-20-discussion-175-spawn-layout.md が正本）

- **採用 = 案C+**（board が 1 サイクルの 2 役 target=pool[0]/reviewer=pool[1] を宣言・FIFO 消費・split fallback）。
- 棄却: 案A（毎回 layout apply → 非冪等で倍増・test 破壊）/ 案D（engine 専用 preset 新規追加を既定化 → cross-project 所有・Minimal Scope 逸脱、`OE_BOARD_LAYOUT` での将来差替に defer）。
- **案B（reviewer 常時 split・decouple）との分岐**: SO（cursor レーン）が「全 board 登録すれば案B でも orphan を防げ、reviewer 結合を消せる」と breadth 指摘。再検討の上で **案C+ を採用** — 受け入れ条件の核「1 サイクルが**規約ベース盤面**で成立」に最も忠実（盤面が target+reviewer を宣言）、既存 parent-children を新規ファイル無し・空ペイン無しで完全消費。reviewer 結合は「盤面が 1 サイクルのペイン集合を宣言する」意図そのもので 1 サイクル限定、N>pool は fallback split が吸収。**この分岐は後戻りコスト中・可逆のため自律確定し、PR で %32 に明示**（human gate へ）。

## 事実・失敗（選択的省略なし）

- **oe-refute 1 回目: `refuted`（2/2 レーン・audit_id 20260620043537W4YCNF4DJ0HS）**。material 指摘: (1) `--wait-ready` 回帰（layout 内部 split は readiness 待ち無し・standalone verb も無い）(2) partial-apply orphan 未処理 (3) cleanup dedup 不在 (4) step順 role 割当 / hidden cursor / reviewer 結合。→ 初期案C を **案C+ にピボット**（全反映）。
- **oe-refute 2 回目: `refuted`（2/2・audit_id 20260620044126WKFA3FJSZ8K2）**。dissent は material 設計欠陥から「微修正＋実装前 grounding」へ収束。新規 actionable: partial 登録は `rollback_failed` のみ（`created` は layout が rollback kill 済）/ `OE_CB_MAX_PANES` ガード追加 / readiness timeout 契約（warn+続行）。→ 反映。残る refute は exploration rubric が pre-implementation claim に対し grounding 軸で必ず立てる**構造的**なもの（実装+テストでしか閉じない）。reframe-on-stall 判定で 3 回目を打ち切り（同軸の再 refute = stall）、微修正を反映して実装へ（grounding は実装+テスト+%32 review で閉じる）。
- **geometry 非互換**: 旧来は target/reviewer とも bottom30% split。parent-children は worker1=bottom30% + worker2=right50%。機能後方互換は保つが視覚配置は preset に従う（「規約ベース盤面」化の意図的帰結）。
- **発見した既存債務（back-propagation）**: orchestration-engine のテストは bash 5.x でのみ検証されており、**master/HEAD 時点で真の bash 3.2 では 3 テストが落ちる**（後述・本 PR 起因ではない）。

## わかったこと（W）

- **bash 3.2.57 empty-array 実測**: `${#arr[@]}`（length）と `${arr[@]+"${arr[@]}"}`（guarded）は空配列でも**安全**。**bare `"${arr[@]}"` のみが空配列で unbound クラッシュ**。→ 本 PR の新規コードは全て安全側パターンを使用。
- layout 経路は `--wait-ready` を持たず、`_wez_wait_pane_ready` は pane.sh private で standalone verb が無い（#191/#190 本体は変更不可）→ engine 側に readiness poll を持つしかない。
- exploration rubric の oe-refute は pre-implementation の設計 claim に対し grounding 軸で構造的に refute する（実装証跡が無いため）。**SO の価値は verdict の survived/refuted そのものより、surfacing した material 指摘の質**にある（2 回で wait-ready 回帰・dedup・partial・max-panes を捕捉 = ゲートの実価値）。

## 検証

- `shellcheck`: 変更 5 ファイル CLEAN。
- 全 14 テスト（default bash 5.2.37）: **PASS=0 FAIL なし**（e2e_smoke 46/46・verify 104・cleanup 19 等）。
- **forced bash 3.2.57**（内側 `bin/oe` も 3.2 に固定）: 本 PR が触る経路は PASS（e2e_smoke 46/46 board 経路・verify 104・board 無効化 kill-switch の fallback split smoke は exit0/state=success/killed[777,888]）。
- 既存 3 失敗（test_cleanup の reviewer-pane 無ガード空配列ループ / test_monitor の `declare -A` / test_oe_delegate の `CLAUDE_ARGS[@]`）は **HEAD でも同様に落ちる pre-existing**（git stash で実証）。本 PR 起因の回帰はゼロ。

## ゲートと SO（heavy: 意図起動の oe-refute 2 本）

- predecision-exploration + 受け入れ条件「Episode + so-compare」を `oe-refute --rubric exploration --lanes 2`（codex,cursor・so-compare を wrap）で充足。2 回実行・verdict/dissent/audit_id を discussion に確定前転記（output_dir は揮発のため要点を本文保全）。
- SO 出力: `tmp/oe-refute-20260620043537W4YCNF4DJ0HS/` ・ `tmp/oe-refute-20260620044126WKFA3FJSZ8K2/`（gitignore 済 = コミットされない揮発パス。要点は discussion / 本 episode に転記）。

## follow-up routing

- **既存 bash 3.2 債務**（本 PR 起因でない・Minimal Scope 外）→ **%32 へ報告し別 issue 判断に routing**: (a) cleanup.sh の `for reviewer_pane in "${OE_VERIFY_MANAGED_PANES[@]}"` 無ガード no-op ループ (b) test_monitor.sh の `declare -A`（ADR-005 違反・テスト側）(c) bin/oe-delegate の `CLAUDE_ARGS[@]` 無ガード。いずれも master で真 3.2 時に落ちる。behavioral-rule §4 に従い「別提案」として %32 に上げ、本 PR では触らない。
- engine 専用 preset（oe-cycle.json）化 → 必要時に別 issue（本 PR は既定 parent-children 流用）。
- multi-target（`oe_verify_run_phase` 複数 target）での pool 不足の非対称 → fallback split で吸収。将来 multi-agent board は別 issue。
- 真の冪等 board / desired-state ensure → #191 defer（schema v2）。

## 蒸留シグナル

- **Decision 昇格**: 現時点では無し（layout 規約は ADR-004 DJ-9 に既存。engine 側の board 消費規約は 1 サイクル PoC の段階で、multi-agent board 確立時に昇格候補）。
- **skill / rule / #62**: 無し。
- **negative knowledge 候補**: 「bare `"${arr[@]}"` は bash 3.2 で空配列クラッシュ・`${arr[@]+...}` を使う」は ADR-005 に既存。今回の実測は ADR-005 の裏取り。

## status

達成（stable）。受け入れ条件: 規約ベース盤面で 1 サイクル成立（e2e_smoke で機械検証）✓ / 既存テスト回帰なし + shellcheck ✓ / engine 運用ゲート（Episode + so-compare = oe-refute 2 本）通過 ✓。PR 作成で停止（マージは %32/ユーザー判断）。

## Step 4 外部チェック（heavy tier）

Step4 辞退: closure 品質（失敗の選択的省略 / routing 網羅 / evidence anchor / back-propagation）は本 episode で自己充足し、かつ **kickoff 規定により親 %32 が compliance review + Copilot で外部レビューする**（closure を読む外部の目が確保される）。設計自体は意図起動 oe-refute 2 本で別レーン検証済（指摘・refute・ピボット・既存債務発見を省略せず記載、SO 出力パス/audit_id を転記、全 follow-up に行き先付与）。/ 既存チェックで覆った観点: routing / evidence anchor / 省略チェック / back-propagation（%32 review + 本文自己充足）/ 未実施観点と判断: なし。
