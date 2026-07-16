---
id: "01KXN127119AT8VSEMSKN5C1RZ"
title: "#259 episode（heavy）— oe-register（自己登録 + 委譲 link）と role 導出述語の締め"
date: 2026-07-16
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/259"
    reason: "自己登録 + 委譲 link の新 verb oe-register"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md"
    reason: "#257 §3 root cause（parent_pane 焼き込み・rewrite 機構なし）/ §4 並列 peer 原則"
  - type: design_input
    ref: ".oe/plan-259-oe-register.md"
    reason: "plan-first の設計正本（DJ-1〜6・guard 真理値表・設計SO 反映）"
tags: [orchestration, delegate-registry, oe-register, role-derivation, episode-259]
---

# #259 episode（heavy）— oe-register と role 導出述語の締め

> 冒頭注記: 本 episode の「前段（plan-first）」節は実装フェーズ着手時に plan §3/§9 から **reconstructed**（後追い再構成）。「実装フェーズ」以降はリアルタイム追記。

## Context（なぜ始まったか）

手動起動 pane（統括）が oe-tree / cockpit に現れない痛点（自己登録手段の不在）と、手動起動 pane 間の委譲に関係を登記する手段の不在。同根 = registry が spawn 時 `parent_pane` 焼き込みしか表現できない（#257 §3 verified）。QDD で scope を「自己登録 + 委譲 link の2操作・単一 verb `oe-register`・guard 既定・付随 doc 2点」に確定（`oe-reseat`＝board 張替は次の増分）。plan-first で親統括（7代目）から委譲され、gate 3 承認済で実装着手。tier=heavy（設計SO が v0 を refute した非自明な設計 pivot + role 導出述語の変更 + durable 知見の昇格見込み）。

## 実行ログ

### 前段（plan-first フェーズ・reconstructed）

- 一次読解（delegate-registry.sh / oe-delegate / oe-tree / oe-list / tests / #257 discussion）→ plan `.oe/plan-259-oe-register.md` 作成。
- gate 1（predecision-exploration）: DJ-1〜6 のゼロベース探索木を確定前に外部化。当初推奨 = 純追加（既存 lib/verb 無変更）・role:"child" 維持・guard は verb 側。
- gate 2（弱設計SO・`oe-refute --claim .oe/claim-259-oe-register.md --rubric exploration --lanes 3`）→ **verdict=refuted（3/3 lane material）**。material 指摘:
  - **F1（最重要・grounding 訂正）**: role は `.role` field でなく **entry 存在**から導出される（`oe-ident:60-71` / `event-bus.sh:49,68-76`）。自己 root 登録した無子 pane は最初の子 spawn まで「child」表示 + event に `role:"child"` 焼き込み（`oe-activity:148` / `oe-undelivered:177` が消費）。当初 grounding「readers は role を読まない」は不完全。
  - **F2（DJ-5 guard 抜け）**: target 生存未確認（record 直後 GC で無言 no-op）/ `%self` self-cycle / 自己 root モードで生きた親を持つ委譲子の暗黙 detach / read-check-write TOCTOU / key と .pane 不整合。
  - **F3（DJ-2×DJ-6）**: 自己 label スロット未定義・positional 二義（typo が silently self-label 化）。
- gate 3（owner HG）承認・実装 go。owner 確定3点:
  1. **DJ-1 = 判定述語を締める**: `is_child = 自 entry 存在 かつ parent_pane 非空`（既存 entry は全て parent 非空 → 既存データに bit-identical・新 role 値なし・空 parent は role 中立）。受け入れ基準5 は「既存データに対する挙動不変」と読み替え。述語テスト追加。
  2. **episode 暫定運用**: worktree 直後・実装前に枠作成 + 設計節を plan から reconstructed 書き起こし → 以降リアルタイム（規範は #159 別途）。
  3. **残フロー**: worktree → episode → 実装+テスト → README/canonical 2 skill → 実装SO（oe-review 2社）→ PR → closure → Copilot。PR 完成で親へ報告。マージ/掃除/close はしない。

### 実装フェーズ（リアルタイム）

- worktree `feat/#259_oe-register` を子が自作（`--base master`）。Claude cwd は追従せず絶対パスで作業。
- **episode 枠を着手時に作成**（本ファイル・reconstructed 前段付き）。
- **bin/oe-register 実装**: `root` / `link` サブコマンド（DJ-6・positional 二義を排し typo は exit 2）。root=`oe_reg_record "$SELF" "" "$ws" ""`（parent 空）/ link=`oe_reg_record "%N" "$label" "$ws" "$SELF"`。guard は verb 側（§4 真理値表 rev.2）。**lib write path は無変更**（既存 `oe_reg_record` を呼ぶだけ）。
  - 実装中の bug: `set -e` 下で `out="$(tmux ...)"; rc=$?` が list-panes 失敗時に代入行で即 exit(1) し rc 捕捉前に落ちる（test [12] が exit 2 期待に対し 1 で検出）→ `|| rc=$?` で compound 化して修正。
- **DJ-1 述語締め**: `bin/oe-ident`（is_child）と `lib/event-bus.sh`（`_oe_event_ident`）を「自 entry 存在 かつ parent_pane 非空」へ。既存 entry は全て parent 非空ゆえ既存データに bit-identical・新 role 値なし。event-bus の report/kick 方向判定は関係（fparent==tp）で上書きするため、parent 空の自己 root sender は honest neutral になり誤 report 化が消える（SO 予測どおりの改善）。
- **テスト**: `tests/test_oe_register.sh`（33 checks・guard 3態 + SO 抜け3〔非生存 target / %self / detach〕 + 形式エラー + env エラー）。`test_oe_ident.sh`（+3: 自己 root neutral / 子持ち→parent / 既存形不変）・`test_event_bus.sh`（+4: `_oe_event_ident` の自己 root neutral / 既存形 child 不変）に述語テスト追加。
- **gate（全 green + shellcheck）**: 新規 33 + 既存 tests/test_*.sh 全 green（test_delegate_registry 20/0・test_oe_delegate 20/0・test_oe_ident 14/0・test_event_bus 66/0・test_oe_tree ok 等）。shellcheck 新規/変更 6 ファイル PASS。
- **doc**: `bin/README.md` に oe-register verb 節 / `delegate-task` skill に register 操作節 + 全体像表 + 関連 / `doc-flow-guardrail` cold-start に自己登記 1 行（#259 が予告した接続の完成）。
- （次: gate 4 実装SO → PR → closure → Copilot）

### closure（gate 5・マージ前）

（PR レビュー後・マージ前に追記）
