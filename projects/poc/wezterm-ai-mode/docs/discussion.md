# WezTerm AI Mode - Discussion Summary

このドキュメントは、WezTerm AI Modeの方向性を決定するに至ったチャット全体の議論を要約したものである。

## 1. 発端: AI IDE向けターミナル環境の最適化

### 問い

WezTerm + tmuxで作業しているが、Cursor / Claude Codeでより「AIユーザブル」な環境を構築するなら、ツール乗り換え候補があるか？WezTermのカスタマイズで特化した自作ツールは作れるか？

### 現状の環境

- **WezTerm**: Lua設定、iceberg-dark、背景画像ローテーション、半透明、カスタムカラースキーム
- **tmux**: `C-Space` prefix、vi keybindings、peco/fzf連携、starship prompt
- **`.bashrc`の`is_ai_ide()`**: AI IDE統合ターミナルを検出し、tmux自動起動・starship・bash-completionをスキップ（7箇所で分岐）

## 2. ターミナルエミュレータ比較

### 調査対象

| ターミナル | 特徴 | AI連携の強み | 弱み |
|---|---|---|---|
| **WezTerm** | Lua API、17コマンドのCLI、user-var通信、toast_notification | 最もプログラマブル、内蔵mux | 最終安定版が2024年2月 |
| **Ghostty** | ネイティブmacOS、OSC 133完全対応、高速 | AppleScript API（v1.3.0+） | プラグインシステムなし |
| **Kitty** | Python kitten、`kitten @` CLI、画像プロトコル | CWD/title/PIDマッチでペイン操作 | macOSのIME挙動に癖 |
| **Warp** | AI組み込みターミナル | ブロックベース出力 | クラウド前提、プロプライエタリ、$20/月 |

**結論**: WezTermのLua APIが最も拡張性が高く、既存環境との互換性も完全。

### cmux（Manaflow / YC / libghostty）

AI Agent用途に特化した新興ターミナル。注目点：

- **Notification rings**: ペインごとに色付きリング表示（青=要注意、緑=完了、赤=エラー）
- **Sidebar metadata API**: `set-status`, `set-progress`, `log` でサイドバーに状態表示
- **Socket API**: JSON-RPCでプログラマティック制御（`/tmp/cmux.sock`）
- **Claude Code Hooks統合**: `~/.claude/hooks.json` で通知連携
- **`cmux read-screen --scrollback`**: ペイン出力キャプチャ

**制約**: macOS専用、WezTermとは別物（乗り換え必要）、Lua設定なし、新しい（長期安定性未知数）

### Zellij

- **強み**: `zellij action` で全操作がCLI経由（20+コマンド）、WASMプラグインシステム（Rust）、`dump-screen`、KDLレイアウト
- **弱み**: デスクトップ通知なし（プラグイン依存）、プラグインはRust前提、マルチプレクサ（ターミナルではない）

## 3. Claude Code Agent Teamsのtmux依存問題

### 現状

Claude Code Agent Teamsは**約20個のtmuxサブコマンド**を直接叩いてAgent Teamsを管理：

- `tmux split-window` → 新ペイン作成（teammate起動）
- `tmux send-keys` → ペインにコマンド送信
- `tmux capture-pane` → ペイン出力取得
- `tmux kill-pane` → teammate終了

**既知問題**: `split-window` + `send-keys` の非同期実行で、4+エージェント同時起動時に約50%の確率でコマンドが化ける。

### CustomPaneBackend プロトコル提案（[Issue #26572](https://github.com/anthropics/claude-code/issues/26572)）

tmux依存を解消するJSON-RPC 2.0プロトコルが提案されている（👍20）。実際に必要な操作は7つのみ：

| 操作 | 目的 |
|---|---|
| `spawn_agent(argv[], cwd, env)` | teammate起動 |
| `write(context_id, data)` | stdin送信 |
| `capture(context_id, lines?)` | 出力取得 |
| `kill(context_id)` | 終了 |
| `list()` | 一覧 |
| `get_self_id()` | 自分のID |
| `context_exited` (push) | 終了通知 |

KILDがリファレンス実装済み、Zellijにもtmux shimが存在。Anthropicの公式採用は未定。

## 4. I/Oレイヤの整理

```
Layer 3: ユーザーUI / 視覚フィードバック
  WezTerm (Human), cmux (AI通知), toast_notification, notification rings

Layer 2: エージェント操作プロトコル
  CustomPaneBackend (7操作) = spawn, write, capture, kill, list, get_self_id, context_exited

Layer 1: PTY / マルチプレクサ実体
  tmux, WezTerm mux, Zellij, KILD daemon

Layer 0: ターミナルエミュレータ
  WezTerm, Ghostty/cmux, Kitty, Alacritty
```

## 5. 方向性の決定

### 選択肢

- **A. WezTermデュアルモード + 自作抽象レイヤ**: Human Mode(tmux)維持、AI Mode(wezterm cli)追加
- **B. cmux併用**: AI作業時だけcmuxに切替
- **C. tmux中心 + WezTerm AI拡張**: AI Modeでもtmuxを残し、wezterm cliで通知・キャプチャを上乗せ

### 決定

**A寄りの方向性**を採用。根拠：

- Claude Code Agent Teamsの優先度は現時点で高くない → AI ModeでのtmuxレイヤはA方式（不要）で問題なし
- `is_ai_ide()` による分岐インフラが既に成熟（7箇所）
- WezTermプラグイン（agent-deck, agent-cards）でcmux的な通知UIも一部カバー可能
- 7操作モデル（spawn, write, capture, kill, list, get_self_id, exit通知）はどのバックエンドでも実装可能 → 抽象レイヤを自前で持てば将来のバックエンド差し替えも容易

### PoCスコープ

ソケット自動検出・ペイン操作・出力キャプチャ・通知の4プリミティブを検証。成功後、`wez` コマンドとしてスタンドアロンツールキットに昇格（[Worktrunk](https://worktrunk.dev/) の `wt` と区別）。

## 6. 参考資料

- [WezTerm CLI ドキュメント](https://wezterm.org/cli/cli/index.html)
- [WezTerm user-var-changed イベント](https://wezterm.org/config/lua/window-events/user-var-changed.html)
- [WezTerm toast_notification](https://wezterm.org/config/lua/window/toast_notification.html)
- [cmux API Reference](https://www.cmux.dev/docs/api)
- [cmux Claude Code Integration](https://manaflow-ai-cmux.mintlify.app/integrations/claude-code)
- [Zellij Programmatic Control](https://zellij.dev/documentation/programmatic-control.html)
- [Claude Code Agent Teams Docs](http://code.claude.com/docs/en/agent-teams)
- [CustomPaneBackend Issue #26572](https://github.com/anthropics/claude-code/issues/26572)
- [WezTerm agent-deck プラグイン](https://github.com/Eric162/wezterm-agent-deck)
- [WezTerm agent-cards プラグイン](https://github.com/wrock/wezterm-agent-cards)
