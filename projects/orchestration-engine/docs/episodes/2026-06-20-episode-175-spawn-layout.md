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

> `reconstructed`: 本 episode は作業中のリアルタイム追記ではなく closure 時に 1 パスで記述（証拠アンカー = oe-refute audit_id / テスト件数 / git stash 実証 / Copilot diff `4426f17` は直接取得）。リアルタイム追記ログと同列の証拠価値は持たない。
>
> closure 2 段: 初版は PR #192 作成時点。本版は **PR 後の外部ゲート（Copilot レビュー）+ 親 compliance review を畳んだ最終 closure**（実装は `4426f17` で確定・本 closure はコード非変更）。

## Context / なぜ

orchestration-engine の `lib/spawn.sh` は盤面構築を `wez pane split --bottom --percent 30 --wait-ready` でハードコードし、`oe_spawn_prepare_pane` が都度ペインを作っていた。#191 で `wez layout apply --json`（宣言的盤面・pane_id map 返却・非冪等）が landed したので、engine の機械1サイクル（envelope → spawn → monitor → verify → cleanup）を「規約ベース盤面」で再現的に成立させる（#169 cockpit 本線の機械オーケストレ層整備）。

## 次の消費者

- **#177（観測 UI）/ cockpit 本線**: 規約ベース盤面の上で 1 サイクルが回る前提を引き継ぐ。
- **将来 multi-agent board**: 本 PR の `OE_BOARD_LAYOUT` / pool 機構 + fallback split を土台に拡張（preset 差し替え・engine 専用 preset 化）。
- **親 %32（消費済）**: compliance review（ADR-005/bash 互換）+ Copilot を実施済。残る消費者は **マージを判断するユーザー**（PR #192 は MERGEABLE/CLEAN・保留中）。

## やったこと（要件 → 実装）

- `oe_board_apply()`（spawn.sh 新規）: `wez layout apply "$OE_BOARD_LAYOUT" --json` を **1 回**呼び、pane_id map を pool（`OE_BOARD_PANE_IDS`）化。全 board ペインを `OE_BOARD_MANAGED_PANES` に登録（cleanup 回収）。max-panes ガード / partial-apply orphan 回収 / 失敗時の board 無効化（fallback）。
- `oe_spawn_prepare_pane()` 改修: pool から FIFO pop（空なら従来 split にフォールバック）。`OE_SPAWN_PANE_ID` の意味は不変。
- `oe_board_wait_ready()`（新規）: layout 経路に無い `--wait-ready` を engine 側で補う readiness poll（best-effort）。
- `bin/oe`: spawn 前に `oe_board_apply` を 1 回（盤面初期化と都度 spawn の責務分離）。
- `cleanup.sh`: 3 配列（MANAGED + VERIFY + BOARD）の dedup union を kill + killed_pane_ids 化。
- パラメータ化: `OE_BOARD_LAYOUT`（既定 parent-children・空で kill switch）、`OE_SPAWN_PERCENT`（既定 30）。
- `test_e2e_smoke.sh`: mock に `wez layout apply --json` 追加 + board 適用/fallback 不使用のアサーション。
- **PR 後の Copilot ラウンド（`4426f17`・親 %32 が実施）**: C1（partial 分岐の到達不能 = orphan 回収 dead code）と C2（`oe_board_wait_ready` の非数値 timeout クラッシュ）を修正し `tests/test_spawn_board.sh`（true-repro・16 アサーション）を追加。詳細は「事実・失敗」。最終コードは `4426f17` で確定。

## 決定と根拠（→ discussion 2026-06-20-discussion-175-spawn-layout.md が正本）

- **採用 = 案C+**（board が 1 サイクルの 2 役 target=pool[0]/reviewer=pool[1] を宣言・FIFO 消費・split fallback）。
- 棄却: 案A（毎回 layout apply → 非冪等で倍増・test 破壊）/ 案D（engine 専用 preset 新規追加を既定化 → cross-project 所有・Minimal Scope 逸脱、`OE_BOARD_LAYOUT` での将来差替に defer）。
- **案B（reviewer 常時 split・decouple）との分岐**: SO（cursor レーン）が「全 board 登録すれば案B でも orphan を防げ、reviewer 結合を消せる」と breadth 指摘。再検討の上で **案C+ を採用** — 受け入れ条件の核「1 サイクルが**規約ベース盤面**で成立」に最も忠実（盤面が target+reviewer を宣言）、既存 parent-children を新規ファイル無し・空ペイン無しで完全消費。reviewer 結合は「盤面が 1 サイクルのペイン集合を宣言する」意図そのもので 1 サイクル限定、N>pool は fallback split が吸収。**この分岐は後戻りコスト中・可逆のため自律確定し、PR で %32 に明示**（human gate へ）。

## 事実・失敗（選択的省略なし）

- **oe-refute 1 回目: `refuted`（2/2 レーン・audit_id 20260620043537W4YCNF4DJ0HS）**。material 指摘: (1) `--wait-ready` 回帰（layout 内部 split は readiness 待ち無し・standalone verb も無い）(2) partial-apply orphan 未処理 (3) cleanup dedup 不在 (4) step順 role 割当 / hidden cursor / reviewer 結合。→ 初期案C を **案C+ にピボット**（全反映）。
- **oe-refute 2 回目: `refuted`（2/2・audit_id 20260620044126WKFA3FJSZ8K2）**。dissent は material 設計欠陥から「微修正＋実装前 grounding」へ収束。新規 actionable: partial 登録は `rollback_failed` のみ（`created` は layout が rollback kill 済）/ `OE_CB_MAX_PANES` ガード追加 / readiness timeout 契約（warn+続行）。→ 反映。残る refute は exploration rubric が pre-implementation claim に対し grounding 軸で必ず立てる**構造的**なもの（実装+テストでしか閉じない）。reframe-on-stall 判定で 3 回目を打ち切り（同軸の再 refute = stall）、微修正を反映して実装へ（grounding は実装+テスト+%32 review で閉じる）。
- **geometry 非互換**: 旧来は target/reviewer とも bottom30% split。parent-children は worker1=bottom30% + worker2=right50%。機能後方互換は保つが視覚配置は preset に従う（「規約ベース盤面」化の意図的帰結）。
- **発見した既存債務（back-propagation）**: orchestration-engine のテストは bash 5.x でのみ検証されており、**master/HEAD 時点で真の bash 3.2 では 3 テストが落ちる**（後述・本 PR 起因ではない）。
- **C1（PR 後 Copilot が捕捉した実バグ・本 PR 由来）**: `oe_board_apply` の partial 分岐が**到達不能（dead code）だった**。#191 layout の realistic な partial は **exit 5（`WEZ_EXIT_PANE_OP_FAILED`）+ stdout `{status:"partial", rollback_failed:[...]}`** で返るが、初版（`d02ebca`）の早期 return 条件が `rc != 0 || -z "$map"` だったため、rc=5 で `status=="partial"` 分岐（`rollback_failed` orphan の cleanup 登録）に到達せず orphan 回収が死んでいた。**oe-refute は「partial-apply orphan を処理せよ」と指摘し分岐を追加させたが、その分岐が rc ガードに遮られ inert になっていることまでは捕捉できなかった**。修正（`4426f17`）: 早期 return を **stdout ベース（`-z "$map"` のみ）** にし、map 非空なら rc に関わらず status で dispatch。
- **C2（同 Copilot・堅牢化）**: `oe_board_wait_ready` の非数値 `timeout` が `timeout_ms=$(( timeout * 1000 ))` で `set -e` 即クラッシュ。`^[0-9]+$` 検証 + 安全 default フォールバックへ。両 Copilot スレッド返信済。
- **親 compliance review の mis-verify（ゲートの穴）**: 親 compliance は PASS（shellcheck / 両 bash / ADR-005 / 後方互換 / 設計証跡）だったが、**edge テストに非現実 mock（partial+rc=0）を使ったため C1（realistic partial=rc=5）を見逃した**。外側ゲート（Copilot）が内側ゲート（子 self-review + 親 compliance）の穴を埋めた。

## わかったこと（W）

- **bash 3.2.57 empty-array 実測**: `${#arr[@]}`（length）と `${arr[@]+"${arr[@]}"}`（guarded）は空配列でも**安全**。**bare `"${arr[@]}"` のみが空配列で unbound クラッシュ**。→ 本 PR の新規コードは全て安全側パターンを使用。
- layout 経路は `--wait-ready` を持たず、`_wez_wait_pane_ready` は pane.sh private で standalone verb が無い（#191/#190 本体は変更不可）→ engine 側に readiness poll を持つしかない。
- exploration rubric の oe-refute は pre-implementation の設計 claim に対し grounding 軸で構造的に refute する（実装証跡が無いため）。**SO の価値は verdict の survived/refuted そのものより、surfacing した material 指摘の質**にある（2 回で wait-ready 回帰・dedup・partial・max-panes を捕捉 = ゲートの実価値）。
- **#191 layout の partial は exit 5 + stdout 併出**（`{status:"partial", rollback_failed:[...]}`）。`wez` 系の「失敗 rc でも stdout に構造化結果を返す」契約を消費側が `rc` 単独で早期 return すると、stdout ベースの分岐が dead code になる（C1 の根因）。**rc と stdout の両方が情報を持つ CLI は stdout 優先で分岐すべき**。
- **指摘の「実装」と「有効化」は別**: oe-refute が partial 処理を指摘 → 分岐を追加したが、別のガード（rc 早期 return）に遮られ inert だった。**指摘の反映はコードの存在で終わらず、到達可能性（realistic 入力で実行されるか）まで検証して初めて閉じる**（C1 のメタ）。

## 検証

- `shellcheck`: 変更 5 ファイル CLEAN。
- 全 14 テスト（default bash 5.2.37）: **PASS=0 FAIL なし**（e2e_smoke 46/46・verify 104・cleanup 19 等）。
- **forced bash 3.2.57**（内側 `bin/oe` も 3.2 に固定）: 本 PR が触る経路は PASS（e2e_smoke 46/46 board 経路・verify 104・board 無効化 kill-switch の fallback split smoke は exit0/state=success/killed[777,888]）。
- 既存 3 失敗（test_cleanup の reviewer-pane 無ガード空配列ループ / test_monitor の `declare -A` / test_oe_delegate の `CLAUDE_ARGS[@]`）は **HEAD でも同様に落ちる pre-existing**（git stash で実証）。本 PR 起因の回帰はゼロ。
- **C1/C2 修正後（`4426f17`）の検証**: `tests/test_spawn_board.sh` 追加（true-repro: pre-fix FAIL → post-fix PASS）。partial(rc=5) で `rollback_failed`（999）が cleanup 登録される / status==ok で pool 構築 + 全 board ペイン登録 / 空 stdout で fallback（partial 登録しない）/ 非数値 timeout で set -e クラッシュしない、を assert。**bash 5.2.37 と forced 3.2.57 の両方で 16/16 PASS**（本 closure で再実行・確認）。

## ゲートと SO（heavy: 意図起動の oe-refute 2 本）

- predecision-exploration + 受け入れ条件「Episode + so-compare」を `oe-refute --rubric exploration --lanes 2`（codex,cursor・so-compare を wrap）で充足。2 回実行・verdict/dissent/audit_id を discussion に確定前転記（output_dir は揮発のため要点を本文保全）。
- SO 出力: `tmp/oe-refute-20260620043537W4YCNF4DJ0HS/` ・ `tmp/oe-refute-20260620044126WKFA3FJSZ8K2/`（gitignore 済 = コミットされない揮発パス。要点は discussion / 本 episode に転記）。
- **PR 後の外部ゲート（Copilot レビュー・PR #192）**: C1（実バグ・partial 到達不能）+ C2（timeout 堅牢化）を捕捉 → `4426f17` で修正・両スレッド返信済。**ゲート積層の実証**: 設計ゲート（oe-refute）→ 子 self-review → 親 compliance → 外部 Copilot の順で、内側が見逃した穴を外側が反復捕捉した（oe-refute は partial 分岐を追加させたが inert 化を見逃し、compliance は非現実 mock で realistic partial を見逃し、Copilot が realistic 条件で捕捉）。

## follow-up routing

- **既存 bash 3.2 債務**（本 PR 起因でない・Minimal Scope 外）→ **%32 へ報告し別 issue 判断に routing**: (a) cleanup.sh の `for reviewer_pane in "${OE_VERIFY_MANAGED_PANES[@]}"` 無ガード no-op ループ (b) test_monitor.sh の `declare -A`（ADR-005 違反・テスト側）(c) bin/oe-delegate の `CLAUDE_ARGS[@]` 無ガード。いずれも master で真 3.2 時に落ちる。behavioral-rule §4 に従い「別提案」として %32 に上げ、本 PR では触らない。
- engine 専用 preset（oe-cycle.json）化 → 必要時に別 issue（本 PR は既定 parent-children 流用）。
- multi-target（`oe_verify_run_phase` 複数 target）での pool 不足の非対称 → fallback split で吸収。将来 multi-agent board は別 issue。
- 真の冪等 board / desired-state ensure → #191 defer（schema v2）。
- **compliance-review の realistic-mock 規律**（C1 mis-verify の再発防止）→ %32/人の判断で別 doc/skill 化候補（本 episode では routing のみ）。
- **完全移譲の closure 所有規約**（子が Copilot ラウンド〜closure まで回す）→ 委譲フロー（`delegate-task`/engine 駆動層）への反映候補（%32/人の判断）。

## 蒸留シグナル

- **Decision 昇格**: 現時点では無し（layout 規約は ADR-004 DJ-9 に既存。engine 側の board 消費規約は 1 サイクル PoC の段階で、multi-agent board 確立時に昇格候補）。
- **negative knowledge 候補（#62）**: (a)「bare `"${arr[@]}"` は bash 3.2 で空配列クラッシュ・`${arr[@]+...}` を使う」は ADR-005 に既存（実測で裏取り）。(b)「`wez` 系は失敗 rc でも stdout に構造化結果を返す（partial=exit5+JSON）→ 消費側は rc 単独でなく stdout 内容で分岐」（C1 根因・転用可能な対構造）。

### プロセス蒸留シグナル（完全移譲実験のメタ学び）

- **ゲート積層が機能する（反復実証）**: 外側ゲート（SO / Copilot）が内側ゲート（子 self-review + 親 compliance）の穴を反復捕捉。#165 では SO が `local -n`、#192 では Copilot が C1 を捕捉。**compliance の委譲テストは非現実 mock（partial+rc=0）で realistic 条件バグ（rc=5）を見逃す** → 行き先: compliance-review チェックリストに「依存先の実 exit/stdout 契約に一致する realistic mock を使う」を足す候補（%32/人の判断）。
- **委譲モデルの構造的学び**: 「子が PR で停止」モデルは **episode が PR 時点で不完全になり Copilot 以降が宙に浮く**。完全移譲では **子が Copilot ラウンド〜closure まで回す**のが正（今回は親が Copilot をやり戻し→本 closure で是正・次回から子が回す）。3 つの第三者視点（SO・親・Copilot）を動的に回し、負の FB は「全保存」でなく「**発見できる仕組み**」を残すのが本筋 → 行き先: 委譲フロー（`delegate-task` / engine 駆動層）の closure 所有規約として検討候補（%32/人の判断）。
- **fresh session への guidance 伝播は有効**: CLAUDE.md / memory 由来の規律（oe-refute 設計ゲート自己選択・bash 3.2 自己適用・4 層 docs・reframe-on-stall）が新規子セッションで自走した。
- **運用知**: 自律委譲子は `--permission-mode auto`（`bypassPermissions` は spawn 時に死ぬ）。
- **skill / rule**: 上記プロセス学びの skill/rule 化は **候補（昇格は %32/人の判断）**。本 episode では昇格せず routing のみ。

## status

達成（stable）。受け入れ条件: 規約ベース盤面で 1 サイクル成立（e2e_smoke で機械検証）✓ / 既存テスト回帰なし + shellcheck ✓ / engine 運用ゲート（Episode + so-compare = oe-refute 2 本）通過 ✓。**PR #192 は外部ゲート（Copilot）+ 親 compliance を通し self-complete（MERGEABLE/CLEAN）、C1/C2 は `4426f17` で修正済**。**マージは保留＝ユーザー判断**。本 episode をもって closure 完了（Copilot ラウンド〜closure を畳んだ最終版）。

## Step 4 外部チェック（heavy tier）

Step4 辞退: closure 品質（失敗の選択的省略 / routing 網羅 / evidence anchor / back-propagation）の 4 観点が既存チェックで覆われている。**失敗の選択的省略**は本版で C1（自分の実バグ）・C2・親 compliance の mis-verify を省略せず記載し、かつ **C1 は Copilot が独立に捕捉済（外部接地・自己評価のみではない）**。**routing**は全 follow-up（bash 3.2 債務 3 件 / preset / multi-target / compliance realistic-mock / 完全移譲 closure 所有）に行き先付与。**evidence anchor**は oe-refute audit_id・`4426f17`・テスト 16/16（両 bash 再実行）を転記。**back-propagation**は既存 bash 3.2 債務と C1 根因（#191 の exit5+stdout 契約）を反映。設計は oe-refute 2 本 + Copilot で別レーン検証済。本 closure は %32 へ報告し人が読む。/ 既存チェックで覆った観点: 省略チェック（Copilot 外部接地）/ routing / evidence anchor / back-propagation / 未実施観点と判断: なし。
