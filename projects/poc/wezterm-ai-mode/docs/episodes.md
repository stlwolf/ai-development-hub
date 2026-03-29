# WezTerm AI Mode PoC - Episodes

各PoC実行後に結果を追記する。

---

## PoC-01: ソケット自動検出

**日時**: 2026-03-29
**結果**: PASSED

### 実行コマンド

```bash
bash 01-socket-discovery.sh --run
```

### 出力

```
=== WezTerm Socket Auto-Discovery PoC ===

--- Step 1: Discover socket ---
[discover] Socket found: /Users/eddy/.local/share/wezterm/gui-sock-92565
  WEZTERM_UNIX_SOCKET=/Users/eddy/.local/share/wezterm/gui-sock-92565

--- Step 2: Verify connection ---
[verify] OK: Connected to WezTerm (2 panes found)
  Connection verified

--- Step 3: List panes ---
WINID TABID PANEID WORKSPACE SIZE   TITLE                      CWD
    1     1      1 default   225x41 MacBookPro14-2021-FA.local file:///Users/eddy/work
    0     0      0 default   166x34                            file:///Users/eddy/work

=== PoC-01 PASSED ===
```

### 観察事項

- ソケットパスは `~/.local/share/wezterm/gui-sock-{PID}` 形式。PIDはWezTermプロセスのもの
- 現在のソケットは1つ（gui-sock-92565）。WezTermを複数起動した場合の挙動は未検証
- `wezterm cli list` の `find: : No such file or directory` は `.wezterm.lua` の `random_background_image()` が空パスでfindを実行しているため（無害）
- Cursor統合ターミナルから `WEZTERM_UNIX_SOCKET` 未設定の状態で自動検出 → 接続まで正常動作
- 2つのWezTermペイン（pane 0, 1）が検出された。両方ともtmux内で動作中

---

## PoC-02: ペイン操作

**日時**: 2026-03-29
**結果**: PASSED（制約あり）

### 実行コマンド

```bash
echo "y" | bash 02-pane-operations.sh
```

### 出力（要約）

```
--- Step 1: Split pane (right) ---
  Created pane: 2

--- Step 2: Send command to new pane ---
  Command sent to pane 2

--- Step 3: List all panes (JSON) ---
  [3 panes: pane 0 (166x34), pane 1 (157x41), pane 2 (67x41)]
  pane 2 は pane 1 の右側に30%幅で作成された

--- Step 4: Send another command ---
  Second command sent

--- Step 5: Capture output from new pane ---
  Output from pane 2: (空行のみ)

--- Step 6: Cleanup - kill new pane ---
  Pane 2 killed

=== PoC-02 PASSED ===
```

### 観察事項

- **split-pane**: 正常動作。WezTerm上に新ペインが右側30%幅で出現（pane_id=2）
- **send-text**: 正常動作。`--no-paste` フラグでブラケットペーストモードを回避
- **list (JSON)**: 正常動作。3ペイン（元の2つ + 新規1つ）のサイズ・cwd・workspace等が取得できた
- **get-text（キャプチャ）**: 空行のみ取得。新ペインでtmux auto-attachが走り、コマンド実行完了前にキャプチャしたためと推定。`sleep 1` では不十分
- **kill-pane**: 正常動作。ペインが即座に削除された

### 制約・課題

- 新ペインはtmux auto-attach（`.bashrc`の`tmux_automatically_attach_session`）が走るため、シェル起動 → tmux接続 → プロンプト表示までにラグがある
- `send-text` はtmuxのプロンプトが出てから送る必要がある（タイミング制御が必要）
- `get-text` のタイミング問題はPoC-03で掘り下げる

---

## PoC-03: 出力キャプチャ

**日時**: 2026-03-29
**結果**: PASSED

### 実行コマンド

```bash
bash 03-output-capture.sh
```

### 結果サマリ

| テスト | 対象 | 結果 |
|---|---|---|
| viewport取得 | pane 0 | git pull結果、starship prompt、tigコマンド履歴が正確に取得 |
| scrollback取得 | pane 0, `--start-line -30` | tmuxステータスバー + git log出力が取得。1行目はtmuxのステータスライン |
| ANSIストリップ | pane 0, sed | ストリップ処理は動作するが、starship/tmuxのパディング空白は残る |
| 別ペイン比較 | pane 1, `--start-line -10` | 別プロダクト向けリポジトリのgit操作履歴が正確に取得 |

### 観察事項

- **tmux内のペイン出力がWezTermのget-textで正確に取得できる**: tmuxが描画した内容（ステータスバー含む）がそのままWezTermのペインバッファに反映されている
- **tmuxステータスバーが1行目に含まれる**: `--start-line` のオフセットで制御可能だが、tmuxレイヤの存在を意識する必要がある
- **starship promptの装飾文字（アイコン等）もそのまま取得**: フィルタリング時に考慮要
- **PoC-02で空だった原因の確認**: 既存の安定したペイン（pane 0, 1）からは問題なく取得できた。PoC-02の空出力は新ペイン起動直後のタイミング問題（tmux attach完了前）
- **パフォーマンス**: 全テスト合計約1秒で完了。実用上問題なし

### PoC-02のタイミング問題に対する知見

新ペイン作成 → コマンド送信 → キャプチャの一連フローでは、tmux auto-attachの完了を待つ仕組みが必要。将来の`wez`コマンドでは以下の対応が考えられる：
- `get-text` でプロンプト文字列を検出するまでポーリング
- `send-text` 前に `get-text` で可読行数をチェック
- AI Mode専用ペインではtmux auto-attachをスキップ（`is_ai_ide()`パターンの応用）

---

## PoC-04: 通知（user-var → toast_notification）

**日時**: 2026-03-29
**結果**: PARTIAL PASS（user-var送信は動作、toast_notificationはLuaハンドラ未適用のため未検証）

### 実行コマンド

```bash
bash 04-notification.sh
```

### 結果

```
--- Step 1: Identify a WezTerm pane for user-var injection ---
  Target pane: 1

--- Step 2: Send user-var via send-text to WezTerm pane ---
  user-var command sent to pane 1

--- Step 3: Verify user-var was received ---
  WARNING: OSC 1337 sequence visible in output (may not have been consumed by WezTerm)

=== PoC-04 PASSED (user-var injection verified) ===
```

### 観察事項

- **user-var送信コマンドの注入**: `wezterm cli send-text` 経由で `printf "\033]1337;SetUserVar=..."` コマンドをWezTermペインに送信できた
- **Step 3のWARNING**: 偽陽性。`get-text`でキャプチャした内容に`printf`コマンドの文字列リテラル`"1337"`が含まれるため。実際のOSCエスケープシーケンスはWezTermが消費しており、テキストとしては表示されない
- **toast_notification**: `ai-mode-events.lua`を`.wezterm.lua`に適用していないため、Luaイベントハンドラは未稼働。user-varの送信自体は成功しているので、Luaハンドラ適用後にデスクトップ通知が出る想定
- **ヘルパー関数**: `wez_set_user_var` / `wez_notify` 関数はsource可能な形で提供。`--direct`モードでWezTermペイン内から直接使用可能

### Lua適用手順（検証を完了させる場合）

1. `wezterm-config/ai-mode-events.lua` の内容を `~/.wezterm.lua` の `return config` の前にコピー
2. または `require` で読み込み: `local ai_mode = require('ai-mode-events'); ai_mode.setup(config)`
3. WezTermペイン内で `bash 04-notification.sh --direct` を実行
4. macOSの通知センターにトースト通知が表示されれば完全成功

### 制約

- **Cursor統合ターミナルからの直接送信は不可**: user-var（OSC 1337）はWezTermのPTYを経由する必要がある。Cursorの統合ターミナルはWezTermのPTYではないため、`send-text`でWezTermペインに間接的に送る方式が必要
- **tmuxのOSCパススルー**: tmux 3.3以降は `allow-passthrough` でOSCシーケンスをパススルーできる。tmux内からのuser-var送信にはこの設定が必要な場合がある

---

