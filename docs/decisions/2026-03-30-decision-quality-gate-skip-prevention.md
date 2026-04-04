---
id: "01KNCK5HAPS40MFQ6NXEQFGYYD"
title: "品質ゲートのスキップ・不完全実行は機械的に防止する"
date: 2026-03-30
type: decision
status: stable
related:
  - type: evidence_for
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "§8 Tier 1 実装からの申し送り — 検証ゲート設計への入力"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/10"
    reason: "Epic #10 Tier 1 実装中に観測された失敗モード"
  - type: integration_target
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "#19 MVP 4-3 検証ゲートの要件入力"
  - type: sibling
    ref: "https://github.com/stlwolf/ai-development-hub/issues/22"
    reason: "so-compare タイムアウト回復・部分成功検知の強化"
tags: [quality-gate, so-compare, validation, epic-10, harness]
---

# 品質ゲートのスキップ・不完全実行は機械的に防止する

## コンテキスト

Epic #10 Tier 1（#11, #12, #13）の実装中に、品質ゲートが「意図どおり実行されない」失敗モードが観測された。

具体的には:

- `so-compare` を `--codex-only` で誤実行し、1者レビューだけで進めそうになった
- 2者で再実行したところ、1者では検出できなかった構造的問題（XSS 誤配置、AuthN/AuthZ 欠落等）が合意ベースで確認できた
- スキル・チェックリスト・SO レビュー手順というレールを敷いても、エージェントがレールを踏み外すケースは残った

問題はさらに手前にある:

- **品質ゲートをスキップする**: SO レビューの手順があるのに実行しない
- **品質ゲートを不完全に実行する**: 2者必要なのに1者で済ませる
- **品質ゲートの結果を無視する**: 指摘があるのに対処せずに進む

これらは「ルールで祈る」問題の変種。ルールをスキルに昇格させても、スキルの参照・実行自体がスキップされうる。

## 決定

品質ゲートはルール・スキルによる案内ではなく、機械的な仕組みで防止する。具体的には以下の4要件を #19 MVP の検証ゲート（4-3）に課す。

## 根拠

| 要件 | 根拠 |
|------|------|
| **実行証跡**: ゲートが実行されたか・結果はどうだったかを構造化データとして残す | 「実行されたか」の事後検証が今は人間の目視に依存 |
| **自動トリガー**: stop / subagentStop フックで検証を自動起動する | 手動起動だとスキップされる。#17（フック基盤）で部分対応 |
| **健全性チェック**: SO の場合「2者が回ったか」「結果が非空か」を機械的に検証 | タイムアウト・片方空・0行出力でも exit=0 で通過しうる |
| **回復パス**: ゲートが不完全だった場合にリトライを促す or 自動リトライする | 現状は人間が気づいて手動で再実行するしかない |

選択肢として「ルールの記述を強化する」「スキルの description を詳細にする」があったが、Tier 1 実装で「レールを敷いても踏み外す」ことが実証されたため棄却。

## 結果

- #19 MVP 4-3（検証ゲート v1）のスコープに上記4要件を含める
- architecture-sketch.md §9 で Phase 4 のスコープを拡張済み
- so-compare 固有の改善（exit code 分離、期待プロバイダ数表示等）は [#22](https://github.com/stlwolf/ai-development-hub/issues/22) で別途対応
- ガードレールは取り外し可能に設計する（architecture-sketch.md §2「Build to Delete」原則）
