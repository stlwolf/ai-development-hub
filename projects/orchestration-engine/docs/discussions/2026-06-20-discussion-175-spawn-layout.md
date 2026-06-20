---
id: "01KVHMVQDN34GZAXJF0HJRMYZ1"
title: "#175 spawn.sh 盤面構築の wez layout 化 — 設計探索と DJ"
date: 2026-06-20
type: discussion
status: stable
related:
  - type: implements
    ref: "https://github.com/stlwolf/ai-development-hub/issues/175"
    reason: "本 discussion の対象 Issue（spawn.sh の layout 化・機械1サイクル正規化）"
  - type: depends_on
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md"
    reason: "DJ-9（wez layout 規約・pane_id map 契約・非冪等）/ DJ-8（split targeting 規約）を消費"
  - type: depends_on
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-005-bash-shell-standards.md"
    reason: "bash 3.2/5.2 両対応・local -n 等 4.0+ 機能禁止"
  - type: source_material
    ref: "projects/wezterm-ai-mode/docs/episodes/2026-06-20-episode-wez-layout.md"
    reason: "#191 layout 実装 episode。次の消費者として #175 を明記"
---

# #175 spawn.sh 盤面構築の wez layout 化 — 設計探索

## Context / なぜ

orchestration-engine の `lib/spawn.sh` は盤面構築をハードコードしている:

```bash
OE_SPAWN_PANE_ID="$(wez pane split --bottom --percent 30 --wait-ready --timeout "$OE_SPAWN_WAIT_READY_SEC")"
```

`oe_spawn_prepare_pane` はこの単発 split で都度ペインを作る。#191（merged）で `wez layout apply <name> --json`（宣言的盤面構築・pane_id map 返却・非冪等）が landed したので、engine の機械1サイクル（envelope → spawn → monitor → verify → cleanup）を「規約ベース盤面」で再現的に成立させる（#175）。

## 暗黙の前提（明示化）

- P1: `oe_spawn_prepare_pane` は **2 経路から呼ばれる**: (a) `bin/oe` の target ペイン生成、(b) `lib/verify.sh:oe_verify_spawn` の reviewer ペイン生成。
- P2: reviewer 数は **動的**（`oe_verify_run_phase` は target ペインのリストを取り各 target に reviewer を1体）。`bin/oe` 1サイクルでは target=1 → reviewer=1。
- P3: `OE_SPAWN_PANE_ID` の下流消費者: envelope（pane_id を JSON に `--argjson` で**数値**記録）/ `oe_spawn_send` / `oe_monitor_loop`（`OE_MANAGED_PANES` に登録 → cleanup kill）/ `oe_verify_run_phase`（target_pane_id）/ `cleanup`。
- P4: `wez layout apply` は WEZTERM_PANE から root(self) を解決して全 split。**非冪等**（2 回 apply でペイン倍増）。preset は `wezterm-ai-mode/lib/layouts/<name>.json` のみから読む（ディレクトリは layout.sh 内ハードコード）。**layout の内部 split は `_wez_pane_split` のみで `--wait-ready` を渡さない**（layout.sh:232）。`_wez_wait_pane_ready` は pane.sh の private で `wez pane split --wait-ready` 経由でしか届かず standalone verb は無い。
- P5: テスト結合: `test_e2e_smoke.sh` は `bin/oe` 全経路を mock wez で回す（mock は `pane split/send/capture/kill/notify` のみ・**`layout` 非対応**）。`test_verify.sh` は `oe_verify_spawn` を**単体**で複数回呼ぶ（mock `pane split` が 888 系を返す前提）。`test_cleanup.sh` は `OE_MANAGED_PANES` のみ設定し `killed_pane_ids==[101,102]` を期待。
- P6: bash 3.2/5.2 両対応（ADR-005）。`local -n` / `declare -A` / `mapfile` 禁止。空配列展開は `${arr[@]+"${arr[@]}"}`。

## 核心 DJ-1: spawn.sh をどう layout 化するか（盤面初期化 vs 都度 spawn の責務分離）

### ゼロベース選択肢列挙

```
DJ-1: spawn.sh 盤面構築の layout 化方式
├── 案A（初期・kickoff 素直読み）: oe_spawn_prepare_pane が毎回 wez layout apply を呼び map から1枚取る
│     採否: ❌ — layout は非冪等(P4)。2 回呼ぶ(target+reviewer)と盤面倍増。test_verify(layout 非対応 mock)破壊。
├── 案B: bin/oe で1回だけ layout apply → target=map[0]、reviewer は従来どおり都度 split（pool 非共有）
│     採否: △→再検討（後述）— 「都度 spawn の責務分離」(issue 文言)に最も忠実。だが parent-children(2子)では
│             worker2 が未消費アイドルに（cleanup 全登録で orphan は防げるが空ペインが残る・geometry 浪費）。
├── 案C+（採用）: bin/oe で1回 board apply → pool 化 FIFO 消費。oe_spawn_prepare_pane は pool から pop
│     （空なら従来 split にフォールバック）。target=pool[0]、reviewer=pool[1]（1サイクルの2役を宣言盤面が宣言）。
│     + 1回目 SO 指摘を反映: readiness 保証 / partial-apply orphan 回収 / cleanup dedup union / max-panes ガード。
│     採否: ✅（2 回の oe-refute で反証・指摘を全反映、breadth で案B を再検討の上で選択）→ 採用
├── 案D: engine 専用 preset(oe-cycle.json) を wezterm-ai-mode/lib/layouts/ に新規追加し board=それ
│     採否: ❌（既定では）— cross-project ファイル所有。Minimal Scope / 「#191 本体は変更しない」境界に近接。
│             既定は既存 parent-children に寄せ、preset 追加は将来必要時に別 issue（defer）。OE_BOARD_LAYOUT で差替可。
└── 未探索: SQLite 的セッション間 board 永続 / desired-state ensure（#191 defer・schema v2）— PoC 範囲外（後戻りコスト高）。
```

## SO ゲート（確定前ゼロベース反証・engine 運用ゲート = oe-refute が so-compare を wrap）

predecision-exploration + 受け入れ条件「Episode + so-compare」を満たすため `oe-refute --rubric exploration --lanes 2`（codex,cursor）を**2 回**実行。verdict/dissent を確定前に転記（output_dir は揮発するため要点を本文に保全）。

### 1 回目（claim=初期 案C・`refuted`・audit_id `20260620043537W4YCNF4DJ0HS`）

material 指摘 → 全て案C+ に反映:
- **(1) --wait-ready 回帰**（両レーン・critical）: layout 経路は readiness 待ちなし。→ engine 側 readiness poll `oe_board_wait_ready` を追加（pool pop ペインを送信前に poll）。fallback split は従来どおり `--wait-ready`。
- **(2) partial-apply orphan**: status≠ok の取りこぼし未検証。→ partial の生存 orphan を cleanup 登録 + board 無効化（fallback）。
- **(3) cleanup dedup**: 現 cleanup は dedup 無し。→ 3 配列 dedup union。
- **(4) step順 role 割当 / hidden cursor / reviewer 結合**: → FIFO 消費を契約として明文化、結合は1サイクル限定の既知制約 + fallback で緩和。

### 2 回目（claim=案C+・`refuted`・audit_id `20260620044126WKFA3FJSZ8K2`）

dissent が **実質的な設計欠陥から「微修正＋実装前 grounding」へ収束**。新規の actionable のみ反映:
- **(5) partial-apply 登録は `rollback_failed` のみ**（codex）: `created` は layout が逆順 rollback kill 済。生存 orphan は `rollback_failed` だけ。→ 登録対象を `rollback_failed` に限定（修正）。
- **(6) board pre-create が `OE_CB_MAX_PANES` ガードを迂回**（codex）: monitor の max-panes 判定は `OE_MANAGED_PANES` のみ数える。→ `oe_board_apply` で board ペイン数 > `OE_CB_MAX_PANES` なら board を使わず（登録だけして fallback）+ warn。CB 不変条件を保つ。
- **(7) readiness timeout 契約が未定義**（codex）: → `oe_board_wait_ready` は timeout 時 **warn + 続行（best-effort）**。`wez pane split --wait-ready` が timeout でも pane を返す挙動をミラー。死にペインは monitor CB が捕捉。
- **(8) 案B+managed の breadth 再検討要求**（cursor）: → 下記「案B 再検討」で対応。

残る dissent（=構造的・実装前 grounding）: 「実装/テスト/oe-refute 未着地」「dedup/readiness の実機検証なし」。これらは **exploration rubric が pre-implementation の claim に対し grounding(軸3) で必ず refute する構造**であり、実装+テストでしか閉じない。reframe-on-stall 判定: 1→2 回目で dissent は material に縮小（=空転ではない）。3 回目は同じ grounding 軸で再 refute する stall になるため**ここで打ち切り**、微修正を反映して実装に進む（grounding は実装+テスト+親 %32 の compliance review + Copilot で閉じる）。

### 案B 再検討（指摘(8)への breadth 応答）

cursor の指摘どおり「全 board ペインを cleanup 登録」を入れれば案B でも orphan は防げる。改めて案B（reviewer=都度 split・decouple）と案C+（reviewer=pool[1]）を比較:

| 観点 | 案B（reviewer 都度 split） | 案C+（reviewer=pool[1]） |
|---|---|---|
| issue 文言「都度 spawn の責務分離」 | ◎ 最も忠実 | ○ board が2役を宣言 |
| 「規約ベース盤面で1サイクル成立」 | △ reviewer は盤面外 | ◎ 盤面が target+reviewer を宣言 |
| parent-children(2子) 利用 | △ worker2 が空アイドル | ◎ 両ペイン消費・浪費なし |
| reviewer 結合 | ◎ 無し（動的 N に自然） | △ 1サイクル限定の結合（N>pool は fallback） |
| 新規ファイル | 1子 preset 追加なら cross-project / 既存流用なら空ペイン | 不要（既存 parent-children を完全消費） |

**採用 = 案C+**。理由: 受け入れ条件の核「`bin/oe` の1サイクルが**規約ベース盤面**で再現的に成立」は、盤面が1サイクルの2役（target/reviewer）を宣言する案C+ に最も忠実。既存 preset を新規ファイル無し・空ペイン無しで完全消費でき Minimal Scope。reviewer 結合は「盤面が1サイクルのペイン集合を宣言する」意図そのもので、N>pool は fallback split が吸収（致命でないと両レーンも明言）。案B は「都度 spawn」文言には忠実だが空ペイン or cross-project preset を招く。**この案B/案C+ の分岐は後戻りコスト中（spawn.sh 1関数 + bin/oe 配線の差）で可逆。PR で %32 に明示し human gate に委ねる**（推測で隠さない）。

## 採用設計（案C+）の具体

- **`oe_board_apply()`（新規・spawn.sh）**: `wez layout apply "$OE_BOARD_LAYOUT" --json` を**1回**。`OE_BOARD_LAYOUT` 空 → board 無し(return)。apply 失敗/非 JSON → warn + board 無し(fallback)。
  - `status=="ok"`: `panes[].pane_id` を step 順で `OE_BOARD_PANE_IDS` へ、`OE_BOARD_CURSOR=0`。**max-panes ガード**: 件数 > `OE_CB_MAX_PANES` なら全件を `OE_BOARD_MANAGED_PANES` に登録（回収用）し pool を空に（fallback）+ warn。通常は全 board ペインを `OE_BOARD_MANAGED_PANES` に登録（未消費ペインも orphan 化させない）。
  - `status=="partial"`: `rollback_failed[]`（生存 orphan のみ）を `OE_BOARD_MANAGED_PANES` に登録 + warn。pool 空（fallback）。
- **`oe_spawn_prepare_pane()`（改修）**: pool に残あり → pop → `OE_SPAWN_PANE_ID` + cursor++ + `oe_board_wait_ready`。残なし → 従来 `wez pane split --bottom --percent "$OE_SPAWN_PERCENT" --wait-ready --timeout "$OE_SPAWN_WAIT_READY_SEC"`。`OE_SPAWN_PANE_ID` の意味は不変。
- **`oe_board_wait_ready()`（新規・spawn.sh）**: `wez pane capture <id>` が非空+安定（2 連続一致）になるまで 0.5s 間隔で `OE_SPAWN_WAIT_READY_SEC` まで poll。timeout は warn + return 0（best-effort）。`_wez_wait_pane_ready` の最小ミラー。
- **`bin/oe`**: spawn 前に `oe_board_apply` を1回。target=pool[0]、verify reviewer=pool[1]。
- **`cleanup.sh`**: `OE_BOARD_MANAGED_PANES` を防御初期化し、3 配列（MANAGED + VERIFY + BOARD）の **dedup union**（先勝ち順保持）を kill + `killed_pane_ids` 化。

## DJ-2: 既定 preset / パラメータ化

- `OE_BOARD_LAYOUT`（既定 `parent-children`・空で board 無効＝kill switch 兼）。layout.sh が読めるのは `wezterm-ai-mode/lib/layouts/` のみ＝この env は同ディレクトリ内 preset 選択に限定（既知制約）。
- `OE_SPAWN_PERCENT`（既定 30・fallback split の `--percent`）。既存 `OE_SPAWN_WAIT_READY_SEC` 据え置き。
- **geometry 非互換の honest 記載**: 旧来は target/reviewer とも `--bottom --percent 30`。parent-children は worker1=bottom30% + worker2=right50%。盤面 geometry は変わる（機能後方互換は保つが視覚配置は preset に従う＝「規約ベース盤面」化の意図的帰結）。

## DJ-3: targeting 規約（#190/DJ-8）の適用面

- 盤面構築の self targeting は **layout apply 経路で満たす**（layout.sh が内部で `_wez_resolve_self_pane` を1回固定）。
- fallback split は `--target` を明示せず **DJ-8 省略時デフォルト**（self 試行→native fallback + warn）に委ねる。明示 `--target self` は解決不能時 hard error(exit3) かつ mock 群が `--target` 非対応 → テスト churn と失敗意味変化を招くため不採用。

## テスト整合（後方互換 critical）

- `test_e2e_smoke.sh`: mock に `wez layout apply --json`（panes=[{id:worker1,pane_id:777,index:0},{id:worker2,pane_id:888,index:1}] を返す）追加。target=777(pool[0])、reviewer=888(pool[1])。**既存アサーション（target=777 / reviewer=888 / kill=[777,888] / notify 等）不変**で通る。board apply 実行のアサーション追加。
- `test_verify.sh`: **無改修**（`oe_verify_spawn` 単体 → board 未 apply → pool 空 → fallback split → mock 888）。
- `test_cleanup.sh`: cleanup が `OE_BOARD_MANAGED_PANES` を防御初期化すれば**無改修**（dedup union が `[101,102]` を維持）。

## 残課題 / follow-up routing

- engine 専用 preset（oe-cycle.json）への移行 → 必要時に別 issue（本 PR は既定 parent-children）。
- multi-target（`oe_verify_run_phase` が複数 target）での pool 不足時の非対称 → fallback split で吸収。将来 multi-agent board は別 issue。
- desired-state ensure / 真の冪等 board → #191 defer（schema v2）。
- 対話 `oe-delegate`(tmux) 盤面 → out of scope（#188・別 mux レイヤ）。
