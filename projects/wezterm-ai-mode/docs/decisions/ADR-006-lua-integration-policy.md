---
title: "ADR-006: Lua ハンドラ統合方針 — Phase 2 先送りの判断根拠"
date: 2026-04-22
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-22-kickoff-wez-notify.md
    reason: "キックオフの Lua 統合方針に基づく"
  - type: depends_on
    ref: ADR-001-cli-file-structure.md
    reason: "CLI の責務範囲を前提"
  - type: design_context
    ref: ../../../poc/wezterm-ai-mode/wezterm-config/ai-mode-events.lua
    reason: "Phase 2 で統合予定の Lua ハンドラ参考実装"
tags: [lua, wezterm, notification, phase2, architecture]
---

# ADR-006: Lua ハンドラ統合方針 — Phase 2 先送りの判断根拠

## ステータス

Accepted

## コンテキスト

`wez notify` は OSC 1337 SetUserVar でペイロードを送信するが、WezTerm でデスクトップ通知（toast）を表示するには `.wezterm.lua` に Lua イベントハンドラ（`user-var-changed` → `toast_notification`）が必要。PoC-04 に参考実装（`ai-mode-events.lua`）があり、Phase 1 で統合するか Phase 2 に先送りするかが論点。

## 判断

**Phase 1 = CLI のみ（user-var 送信まで）。Lua 統合は Phase 2 で dotfiles リポジトリに実装。**

### 検討した選択肢

| 選択肢 | 内容 | 評価 |
|--------|------|------|
| A: Phase 1 で `.wezterm.lua` に直接追記 | 最短経路 | `.wezterm.lua` は dotfiles リポジトリ管轄。本リポジトリからの変更はスコープ越境 |
| B: Phase 1 で `require` パターンで外部ファイル化 | モジュール分離 | `require` パスの解決が環境依存（XDG, symlink）。設定が複雑化 |
| **C: Phase 2 で dotfiles 統合** | CLI と Lua の責務を分離 | Phase 1 は CLI 検証に集中できる。toast は Phase 2 の検証対象 |

### 採用理由

1. **責務分離**: `wez` CLI（本リポジトリ）と `.wezterm.lua`（dotfiles）は管轄が異なる。Phase 1 は CLI の機能完成度に集中
2. **検証の段階化**: CLI が user-var を正しく送信できることを先に確立し、toast 表示は独立した検証項目とする（VERIFICATION_MATRIX A-1-4 が PARTIAL のまま）
3. **PoC 参考実装の品質**: `ai-mode-events.lua` の `gmatch('[^|]+')` パーサは空セグメント問題あり（DJ-3）。Phase 2 で Lua パーサ修正と同時に統合する方が効率的
4. **YAGNI**: 現時点で toast 通知を必要とする運用ケースがない。Phase 2 の agent 連携設計で需要が具体化してから統合

## 結果

- Phase 1 の `wez notify` はユーザー観点で「無音」（user-var は送信されるが toast は出ない）
- `--help` と README に「toast 表示には `.wezterm.lua` に Lua ハンドラが必要（Phase 2）」と明記
- Phase 2 の scope: Lua ハンドラの dotfiles 統合、`gmatch` パーサ修正、`allow-passthrough` 対応
