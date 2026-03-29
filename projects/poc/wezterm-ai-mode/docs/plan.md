# WezTerm AI Mode PoC - Plan

## 背景と方向性

WezTerm + tmuxの既存環境（Human Mode）を維持したまま、AI IDE（Cursor / Claude Code）からの操作時にwezterm cliベースのAI Modeを上乗せする。

**PoCで検証した事実（Plan mode中に確認済み）:**

- `wezterm cli list --format json` はCursor統合ターミナルから`WEZTERM_UNIX_SOCKET`を明示すれば動作する
- `wezterm cli get-text --pane-id 0 --start-line -5` でtmux内ペインの出力キャプチャ成功
- ソケットファイルは `~/.local/share/wezterm/gui-sock-*` に1つ存在（PID付き）
- 環境変数 `WEZTERM_UNIX_SOCKET`, `WEZTERM_PANE` はCursor内に伝搬しない → 自動検出が必要

## ディレクトリ構成

```
projects/poc/wezterm-ai-mode/
├── README.md                    # PoC概要 + Future Vision（ツールキット構想）
├── docs/
│   ├── plan.md                  # プラン（本ファイル）
│   ├── discussion.md            # チャット全体の議論要約（背景・比較・判断根拠）
│   └── episodes.md              # PoC実行ログ（各PoC完了後に追記）
├── 01-socket-discovery.sh       # ソケット自動検出
├── 02-pane-operations.sh        # ペイン操作（split, send, list）
├── 03-output-capture.sh         # 出力キャプチャ
├── 04-notification.sh           # user-var → toast_notification
└── wezterm-config/
    └── ai-mode-events.lua       # .wezterm.luaに追加するイベントハンドラ（参考実装）
```

## 実行順序

1. **ドキュメント準備**（コード着手前）
   - `docs/discussion.md`: チャット全体の議論を要約転記
   - `docs/plan.md`: Plan mode出力をそのまま転記（本ファイル）
   - `README.md`: PoC概要 + Future Vision
   - `docs/episodes.md`: ヘッダとテンプレートのみ
2. **PoC-01〜04**: 各スクリプト作成 → 実行 → 結果を `docs/episodes.md` に追記
3. **Gate**: 全結果を `README.md` に反映、次ステップ判断

## Future Vision: PoC成功後のツールキット構想

PoC成功後、`projects/wezterm-ai-mode/` として昇格し `wez` コマンドとして実装する想定。CLI名は [Worktrunk](https://worktrunk.dev/) の `wt` と重ならないよう `wez` とする。

### 基盤コマンド（PoC由来）

- `wez discover` - ソケット自動検出（全コマンドの前提）
- `wez pane list` - 全ペイン一覧（JSON）
- `wez pane split [--right|--bottom]` - 新ペイン作成
- `wez pane send <pane-id> "command"` - ペインへコマンド送信
- `wez pane capture [pane-id] [--lines N]` - ペイン出力キャプチャ
- `wez pane kill <pane-id>` - ペイン終了
- `wez notify "title" "message"` - デスクトップ通知（user-var経由）

### エージェント連携コマンド（拡張フェーズ）

- `wez agent spawn "task"` - ペイン分割 + Claude Code起動（タスク付き）
- `wez agent monitor` - 全エージェントペインの完了監視
- `wez agent capture-error` - 直前エラーをキャプチャしAI向けに整形

### レイアウト管理コマンド（拡張フェーズ）

- `wez layout save <name>` - 現在のペインレイアウトを保存
- `wez layout load <name>` - レイアウト復元
- `wez layout ai-dev` - AI開発用プリセット一発構築

### dotfiles統合（別計画）

- `.bashrc`: `is_ai_ide()` 検出時に `wez` ヘルパー関数を自動source
- `.wezterm.lua`: user-var-changedイベントハンドラ、AI Modeステータス表示

## PoC項目

### PoC-01: ソケット自動検出 (`01-socket-discovery.sh`)

AI Mode全体の基盤。Cursor/Claude Code統合ターミナルから親WezTermインスタンスのソケットを自動発見する。

- `~/.local/share/wezterm/gui-sock-*` からソケットパスを検出
- 複数ソケット存在時の対処（最新 or `lsof`でPID確認）
- `wezterm cli list` で接続確認
- 環境変数 `WEZTERM_UNIX_SOCKET` をexportして後続スクリプトに伝搬
- 関数 `wez_ensure_socket()` としてsource可能に

**成功基準**: Cursor統合ターミナルから `source 01-socket-discovery.sh && wezterm cli list` が通る

### PoC-02: ペイン操作 (`02-pane-operations.sh`)

wezterm cliでtmux的なペイン操作がAI Modeから可能か検証。

- `wezterm cli split-pane --right` / `--bottom` でペイン作成
- `wezterm cli send-text --pane-id $ID "command\n"` でコマンド送信
- `wezterm cli list --format json` でペイン一覧取得（pane_id, cwd, title）
- `wezterm cli kill-pane --pane-id $ID` でクリーンアップ
- 一連の流れをデモ: 新ペイン作成 → コマンド送信 → 結果取得 → クリーンアップ

**成功基準**: Cursor内からWezTerm上に新ペインが出現し、コマンドが実行される

### PoC-03: 出力キャプチャ (`03-output-capture.sh`)

エージェントワークフローの核心。ペインの出力をプログラマティックに取得する。

- `wezterm cli get-text --pane-id $ID` でビューポート取得
- `--start-line -100` でスクロールバック100行取得
- キャプチャ結果のフィルタリング（空行除去、ANSIエスケープ除去）
- デモ: 指定ペインの直近出力をキャプチャして標準出力に表示

**成功基準**: tmux内で動いているペインの出力をCursor側から正確に取得できる

### PoC-04: 通知 (`04-notification.sh` + `ai-mode-events.lua`)

user-var → WezTerm Lua → toast_notification のパスを検証。

シェル側:

- `printf "\033]1337;SetUserVar=%s=%s\007"` でuser-var送信するヘルパー関数
- `wez_notify "title" "message"` として呼び出し可能に

Lua側（`.wezterm.lua` への追記参考実装）:

- `wezterm.on('user-var-changed', ...)` でイベントハンドル
- `window:toast_notification(title, message)` でmacOSデスクトップ通知

**成功基準**: シェルから `wez_notify` 実行 → macOSの通知センターに表示

### 検証完了後のGate

全PoCの結果を `README.md` にまとめ、以下を判断:

- 各PoCの成功/失敗と制約事項
- WezTermプラグイン（agent-deck等）の追加調査の要否
- 本格実装（dotfiles側への`.bashrc` / `.wezterm.lua` 統合）に進むか

## 変更対象ファイル

- **新規作成**: `projects/poc/wezterm-ai-mode/` 以下の全ファイル（ai-development-hubリポジトリ内）
- **dotfilesリポジトリは変更しない**（PoC段階ではdotfilesに手を入れない。本格実装時に別途計画）
- **`projects/README.md` は更新しない**（PoC段階。昇格時に追記）

## 依存・前提

- WezTermが起動している状態でPoCを実行する
- `wezterm` コマンドがPATHにある（確認済み: `/opt/homebrew/bin/wezterm`）
- PoC-04のLua側はWezTermの設定を変更する必要があるため、参考実装として提供し手動適用とする
