---
id: "01KVG6J2NSTSTJ2R9HQ17ST2F9"
title: "wez layout 実装計画 — 宣言的盤面構築 PoC（親1+子N）"
date: 2026-06-20
type: plan
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/165"
    reason: "本計画の対象 Issue"
  - type: source_material
    ref: "projects/wezterm-ai-mode/docs/discussions/2026-06-20-discussion-wez-layout.md"
    reason: "設計探索 + DJ 確定 + 設計SO reconcile（6点）"
tags: [wezterm, wez-layout, board, preset, plan]
---

# wez layout 実装計画 — 宣言的盤面構築 PoC（親1+子N）

> 駆動層: 調査 → DJ 確定（承認）→ 設計SO（codex+cursor）reconcile 6点 → **本計画**（承認済）→ 実装 → 実装SO → episode → PR。
> 設計根拠: `docs/discussions/2026-06-20-discussion-wez-layout.md`。

## 1. 成果物

`wez layout` 新サブコマンド（`lib/layout.sh` + `bin/wez` dispatch）。既存プリミティブ（`wez pane split --target` 等）を宣言 preset に沿って機械オーケストレーションする薄い上位層。**wez 基盤専用・盤面構築のみ・非冪等（create-only）**。

## 2. コマンド仕様

```
wez layout apply <name> [--focus <target>] [--json]
wez layout list
wez layout --help
```

`apply <name>` の処理順（W1 修正後・実装/README に一致）:
1. socket 解決 → `export WEZTERM_UNIX_SOCKET`（`wez_cmd_layout` が `wez_cmd_pane` と同型で1回だけ）。内部関数を呼ぶ（`wez pane split` を N subprocess で呼ばない）。
2. preset 読込・検証を **`ROOT` 解決より前**に行う（W1）: preset 名は `[A-Za-z0-9._-]+` のみ許可（`/`・`..`→exit 64）。`lib/layouts/<name>.json` 不在→exit 1、parse 不能/schema 不正/引数不正→exit 64、`jq` 未導入→exit 5（依存失敗）。preset を先に検証することで missing/invalid preset が root-not-found (3) に隠れない。
3. `ROOT=$(_wez_resolve_self_pane)` を1回解決 + `_wez_pane_exists "$ROOT"`。不在/stale→exit 3。
4. steps を順に: `wez pane split --pane-id "$ROOT" --<dir> --percent <p>`（explicit 固定・B3 default を踏まない）。新 pane_id を収集。
5. split 失敗→ abort、作成済 pane を**逆順 kill（rollback）**、exit 5。`--json` 時 `{status:"partial", root_pane_id, created:[...], failed_step:k}`。
6. 成功→ focus 復帰（既定 `$ROOT` / `--focus <target>`）。`--json` 時 `{status:"ok", root_pane_id, window_id, panes:[{id, pane_id, index}]}`。

## 3. preset スキーマ（`lib/layouts/<name>.json`）

```json
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "root", "dir": "bottom", "percent": 30},
    {"id": "worker2", "from": "root", "dir": "right", "percent": 50}
  ],
  "focus": "root"
}
```

- PoC 制約: `root` は `self` のみ、各 step の `from` は `root` のみ、`dir` ∈ {bottom,right,left,top}、`percent` は 1-99。`target:parent-window` は preset で禁止（フォーカス drift 回避）。
- `dir` 値 → CLI `--<dir>` へマップ（バリデーション + README 明記）。
- 将来の grid/ネストは再帰ツリー schema v2（本 PoC 範囲外）。

## 4. PoC preset

`lib/layouts/parent-children.json`（親1 + 子2 の最小例）1 本。

## 5. テスト（`tests/test_wez_layout.sh`・mock shim）

#174 の `PATH` 差し替え `wezterm` shim + fixture JSON を流用:
- [ ] apply: preset 通りの split 引数列（`--pane-id $ROOT --bottom --percent 30` 等）が発行される
- [ ] **再現性**: 異なる active window（fixture で is_active を別 pane に）でも root=self 起点で同一 split 列
- [ ] `--json`: `{status:"ok", root_pane_id, window_id, panes:[{id,pane_id,index}]}` を返す（`jq -e` 検証）
- [ ] 部分失敗: k 番目 split 失敗（mock で失敗注入）→ 逆順 kill 発行 + exit 5 + `--json {status:"partial", failed_step}`
- [ ] 非冪等の確認: 2 回 apply で split が倍発行（仕様として固定）
- [ ] focus: 末尾に `activate $ROOT`（or `--focus`）
- [ ] 異常系: preset 不在→1 / schema 不正→64 / root 不在(WEZTERM_PANE 無)→3 / 未知オプション→64
- [ ] `list` / `--help`
- [ ] `shellcheck`

## 6. 触るファイル
- 追加: `lib/layout.sh`、`lib/layouts/parent-children.json`、`tests/test_wez_layout.sh`
- 変更: `bin/wez`（layout dispatch 追加）、`README.md`（layout 節）、`docs/decisions/ADR-004-pane-design-decisions.md`（**DJ-9** layout 規約昇格）
- 流用（read）: `lib/pane.sh`（split/activate/kill の内部関数）、`lib/discover.sh`、`lib/common.sh`

## 7. スコープガード
- 盤面構築のみ（エージェント起動コマンドを持たない）/ wez 専用（tmux 非対応）/ 非冪等（明記）/ `spawn.sh` は触らない（#175）/ grid は v2。

## 8. ゲート
- 実装SO（option-expansion なし・欠陥検出）/ closure = episode-retrospective（DJ-9 昇格は ADR-004 に実体化済 → 蒸留シグナル=Decision 明示）。
