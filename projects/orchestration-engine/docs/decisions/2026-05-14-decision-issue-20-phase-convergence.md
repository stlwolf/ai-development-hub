---
id: "01KRH830RTAP964SG8JWE9F404"
title: "DI-10: #20 Phase 2 合流点 — Step 4-1 完了後に #20 Phase 3 着手"
date: 2026-05-14
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-plan-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 Plan"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20"
    reason: "wez CLI Epic — Phase 3 合流先"
tags: [orchestration, mvp, step-4-1, decision, wez-cli, convergence, phase-planning]
---

# DI-10: #20 Phase 2 合流点 — Step 4-1 完了後に #20 Phase 3 着手

## コンテキスト

orchestration-engine（Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19)）と wez CLI（[#20](https://github.com/stlwolf/ai-development-hub/issues/20)）は独立した Epic だが、中間層プロトコルで合流する。Step 4-1 の Plan 段階で「いつ、どの粒度で合流するか」を確定する必要があった。

[#20](https://github.com/stlwolf/ai-development-hub/issues/20) の Phase 構成:

- **Phase 1**（完了済み）: `wez` CLI 7 プリミティブ（discover / pane list / split / send / capture / kill / notify）
- **Phase 2**: dotfiles 統合（シンボリックリンク、PATH 設定）
- **Phase 3**: `wez agent`（中間層のリッチ化）

## 検討した選択肢

- **案 A — Step 4-1 Plan 着手前に合流**: Phase 2 の中間層仕様を待ってから Plan を開始
- **案 B — Step 4-1 完了後に Phase 3 着手**: 4-1 のエンベロープ/ディスパッチャ設計を Phase 3 の入力にする
- **案 C — 4-2 着手前に合流**: Phase 2 完了を待ち、4-2 で中間層リッチ化を取り込む

## 決定

**案 B を採用**: 合流タイミングは「Step 4-1 完了 → #20 Phase 3 着手」。

- #20 Phase 2（dotfiles 統合）は orchestration-engine との合流不要。独立して進行可能
- #20 Phase 3（`wez agent`）= 中間層のリッチ化であり、Step 4-1 で確定するエンベロープ/ディスパッチャの設計が入力になる
- 本 ADR は engine 側 `docs/decisions/` に単独配置。#20 側からは相互参照で接続する

## 根拠

- Phase 1 の 7 プリミティブで DI-3 の最小集合（capture / send / kill）は充足済み。Step 4-1 は Phase 2 を待たずに進行可能
- Phase 2 は dotfiles のシンボリックリンク管理であり、中間層プロトコル仕様とは無関係
- Phase 3（`wez agent`）はディスパッチャが「何を中間層に要求するか」が確定してから設計すべき。Step 4-1 がその確定の場
- 案 A は不必要なブロッキング。案 C は 4-1 と 4-2 の間に空白期間を作るリスク

## 影響・制約

- Step 4-1 は `wez` Phase 1 API のみに依拠して実装する。Phase 2/3 の機能を前提にしない
- #20 Phase 3 の設計開始は、本 Step（4-1）のエンベロープスキーマ + ディスパッチャ責務範囲の確定が前提条件となる
- 本 ADR は engine 側にのみ配置。#20 側は Issue コメントまたは docs 内の相互参照リンクで接続

## 将来の変更トリガー

- #20 Phase 2 で `--raw` オプション等の新機能が追加され、Step 4-1 の capture 解析に影響する場合 → DI-8（最小解析ラッパー）の再評価
- Phase 3 設計時に Step 4-1 のエンベロープスキーマが不十分と判明した場合 → Step 4-5 フィードバックで修正
- 3 層モデルの中間層が `wez` 以外の実装に拡張される場合 → 本 ADR の合流点定義を再検討
