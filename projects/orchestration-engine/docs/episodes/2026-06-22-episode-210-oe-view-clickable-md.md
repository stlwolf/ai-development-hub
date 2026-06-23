---
id: "01KVQA86WVXQQVPFSB65NE5ZP0"
title: "oe-view #210 — 上流ゲートが全部 green でも実欠陥は残った、の記録"
date: 2026-06-22
type: episode
status: stable
related:
  - type: target_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/210"
    reason: "対象 Issue"
  - type: pr
    ref: "https://github.com/stlwolf/ai-development-hub/pull/212"
    reason: "PR1（実装SO 4巡の verdict/sha・e2e 結果はここのコメントが正本アンカー）"
  - type: pr
    ref: "https://github.com/stlwolf/dotfiles/pull/21"
    reason: "PR2（dotfiles クリック層）"
  - type: plan
    ref: "projects/orchestration-engine/docs/plans/2026-06-21-plan-210-oe-view-clickable-md.md"
    reason: "設計・DJ・argv-spawn 改定（§11）— 技術 how の正本"
tags: [oe-view, cockpit, episode, negative-knowledge, mock-vs-e2e, implementation-so]
---

# oe-view #210 — 上流ゲートが全部 green でも実欠陥は残った、の記録

> **reconstructed**: 作業後の再構成（リアルタイム追記を怠った自己申告・証拠価値は real-time より低い）。
> closure は plan 完了＋実装SO 4 巡 survived 後・**マージ前**に実施。tier=heavy。技術詳細（コマンド仕様・argv-spawn 機構・allowlist 実装）は plan §11 / PR #212 / コードにあるので本書では再掲しない。

## なぜ始まったか

cockpit（#169）で生成 doc の md を Finder/手動ペイン操作なしで即ビューしたい。

## この episode の価値（他ファイルから復元できない接続）

UI 機能ひとつで、**上流の検証ゲートが全部 green でも実欠陥が 3 件残った**——うち 1 件は P0（allowlist バイパス）。

- green だったのに通り抜けた上流: mock 単体 61 件 / 親のコード read / **設計SO 3 者**。
- 実欠陥を捕捉したのは下流の **実機 e2e と実装SO（oe-review）だけ**。しかも実機 e2e に踏み込んだ契機は、人の「**実地テストした？**」の一言だった（それが無ければ green のままマージしていた）。
- 見逃しの理由は共通: mock は呼び出し引数しか見ず実行・tmux 自動アタッチ・PATH 実体・タイミングを再現しない。設計SO とコード read は「コードが正しいか」を見て「実環境で動くか」を見ない。実装SO は設計SO と別レンズ（reviewed diff の到達可能性）なので P0 を拾えた。
- 実装SO が 4 巡を要したのは、各修正が次の層を露出させたから（P0 コード → 既定が仕様より広い → **その修正で生じた doc/code drift**＝自分の取りこぼし → clean）。3 巡目は自己誘発。

→ 結論（転用可能）: **pane 描画/レンダラ起動を伴う機能では、real e2e と実装SO が load-bearing。green な mock を結合の証拠として扱わない。**

## closure

- **次の消費者**: pane 描画/spawn を伴う engine ツールを次に作る人（real-e2e を先例ゲートとして）／#210 マージ実行者。
- **follow-up routing**:
  - Cmd+Click → oe-view 発火の実 e2e → 両 PR マージ後に親が実施（本 episode の持ち越し）
  - 昇格（下記「蒸留シグナル」で基準判定済）: 候補2=ADR-004 DJ-10 へ昇格済 / 候補1=ADR 対象外・rule 昇格は時期尚早で defer
  - 非material 残差（`OE_VIEW_ROOTS` 空白パス・稀な state 書込失敗）→ **追わない**（Minimal Scope 宣言）
  - worktree 掃除（hub / dotfiles 子）→ マージ時
- **status**: stable（達成度＝**部分**: hub 側は実機 e2e まで完結／Cmd+Click 実 e2e はマージ後）
- **evidence anchor**: 実装SO 4 巡の verdict・reviewed_sha・e2e 結果は PR #212 のコメントに転記済（`tmp/` 出力は揮発のため PR コメントを正本アンカーとする）

## 蒸留シグナル（昇格基準に照らした判定）

昇格基準＝「非自明な設計判断（選択肢比較・棄却案あり）」（`episode-retrospective:40`）に当てて判定:

- 候補1「pane 描画系は実機 e2e 必須ゲート」→ **ADR 対象外**。選択肢比較・棄却案を伴う設計判断ではなく、検証規律＝**negative knowledge**（#62 注入先候補）。rule への昇格は 1 事例では時期尚早 → **defer**（非昇格判断を本 episode に記録・`episode-flow-discipline:19`）。
- 候補2「新ペイン描画は argv-spawn（`split-pane -- PROG`）／shell send 棄却」→ **昇格済**。shell-send を実機で棄却 → argv-spawn 採用＝「選択肢比較・棄却案あり」に該当。pane 設計判断なので慣習どおり **ADR-004 に DJ-10 として追記**（`projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md`・DJ-8/#174・DJ-9/#165 と同じ追記方式）。

## Step4（heavy 外部チェック）辞退

Step4 辞退: オーナーが本 closure を対面レビュー中＋失敗 3 件と実装SO 4 巡は PR #212 コメントに durable 記録済 / 既存チェックで覆った観点: routing・evidence anchor・選択的省略チェック（失敗は隠していない）・back-propagation（plan §11 に反映済）/ 未実施観点と判断: なし
