---
id: "01KRH830V72B46ETV5NXJNNM0J"
title: "DI-8: 最小解析ラッパー — CLI ラッパー + 終了マーカースキャン"
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
    ref: "docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md"
    reason: "CLI ラッパー 4 層モデル（DI-8 の前提）"
tags: [orchestration, mvp, step-4-1, episode, dispatcher, analysis-wrapper, state-marker]
---

# DI-8: 最小解析ラッパー — CLI ラッパー + 終了マーカースキャン

## 経緯・背景

KickOff DI-8 は「ディスパッチャが CLI ラッパー層に留まるか、ポーリング出力の装飾除去・状態抽出の最小解析ラッパー機能をどこまで持つか」の確定を求めていた。DI-1（中間層責務範囲 = 案 B: 薄いライブラリ層統合）と DI-3（最小集合 4 項目）が前提依存として確定済み。

## 検討した選択肢

- **案 A**: 純粋な CLI ラッパー（起動 + envelope 注入 + exit code 取得のみ）
- **案 B**: 案 A + 出力末尾の「終了マーカー」スキャン（例: `===STATE: done===`）
- **案 C**: 案 B + ANSI 装飾除去 / 状態語彙閉集合の正規表現抽出

## 確定内容: 案 B

CLI ラッパー機能に加え、`wez pane capture` の出力から終了マーカー（`===STATE: done===` 等）をスキャンする機能をディスパッチャに含める。

マーカー仕様:

| マーカーパターン | 対応状態 | 検出方法 |
|-----------------|----------|----------|
| `===STATE: done===` | done | grep / bash pattern match |
| `===STATE: blocked===` | blocked | 同上 |
| `===STATE: progress===` | progress（optional） | 同上 |

マーカーはサブエージェントが出力末尾に書き出す契約。ディスパッチャは `wez pane capture` の結果に対して固定パターンの grep を実行し、状態を判定する。

## 根拠

- [#20](https://github.com/stlwolf/ai-development-hub/issues/20) コメントの実証: オープンループは `__DONE__` マーカー + capture ポーリングで実用可能であることが確認済み
- exit code だけでは「部分成功」「停滞（blocked）」を区別できない。マーカーにより状態語彙（DI-3 の 5 値）への明確なマッピングが可能
- 案 A は exit code のみに依存し、オープンループの状態判定に不十分
- 案 C の ANSI 除去は、capture の装飾混入問題が #20 Phase 2 の `--raw` オプションで対処予定。ディスパッチャ側で対処する優先度は MVP では低い
- 状態語彙の正規表現抽出（案 C）は、マーカー方式で十分代替可能。サブエージェント側に明示的マーカー出力を契約化する方が信頼性が高い

## 影響・制約

- サブエージェント側の契約: 実行完了時に `===STATE: {state}===` を出力する必要がある。この契約は envelope 内で指示する（DI-5 G6 Initializer Envelope で定義予定）
- DI-1 との整合: ディスパッチャのライブラリ層に `capture + grep` の薄い関数が追加される
- ANSI 装飾が混入した場合、マーカーの grep が失敗するリスクがある。MVP ではこのリスクを受容し、#20 Phase 2 の `--raw` で根本対処する

## 将来の拡張ポイント

- #20 Phase 2 で `--raw` が利用可能になれば、案 C の ANSI 除去 + 正規表現抽出への段階的移行が可能
- マーカーパターンの拡張: `===STATE: retryable_failure===` 等の G4 6 値への対応は Step 4-3 以降
- 構造化出力（JSON マーカー）への移行: マーカーを `{"state": "done", "exit_code": 0}` のような JSON に拡張し、grep から jq パースに切り替える案は Phase 3 以降の候補
