---
title: "ADR-001: CLI ファイル構成 — dispatcher + lib 分離"
date: 2026-04-19
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-19-kickoff-wez-entrypoint-discover.md
    reason: "DJ-1 および DJ-3 の判断を記録"
  - type: derived_from
    ref: ../../../poc/wezterm-ai-mode/01-socket-discovery.sh
    reason: "PoC-01 の単一ファイル構成からの発展"
tags: [architecture, cli, file-structure, source-chain]
---

# ADR-001: CLI ファイル構成 — dispatcher + lib 分離

## ステータス

Accepted

## コンテキスト

`wez` CLI は Phase 1 で `discover` のみだが、Phase 2 以降に `pane`・`notify` 等のサブコマンドが追加される。PoC-01 は単一ファイル（`01-socket-discovery.sh`）で動作していた。

## 選択肢

- **A**: 単一ファイル（PoC-01 踏襲）
- **B**: `bin/wez`（dispatcher）+ `lib/*.sh`（機能別ライブラリ）

## 判断

**B を採用**。サブコマンド追加時のファイル肥大化を避け、`lib/discover.sh`・`lib/pane.sh` 等の機能分離を最初から確立する。

## 内部呼び出しアーキテクチャ（DJ-3 統合）

- `bin/wez` が `source "$WEZ_ROOT/lib/common.sh"` / `source "$WEZ_ROOT/lib/discover.sh"` で読み込む
- lib 関数はデフォルトでサイレント（stderr 出力なし）。CLI 出力制御は `bin/wez` の `wez_cmd_*` ハンドラが担当
- `--json` は暗黙 quiet（stderr 無音）、`--verbose` で再有効化

### export 非伝搬の制約

`bin/wez` はサブシェルとして実行されるため、`export WEZTERM_UNIX_SOCKET=...` しても呼び出し元シェルには伝搬しない。対処:

- `wez discover` は stdout にソケットパスを出力し、呼び出し元が `WEZTERM_UNIX_SOCKET=$(wez discover)` で取得する
- `--json` 出力でも同様に stdout から取得する設計

## 結果

```
projects/wezterm-ai-mode/
├── bin/wez           # エントリポイント（dispatcher）
└── lib/
    ├── common.sh     # 共通ユーティリティ（色、ログ、exit code）
    └── discover.sh   # discover サブコマンド実装
```
