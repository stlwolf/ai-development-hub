---
title: "wez エントリポイント + discover サブコマンド実装"
date: 2026-04-19
type: episode
related:
  - type: implements
    ref: ../plans/2026-04-19-kickoff-wez-entrypoint-discover.md
    reason: "キックオフプランの実行記録"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-2-1, A-2-4 の検証結果"
tags: [implementation, cli, discover, socket, phase1]
---

# wez エントリポイント + discover サブコマンド実装

## 概要

Issue #28 に基づき、`wez` CLI のエントリポイントと `discover` サブコマンドを実装した。Phase 1 ステップ 1-1。

## 実行フロー

- **Stage 1（プラン策定）**: arena-compare 2ラウンド + peer-ai-review で3モデル合意済み（前スレッドで完了）
- **Stage 2（実装）**: Step 0〜3 を本スレッドで実行
- **Stage 3（記録）**: 本エピソード + ADR-001, ADR-002 + VERIFICATION_MATRIX 更新

## Step 0: 前提調査

| 項目 | 結果 |
|------|------|
| wezterm CLI | `/opt/homebrew/bin/wezterm` v20240203 |
| jq | `/opt/homebrew/bin/jq` v1.8.0 → jq 使用で決定 |
| ソケット | `~/.local/share/wezterm/gui-sock-93607` に1個存在 |
| stat macOS | `stat -f %m` 正常動作 |
| デッドソケット | ハング無し、約2.5秒でエラー返却（exit 1） |
| bin/ | 未作成（期待通り） |

## Step 1: エントリポイント + lib 骨格

- `bin/wez`: dispatcher（help/version/discover サブコマンド）
- `lib/common.sh`: カラー、ログ関数、exit code 定数
- `lib/discover.sh`: スタブで作成
- `WEZ_ROOT` は `BASH_SOURCE` の symlink 再帰解決（macOS 互換）
- shellcheck パス

## Step 2: discover サブコマンド実装

- `wez_discover_socket()`: オーバーライド優先順位（--socket > env > auto-detect）
- `_wez_auto_detect_socket()`: mtime ソート + 接続確認のハイブリッド方式
- `wez_verify_connection()`: `jq length` でペイン数カウント
- `wez_cmd_discover()`: `--json`/`--quiet`/`--verbose`/`--socket` オプション
- PoC-01 の空 newest バグを設計レベルで解消
- shellcheck パス

## Step 3: E2E 検証

全9項目パス:

| # | テスト | 結果 |
|---|--------|------|
| 1 | `wez discover` | PASSED |
| 2 | `wez discover --json` + jq パース | PASSED |
| 3 | `wez discover --quiet` stderr 空 | PASSED |
| 4 | `wez discover --json` stderr 漏出なし | PASSED |
| 5 | `wez help` | PASSED |
| 6 | `wez --version` | PASSED |
| 7 | `wez foo` エラー | PASSED |
| 8 | `WEZTERM_UNIX_SOCKET` override | PASSED |
| 9 | `--socket /nonexistent` エラー | PASSED |

## 設計判断

- **DJ-1**: B（dispatcher + lib）→ ADR-001
- **DJ-2**: C ハイブリッド（mtime + verify）→ ADR-002
- **DJ-3**: lib サイレント、出力は bin/wez 側 → ADR-001 に統合
- **DJ-4**: exit code 体系（0/1/2/127）→ ADR-002 に統合

## 概算 vs 実績

| Step | 概算 | 備考 |
|------|------|------|
| Step 0 | 15分 | 前提すべて OK、ブランチ作成含む |
| Step 1 | 30分 | shellcheck SC2034 修正含む |
| Step 2 | 45分 | SC2317 リファクタ含む |
| Step 3 | 15分 | 全パス、修正不要 |
