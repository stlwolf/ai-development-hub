---
id: "01KVFKJT5S584R7VXB88TCE9D7"
title: "wez pane split ターゲティング規約（--target self/parent-window/explicit）実装"
date: 2026-06-19
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/174"
    reason: "本 episode の対象 Issue"
  - type: decision
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md"
    reason: "DJ-8 として targeting 規約の決定を昇格（蒸留シグナル）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/165"
    reason: "本規約を再利用する wez layout（次の消費者）。#174 は #165 から切り出した前提プリミティブ"
tags: [wezterm, wez-pane, split, targeting, cockpit, episode]
---

# wez pane split ターゲティング規約 実装

## Context / なぜ

cockpit（#169）/ wez layout（#165）/ engine `spawn.sh` が共通で使う `wez pane split` は、`--pane-id` 省略時に WezTerm のアクティブペイン依存で分割先が不定になる（親が別ウィンドウをアクティブにしていると意図しないウィンドウにペインが生える、#165 で観察）。これを安定させる targeting 規約を `wez` CLI に導入した。#174 は #165 の前提プリミティブとして切り出された。

## 次の消費者

- **#165 wez layout apply**: 本 targeting 規約を盤面構築で使う（直接の依存先）。
- 後続 issue: `spawn.sh` のハードコード split を本規約へ置換（#174 範囲外）。

## やったこと（要件 → 実装）

- `--target self|parent-window|explicit` を split に追加（`lib/pane.sh`）。優先順位 = explicit(`--pane-id`/`--target explicit`) > self > parent-window。
- 解決ヘルパー: `_wez_resolve_self_pane`（`WEZTERM_PANE` から・MVP）/ `_wez_resolve_parent_window_pane`（self の `window_id` を `wezterm cli list` から引き同 window の active pane）。
- 省略時デフォルト（DJ-b=B3）: self 試行 → 解決不能なら native default（`--pane-id` 省略）にフォールバック + warn。明示 self/parent-window の解決失敗は exit 3。
- 後方互換: 既存 `--pane-id` 不変。`spawn.sh:12` の省略呼び出しは native と同じ `WEZTERM_PANE` を解決するため同一ペインを分割（回帰なし）。

## 決定と根拠（Decision 昇格 → ADR-004 DJ-8）

- DJ-a インタフェース = `--target <mode>`（名前付き規約・拡張性）。activate が pane-id 必須化した「既存一貫性優先」前例と緊張するが、split は規約導入が要件のため名前付き mode を採用。
- DJ-b デフォルト = B3（self+フォールバック）。「default→規約」と「spawn.sh 非破壊」を両立する唯一の線。明示指定は discover の「明示失敗=即エラー」思想に倣いエラー。
- DJ-c self = `WEZTERM_PANE`（MVP）。TTY 逆引きは env 非伝搬が問題化したら後続（未着手）。
- 棄却: 個別フラグ（DJ-a A2）/ デフォルト維持 opt-in（B2・default を変えない）/ self 即エラー（B1・spawn 破壊リスク）。

## わかったこと（W）

- **WezTerm native `split-pane`（`--pane-id` 省略）の既定は「active pane」ではなく `WEZTERM_PANE`（呼び出し元ペイン）。未設定時に active pane**（公式仕様 + `split-pane --help`）。当初 doc が「active pane」と誤記しており実装SO で是正（M1）。
- `wezterm cli list` の `pane_id` は JSON 数値/文字列のいずれもあり得る → 解決 jq は tostring 比較で版差を吸収（既存 `_wez_pane_exists` と同流儀）。

## 検証

- mock shim テスト（PATH 差し替え `wezterm`・fixture `cli list` JSON）新設: **19 passed / 0 failed**（wezterm-ai-mode 初のテストハーネス）。引数パース・優先順位・B3・明示エラー・後方互換・型差・stale self・非数値 env を機械検証。
- `shellcheck` clean（`pane.sh` + test）。
- 実機スモーク（実 wezterm で split→kill）: self/parent-window/default が成功、エラー経路が 64/64/3。

## 実装SO（heavy: 意図起動の外部レビュー）

`so-compare --with codex,cursor`（出力 `tmp/so-20260619-180456/`・揮発）で欠陥検出。後方互換の回帰は無し（codex の「別ペイン分割」は active-pane と `WEZTERM_PANE` の混同で過大主張・cursor が訂正）。1 ラウンドで修正:
- M1: doc/warn の「active pane」誤記を `WEZTERM_PANE` 基準へ是正（back-propagation）。
- R1: parent-window jq を tostring 比較 + `$win` null ガード（型差・self 不在で誤採用しない）。
- R2: 明示 `--target self` の stale pane を `_wez_pane_exists` で検出し exit 3（send/capture と一貫）。

## follow-up routing

- D1（同 window 複数 `is_active` → JSON 順先頭）: ADR-004 DJ-8 に既知限界として記載（destination = ADR。WezTerm は通常 window あたり active 1）。
- D2（`--target` 二重指定で後勝ち・explicit 必須チェック迂回）: ADR-004 DJ-8 に既知限界として記載（病的入力）。
- self の TTY 逆引き（C2）: `WEZTERM_PANE` 非伝搬が実問題化したら後続（現状は env 一本で十分）。
- `spawn.sh` の本規約への置換: 別 issue（#174 範囲外）。
- 未解決の open issue 化は無し（上記はすべて ADR 記載 or 明示的に「後続/不要」）。

## 蒸留シグナル

- **Decision**: ADR-004 DJ-8（targeting 規約）として昇格済。
- skill / rule / #62: なし。

## status

達成（stable）。受入条件3点（アクティブウィンドウ切替時も意図通り[実機スモーク]/ `--pane-id` 非破壊 / shellcheck）を満たす。

## Step 4 外部チェック（heavy tier）

Step4 辞退: closure 品質（失敗の選択的省略 / routing 網羅 / evidence anchor / back-propagation）は本 episode で自己充足 — 実装SO の指摘・修正・過大主張の訂正を省略せず記載、follow-up は全て ADR 記載 or 後続/不要に routing、揮発 SO パスの要点は本文へ転記、doc 誤記は M1 で back-propagate 済。コード品質は実装SO（別レーン）が既に担保。/ 既存チェックで覆った観点: routing / evidence anchor / 省略チェック / back-propagation / 未実施観点と判断: なし。
