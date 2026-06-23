---
title: "ADR-004: pane サブコマンド群の設計判断集"
date: 2026-06-22
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-20-kickoff-wez-pane.md
    reason: "DJ-2, DJ-4, DJ-5, DJ-6, DJ-7, kill 非対話設計の判断を記録"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/174"
    reason: "DJ-8 split ターゲティング規約 (self / parent-window / explicit) の判断を追記"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/165"
    reason: "DJ-9 wez layout 宣言的盤面構築規約 (preset schema / 非冪等 / rollback) の判断を追記"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/210"
    reason: "DJ-10 split PROG パススルー / 新ペインでのプログラム起動方式 (shell send 棄却 → argv-spawn) の判断を追記"
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

## DJ-9: wez layout 宣言的盤面構築の規約（#165）

`wez layout` サブコマンド（`lib/layout.sh` + `bin/wez` dispatch）を追加。既存の `wez pane split` プリミティブを名付き JSON preset に沿って機械的に反復する **薄い上位層**。**wez 基盤専用・盤面構築のみ・非冪等（create-only）** に範囲を固定する。設計探索と設計SO reconcile（6 点）は `docs/discussions/2026-06-20-discussion-wez-layout.md` / `docs/plans/2026-06-20-plan-165-wez-layout.md` を正本とする。

- **定義形式（DJ-a）**: YAML パーサを持ち込まず、`jq` で読む JSON 名付き preset を採用。flat children でなく `steps`（`id` + `from` + `dir` + `percent`）+ 明示 `root` とする。flat `children[].target:self` は grid／連鎖を表現できないため。PoC は `root:"self"` / `from:"root"` のみに制約する（逸脱は exit 64）。`dir` ∈ {bottom,right,left,top}（CLI の `--<dir>` フラグへ直接マップ）、`percent` は 1-99。グリッド／ネストは将来の再帰ツリー schema v2（本 PoC 範囲外）。
- **責務（DJ-b）**: layout は盤面構築のみで、エージェント起動コマンドを持たない（`#114` クリーン出力との二重化回避）。ただし `apply --json` で **pane_id map** を返す（盤面 only ≠ ID を返さない。消費側 `#175` の `OE_SPAWN_PANE_ID` 要求に応える契約）。
- **実現方式（DJ-c）**: 既存 `wez pane split` の反復で実現する。Lua の `gui-startup`（`.wezterm.lua`）は別リポ管轄であり CLI 主体の hub と思想が割れるため不採用。
- **socket / root を一度だけ固定（SO reconcile #5）**: `wez_cmd_layout` が `wez_cmd_pane` と同型でソケットを1回解決し `export WEZTERM_UNIX_SOCKET`、`ROOT=$(_wez_resolve_self_pane)` + `_wez_pane_exists` を1回行う。以降全 split は **explicit `--pane-id $ROOT`** を内部関数 `_wez_pane_split` に渡す（`wez pane split` を N 個の subprocess で呼ばない）。これにより B3 default の active-pane フォールバックを踏まず、親が別ウィンドウを active にしていても self 起点で同一盤面を再現する。
- **非冪等（SO reconcile #2）**: split は create-only。2 回 apply するとペインが倍増する。「冪等」と呼ばず **「非冪等・clean baseline に再現的」** と help/README に明記する。真の冪等（`--replace` + 所有 marker、desired-state 差分）は PoC 外。
- **部分失敗の rollback（SO reconcile #4）**: k 番目の split が失敗したら abort し、作成済みペインを **逆順に kill（rollback）** して exit 5（`WEZ_EXIT_PANE_OP_FAILED`）。`--json` 時は `{status:"partial", root_pane_id, created, failed_step}` を出力。エージェント未起動の盤面段階のため逆順 kill は安全。
- **focus（DJ-d）**: 全 split を explicit ターゲティングするため split 毎 activate は不要。最後に focus を復帰する（既定 `root`、`--focus <target>` で上書き、preset の `focus`（step id 可）も解釈）。
- **oe / tmux（DJ-e）**: wez 基盤専用とし、tmux への delegate は out of scope（`#188` の2基盤別レイヤ + `#175` の非対話 `claude -p` 限定）。価値は engine／非対話用 outer WezTerm board に限ると honest に明記する。

#### 終了コード（DJ-7 の体系を踏襲）

layout 固有の追加コードは無く、既存定数を再利用する: preset 不在 = 1（`WEZ_EXIT_NOT_FOUND`）、root 不在/stale = 3（`WEZ_EXIT_PANE_NOT_FOUND`）、split 失敗（rollback 済）= 5（`WEZ_EXIT_PANE_OP_FAILED`）、schema/引数不正 = 64（`WEZ_EXIT_USAGE`）。`jq` 未導入は依存失敗として 5 に寄せる（DJ-8 の `parent-window` と一貫）。

#### スコープガード

盤面構築のみ（エージェント起動コマンドを持たない）/ wez 専用（tmux 非対応）/ 非冪等（明記）/ `spawn.sh`（`#175`）は触らない / grid は schema v2。

## DJ-10: split の PROG パススルーと新ペインでのプログラム起動方式（#210）

`wez pane split` に trailing `-- <PROG>...` パススルーを追加し、**新ペインでプログラムを動かす場合はペインのプログラムとして直接起動する**（split したシェルへ `wez pane send` でコマンドをタイプ送信しない）ことを規約とする。消費側は oe-view（`#210`）の viewer ペイン（`wez pane split … -- glow -p -- <path>`）。設計探索・実機検証は `../../orchestration-engine/docs/episodes/2026-06-22-episode-210-oe-view-clickable-md.md` / `../../orchestration-engine/docs/plans/2026-06-21-plan-210-oe-view-clickable-md.md` §11 を正本とする。

- **PROG パススルー（DJ-a）**: `wez pane split [...flags] -- <PROG>...` の `--` 以降を `wezterm cli split-pane` の PROG（「シェルの代わりに PROG を実行」）へ透過する。PROG 無しは既定シェル split で **完全後方互換**（出力・exit code 不変）。
- **shell-send 棄却（DJ-b・実機根拠）**: 当初 `wez pane split`（シェル）→ `wez pane send "<cmd>"`（タイプ送信）で起動する案を採ったが、実機（cockpit）で **新規ペインのシェル rc が tmux に自動アタッチ**し、send したコマンドが実行されず描画されないことを e2e で確認 → 棄却。新ペインでのプログラム起動は send-keys に依存させず PROG 直接起動に倒す。
- **副次効果（DJ-c）**: PROG は argv 配列で渡るため受信シェルの再トークナイズが起きず、パスのシェル注入面が消える（`printf %q` クォート不要）。
- **スコープ**: PROG パススルーは split の薄い透過拡張のみ。PROG の中身・ライフサイクル管理は呼び出し側責務（oe-view は replace モデルで viewer を kill→spawn）。
