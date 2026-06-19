---
title: "ADR-004: pane サブコマンド群の設計判断集"
date: 2026-04-20
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-20-kickoff-wez-pane.md
    reason: "DJ-2, DJ-4, DJ-5, DJ-6, DJ-7, kill 非対話設計の判断を記録"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/174"
    reason: "DJ-8 split ターゲティング規約 (self / parent-window / explicit) の判断を追記"
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

## DJ-8: split のターゲティング規約（#174）

`wez pane split` に分割元ペインの解決方法を選ぶ `--target self|parent-window|explicit` フラグを追加。優先順位は **明示（`--pane-id` または `--target explicit`） > `self` > `parent-window`**。

- `self`: `WEZTERM_PANE` 環境変数から「コマンドが動作しているペイン」を解決（MVP）。TTY 逆引きは将来スコープ。明示 `--target self` 指定時は解決した pane を `_wez_pane_exists` で実在確認し、`WEZTERM_PANE` が数値でも実在しなければ exit 3（`WEZ_EXIT_PANE_NOT_FOUND`）を返す（send/capture と一貫）。
- `parent-window`: `self` のペインの `window_id` を `wezterm cli list --format json` から引き、同ウィンドウ内の active pane（`is_active==true`）を分割元にする。`self` が解決不能なら `parent-window` も解決不能。`pane_id` / `window_id` の比較は WezTerm の JSON が数値型でも文字列型でも一致するよう `tostring` ベースで行う。`self` の `window_id` が null/不在なら明示的に失敗させ、`window_id: null` の pane を誤採用しない。
- `explicit`: 既存の `--pane-id <ID>` を踏襲。`--target explicit` 指定時は `--pane-id` 必須（無ければ usage error）。
- 解決ヘルパー（`_wez_resolve_self_pane` / `_wez_resolve_parent_window_pane`）は ADR-001 / DJ-2 の `_wez_*` ヘルパー先頭配置に従い `lib/pane.sh` に置く。pane ターゲティングは pane 操作固有のため `lib/discover.sh`（socket 解決専用）ではなく `lib/pane.sh` を選択。

#### 既知の限界

- D1: `parent-window` で同一 window に `is_active==true` の pane が複数存在する場合、JSON 順の先頭を採る（WezTerm は通常 window あたり active 1 という前提）。
- D2: `--target` を複数指定すると最後が勝つ（例: `--target explicit --target self` では `--pane-id` 必須チェックが後者の `self` で上書きされる）。病的入力につき仕様化はしない。

### 省略時デフォルト（B3）と後方互換

`--target` / `--pane-id` を両方省略した場合は **`self` を試行 → 解決不能なら `--pane-id` を省略し wezterm のネイティブ既定（`WEZTERM_PANE` が設定済みならそれ、未設定なら active pane）に委ねる + `wez_warn`**。一方、ユーザが**明示**した `self` / `parent-window` が解決不能なら**フォールバックせず即エラー終了**（exit 3 = `WEZ_EXIT_PANE_NOT_FOUND`）。これは `discover.sh` の「明示指定の失敗＝即エラー」思想に倣う。

後方互換: 本変更でデフォルトが **「常に native 既定」→「`self` を明示渡し（解決不能時のみ native 既定にフォールバック）」** に変わる。B3 は native が使うのと同じ `WEZTERM_PANE` を `--pane-id` で明示渡しするため、`WEZTERM_PANE` が設定された端末では従来 native が選んでいたペインと同一ペインを分割する。解決不能時は `--pane-id` を省略し native の既定（`WEZTERM_PANE`→active pane）に委ねる。`--pane-id`/`--target` なしの呼び出し（`orchestration-engine` の `spawn.sh` 等）は壊れない。明示 `--pane-id N` の挙動は不変。
