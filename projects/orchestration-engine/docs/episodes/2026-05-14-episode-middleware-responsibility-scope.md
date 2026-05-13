---
id: "01KRH830T0M0P2JQW2GH5BMCEZ"
title: "DI-1: 中間層責務範囲 — CLI 起動 + envelope 注入 + 最小限中間層 API を薄いライブラリ層に統合"
date: 2026-05-14
type: episode
status: draft
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
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "3 層モデル・ディスパッチャ概念の起点"
  - type: design_context
    ref: "docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md"
    reason: "CLI ラッパー 4 層モデル"
tags: [orchestration, mvp, step-4-1, episode, dispatcher, middleware, responsibility]
---

# DI-1: 中間層責務範囲 — CLI 起動 + envelope 注入 + 最小限中間層 API を薄いライブラリ層に統合

## 経緯・背景

3 層モデル（指揮層 / 中間層 / 実行層）のうち、中間層（通信プロトコル）の責務をディスパッチャがどこまで内包するかが Step 4-1 の設計判断の核心。DI-3 で中間層プロトコル要件の最小集合が確定したことを受け、ディスパッチャ側の責務範囲を確定する必要があった。

## 検討した選択肢

- **案 A**: ディスパッチャは CLI 起動と envelope 注入のみ。中間層 API（`wez pane capture` 等）の呼び出しは別レイヤが担当
- **案 B**: ディスパッチャに最小限の中間層 API 呼び出し（capture / send / kill）を含む薄いライブラリ層を統合
- **案 C**: ディスパッチャは Bash 関数として中間層 API をラップし、UC ごとの「監視ループ関数」を提供

## 確定内容: 案 B

CLI 起動 + envelope 注入 + 最小限の中間層 API 呼び出し（capture / send / kill）を薄いライブラリ層としてディスパッチャに統合する。

ディスパッチャの責務:

| 責務 | 具体的な操作 |
|------|-------------|
| CLI 起動 | サブエージェント CLI（claude / codex / cursor）の spawn |
| envelope 注入 | 起動時にコンテキスト・エンベロープを引数/環境変数/プロンプトで注入 |
| capture | `wez pane capture` で直近出力をポーリング取得 |
| send | `wez pane send` で TTY 文字列注入（割り込み・応答注入） |
| kill | `wez pane kill` でペイン終了（タイムアウト・クリーンアップ） |

## 根拠

- architecture-sketch §5: 「ディスパッチャ: Bash スクリプト / CLI 呼び出しの薄いラッパー」— 案 B はこの設計指針と合致
- Discussion §7: 「ディスパッチャは CLI ラッパー層 + 最小限の解析ラッパー機能を担う」— 解析ラッパー（DI-8）の前提として中間層 API の呼び出し手段が必要
- 案 A ではディスパッチャがペインの生死すら管理できず、MVP の 1 サイクル完走に不十分
- 案 C の UC ごとの監視ループ関数は責務が肥大。4-2 以降で段階的に追加すべき範囲
- capture / send / kill は `wez` CLI の薄い呼び出し（1 コマンド = 1 関数）であり、統合しても複雑度は低い

## 影響・制約

- DI-3 との整合: ディスパッチャが呼び出す中間層 API は DI-3 で確定した 4 項目の範囲内。registry 管理 + capture + send + kill
- DI-8（最小解析ラッパー）: capture の戻り値をディスパッチャ内で解析する責務が追加される。ただし解析範囲は DI-8 で別途確定
- 監視ループ（ポーリング間隔の制御、リトライ戦略）はディスパッチャの外側（指揮層 or UC 固有スクリプト）に置く。4-2 以降のスコープ

## 将来の拡張ポイント

- 案 C の監視ループ関数は Step 4-2 以降で UC ごとに段階的追加
- `wez agent`（#20 Phase 3）が提供するリッチ API への切り替え時、ライブラリ層の内部実装を差し替えるだけで上位は影響なし
- 中間層 API が `wez` 以外（Docker / SSH 等）に拡張される場合、ライブラリ層のインターフェースを維持したまま実装を追加
