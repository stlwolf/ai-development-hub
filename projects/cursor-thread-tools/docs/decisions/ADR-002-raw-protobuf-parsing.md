---
title: "ADR-002: raw protobuf wire-format パーサーの採用"
date: 2026-02-21
type: decision
status: accepted
related:
  - type: derived_from
    ref: ../episodes/2026-02-21-phase2-markdown-export.md
    reason: "Phase 2 実装中にプランのアプローチを変更"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-2-1 の実装基盤"
tags: [protobuf, raw-parsing, zero-dependency]
---

# ADR-002: raw protobuf wire-format パーサーの採用

## 状態

Accepted

## コンテキスト

`agentKv:blob` に格納された protobuf バイナリからテキストを抽出する方法を選定する必要があった。Phase 2 キックオフ + peer-ai-review では `@bufbuild/protobuf` の `makeMessageType()` API を使う方針で3者合意していた。

## 決定

**外部依存ゼロの raw protobuf wire-format パーサーを自前実装する。**

## 根拠

| 候補 | 棄却理由 |
|------|---------|
| `@bufbuild/protobuf` (makeMessageType) | Step 0.5 の実データ調査で raw parsing が動作確認済み。外部依存追加の必要がなくなった |
| `.proto` codegen (protoc) | `.proto` ファイルの逆エンジニアリングが困難。必要なフィールドが限定的で過剰 |
| `protobufjs` (dynamic) | 外部依存が不要な以上、追加する理由がない |

Phase 2 Step 0.5 の実データ調査で以下が判明:

- 必要なフィールドが限定的（text, blob ID, steps のみ）
- wire-format の手動パースが実データで動作確認済み
- ~160行で全メッセージ型のデコードが完了
- 外部依存ゼロにより、バージョン互換問題が発生しない

## 影響

- `extension/src/proto/decoder.ts` に実装（198行）
- `package.json` への依存追加なし
- Cursor の protobuf スキーマ変更時は decoder.ts のフィールド番号を修正する必要がある
