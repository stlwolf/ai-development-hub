---
id: "01KRH2GEPK857YKK64WRJWA30X"
title: "依存関係表現の正本形式 — 暫定 Mermaid 採用 + 将来 JSON Schema 正本案の識別"
date: 2026-05-14
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 配下、Step 4-1 KickOff Phase 1 中の派生 episode"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue（本 episode のトラッキング先）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md"
    reason: "本 episode の起点となった KickOff（§DI 依存関係セクション）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "DI-5 / DI-11 / DI-15 の Schema-driven 方針と整合"
tags: [orchestration, mvp, step-4-1, episode, dependency-graph, schema-driven, dogfood, future-issue]
---

# 依存関係表現の正本形式 — 暫定 Mermaid 採用 + 将来 JSON Schema 正本案の識別

> Step 4-1 KickOff Phase 1 中の横道の議論から派生した記録。本ツール（orchestration-engine）自体が解決すべき課題候補として識別。

## 経緯

Step 4-1 KickOff の Phase 1 軽微改善で `## DI 依存関係` セクションを追加した際、ユーザーから「依存関係に C4 を利用できるか」の問いがあった。検討した結果:

- C4 モデルは「ソフトウェア要素の構造」を統一表記で描くためのフレームワーク。Decision Item 間の依存（タスク・前提依存）に当てはめるのは意味論的にずれる
- 図化の現実解として ASCII / Mermaid / PlantUML / Graphviz / JSON-YAML を比較
- orchestration-engine 観点（構造化ドキュメントのルーティング = ノード/エッジ操作 + Schema-driven Boundaries (DI-15)）から、**JSON 正本 + Mermaid 派生レンダリング** が思想的に最も一貫する案として浮上

## 暫定決定（本 Step 範囲）

KickOff の `## DI 依存関係` を **Mermaid `flowchart`** で記述する。

| 観点 | 採用理由 |
|---|---|
| 機械抽出可能性 | Mermaid は AST 化可能（mermaid parser）で、ルーティング処理に流用可 |
| 視覚化 | GitHub / Cursor / VSCode で native レンダリング |
| 人間レビュー性 | Diff も読める + プレビューもある |
| Schema-driven 整合 | 文法レベルでは検証可（厳密 Schema 検証は JSON ほどではない） |

## 将来の dogfood 課題（識別、本 Step ではスコープ外）

**「依存関係の正本を JSON Schema 化し、Mermaid / ASCII / 任意のレンダラーを派生生成する」** という構造を取り入れる案。orchestration-engine の本質（構造化ドキュメントのルーティング）と直接的に整合する。

### 思想的整合性

| DI | 整合理由 |
|---|---|
| DI-5（G6 Initializer Envelope） | envelope 内で「依存グラフ」フィールドを持つなら JSON。可視化は派生 |
| DI-11（監査ログ JSON Lines） | タスク間遷移の記録も「ノード/エッジ」構造。同形式で揃う |
| DI-15（Schema-driven Boundaries） | 「依存表現」も Schema 化対象に含められる。enum/構造まで検証可能 |

### 実装イメージ（粗）

- 正本: `dependencies.json`（ノード ID、エッジ種別、メタデータを定義）
- レンダラー: `render-mermaid.sh` / `render-ascii.sh`（jq で正本を読み Mermaid/ASCII 生成）
- 検証: `validate-deps.sh`（JSON Schema による正本検証 + 循環依存検出）

### MVP に入れない理由

- 本 Step（4-1）のスコープは「エンベロープ + ディスパッチャの骨格」。依存表現の Schema 化は範囲外
- Mermaid 採用で「人間レビュー + 機械抽出」は最低限満たせる
- 将来の Plan 自動生成（KickOff↔Plan 自動昇格フロー）の素材としても有望なので、独立評価が望ましい

## 連結する dogfood 課題

[KickOff §補完履歴](../plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md#補完履歴) で記録した「KickOff↔Plan 自動昇格フロー」課題と同類。両者ともに「**本ツールが扱うべき構造を、本ツール自身がメタに扱う**」テーマ。Step 4-5 でまとめて Issue 化判断する候補。

## 次の判断ポイント

- Step 4-5（フィードバック → 設計修正）で本案を Issue 化するか判断
- Issue 化する場合、`KickOff↔Plan 自動昇格フロー`課題と同じ Issue にまとめるか別 Issue にするかを別途判断
- MVP 内で先行して試す価値があるなら 4-2 / 4-3 のスコープ追加候補

## 参照

- 起点 KickOff: [`docs/plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md`](../plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md)
- 設計起源: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md) §「構造化の設計課題」
- 関連 Discussion: [`docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md`](../discussions/2026-05-13-discussion-engine-scope-and-goals.md) §15 Schema-driven Boundaries
- C4 モデル: https://c4model.com/
- Mermaid `flowchart`: https://mermaid.js.org/syntax/flowchart.html
