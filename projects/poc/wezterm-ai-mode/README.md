# WezTerm AI Mode PoC

WezTermのデュアルモード（Human Mode: tmux維持 / AI Mode: wezterm cli活用）の技術検証。

## 概要

WezTerm + tmuxの既存環境を一切変更せず、AI IDE（Cursor / Claude Code）からの操作時に `wezterm cli` ベースの制御機能を上乗せする。

- **Human Mode**: WezTerm → tmux → 既存ワークフロー（変更なし）
- **AI Mode**: AI IDE → wezterm cli → ペイン操作・出力キャプチャ・通知

## PoC項目

| PoC | 検証内容 | 成功基準 | 結果 |
|---|---|---|---|
| 01 | ソケット自動検出 | Cursor内から `wezterm cli list` が通る | PASSED |
| 02 | ペイン操作 | Cursor内からWezTermに新ペインが出現 | PASSED（タイミング制約あり） |
| 03 | 出力キャプチャ | tmux内ペインの出力をCursor側から取得 | PASSED |
| 04 | 通知 | シェルからmacOSデスクトップ通知が表示 | PARTIAL（user-var送信OK、Lua手動適用要） |

### 主な発見事項

- `WEZTERM_UNIX_SOCKET` はCursor統合ターミナルに伝搬しないが、`~/.local/share/wezterm/gui-sock-*` から自動検出可能
- tmux内ペインの出力は `wezterm cli get-text` で正確にキャプチャできる（tmuxステータスバー含む）
- 新ペイン作成時、tmux auto-attach完了までのタイミング制御が必要（将来のポーリング機構で対処）
- user-var（OSC 1337）はCursor→WezTermペインへの `send-text` 経由で間接的に送信可能

## 実行方法

```bash
# PoC-01: ソケット検出（sourceして環境変数をセット）
source 01-socket-discovery.sh

# PoC-02: ペイン操作デモ
bash 02-pane-operations.sh

# PoC-03: 出力キャプチャデモ
bash 03-output-capture.sh [pane-id]

# PoC-04: 通知デモ（要: wezterm-config/ai-mode-events.lua を .wezterm.lua に適用）
bash 04-notification.sh
```

## 副次検証（オプション）: caffeinate

長時間のエージェント実行や放置ジョブで、macOSのアイドルスリープがWezTerm/tmux上の処理を妨げないかを確認する。**本PoCの主目的ではない**が、将来 `wez agent` 等と組み合わせる前提の知見用。

### 想定する確認観点

- `caffeinate -i` で子プロセスが生きている間、アイドルスリープが抑制されるか
- **バッテリー駆動 / 電源接続**で挙動差があるか（`man caffeinate` の `-s` 等）
- 蓋を閉じた状態・ディスプレイスリープ（`-d`）との関係
- **終了条件**: ジョブ完了後に抑制が残らないか（プロセスツリーで `caffeinate` が親にぶら下がっているか）

### 手がかりとなるコマンド例（検証設計は各自）

```bash
# 子が終わるまでアイドルスリープを抑制して sleep を実行
caffeinate -i sleep 120

# 長いジョブをラップ（例）
caffeinate -i bash -c 'your-long-command'

# 動作中の caffeinate を確認（別ターミナル）
pgrep -lf caffeinate
```

### 結果の記録

実行したら [docs/episodes.md](docs/episodes.md) に **PoC-05（caffeinate）** として日時・環境・結論を追記する。

## Future Vision: `wez` コマンド体系

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
- `wez session awake`（案）- 監視中のエージェントペインがある間だけ `caffeinate` 相当を維持（要検証）

## ドキュメント

- [docs/plan.md](docs/plan.md) - 実行プラン
- [docs/discussion.md](docs/discussion.md) - 議論の経緯と判断根拠
- [docs/episodes.md](docs/episodes.md) - PoC実行ログ

## 次のステップ

PoC結果を踏まえた展開候補：

1. **`wez` コマンドとしてプロジェクト昇格** (`projects/wezterm-ai-mode/`)
   - PoC由来の基盤コマンド7種を `wez` サブコマンドとして統合
   - ソケット検出の自動化（`.bashrc` の `is_ai_ide()` ブロック内で自動export）
2. **dotfiles統合**
   - `.wezterm.lua`: `ai-mode-events.lua` のイベントハンドラを本体に統合
   - `.bashrc`: AI IDE検出時に `wez` ヘルパー関数をsource
   - `.tmux.conf`: `allow-passthrough` の追加（tmux内からのOSC 1337対応）
3. **WezTermプラグイン調査**
   - `wezterm-agent-deck` / `wezterm-agent-cards` の動作検証
   - 既存プラグインで補える範囲と自作が必要な範囲の切り分け

## 前提

- WezTermが起動している状態で実行
- `wezterm` コマンドがPATHに存在（`/opt/homebrew/bin/wezterm`）
- PoC-04はLuaイベントハンドラの手動適用が必要
