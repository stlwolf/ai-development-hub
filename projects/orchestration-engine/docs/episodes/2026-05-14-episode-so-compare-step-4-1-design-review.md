---
id: "01KRJQMAXADWEKV1P84XCZ636M"
title: "Step 4-1 設計全体の so-compare レビュー — 4 件の設計修正"
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
    reason: "Step 4-1 Plan"
  - type: design_context
    ref: "tmp/so-20260514-162654/"
    reason: "so-compare 出力ディレクトリ（Codex + Claude の生回答）"
tags: [orchestration, mvp, step-4-1, episode, so-compare, peer-review, design-correction]
---

# Step 4-1 設計全体の so-compare レビュー

## 経緯

Step 4-1 の全 5 フェーズ完了後、フェーズ境界での so-compare を全てスキップしていたため、設計全体を一括で so-compare にかけた。Codex + Claude の 2 者レビューで 8 検証ポイントを評価。

## so-compare 実行概要

- 実行日時: 2026-05-14 16:26 JST
- ツール: `so-compare -w $(pwd) -f prompt.txt`（SO_TIMEOUT=360）
- 結果: Codex 113 秒 / Claude 205 秒、2 者とも成功

## 検証結果サマリ

| # | 検証ポイント | Codex | Claude | 合意 |
|---|------------|-------|--------|------|
| 1 | Envelope Schema の妥当性 | 要注意 | OK | 方向性一致（「骨格」として OK） |
| 2 | Failure Taxonomy 6 値の網羅性 | OK | OK | 合意 |
| 3 | exit code マッピングの健全性 | 要注意 | 要注意 | 合意（SIGINT 130 問題を共通指摘） |
| 4 | SLO 数値の妥当性 | 要注意 | OK（留保あり） | 方向性一致（MVP ブロックせず） |
| 5 | KVS atomic rename 戦略 | OK | OK | 合意 |
| 6 | サーキットブレーカー監視方式 | 要注意 | 要注意 | 合意（Claude がより具体的） |
| 7 | jq 検証ツール選定 | OK | OK | 合意 |
| 8 | DI 間の整合性 | 問題あり | 要注意 | 合意（最重要指摘） |

## 発見された 4 件の設計修正

### 修正 1: session-state KVS の lifecycle state 欠如

- **問題**: `session-state.schema.json` の `state` フィールドが failure taxonomy 6 値のみ。実行中の状態（`spawn/ready/progress/done/blocked`）を KVS に表現できない
- **影響先**: `schemas/session-state.schema.json`, `docs/episodes/2026-05-14-episode-outputs-declaration-and-kvs.md`
- **修正方針**: MVP 縮退として「KVS は完了時のみ書き込む。実行中状態は `wez pane capture` のマーカースキャンで取得」を明文化（Claude 案 C）
- **根拠**: DI-8 で終了マーカースキャン（案 B）を採用済み。ポーリングによる実行中状態取得は既にディスパッチャの責務内
- **将来の拡張**: `lifecycle_state` フィールド追加（Claude 案 A）は 4-2 以降で UC-2 の並列協調が本格化した段階で検討

### 修正 2: exit code 128+N（signal-killed）の扱い未定義

- **問題**: SIGINT (130) / SIGKILL (137) が `protocol_error` に分類される。UC-1 の意図的 interrupt（`wez pane send` による SIGINT 注入）と区別不能
- **影響先**: `docs/episodes/2026-05-14-episode-exit-code-mapping.md`
- **修正方針**: episode に「128+N の扱い」セクションを追加。MVP ではディスパッチャ側で「直前に interrupt を送信した場合は exit 130 を `blocked` に再分類」する補助判定ルールを契約として明示
- **根拠**: ディスパッチャは `wez pane send` の実行主体なので、「直前に interrupt を送った」という情報を保持できる

### 修正 3: ターン定義の不整合

- **問題**: Discussion §12「メインからの再投入回数」と episode「出力変化検知回数」が異なる意味
- **影響先**: `docs/episodes/2026-05-14-episode-circuit-breaker-design.md`
- **修正方針**: Discussion §12 の定義（メイン→サブの注入回数）に統一。episode に定義変更があった場合は根拠を明示
- **根拠**: 「出力変化検知回数」はサブエージェントの進捗に依存するため、上限値の意味が曖昧になる

### 修正 4: ペイン上限のカウント対象

- **問題**: `wez pane list | jq length` は engine 管理外のペイン（ユーザー手動作成等）も含む
- **影響先**: `docs/episodes/2026-05-14-episode-circuit-breaker-design.md`
- **修正方針**: ディスパッチャが管理する `managed_pane_ids` 配列（DI-14 の trap で使用）の長さでカウント。`max_panes` は「engine が同時に管理するペイン数の上限」に再定義
- **根拠**: DI-14 で `trap` 対象の pane_id リストは既に設計済み。この配列を流用すればコスト最小

## 修正の適用方針

- 上記 4 件はいずれも **既存 Episode の改変ではなく、本 Episode 内に修正内容を記録**
- 実装（4-2 以降）では本 Episode を参照し、該当 Schema / Episode の設計を修正版として読む
- MVP リリースをブロックする問題はない。全て「実装着手前の文言修正」レベル

## 逆算検証 so-compare の省略判断

当初予定していた「KickOff 完了条件 7 項目の逆算検証」は省略。理由:

- 本 so-compare で内容面の検証（8 ポイント）を深くカバー済み
- 残りは形式面（status / リンク / 変換メモの存在）であり、PR 本文で照合完了
- 追加コスト（240 秒 × 2）に見合う新規発見の確率が低い

## 関連

- so-compare 生回答: `tmp/so-20260514-162654/codex-stdout.txt`, `claude-stdout.txt`
- 影響先 Episode: `episode-outputs-declaration-and-kvs.md`, `episode-exit-code-mapping.md`, `episode-circuit-breaker-design.md`
- 影響先 Schema: `session-state.schema.json`
