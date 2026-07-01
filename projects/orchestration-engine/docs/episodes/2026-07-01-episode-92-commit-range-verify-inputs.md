---
id: "01KWEGNDJ4W0ZCYCFCJ0NDG5S5"
title: "#92 検証入力を commit 範囲評価へ — working-tree 前提の破棄と commit reframe"
date: 2026-07-01
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/92"
    reason: "本 episode の対象 issue（検証ゲート v2）"
  - type: decision
    ref: ../decisions/2026-07-01-decision-92-commit-range-verify-inputs.md
    reason: "本 episode の設計判断を蒸留した ADR（commit 範囲評価・worker-commit 契約）"
  - type: refines
    ref: ../decisions/2026-06-30-decision-114-clean-output-channel.md
    reason: "#114 のクリーン取得チャネル上で検証入力を構築。#92 は acquisition の上の『何を検証入力にするか』"
  - type: source_material
    ref: ../../lib/verify.sh
    reason: "oe_verify_prompt_build を commit 範囲評価へ変更（主実装）"
  - type: follow_up
    ref: "https://github.com/stlwolf/ai-development-hub/issues/101"
    reason: "reviewer verdict チャネルの marker 注入（本 episode スコープ外・直交）"
tags: [orchestration, verification-gate, commit-range, design-so, impl-so, reframe, episode]
---

# #92 検証入力を commit 範囲評価へ

> **reconstructed**: 本 episode はリアルタイム追記でなく、作業完了時に会話ログから再構成した。締めの構造化のみ episode-retrospective 準拠。証拠価値はリアルタイム追記ログと同列に扱わない。

## Context（なぜ）

検証ゲート（target を検証 agent が採点する）で、検証 agent への入力（変更ファイル一覧・完了報告）が貧弱だった（変更ファイル=repo-wide `git diff`、完了報告=state enum 1 個）。#114/#98 で per-pane のクリーン取得チャネルが landed した後、#92 の必要性を再評価し、必要分を実装するのが本作業。

## 経緯（失敗と撤回を含む）

蒸留パイプラインの gate（設計SO → 実装ゲート → 実装 → 実装SO）を全て踏んだ。**設計SO は 3 ラウンド refuted、実装SO は 1 ラウンド refuted**。各 refuted が設計/実装を実際に変えた。

1. **再スコープ**: #114/#98 が subsume した範囲を一次確認。当初「F-SO-9（完了報告充実）のみ、F-SO-8（変更ファイル per-pane 化）は defer」で確定しかけた（ユーザー選択）。
2. **設計SO v1（Alt A: raw transcript を verify-inputs.md に embed）→ refuted (2/2)**。前提 P1〜P3 が崩れた: `read_docs` は既に絶対パスを渡し validator も未検証（pull 型棄却根拠が無効）／skill は変更ファイル一覧を要求（F-SO-8 の defer は非対称）／raw transcript は未信頼入力。audit `202607010256044P78T7A6GM7H`。
3. **方向再確定 → 設計SO v2（F-SO-8-lite + F-SO-9-pull）→ refuted (2/2)**。改訂も構造的に不足: output_dir スコープは per-pane でなく output_dir-wide 止まり（pre-existing dirty / 並行 writer が混入）、pull も marker 注入（#101 既知弱点）を構造的に解かない。audit `20260701041800NMG0P7ZVB598`。
4. **フレーム破棄（ユーザー reframe）**: 2 ラウンド refuted で「minimal な working-tree diff 推定」というフレーム自体が誤りと判明。ユーザーが「**評価単位を commit にする**（WIP コミット可、commit された論理単位を評価）」を提案。これが working-tree 推定の構造的欠陥を root で溶かした（設計 D）。
5. **設計SO v3（設計 D）→ refuted (2/2) だが質が変化**: 「commit 評価は**有望**、ただし engine が境界を強制せず worker 頼み／end 未固定／worker commit 遵守が未検証」。structural kill から grounding-gap へ収束。audit `202607010853001Q8NVTKJ0W2Z`。
6. **SO ループ停止（reframe-on-stall）+ 人間ゲート**: exploration rubric は empirical 仮定が残る限り refute し続ける設計。3 ラウンドで「フレーム収束・残 residual は empirical/scope」と判断し、**「文書化 residual + テスト実測を前提に D' を作るか」をユーザー（人間ゲート）が承認**。D' = clean 境界強制（baseline + dirty 集合記録 / end materialize / pre-existing 注記）。
7. **実装 → 実装SO v1（oe-review）→ refuted (2/2)**。設計SO とは別レンズがコード欠陥を捕捉: 部分コミット時に未コミット残余が漏れる（codex）／commit あるのに diff 空だと degraded へ誤フォールバックし事実矛盾（cursor）。audit `202607010937017EMCG63SGW7P`。
8. **修正 → 実装SO v2 → survived (2/2)**。変更ファイルを `git diff <baseline>`（committed + 未コミット残余）+ untracked に変更。audit `20260701094830KD1590C5MCT3`。

## 決定と根拠（棄却案つき）

- **採用**: 評価単位 = commit 範囲。変更ファイル = `git diff --name-only <baseline>` + untracked（＝baseline からの全 footprint）、完了報告 = `git log baseline..end`、worker commit 契約を engine task に付与、baseline は spawn 前 / end は EXIT 時に materialize。
- **棄却 Alt A（raw transcript embed）**: 未信頼入力の注入面・skill 契約（叙述報告）不一致・tail サイズ無根拠。
- **棄却 Alt B/E（pull だが working-tree 前提）**: pull 自体は妥当だが、変更ファイルを working-tree diff で推定する限り pane-blind/dirty 混入が残る。
- **棄却 output_dir スコープ**: 契約が緩く（絶対パス / repo 外 /tmp で git 破綻）、Compliance が見たい範囲外変更も落とす。
- **なぜ commit が効くか**: commit は論理単位で、baseline からの diff が worker footprint を過不足なく与える。「commit すると git diff が空（#92 が"バグ"と記述）」を「commit を評価するのが設計」に反転した。

## わかったこと（W）

- **exploration rubric の SO は empirical 仮定が 1 つでも残れば refute する**。実装前に「worker が実際にコミットするか」等は証明不可 → survived を待つと loop する。SO は gap を surface する役で承認する役ではなく、**「文書化 residual を前提に作るか」は人間ゲートの判断**。
- **設計SO 通過 ≠ 実装SO 代替**（#114 と同じ再確認）。設計 D は設計SO を通っていないが、実装SO が別レンズ（部分コミット・空 diff）で material 欠陥を捕捉した。逆も真で、設計SO が捉えた構造欠陥は実装SO のレンズでは出ない。
- **2 回の structural refuted は「フレームを疑え」の信号**（reframe-on-stall）。3 回目で patch を重ねず、ユーザーの zero-base reframe に乗ったことで root が溶けた。

## 原則（転用可能）

- NG: 「汚れた作業ツリーの diff を推定して『誰が何を変えたか』を得る」→ 共有 workspace では原理的に pane-blind。
- OK: 「評価単位を VCS の論理単位（commit）に置き、baseline からの footprint を取る」→ 帰属が構造的に決まる（単一 writer 前提）。

## 残課題（routing 済み）

- **multi-pane 帰属**: 同一ブランチで commit 交錯 → per-pane branch/worktree が必要。→ #92 本文 + README に「別 follow-up」と明記。着手条件 = multi-pane を実際に行使する時。
- **reviewer verdict チャネルの marker 注入**: worker→reviewer 入力とは直交。→ [#101](https://github.com/stlwolf/ai-development-hub/issues/101)（既存 issue）に routing。
- **worker commit 遵守率（empirical residual）**: pre-implementation では証明不可。→ e2e/dogfood で fallback 率として実測。未コミット時は degraded 明示で安全側に縮退する実装で暫定対処。
- **`git status --porcelain` の quoted-path パース**: baseline_dirty 注記がクォート付きパスで外れ得る（ファイル自体は footprint に出る）。実装SO で「軽微・単独 refuted にせず」判定。→ 追わない（低頻度・注記のみの劣化）。
- **`attach.sh` 経路の baseline 欠落**: session_start なし → baseline 未解決 → degraded フォールバック（既知・#92 スコープ外）。→ 追わない（degraded で安全）。

## 蒸留シグナル

- **昇格候補あり**: 「exploration rubric SO は empirical 仮定を残す設計を承認しない → 人間ゲートで『文書化 residual を前提に作る』を決める」は複数セッションで再現しうる運用知。`reframe-on-stall-rule` / `exhaustion-before-conclusion-rule` の「SO ループの停止条件」節、または so-compare skill への追記候補。ただし本 episode 1 事例では時期尚早 → 非昇格、次に同型が出たら Decision 化を検討。
- 「commit-as-eval-unit」パターンは engine の multi-pane 設計（worktree-per-pane）着手時に再利用。

## Closure

- **次の消費者**: (1) #92 の multi-pane follow-up 着手者（本 episode の commit-range 基盤 + worktree 合流 path を読む）。(2) engine 検証ゲートを触る実装者（verify-inputs の構造）。
- **status**: stable / 達成度 = **部分達成**（単一 UC 分の変更ファイル・完了報告は達成、multi-pane と verdict 注入は明示 defer）。
- **evidence anchor**: 設計SO 3 ラウンド（audit `…4P78` / `…NMG0` / `…1Q8N`）・実装SO 2 ラウンド（`…MCG6` refuted → `…KD15` survived）。生出力は `tmp/oe-refute-*` / `tmp/oe-review-*`（揮発）だが verdict と要点は本文に転記済み。
- **back-propagation**: #92 の issue framing（working-tree diff 前提・「commit で diff 空=問題」）が今回の設計で覆った → README 派生 issue 表の #92 行を landed スコープに更新。
- **PR**: [#219](https://github.com/stlwolf/ai-development-hub/pull/219)。マージ・worktree 掃除は人間/親（本 session はしない）。
- **PR レビュー後の追記**: Copilot review の実質指摘があれば本 closure に追記（マージ前）。

Step4 辞退: heavy tier の closure 外部チェック（`so-compare`）を起動したが SO lanes が空出力（env: codex は 240s 内に stdout を emit せず / claude-safe 空）で usable な結果を得られず。closure の 4 観点は本 episode で機械検証可能なため辞退。 / 既存チェックで覆った観点: 省略チェック（失敗＝本文の主内容・設計SO 3R + 実装SO refuted→survived を audit_id つきで全記載）/ routing（全 5 follow-up に行き先付与）/ evidence anchor（audit_id 5 件を本文転記・`tmp/oe-refute-*` / `tmp/oe-review-*` の verdict JSON と突合可）/ back-propagation（#92 issue framing の欠陥 → README #92 行を更新）。 / 未実施観点と判断: なし（4 観点すべて covered・低リスク）。
