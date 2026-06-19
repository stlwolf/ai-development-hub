---
id: "01KVG8A2SQ9GT6EH2YCR9P8MBF"
title: "wez layout（宣言的盤面構築 PoC・親1+子N）実装"
date: 2026-06-20
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/165"
    reason: "本 episode の対象 Issue"
  - type: decision
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md"
    reason: "DJ-9 として layout 規約を昇格（蒸留シグナル）"
  - type: source_material
    ref: "projects/wezterm-ai-mode/docs/discussions/2026-06-20-discussion-wez-layout.md"
    reason: "設計探索・DJ 確定・設計SO reconcile"
  - type: design_context
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-005-bash-shell-standards.md"
    reason: "bash 3.2 互換・local -n 禁止（実装SO が捕捉した critical の根拠）"
tags: [wezterm, wez-layout, board, preset, cockpit, episode]
---

# wez layout 実装

## Context / なぜ

cockpit（#169）/ wez layout（Epic #20 Phase4）で、AI/CLI からマルチエージェント盤面を宣言的・再現可能に構築する手段が無い。`wez pane split` 等は単発・その場任せ。#174 で targeting 規約が landed した上で、#165 は「宣言 preset → 機械的盤面構築」の最小 PoC（親1+子N）を `wez layout` として実装した。

## 次の消費者

- **#175**: spawn.sh の wez split ハードコードを `wez layout` 化（本 episode が返す `--json` pane_id map = `{root_pane_id, window_id, panes:[{id,pane_id,index}]}` を消費）。
- スキル層（薄ラッパー）は後続。

## やったこと（要件 → 実装）

- `wez layout apply <name> [--focus] [--json]` / `list` / `--help`（`lib/layout.sh` + `bin/wez` dispatch）。
- JSON 名付き preset（`lib/layouts/<name>.json`・`{version, root:"self", steps:[{id, from:"root", dir, percent}], focus}`）。PoC preset `parent-children.json`。
- socket を 1 回解決+export、ROOT=self を 1 回解決、全 step を explicit `--pane-id $ROOT` で分割、失敗時は逆順 kill で rollback、focus 復帰、pane_id map 返却。**wez 専用・盤面構築のみ・非冪等(create-only)**。

## 決定と根拠（Decision 昇格 → ADR-004 DJ-9）

- DJ-a JSON preset（steps+id+root・flat children でない）/ DJ-b 盤面 only（コマンド起動を持たない=#114 切り分け・ただし pane_id map は返す）/ DJ-c split 反復（Lua 不採用）/ DJ-d focus 既定 self+`--focus` / DJ-e wez 専用（#188 の 2 基盤別レイヤ）。
- 棄却: flat children（grid 不可）/ Lua gui-startup（別リポ symlink）/ skill-only（#175 非接続）/ oe 内蔵（再利用不可）/ ensure（PoC 超過）。grid は再帰ツリー schema v2 へ defer。

## わかったこと（W）— bash 3.2 互換が最大の学び

- **`local -n`（nameref）は bash 4.3+ で macOS 標準 bash 3.2 では動かない**（ADR-005 で禁止・`wez` は `~/bin/` に sync されログインシェル 3.2 から呼ばれる）。初版の `--json` builder が `local -n` を使い、**dev の bash 5 では 38 テスト全 pass だが 3.2 では成功経路が壊れる**潜在 bug だった。→ JSON 組み立てを配列がスコープ内の `_wez_layout_apply` にインライン化して解消。**テストは `/bin/bash`（3.2）でも走らせる**べき（最終は両 bash で 38/0）。
- preset 名の path traversal（`../`）は CLI で頻出 → 名前を `^[A-Za-z0-9._-]+$` に制限。

## 検証

- mock shim テスト（PATH 差し替え `wezterm`・fixture JSON・kill/split 失敗注入）: **bash 5.2 と macOS bash 3.2 の両方で 38/38 pass**。shellcheck clean。`grep 'local -n'` ゼロ。`bin/wez` 経由 e2e（help/list/dispatch）。
- 負のコントロール: 各ガード（C2/W2/W5）を外すと対応テストが落ちることを確認（テストがガードを守る）。

## ゲートと SO（heavy: 意図起動の外部レビュー 2 本）

- **設計SO**（`so-compare --with codex,cursor`・選択肢拡張つき）で 6 点 refine（steps schema / 非冪等明記 / pane_id map / rollback / socket・root 固定 / 価値範囲）→ 実装前に反映。
- **実装SO**（同・欠陥検出）で **critical 3 件**（`local -n` の bash 3.2 破綻 / preset 名 path traversal / `--focus` 不正の silent exit 0）+ warning 6 件を捕捉 → 1 ラウンドで全修正。
- **学び（プロセス）**: 親の compliance review は SO reconcile 点（ロジック一致）を確認したが、**プラットフォーム/version 互換（ADR-005・bash 3.2）を明示チェックせず `local -n` を見落とした**（行は見たのに）。compliance review に「ADR-005 / bash 3.2 機能の grep」を含めるべき。実装SO がこの穴を埋めた = ゲートの実価値。

## follow-up routing

- grid/ネスト幾何 → 再帰ツリー schema v2（別 issue・本 PoC 範囲外）。
- spawn.sh の layout 化 → #175（消費側）。
- 真の冪等（`--replace`+所有 marker）/ ensure(desired-state) → defer（ADR-004 DJ-9 に記載）。
- delegate(tmux) 盤面 → out of scope（#188・別 mux レイヤ）。
- 未解決 open issue 化は無し（上記はすべて #175 / 別 issue / defer に routing）。

## 蒸留シグナル

- **Decision**: ADR-004 DJ-9（layout 規約）として昇格済。
- skill / rule / #62: なし（スキル薄ラッパーは後続だが本 PoC では作らない）。

## status

達成（stable）。PoC 成功条件（別 active window でも self 起点で同一盤面・`wez pane list` JSON 機械検証）+ shellcheck + bash 3.2/5.2 両対応を満たす。

## Step 4 外部チェック（heavy tier）

Step4 辞退: closure 品質（失敗の選択的省略 / routing 網羅 / evidence anchor / back-propagation）は本 episode で自己充足 — 設計SO/実装SO の指摘・critical・修正・**親 review の見落とし（local -n）を省略せず記載**、follow-up は全て #175/別 issue/defer に routing、揮発 SO パスの要点は本文転記、bash 3.2 学びは ADR-005 を前方参照。コード品質は実装SO（別レーン）が担保。/ 既存チェックで覆った観点: routing / evidence anchor / 省略チェック / back-propagation / 未実施観点と判断: なし。
