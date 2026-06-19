# wezterm-ai-mode

WezTerm の **Human Mode（tmux 維持）** と **AI Mode（`wezterm cli` 上乗せ）** を両立する `wez` CLI ツールキット。技術検証は [`projects/poc/wezterm-ai-mode/`](../poc/wezterm-ai-mode/) に凍結されたまま残す。

## ステータス

**Phase 1 完了** — `wez discover` + `wez pane` (list/split/send/capture/kill) + `wez notify` が動作し、Cursor / Claude Code / Codex CLI の3ツールで7ステップ統合フロー（discover → pane list → split → send → capture → notify → kill）の E2E 検証を完了。[Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20) で Phase 2 以降の追加機能を予定。

**既知制約**:
- capture の出力に tmux statusbar / prompt 装飾が混入する。`wez pane capture --raw` は ANSI escape を保持するオプション（CLI リファレンス参照）であり、装飾除去ではない。マーカー方式で回避可能。装飾を落とすフィルタやオーケストレータ向けの専用オプションは Phase 2 で検討。
- Cursor / Codex CLI のサンドボックス環境では `required_permissions: ["all"]` が必要（WezTerm の Unix ソケットへのアクセス制限）

## クイックスタート

```bash
# ソケット自動検出 + 接続確認
./projects/wezterm-ai-mode/bin/wez discover

# JSON 出力（スクリプト連携用）
./projects/wezterm-ai-mode/bin/wez discover --json

# 他スクリプトからソケットパスを取得
WEZTERM_UNIX_SOCKET=$(./projects/wezterm-ai-mode/bin/wez discover --quiet)

# ペイン操作
./projects/wezterm-ai-mode/bin/wez pane list
./projects/wezterm-ai-mode/bin/wez pane split --right --percent 30
./projects/wezterm-ai-mode/bin/wez pane activate <source-pane-id>   # split 後に元ペインへフォーカスを戻す
./projects/wezterm-ai-mode/bin/wez pane send <pane-id> "echo hello"
./projects/wezterm-ai-mode/bin/wez pane capture <pane-id> --lines 5
./projects/wezterm-ai-mode/bin/wez pane kill <pane-id>

# 通知（user-var 送信）
./projects/wezterm-ai-mode/bin/wez notify "Build Complete" "All tests passed"
./projects/wezterm-ai-mode/bin/wez notify --json --timeout 8000 "Deploy" "Production"
```

## CLI リファレンス

### `wez discover`

WezTerm の UNIX ソケットを自動検出し、`wezterm cli list` で接続を確認する。

```
Usage: wez discover [options]

Options:
  --json           JSON 出力（stderr 抑制）
  --quiet          stderr のステータスメッセージを抑制
  --verbose        --json 使用時にも stderr を有効化
  --socket <path>  ソケットパスを明示指定（自動検出をスキップ）
```

**ソケット解決の優先順位**:

1. `--socket <path>` フラグ
2. `WEZTERM_UNIX_SOCKET` 環境変数
3. `~/.local/share/wezterm/gui-sock-*` からの自動検出

明示指定（1, 2）が失敗した場合はフォールバックせず即エラー。自動検出（3）では複数ソケットがある場合に mtime 降順 + 接続確認のハイブリッド方式で最適なものを選択する。

**JSON 出力スキーマ** (`--json`):

```json
{
  "socket": "/Users/you/.local/share/wezterm/gui-sock-12345",
  "pane_count": 3
}
```

### `wez pane`

WezTerm ペインの操作。ソケットは `wez discover` と同じ優先順位で自動解決される。`--socket` で明示指定も可能。

```
Usage: wez pane [--socket <path>] <subcommand> [options]

Subcommands:
  list      List all panes as JSON
  split     Split a pane to create a new one
  send      Send text to a pane
  capture   Capture text output from a pane
  kill      Kill (close) a pane
  activate  Activate (focus) a pane
```

#### `wez pane list`

```
Usage: wez pane list [options]

Options:
  --quiet          Suppress status messages on stderr
  --verbose        Show pane count on stderr
```

#### `wez pane split`

```
Usage: wez pane split [options]

Options:
  --right          Split horizontally, new pane on the right (default)
  --bottom         Split vertically, new pane on the bottom
  --left / --top   Other directions
  --percent <N>    Size of the new pane as percentage 1-100 (default: 50)
  --pane-id <ID>   Specify the source pane to split (explicit target)
  --target <T>     Targeting mode: self | parent-window | explicit
  --cwd <PATH>     Set working directory for the new pane
  --json           Output result as JSON
  --wait-ready     Wait until the new pane is ready for input
  --timeout <SEC>  Timeout for --wait-ready in seconds (default: 10)
```

`--wait-ready` はポーリングで新ペインの出力が安定するまで待機する（tmux auto-attach のタイミング問題を吸収）。

##### ターゲティング規約（`--target`）

分割元ペインの解決方法を選ぶ。優先順位は **明示（`--pane-id` または `--target explicit`） > `self` > `parent-window`**。

- `self` — このコマンドが動作しているペイン（`WEZTERM_PANE` 環境変数から解決）を分割する。MVP では `WEZTERM_PANE` のみ対応（TTY 逆引きは将来）。明示 `--target self` で `WEZTERM_PANE` が数値でも実在しない（stale）場合は exit 3（`WEZ_EXIT_PANE_NOT_FOUND`）。
- `parent-window` — `self` のペインの `window_id` を `wezterm cli list` から引き、同ウィンドウ内の active pane（`is_active==true`）を分割元にする。`self` が解決できなければ `parent-window` も解決不能。`pane_id` / `window_id` は JSON が数値型でも文字列型でも一致するよう比較する。**`jq` 必須**（JSON から `window_id` / `is_active` を解決するため）。`jq` 未導入で明示 `--target parent-window` を指定した場合は `jq` 不在を示す明示エラーで exit 5（`WEZ_EXIT_PANE_OP_FAILED`）となる（`self`（`WEZTERM_PANE` のみ）と省略時デフォルトは `jq` 不要）。
- `explicit` — `--pane-id <ID>` を分割元にする。`--target explicit` 指定時は `--pane-id` が必須（無ければ usage error）。

`self` / `parent-window` を**明示**して解決できない場合（例: `WEZTERM_PANE` 未設定）は、フォールバックせず即エラー終了する（`wez discover` の「明示指定の失敗＝即エラー」思想に倣う）。

既知の限界: 同一 window に active pane が複数報告される場合は JSON 順の先頭を採る（通常 window あたり active 1 の前提）。`--target` を複数指定すると最後が勝つ。

###### 省略時デフォルトと後方互換

`--target` と `--pane-id` を**両方省略**した場合は `self` を試行し、解決できなければ `--pane-id` を省略して `wezterm cli split-pane` のネイティブ既定（`WEZTERM_PANE` が設定済みならそれ、未設定なら active pane）に委ね、`WARNING` を出す。

> **後方互換に関する注記**: `wezterm cli split-pane` のネイティブ既定は「`--pane-id` 省略時に `WEZTERM_PANE` を使い、未設定なら active pane にフォールバック」である。本変更でデフォルトが **「常に native 既定」→「`self` を `--pane-id` で明示渡し（解決不能時のみ native 既定にフォールバック）」** に変わった。B3 は native が使うのと同じ `WEZTERM_PANE` を明示渡しするので、`WEZTERM_PANE` が設定された端末では従来 native が選んでいたペインと同一ペインを分割する。解決不能時は `--pane-id` を省略し native の既定（`WEZTERM_PANE`→active pane）に委ねる。`wez pane split --bottom --percent 30 --wait-ready --timeout N` のような `--pane-id`/`--target` なしの呼び出し（`orchestration-engine` の `spawn.sh` 等）は壊れない。明示 `--pane-id N` の挙動は不変。

#### `wez pane send`

```
Usage: wez pane send (<pane-id> | --pane-id <ID>) <text>
```

テキストを `--no-paste` モードで送信し、末尾に改行を追加。改行・復帰文字を含むテキストは拒否。

#### `wez pane capture`

```
Usage: wez pane capture (<pane-id> | --pane-id <ID>) [options]

Options:
  --lines <N>      Capture only the last N lines
  --raw            Include ANSI escape sequences (uses get-text --escapes)
```

デフォルトはプレーンテキスト（末尾空行ストリップ済み）。

#### `wez pane kill`

```
Usage: wez pane kill (<pane-id> | --pane-id <ID>) [options]

Options:
  --json           Output result as JSON
```

確認プロンプトなしで即座にペインを閉じる。

#### `wez pane activate`

```
Usage: wez pane activate (<pane-id> | --pane-id <ID>) [options]

Options:
  --json           Output result as JSON
```

指定ペインにフォーカスを移す（`wezterm cli activate-pane` 相当）。`split` はデフォルトで新ペインにフォーカスを奪うため、オーケストレータが作業ウィンドウのフォーカスを維持したい場合は `split` 直後に元ペイン id を `activate` してフォーカスを戻す。成功時は標準出力なし（`--json` 指定時のみ `{"pane_id":N,"status":"activated"}`）。

### `wez notify`

WezTerm ペインに user-var（OSC 1337 SetUserVar）を送信する。送信方式は TTY 直接書き込み（primary）と command string（fallback）の2段階。

```
Usage: wez notify [options] <title> [body]

Options:
  --pane-id <ID>    Target pane (default: auto-detect first pane)
  --timeout <MS>    Toast duration in milliseconds (default: 4000)
  --socket <path>   WezTerm socket path (default: auto-detect)
  --json            Output result as JSON
```

ペイロード形式: `title|body|timeout` を base64 エンコードし、user-var `ai_notify` として送信。

**制約**:
- title: 必須、最大 500 文字
- body: 任意、最大 2000 文字
- title と body に `|`（パイプ文字）および制御文字（改行・タブなど）を含めることはできない
- timeout の範囲: 100〜60000 ミリ秒

**送信方式（ADR-007）**:
- **Primary**: `wezterm cli list` から `tty_name` を取得し、TTY デバイスに OSC を直接書き込み。history 汚染なし、プロンプト状態非依存
- **Fallback**: `tty_name` が利用不可の場合、`printf` コマンド文字列を `send-text --no-paste` で送信。history にコマンドが残る

**toast 通知の表示**: Phase 1 では CLI（user-var 送信）のみ。デスクトップ通知を表示するには `.wezterm.lua` に Lua イベントハンドラが必要（Phase 2、ADR-006）。

**JSON 出力スキーマ** (`--json`):

```json
{
  "pane_id": 0,
  "status": "sent",
  "method": "tty",
  "title": "Build Complete",
  "timeout": 4000
}
```

### `wez help`

サブコマンド一覧を表示。

### `wez version` / `wez --version`

バージョン情報を表示。

## Exit codes

全サブコマンド共通。

| コード | 定数 | 意味 |
|--------|------|------|
| 0 | `WEZ_EXIT_SUCCESS` | 成功 |
| 1 | `WEZ_EXIT_NOT_FOUND` | ソケット未検出 |
| 2 | `WEZ_EXIT_CONN_FAIL` | 接続失敗 |
| 3 | `WEZ_EXIT_PANE_NOT_FOUND` | ペイン未検出 |
| 4 | `WEZ_EXIT_TIMEOUT` | タイムアウト（`--wait-ready`） |
| 5 | `WEZ_EXIT_PANE_OP_FAILED` | ペイン操作失敗 |
| 64 | `WEZ_EXIT_USAGE` | 使用法エラー（不正なオプション、引数不足） |
| 127 | `WEZ_EXIT_NO_WEZTERM` | wezterm 未インストール |

## ファイル構成

```
projects/wezterm-ai-mode/
├── bin/wez              # エントリポイント（subcommand dispatcher）
├── lib/
│   ├── common.sh        # 共通: カラー、ログ関数、exit code 定数
│   ├── discover.sh      # wez discover の実装
│   ├── pane.sh          # wez pane の実装（list/split/send/capture/kill/activate）
│   └── notify.sh        # wez notify の実装（TTY direct write + fallback）
├── docs/
│   ├── VERIFICATION_MATRIX.md
│   ├── decisions/       # ADR（設計判断記録）
│   ├── episodes/        # 作業記録
│   └── plans/           # キックオフ・実装プラン
├── CONVENTIONS.md        # ドキュメント規約
└── README.md             # ← このファイル
```

## 前提条件

- **Bash** 3.2+
- **wezterm** CLI（`brew install --cask wezterm`）
- **jq**（推奨。不在時は `grep -c` フォールバックで動作）

## 開発方式（検証ケース）

[cursor-thread-tools](../cursor-thread-tools/) と同型の **Stage 1（Agent: プラン + peer-ai-review）→ Stage 2（Plan mode: 実装）→ Stage 3（記録）** を本リポジトリで2例目として検証する。手順の正本は [CONVENTIONS.md](CONVENTIONS.md)。

## ドキュメント

- [CONVENTIONS.md](CONVENTIONS.md) — 命名・frontmatter・plan/episode 分離・gate
- [docs/plans/](docs/plans/) — キックオフ・実装プラン
- [docs/VERIFICATION_MATRIX.md](docs/VERIFICATION_MATRIX.md) — A: ツール / B: プロセス
- [docs/decisions/](docs/decisions/) — ADR（設計判断記録）
- [docs/episodes/](docs/episodes/) — 実装エピソード
- [docs/raw-logs/README.md](docs/raw-logs/README.md) — 層3の一時ログ置き場

## sync-bin.sh 統合

`~/bin/wez` として PATH 配置済み（[`scripts/sync/sync-bin.sh`](../../scripts/sync/sync-bin.sh) 経由のシンボリックリンク）。`so-compare` / `arena-compare` と同じパターン。

```bash
./scripts/sync.sh bin   # ~/bin/wez を作成・更新
wez discover            # パスなしで実行可能
```
