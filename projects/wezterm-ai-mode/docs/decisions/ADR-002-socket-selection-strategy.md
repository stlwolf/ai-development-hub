---
title: "ADR-002: 複数ソケット選択戦略 — ハイブリッド方式"
date: 2026-04-19
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-19-kickoff-wez-entrypoint-discover.md
    reason: "DJ-2 および DJ-4 の判断を記録"
  - type: derived_from
    ref: ../../../poc/wezterm-ai-mode/01-socket-discovery.sh
    reason: "PoC-01 の mtime ソートからの発展"
tags: [socket, selection, wezterm, error-handling]
---

# ADR-002: 複数ソケット選択戦略 — ハイブリッド方式

## ステータス

Accepted

## コンテキスト

WezTerm は複数インスタンスを起動できる。`~/.local/share/wezterm/gui-sock-*` に複数のソケットファイルが存在する場合がある。PoC-01 は mtime が最新のソケットを選択していたが、デッドソケット（プロセス終了後に残ったファイル）を選んでしまうリスクがあった。

## 選択肢

- **A**: mtime 最新のソケットを選択（PoC-01 方式）
- **B**: 全ソケットに接続確認し、成功した最初のものを選択
- **C**: A+B のハイブリッド（mtime ソート + 接続確認でフォールバック）

## 判断

**C（ハイブリッド）を採用**。mtime 降順でソートし、`wezterm cli list` による接続確認が成功した最初のソケットを採用する。失敗したら次候補へフォールバック。

### オーバーライド優先順位

1. `--socket <path>` フラグ（明示指定。失敗時はフォールバックせず即エラー）
2. `WEZTERM_UNIX_SOCKET` 環境変数（同上）
3. 自動検出（ハイブリッド方式）

### PoC-01 バグ修正

PoC-01 の `newest` 変数が mtime 取得全失敗時に空のまま `export` されるバグを修正。ハイブリッド方式では接続確認を必須化し、空ソケットパスが伝搬しない設計とした。

## エラーコード体系（DJ-4 統合）

| コード | 意味 |
|--------|------|
| 0 | 成功 |
| 1 | ソケット未検出 |
| 2 | 接続失敗 |
| 64 | 使用法エラー（不正なオプション、引数不足） |
| 127 | wezterm 未インストール |

## 結果

- 単一ソケット時は接続確認のみ（mtime ソート不要）
- 複数ソケット時は mtime 降順 → 接続確認で最適なソケットを選択
- `stat -f %m`（macOS）/ `stat -c %Y`（Linux）の互換性は PoC-01 のフォールバックパターンを踏襲
