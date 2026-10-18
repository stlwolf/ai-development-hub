---
title: "ADR-005a: util.parseArgs() の --no-* negation は自動処理されない（ADR-005 訂正）"
date: 2026-02-21
type: decision
status: accepted
related:
  - type: supersedes
    ref: ADR-005-cli-packaging.md
    reason: "ADR-005 の根拠に含まれていた「--no-* negation を自動処理」が事実誤認"
  - type: evidence_for
    ref: ../episodes/2026-02-21-phase3-auto-save-cli.md
    reason: "E2E テストで --no-thinking が ERR_PARSE_ARGS_UNKNOWN_OPTION になり発覚"
tags: [cli, util-parseArgs, negation, errata]
---

# ADR-005a: util.parseArgs() の --no-* negation は自動処理されない

## 状態

Accepted（ADR-005 を部分訂正）

## 訂正内容

ADR-005 の根拠に以下の記載がある:

> `--no-*` negation を自動処理

**これは誤り。** `util.parseArgs()` は `--no-*` 形式のフラグを自動で negation 処理しない。`--no-thinking` を使うには、options に `'no-thinking': { type: 'boolean' }` を明示的に定義する必要がある。

## 経緯

- Phase 3 プラン peer-ai-review で Claude が「negation 処理も自動対応」と主張
- 3者合意に含めたが、Node.js 公式ドキュメントの `parseArgs` API に negation auto-handling の記載はなかった
- E2E テストで `--no-thinking` が `ERR_PARSE_ARGS_UNKNOWN_OPTION` となり発覚
- `'no-thinking': { type: 'boolean' }` を手動定義して解決

## ADR-005 の結論への影響

ADR-005 の結論（`util.parseArgs()` を採用する）自体は変わらない。根拠の1項目が誤りだっただけで、他の利点（ゼロ外部依存、Node.js 標準、`allowPositionals` 対応）は有効。

## 教訓

peer-ai-review の事実検証で「API が stable である」ことと「API の具体的動作」は検証粒度が異なる。公式ドキュメントの該当セクションを引用レベルで確認すべき。
