---
id: "01KWERZMJ4FPJN2EHTCNE21GQX"
title: "#92 検証ゲートの評価入力は working-tree diff 推定でなく commit 範囲（baseline..end）を正本とする — worker-commit 契約"
date: 2026-07-01
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/92"
    reason: "本 ADR の主スコープ（検証ゲート v2 の評価入力＝変更ファイル/完了報告の正本化）"
  - type: sibling
    ref: ./2026-06-30-decision-114-clean-output-channel.md
    reason: "取得/検証チャネル系の対。#114 は子出力の取得側、本 ADR は検証入力（評価単位）側"
  - type: refines
    ref: ./2026-05-16-decision-verification-gate-design.md
    reason: "検証ゲート v1（Compliance Review / pane-keyed KVS）。本 ADR は v1 の評価入力を commit 範囲へ差し替える"
  - type: source_material
    ref: ../../lib/verify.sh
    reason: "本決定の主実装（oe_verify_prompt_build の commit 範囲評価・_oe_verify_annotate_files）"
  - type: source_material
    ref: ../../lib/spawn.sh
    reason: "baseline（git_head / baseline_dirty）を worker 起動前に session_start payload へ materialize"
  - type: source_material
    ref: ../../lib/monitor.sh
    reason: "end を worker 終了（EXIT）時の HEAD に固定"
  - type: source_material
    ref: ../../lib/constants.sh
    reason: "worker-commit 完了プロトコル（target task 契約）"
  - type: episode
    ref: ../episodes/2026-07-01-episode-92-commit-range-verify-inputs.md
    reason: "本 ADR を生んだ実装エピソード（設計SO 3R → reframe → 実装SO 2R）"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/101"
    reason: "reviewer verdict チャネルの marker 注入（本 ADR と直交・別 follow-up）"
tags: [orchestration, verification-gate, commit-range, worker-commit, reframe, decision, adr]
---

# #92 検証ゲートの評価入力は commit 範囲（baseline..end）を正本とする

## コンテキスト

検証ゲート v1（[2026-05-16 ADR](./2026-05-16-decision-verification-gate-design.md)）は、検証 agent（Compliance Review）へ「変更ファイル一覧」と「完了報告」を渡して実装の妥当性を評価させる。v1 はこれを **working-tree diff の推定**で得ていた（`oe_verify_prompt_build` が KVS `outputs[]`、空なら `git diff --name-only` フォールバック）。#92 はこの入力の質不足（F-SO-8: 変更ファイル per-pane 化 / F-SO-9: 完了報告の充実）を扱う。

working-tree diff 推定は共有 workspace で構造的に破綻する: repo-wide `git diff` は検証対象外の dirty を拾い、commit 済みなら空になり、複数 pane 並走ではどの pane の変更か区別できない。#92 の当初 framing は「commit すると `git diff` が空になる（＝"バグ"）」だったが、これは**フレーム自体の誤り**だった（後述）。

## 決定

- **評価単位 = commit 範囲 `baseline..end`。** working-tree diff の推定を廃し、VCS の論理単位（commit）を評価する。
- **変更ファイル = `git diff --name-only <baseline>` + untracked**（＝baseline からの全 footprint。committed + 未コミット残余の両方を捕捉）。baseline 時点で既に dirty だったパスには `pre-existing at baseline` 注記を付け、worker の `git add -A` 巻き込みを可視化する。
- **完了報告 = `git log baseline..end`**（skill 契約の「コミットログ」に合致）。旧 state enum 1 個の受け渡しを置換。
- **worker-commit 契約を engine の target task に付与**（`lib/constants.sh` の完了プロトコル: 「作業完了後に自分の変更のみを git commit してから終了。1行目に何を・なぜ」）。検証はその commit 範囲を評価する。
- **baseline は worker 起動前**（`lib/spawn.sh`・session_start payload の `git_head` / `baseline_dirty`）、**end は worker 終了（EXIT）時の HEAD に固定**（`lib/monitor.sh`。verify 遅延や後続 commit で範囲がずれるのを防ぐ）。
- **degraded フォールバック**: 非 git / baseline 未解決（`attach.sh` 経路等）では working-tree diff へ明示的に縮退する（安全側）。

## 実装

- `lib/verify.sh`: `oe_verify_prompt_build` を commit 範囲評価へ変更 + `_oe_verify_annotate_files`（baseline-dirty 注記）。
- `lib/spawn.sh`: baseline を send **前**に確定（send 後だと worker 変更が baseline に混入する競合窓が残る）。
- `lib/monitor.sh`: end_head を worker 終了時に固定。
- `lib/envelope.sh` / `lib/constants.sh`: 完了プロトコルを target の `task.description` 末尾へ付与。
- 単一 UC（1 worker）スコープ。テスト 23 ファイル green（bash 5.2）・shellcheck clean。

## 根拠

- **なぜ commit が効くか**: commit は論理単位で、baseline からの diff が worker の footprint を過不足なく与える。単一 writer 前提なら帰属が構造的に決まる（推定でなく事実）。「commit で `git diff` が空＝問題」を「**commit を評価するのが設計**」へ反転した。
- **reframe の経緯**: 設計SO を 3 ラウンド回した。v1（raw transcript embed）/ v2（F-SO-8-lite + F-SO-9-pull）はいずれも **2/2 refuted**——working-tree diff で推定する限り pane-blind / dirty 混入 / marker 注入（#101 既知弱点）が構造的に残る、と判明。**2 回の structural refuted を「フレームを疑え」の信号**（`reframe-on-stall-rule`）と捉え、3 回目で patch を重ねず、ユーザーの zero-base reframe（評価単位を commit にする）に乗ったことで root が溶けた（設計 D）。設計SO v3 は「有望・ただし worker commit 遵守が未検証」と structural kill から grounding-gap へ収束。
- **実装SO が別レンズで material 欠陥を捕捉**: 実装後 `oe-review` v1 が refuted（部分コミット時に未コミット残余が漏れる / commit あるのに diff 空だと degraded へ誤フォールバックし事実矛盾）。変更ファイルを `baseline..end`[committed のみ] → `git diff <baseline>` + untracked[全 footprint] に修正し v2 で survived。設計SO 通過 ≠ 実装SO 代替（[#114](./2026-06-30-decision-114-clean-output-channel.md) と同じ再確認・#192 の false-pass 回避）。

## 棄却・defer 案

確定前に `oe-refute --rubric exploration`（設計SO 3R・lanes=codex/cursor）で外部化。

| 案 | 判定 | 理由 |
|---|---|---|
| working-tree diff 推定（v1 現状） | ❌ 破棄 | 共有 workspace で pane-blind / dirty 混入 / commit 後 空。フレーム自体が誤り |
| Alt A: raw transcript を verify-inputs.md に embed | ❌ 棄却 | 未信頼入力の注入面・skill 契約（叙述報告）不一致・tail サイズ無根拠 |
| Alt B/E: pull だが working-tree 前提 | ❌ 棄却 | pull は妥当だが working-tree 推定を残す限り pane-blind/dirty が解けない |
| output_dir スコープ | ❌ 棄却 | 契約が緩く（絶対パス / repo 外 /tmp で git 破綻）Compliance が見たい範囲外変更も落とす |
| **commit 範囲 `baseline..end`（採用）** | ✅ 採用 | 論理単位・単一 writer で帰属が構造的に決まる・skill 契約と合致 |
| multi-pane 帰属（per-pane branch/worktree） | ⏸ defer | 同一ブランチで commit 交錯。commit-range 基盤 + worktree 合流 path として別 follow-up（着手条件＝multi-pane を実際に行使する時） |

## 結果

- 検証入力（変更ファイル・完了報告）が単一 UC で **commit 範囲から構造的に決まる**（推定でなく事実）。検証ゲート v1 の working-tree フォールバックを置換。
- **未検証 residual の上に立つ**: 「worker が実際に commit するか」は実装前に証明不可。人間ゲートで「文書化 residual を前提に作る」と承認の上で構築（exploration rubric の SO は empirical 仮定が残れば refute し続けるため、承認は人間の役）。degraded フォールバックで未コミット時も安全側へ縮退。
- **follow-up**（routing 済み）:
  - multi-pane 帰属（per-pane branch/worktree）→ #92 本文 + README に明記。
  - reviewer verdict チャネルの marker 注入 → [#101](https://github.com/stlwolf/ai-development-hub/issues/101)（直交・別 issue）。
  - worker commit 遵守率 → e2e / dogfood で fallback 率として実測。
  - `git status --porcelain` の quoted-path パース（baseline_dirty 注記が外れ得る）→ 追わない（低頻度・注記のみの劣化）。
  - `attach.sh` 経路の baseline 欠落 → 追わない（degraded で安全）。
- SO 証跡: 設計SO 3R（audit `…4P78T7A6GM7H` / `…NMG0P7ZVB598` / `…1Q8NVTKJ0W2Z`）・実装SO 2R（`…7EMCG63SGW7P` refuted → `…KD1590C5MCT3` survived）。生出力は揮発（`tmp/oe-refute-*` / `tmp/oe-review-*`）だが verdict/要点は本文と episode に転記済み。
