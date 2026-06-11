---
id: "01KRH830QHK3NWQR5R5C8GW4AS"
title: "DI-3: UC 中間層プロトコル要件 — 3 UC 共通最小集合のみ Step 4-1 に含める"
date: 2026-05-14
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-plan-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 Plan（本 episode の実行元）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20"
    reason: "wez CLI Epic — 中間層 API の供給元"
tags: [orchestration, mvp, step-4-1, episode, middleware-protocol, uc-subset]
---

# DI-3: UC 中間層プロトコル要件 — 3 UC 共通最小集合のみ Step 4-1 に含める

## 経緯・背景

Step 4-1 は「エンベロープ + ディスパッチャの骨格」構築が主題。Discussion §5 の各 UC が要求する中間層プロトコル要件は多岐にわたるが、全てを Step 4-1 に含めるとスコープが肥大する。KickOff DI-3 として「Step 4-1 で実装する最小サブセット」の確定が求められていた。

## 検討した選択肢

- **案 A**: 3 UC 共通の最小集合のみ Step 4-1 で実装。UC 固有要件は 4-2 以降に延期
- **案 B**: 案 A + UC-2 のファイルベース KVS スキーマも 4-1 に含める
- **案 C**: UC-3 の dashboard API を 4-3/4-4 に延期し、UC-1/UC-2 中心で 4-1 を組む

## 確定内容: 案 A

3 UC 共通の最小集合 4 項目のみを Step 4-1 の中間層プロトコル要件とする。

| # | 要件 | 充足手段 |
|---|------|----------|
| 1 | `session_id ⇔ pane_id` registry | 全 UC 共通。ファイル or 変数で管理 |
| 2 | ペイン直近出力の非同期ポーリング API | 既存: `wez pane capture` |
| 3 | 実行中プロセスへの割り込み + TTY 文字列注入 API | 既存: `wez pane send` |
| 4 | ライフサイクル状態語彙の閉集合 | `spawn / ready / progress / done / blocked` |

## 根拠

- Step 4-1 はエンベロープ + ディスパッチャの骨格構築。中間層の完全実装は [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 3 に依存する
- 上記 4 項目は `wez` Phase 1 の既存 API（7 プリミティブ）で充足可能。新規実装が不要
- 案 B の KVS スキーマは UC-2 固有の要件であり、ディスパッチャ骨格の前提ではない
- 案 C は UC-3 を 4-1 から除外するが、状態語彙やポーリングは UC-3 でも必要であり、除外基準が不明確

## 影響・制約

- DI-1（中間層責務範囲）: 本決定により、ディスパッチャが呼び出す中間層 API が 3 つ（capture / send / kill）に限定される
- DI-8（最小解析ラッパー）: capture の出力を解析する範囲が、状態語彙 5 値 + 終了マーカーに限定される
- UC-2 の KVS / UC-3 の dashboard API は 4-2 以降のスコープ。段階的に追加する設計が前提

## 将来の拡張ポイント

- [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 3（`wez agent`）で中間層 API がリッチ化された際に、本 4 項目を基盤として拡張
- UC-2 KVS スキーマは Step 4-2 の候補。registry の上に KVS レイヤを積む構造
- `--raw` オプション（#20 Phase 2）による ANSI 除去が利用可能になれば、capture 出力の解析精度が向上
