---
title: "ADR-004: pane サブコマンド群の設計判断集"
date: 2026-04-20
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-20-kickoff-wez-pane.md
    reason: "DJ-2, DJ-4, DJ-5, DJ-6, DJ-7, kill 非対話設計の判断を記録"
  - type: depends_on
    ref: ADR-001-cli-file-structure.md
    reason: "ファイル構成・命名規約を踏襲"
  - type: depends_on
    ref: ADR-002-socket-selection-strategy.md
    reason: "exit code 体系を拡張"
tags: [pane, architecture, exit-codes, ansi, design-decision]
---

# ADR-004: pane サブコマンド群の設計判断集

## ステータス

Accepted

## DJ-2: pane ファイル構成

ADR-001 の `bin/wez` + `lib/*.sh` パターンを踏襲し、`lib/pane.sh` を追加。

- ヘルパー関数（`_wez_*`）を先頭、ディスパッチャ（`wez_cmd_pane`）を末尾に配置
- `wez_cmd_pane()` は2段階パース: Stage 1 で `--socket` + サブコマンド抽出、Stage 2 で残引数をサブコマンドに丸渡し
- `--socket` はサブコマンドより前に記述する規約

## DJ-4: ソケット取得の共通化

`wez_discover_socket()` を `lib/discover.sh` から再利用。`wez_cmd_pane()` 内で `export WEZTERM_UNIX_SOCKET="$socket"` し、以降の `wezterm cli` 呼び出しがネイティブにこの環境変数を消費する設計。引数汚染（全サブコマンドに `--class` 等を透過する必要）を回避。

## DJ-5: ANSI ストリップ + 末尾空行除去

- デフォルト（`--raw` なし）: `wezterm cli get-text`（エスケープなし）+ `_wez_strip_trailing_blank`
- `--raw`: `wezterm cli get-text --escapes`（ANSI シーケンス付き）をそのまま返す
- `_wez_strip_ansi` 関数は用意したが Phase 1 では dormant。CSI 完全版（`?` private mode、DEC sequences 等）は将来の `--raw` 後処理オプション追加時に拡充予定
- so-compare レビューで CSI パターン網羅不足を指摘されており、Phase 2 での拡充が推奨

## DJ-6: send の入力制約

- 改行（`$'\n'`）とキャリッジリターン（`$'\r'`）を拒否。意図しない複数コマンド実行を防止
- `--no-paste` モードで送信（ブラケットペーストモード回避）
- Phase 1 では制御文字送信はスコープ外

## DJ-7: pane 固有 exit code

ADR-002 の exit code 体系（0〜2, 64, 127）を拡張:

| Code | 定数 | 意味 |
|------|------|------|
| 3 | `WEZ_EXIT_PANE_NOT_FOUND` | 指定 pane_id が存在しない |
| 4 | `WEZ_EXIT_TIMEOUT` | `--wait-ready` タイムアウト |
| 5 | `WEZ_EXIT_PANE_OP_FAILED` | pane 操作の実行失敗 |

send/kill で操作失敗時は `_wez_pane_exists` で再確認し、存在しなければ 3（NOT_FOUND）、存在するが操作失敗なら 5（OP_FAILED）を返す。

## kill の非対話設計

PoC-02 では `read -p "Kill pane?"` で確認を取っていたが、AI エージェントからの自動実行を前提として確認プロンプトを排除。`wez pane kill <id>` は即座に削除を実行する。これは PoC-02 から意図的に変更した設計判断。

## capture の --lines 実装

`--lines N` は `wezterm cli get-text` の全出力に対して `tail -n N` でフィルタリング。`--start-line -N` は「スクロールバック N 行前から画面末尾まで」を返すため、画面行数分余計になる問題を E2E テストで発見し修正。
