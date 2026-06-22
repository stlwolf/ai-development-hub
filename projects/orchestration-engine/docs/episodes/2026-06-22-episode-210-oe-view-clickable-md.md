---
id: "01KVQA86WVXQQVPFSB65NE5ZP0"
title: "oe-view クリッカブル md ビューア — 実装と『mock では見えない実結合欠陥』の記録"
date: 2026-06-22
type: episode
status: draft
related:
  - type: target_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/210"
    reason: "本 episode の対象 Issue"
  - type: pr
    ref: "https://github.com/stlwolf/ai-development-hub/pull/212"
    reason: "PR1（hub oe-view + wez PROG passthrough）"
  - type: pr
    ref: "https://github.com/stlwolf/dotfiles/pull/21"
    reason: "PR2（dotfiles wezterm.lua クリック層 + glow Brewfile）"
  - type: plan
    ref: "projects/orchestration-engine/docs/plans/2026-06-21-plan-210-oe-view-clickable-md.md"
    reason: "設計・設計SO reconcile・DJ-4 argv-spawn 改定（§11）"
tags: [oe-view, cockpit, wezterm, episode, negative-knowledge, mock-vs-e2e, implementation-so]
---

# oe-view クリッカブル md ビューア — 実装と「mock では見えない実結合欠陥」の記録

> **reconstructed**: 本 episode は作業中のリアルタイム追記ではなく、作業後にまとめて再構成した（episode-flow-discipline 違反の自己申告・証拠価値は real-time 追記より低い）。時刻順の細部より、再利用価値のある学び（Negative Knowledge）の保全を主目的とする。
> closure（episode-retrospective: 消費者明示・routing・status 確定・tier 判定・Decision 昇格検討）は **両 PR マージ時に実施**（本時点は draft）。

## 何をやったか（要約）

生成 doc の md を Finder/手動ペイン操作なしで即ビューする `oe-view`（クリック起点）。痛点ヒアリング → レンダラ/起動 DJ 確定（glow + クリック）→ 設計SO(3者) reconcile → 実装 → 実機 e2e → 実装SO(oe-review 4巡) → 2 PR（hub #212 / dotfiles #21）。クロスセッション委譲（親=PR1 / 子=dotfiles PR2 / 実装サブエージェント）。

## 核心の学び（Negative Knowledge）

### L1. mock-shim テストは「実結合」を原理的に検証できない（最重要）

`test_oe_view.sh` は 61 件 pass（bash 4/3.2）だが、**実機でしか出ない欠陥が 3 つ**出た。mock は「呼び出し引数」を記録するだけで、シェル実行・tmux 自動アタッチ・PATH 解決・タイミングを再現しない。

- **(a) shell-send→glow が描画しない**: 初版は `wez pane split`（シェル）→ `wez pane send "glow -- <path>"`。実 wezterm+tmux では新規ペインのシェル rc が **tmux に自動アタッチ**し、send したコマンドが実行されず glow が描画されない（capture に tmux ステータスバー＋生コマンドのみ・marker 未生成で確定）。#144/#188 系統。
- **(b) PATH の wez 実体取り違え**: 修正で `wez pane split` に PROG パススルーを足したが、`oe-view` は **PATH の `wez`（`~/bin/wez`＝main repo への symlink・master 版＝PROG 非対応）** を呼ぶため失敗。worktree の wez を PATH 前置すると成功。「どの wez 実体が PATH に乗るか」は mock の外。
- **(c) P0 allowlist symlink バイパス**: `--from-link` の canonicalize フォールバック（realpath 不在時の `cd -P dir`+basename）が**最終要素のファイル symlink を解かず**、許可 root 内 symlink で root 外 md を開けた。mock・親 spot-check・**設計SO すべて見逃し**、実装SO だけが捕捉。

→ **対策（plan §6/§11 に反映）**: pane 描画・レンダラ起動を伴う機能は **実機 e2e を必須ゲート**化。mock は logic 検証に留め、render/spawn/timing は実機で確認する。

### L2. 実装SO（oe-review）は設計SO と別レンズで load-bearing

設計SO（so-compare 3者・選択肢拡張）は方向・反証に有効だが、**コード欠陥の到達可能性**は別レンズ。実装SO（`oe-review --lanes 3`・reviewed diff バインド）が設計SO の見逃した P0(c) を捕捉。4 巡で P0→spec(既定広すぎ)→doc/code 不整合 と収束し survived。conservative 集約（1レーン material→全体 refuted）が効いた。「設計SO を回しても実装SO の代替にならない」（#192 false-pass 回避）の実例。

### L3. argv-spawn が新ペイン描画の正解

「シェルにコマンドをタイプ送信」ではなく **ペインのプログラムとして直接起動**（`wezterm cli split-pane [PROG]` = シェルの代わりに PROG 実行）。`wez pane split … -- glow -p -- <path>`。シェルも tmux も経由せず確実に描画し、path が **argv 要素**で渡るため再トークナイズが起きず **シェル注入面も消滅**（`%q` 不要化）。viewer 再利用は send 不可（pager はシェルでない）ため **replace**（kill→spawn）。

### L4. デプロイ結合（worktree と PATH 実体のズレ）

hub のツールは PATH の実体（`~/bin/*` = main repo への symlink）を呼ぶため、**worktree 上の変更はマージ前は PATH に乗らない**。ローカル実機 e2e では worktree の bin を PATH 前置する必要がある。逆に、同一 PR に同梱した wez(PROG)+oe-view は **master マージで symlink 経由同時有効化**される。

## 効いた進め方（Positive）

- **クロスセッション委譲**: 親=PR1（hub）/ 子=dotfiles PR2（auto 権限・HG は親へエスカレーション）/ 実装サブエージェント（implementer-contract）。契約（`oe-view --from-link <path>` IF）を固定したため、内部を argv-spawn に作り直しても **dotfiles PR2 は無改修**で済んだ。
- **段階を分けない判断**: 「core とクリック層を分割出荷しない」をユーザーと合意（issue 1 / PR 2）。
- **トリガ再計量の確定前トレース**: 設計SO がゼロベースで QuickSelect/record-replay を提示 → クリック維持＋全緩和で確定（predecision-exploration）。

## 未確認 / 持ち越し

- **Cmd+Click → oe-view 発火**の end-to-end は両 PR マージ後に実機確認。
- 非material 残差（`OE_VIEW_ROOTS` の空白パス・稀な state 書込失敗）は Minimal Scope で非対応。

## closure（マージ時に実施・現時点 TODO）

- [ ] 消費者明示 / routing / status 確定（episode-retrospective）
- [ ] Decision 昇格検討: 「pane 描画系は実機 e2e 必須」「argv-spawn for new-pane render」は汎用原則になりうる（L1/L3）→ Decision or 既存ルールへの反映を判断
- [ ] worktree 掃除（hub / dotfiles 子）
