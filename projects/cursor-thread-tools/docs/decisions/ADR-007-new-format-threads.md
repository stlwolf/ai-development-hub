---
title: "ADR-007: 新フォーマットスレッド — 現状はスキップ（明示エラー）"
date: 2026-02-21
type: decision
status: accepted
related:
  - type: derived_from
    ref: ../plans/2026-02-21-plan-phase3-auto-save-cli.md
    reason: "Phase 3 Step 0-a の調査結果"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-3-4 新フォーマットスレッド検証"
tags: [new-format, conversationState, scope, skip]
---

# ADR-007: 新フォーマットスレッド — 現状はスキップ（明示エラー）

## 状態

Accepted

## コンテキスト

Phase 2 の残課題として、`conversationState: "~"` のスレッドがテキスト抽出不可であった。Phase 3 Step 0 で調査を実施。

## 決定

**新フォーマットスレッドへの積極的対応はしない。現在のコードで安全にスキップし、ワーニングメッセージで明示する。**

## 根拠

調査結果:
- `"~"` は base64 prefix だが、`extractCsString()` は `raw.length > 10` チェックで長さ1の文字列を `null` として扱う
- つまり `conversationState: "~"` は「空の base64 エンコード状態」であり、そもそもターンデータが存在しない
- 空スレッド（作成直後で会話なし）またはデータが別の場所に格納されているケース

対応しない理由:
- 空スレッドはエクスポートする内容がない（正しい動作）
- 別データパスのスレッドは Cursor のバージョンアップに伴うデータモデル変更であり、リバースエンジニアリングコストが高い
- 現在のコードは `findConversationState` → `null` → ワーニングメッセージで安全にスキップ済み
- CLI も同様に stderr に「no content」を出力してスキップ

## 影響

- コード変更なし（既存の安全なスキップで対応済み）
- ユーザーには「The thread may use a newer data format not yet supported.」メッセージを表示
- 将来 Cursor のデータモデルが判明した場合は、`findConversationState` に新パスを追加するだけで対応可能
