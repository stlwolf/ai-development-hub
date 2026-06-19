---
id: "01KVG6J2MZ7S762Q7BK55EJBEG"
title: "wez layout（配置規約付き盤面構築CLI）設計探索 — PoC 親1+子N"
date: 2026-06-20
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/165"
    reason: "本探索の対象 Issue（wez layout 検証・設計 + 最小 PoC）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/174"
    reason: "前提プリミティブ。wez pane split --target が landed（ターゲット不定性は解消済）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/175"
    reason: "消費側。spawn.sh を layout 化（本件は #175 を触らず layout プリミティブのみ）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "2基盤(wez/tmux)は別 identity レイヤ → layout は wez 専用（DJ-e）"
tags: [wezterm, wez-layout, board, preset, cockpit, discussion]
---

# wez layout 設計探索 — PoC 親1+子N

> pre-plan の設計探索ログ。確定プランは `docs/plans/2026-06-20-plan-165-wez-layout.md`。
> 探索 = 調査サブエージェント（一次情報直読）+ DJ 確定（オーナー承認）+ **設計SO（codex+cursor・選択肢拡張つき）で 6 点 refine**。

## 1. Context

`#165` は cockpit（#169）/ wez layout（Epic #20 Phase4）の検証・設計フェーズ + 最小 PoC「親1+子N の宣言的展開が CLI から再現できるか」。二層構造（wez CLI = 機械的盤面操作 / スキル = 判断・手順）は仮説。

**前提（landed）**: #174 で `wez pane split --target self|parent-window|explicit` + B3 default が入り、「ターゲットウィンドウ不定」課題は解消済（`lib/pane.sh`、ADR-004 DJ-8）。残りの検討項目を詰めるのが本件。

## 2. 現状能力マップ

| 機構 | 状態 |
|---|---|
| `wez pane split --target` / `activate` / `send` / `list` / `kill` | 既存（PoC の下回りプリミティブ）[verified] |
| socket 解決（`discover.sh`）/ exit code 定数（`common.sh`） | 既存 [verified] |
| **layout / preset 機構** | **存在しない（完全新規）** [verified — grep でコメント言及のみ] |

→ layout は「既存プリミティブを宣言定義に沿って機械オーケストレーションする薄い上位層」。

## 3. 設計判断（DJ）— 確定 + SO reconcile

| DJ | 確定 | 根拠 / SO |
|---|---|---|
| DJ-a 定義形式 | **JSON 名付き preset**（jq・YAML パーサ無し）。flat children でなく **`steps`（id + from + dir + percent）** + 明示 root | SO refine #1: flat `children[].target:self` は grid/連鎖を表現不可。PoC は `from=root` のみ |
| DJ-b 責務 | layout = **盤面構築のみ**（エージェント起動コマンドは持たない）。ただし **pane_id map を返す** | #114 と二重化回避。SO refine #4: 盤面 only ≠ ID 返さない（#175 が `OE_SPAWN_PANE_ID` を要する） |
| DJ-c 実現方式 | 既存 `wez pane split` の**反復**（Lua gui-startup 不採用 = `.wezterm.lua` 別リポ symlink） | 両 SO 是認 |
| DJ-d focus | 既定 root へ戻す + `--focus <target>` 上書き | 全 split を explicit `--pane-id $ROOT` にするため split 毎 activate は不要（targeting は決定論的）。最後に root へ復帰 |
| DJ-e oe/tmux | **wez 基盤専用**（tmux delegate は out of scope） | #188（2基盤別レイヤ）+ #175（非対話 claude -p 限定）。価値 = engine/非対話用 outer board と明記 |

## 4. 設計SO の reconcile（6 点・codex+cursor 収束）

1. **スキーマ**: `{version, root:"self", steps:[{id, from:"root", dir, percent}], focus}`。PoC は `from=root`/`target=self` のみ（`parent-window` mid-layout はフォーカス drift で禁止）。grid は v2（再帰ツリー＝代替 E）。
2. **非冪等**: split は create-only。2 回 apply で倍増 → 「冪等」と呼ばず **「非冪等・clean baseline に再現的」** と明記。真の冪等は `--replace`+所有 marker（PoC 外）。
3. **pane_id map 返却**: `apply --json` = `{status, root_pane_id, window_id, panes:[{id, pane_id, index}]}`。#175 接続の契約。
4. **部分失敗**: k 番目 split 失敗 → abort + 作成済を**逆順 kill（rollback）**（agent 起動無しで安全）+ `--json {status:"partial", created, failed_step}`、exit 5。
5. **socket / root を一度だけ固定**: `wez_cmd_layout` で socket 解決+`export WEZTERM_UNIX_SOCKET`、`ROOT=$(_wez_resolve_self_pane)`+`_wez_pane_exists` を 1 回、以降全 split は **explicit `--pane-id $ROOT`**（B3 default の active-pane fallback を踏ませない）。N subprocess 呼びの socket 揺れも回避。
6. **価値の範囲**: wez 専用 → delegate(tmux) cockpit には効かない。「engine/非対話用 outer WezTerm board・delegate は別 issue」と honest に明記。

## 5. 検討した代替案（選択肢拡張・PoC は縮小採用）

| 案 | 評価 |
|---|---|
| 初期案（`wez layout apply` + JSON preset + split反復） | **採用**（上記 reconcile 込み） |
| A Lua/workspace 宣言 | 冪等/原子性は強いが `.wezterm.lua` 別リポ管轄・CLI 主体 hub と思想割れ。PoC 後に再評価余地 |
| B skill のみ（新 CLI 無し） | `spawn.sh` から機械呼び出しできない（#175 非接続）→ 不可 |
| C oe spawn template 内蔵 | layout を wez CLI 共通化（Epic #20）でなく oe 内蔵に縮退 → 他ツール再利用不可。#175 の「呼び出し置換」に留めるべき |
| D ensure（desired-state 差分） | 真の冪等。PoC の最小性を超える（差分算法要）。grid 需要時に再検討 |
| E 再帰ツリー preset（split ノード） | grid/ネスト可。**schema v2 の本線**。PoC は flat steps で十分 |

## 6. PoC 成功条件
親が**別ウィンドウを active にした状態でも** self 起点で同一 window に同一盤面を生成（`wez pane list --format json` の window_id/pane_id で機械検証）。#174 の mock shim ハーネス（PATH 差し替え `wezterm` + fixture JSON）流用。

## 7. スコープ境界 / 昇格
- #175（spawn.sh layout 化＝消費側）は触らない / #111（activate）CLOSED / #114（クリーン出力）はコマンド起動を持たないことで切り分け。
- **Decision 昇格**: layout 規約は ADR-004 DJ-9 に昇格（closure で確定）。
