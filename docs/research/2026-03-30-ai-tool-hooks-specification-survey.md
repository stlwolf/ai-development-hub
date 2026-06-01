# AI ツール Hooks 仕様比較調査

- 調査日: 2026-03-30
- 関連 Issue: [#10](https://github.com/stlwolf/ai-development-hub/issues/10), [#17](https://github.com/stlwolf/ai-development-hub/issues/17)
- 出典: [Cursor Hooks Docs](https://cursor.com/docs/hooks), [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks), [Codex Hooks Docs](https://developers.openai.com/codex/hooks)

## 2026-06-01 追記（[#119](https://github.com/stlwolf/ai-development-hub/issues/119) 通知フック実装時の実機検証）

本調査は 2026-03-30 時点のスナップショット。Codex hooks は experimental で変化が速く、v0.135 実機検証で以下の差分を確認した（下記の歴史的な表は当時のまま保持）。

- **Codex の有効化フラグ**: 旧 `codex_hooks` は `hooks` の **legacy alias**（`codex doctor` で `legacy alias codex_hooks -> hooks` と表示）。`codex_hooks = true` のままでも機能するが非推奨警告が出る → `[features].hooks = true` 推奨。
- **Codex のイベント拡張**: 現行公式 docs では `Stop` / `PermissionRequest` 等が記載され、当時の「5 イベントのみ」より増えている。ただし **`codex exec`（非対話）では `Stop` フックが発火しないことを実機確認**。ライフサイクル hook は対話 TUI 想定の可能性が高く、`PermissionRequest` の実 emit は対話セッションで要検証。
- **shell_snapshot**: `codex exec` 実行時に `Shell snapshot validation failed`（ユーザーシェル環境スナップショットの構文エラー）が出る環境がある。command 系 hook 実行への影響可能性があり別途要調査（本 Issue の通知フックとは独立）。
- **macOS 通知の配信経路（最重要）**: CLI/フック文脈から `osascript`（スクリプトエディタ名義・通知一覧に出ず許可不可）や `terminal-notifier`（2.0.0 は Sequoia で表示不発）を叩いても**通知が表示されない**ことを実機確認（Cursor 等 GUI アプリは出る＝macOS 通知自体は正常）。**GUI 権限を持つアプリが出す必要がある**。WezTerm ユーザーでは **OSC 777 を WezTerm に出させる**のが解。tmux 内はフックが controlling TTY を持たないため、`tmux display-message -t "$TMUX_PANE" -p '#{pane_tty}'` で得たペイン TTY に **DCS passthrough** で包んで書く（`set -g allow-passthrough on` 前提、tmux 3.3+）。実機で OSC 9 / OSC 777 の表示・pane_tty 直書きを確認済み。
- **Codex 通知の最終方針（実機確認込み）**: hooks は通知に使わない。完了は `config.toml` の `notify`→共有 notify.sh（OSC、Claude と統一フォーマット）で**動作確認済み**。入力待ちは:
  - `PermissionRequest` hook → **対話で承認プロンプトが出ても発火しないことを実機確認**（`Stop` 非発火 [openai/codex#17532] と同様、observability only で通知に使えない）。
  - Codex ネイティブ `[tui] notifications=["approval-requested"] notification_method="osc9"` → **Codex は OSC を tmux passthrough で包まないため tmux 内で通知が出ないことを実機確認**（bare OSC を tmux が遮断）。
  - → **Codex 入力待ち通知は tmux 環境では出せない既知ギャップ**。`notify` は `agent-turn-complete` のみで入力待ちを拾えない。完了通知は動くため best-effort として許容。tmux 外なら `[tui] osc9` が機能する見込み。

## 要約

3ツールとも hooks は **JSON stdin/stdout + exit code** プロトコルを共有し、Claude Code の hooks フォーマットが事実上の共通語になりつつある（Cursor は Claude Code hooks の読み込みに対応、Codex も同構造を採用）。ただしイベント名の casing（Cursor: camelCase / Claude Code・Codex: PascalCase）、設定ファイルパス、対応イベント数に差がある。

## 比較総覧

### 設定ファイル


| 項目        | Cursor                 | Claude Code                   | Codex                                   |
| --------- | ---------------------- | ----------------------------- | --------------------------------------- |
| ファイル形式    | `hooks.json`           | `settings.json` 内 `hooks` キー  | `hooks.json`                            |
| ユーザーレベル   | `~/.cursor/hooks.json` | `~/.claude/settings.json`     | `~/.codex/hooks.json`                   |
| プロジェクトレベル | `.cursor/hooks.json`   | `.claude/settings.json`       | `.codex/hooks.json`                     |
| ローカル上書き   | なし                     | `.claude/settings.local.json` | なし                                      |
| スキーマバージョン | `"version": 1` 必須      | なし                            | なし                                      |
| 有効化フラグ    | 不要（常時有効）               | 不要（常時有効）                      | `config.toml` で `codex_hooks = true` 必須 |


### イベント名の対応


| カテゴリ              | Cursor (camelCase)     | Claude Code (PascalCase)               | Codex (PascalCase) |
| ----------------- | ---------------------- | -------------------------------------- | ------------------ |
| セッション開始           | `sessionStart`         | `SessionStart`                         | `SessionStart`     |
| セッション終了           | `sessionEnd`           | `SessionEnd`                           | -                  |
| プロンプト送信前          | `beforeSubmitPrompt`   | `UserPromptSubmit`                     | `UserPromptSubmit` |
| ツール実行前（汎用）        | `preToolUse`           | `PreToolUse`                           | `PreToolUse`       |
| ツール実行後（汎用）        | `postToolUse`          | `PostToolUse`                          | `PostToolUse`      |
| ツール失敗後            | `postToolUseFailure`   | `PostToolUseFailure`                   | -                  |
| シェル実行前            | `beforeShellExecution` | - (PreToolUse + matcher "Bash")        | -                  |
| シェル実行後            | `afterShellExecution`  | - (PostToolUse + matcher "Bash")       | -                  |
| MCP 実行前           | `beforeMCPExecution`   | - (PreToolUse + matcher "mcp__*")      | -                  |
| MCP 実行後           | `afterMCPExecution`    | - (PostToolUse + matcher "mcp__*")     | -                  |
| ファイル読取前           | `beforeReadFile`       | - (PreToolUse + matcher "Read")        | -                  |
| ファイル編集後           | `afterFileEdit`        | - (PostToolUse + matcher "Edit|Write") | -                  |
| Tab ファイル読取前       | `beforeTabFileRead`    | -                                      | -                  |
| Tab ファイル編集後       | `afterTabFileEdit`     | -                                      | -                  |
| サブエージェント開始        | `subagentStart`        | `SubagentStart`                        | -                  |
| サブエージェント終了        | `subagentStop`         | `SubagentStop`                         | -                  |
| パーミッション要求         | -                      | `PermissionRequest`                    | -                  |
| 通知                | -                      | `Notification`                         | -                  |
| タスク作成             | -                      | `TaskCreated`                          | -                  |
| タスク完了             | -                      | `TaskCompleted`                        | -                  |
| チームメイトアイドル        | -                      | `TeammateIdle`                         | -                  |
| エージェント応答後         | `afterAgentResponse`   | -                                      | -                  |
| エージェント思考後         | `afterAgentThought`    | -                                      | -                  |
| 停止                | `stop`                 | `Stop`                                 | `Stop`             |
| 停止失敗              | -                      | `StopFailure`                          | -                  |
| コンパクト前            | `preCompact`           | `PreCompact`                           | -                  |
| コンパクト後            | -                      | `PostCompact`                          | -                  |
| 設定変更              | -                      | `ConfigChange`                         | -                  |
| CWD 変更            | -                      | `CwdChanged`                           | -                  |
| ファイル変更            | -                      | `FileChanged`                          | -                  |
| Worktree 作成       | -                      | `WorktreeCreate`                       | -                  |
| Worktree 削除       | -                      | `WorktreeRemove`                       | -                  |
| 命令ファイルロード         | -                      | `InstructionsLoaded`                   | -                  |
| Elicitation       | -                      | `Elicitation`                          | -                  |
| ElicitationResult | -                      | `ElicitationResult`                    | -                  |


### プロトコル比較


| 項目          | Cursor                                 | Claude Code                                                       | Codex                   |
| ----------- | -------------------------------------- | ----------------------------------------------------------------- | ----------------------- |
| 入力          | JSON via stdin                         | JSON via stdin                                                    | JSON via stdin          |
| 出力          | JSON via stdout                        | JSON via stdout                                                   | JSON via stdout         |
| ブロック        | exit 2 or `"permission": "deny"`       | exit 2 or JSON `permissionDecision: "deny"` / `decision: "block"` | exit 2 or JSON decision |
| 許可          | exit 0 or `"permission": "allow"`      | exit 0 or `permissionDecision: "allow"`                           | exit 0                  |
| ユーザー確認      | `"permission": "ask"`                  | `permissionDecision: "ask"`                                       | -                       |
| フェイルオープン    | デフォルト（`failClosed: true` で反転可）         | デフォルト（exit ≠ 0 and ≠ 2 は non-blocking）                            | デフォルト                   |
| 入力修正        | `updated_input` (preToolUse)           | `updatedInput` (PreToolUse)                                       | -                       |
| フォローアップ     | `followup_message` (stop/subagentStop) | `decision: "block"` + `reason` (Stop)                             | -                       |
| ハンドラー型      | command, prompt                        | command, http, prompt, agent                                      | command                 |
| デフォルトタイムアウト | プラットフォームデフォルト                          | 600s (command), 30s (prompt), 60s (agent)                         | 600s                    |


### 共通入力フィールド

3ツールに共通（フィールド名に差異あり）:


| 概念       | Cursor            | Claude Code         | Codex             |
| -------- | ----------------- | ------------------- | ----------------- |
| セッション ID | `conversation_id` | `session_id`        | `session_id`      |
| 生成 ID    | `generation_id`   | -                   | -                 |
| モデル      | `model`           | - (SessionStart のみ) | -                 |
| イベント名    | `hook_event_name` | `hook_event_name`   | `hook_event_name` |
| ワークスペース  | `workspace_roots` | `cwd`               | `cwd`             |
| トランスクリプト | `transcript_path` | `transcript_path`   | `transcript_path` |


### 環境変数


| 変数名       | Cursor                    | Claude Code                                             | Codex |
| --------- | ------------------------- | ------------------------------------------------------- | ----- |
| プロジェクトルート | `CURSOR_PROJECT_DIR`      | `CLAUDE_PROJECT_DIR`                                    | -     |
| バージョン     | `CURSOR_VERSION`          | -                                                       | -     |
| ユーザーメール   | `CURSOR_USER_EMAIL`       | -                                                       | -     |
| トランスクリプト  | `CURSOR_TRANSCRIPT_PATH`  | -                                                       | -     |
| リモート      | `CURSOR_CODE_REMOTE`      | `CLAUDE_CODE_REMOTE`                                    | -     |
| 互換エイリアス   | `CLAUDE_PROJECT_DIR` (互換) | -                                                       | -     |
| ENV ファイル  | -                         | `CLAUDE_ENV_FILE` (SessionStart/CwdChanged/FileChanged) | -     |


## ツール別の特記事項

### Cursor

- **Claude Code hooks 互換**: Cursor は `.claude/settings.json` の hooks も読み込み可能（[Third Party Hooks](https://cursor.com/docs/reference/third-party-hooks)）
- **4階層の優先度**: Enterprise → Team → Project → User
- **専用イベント**: `beforeShellExecution`/`afterShellExecution` は Cursor 独自の分離イベント（Claude Code は PreToolUse matcher "Bash" で同等機能を実現）
- **Tab 専用フック**: `beforeTabFileRead`, `afterTabFileEdit` はインライン補完に特化
- **Prompt-based hooks**: LLM にポリシー判定させる `"type": "prompt"` をサポート
- `loop_limit`: stop/subagentStop のフォローアップ回数制限（デフォルト 5）
- `failClosed`: セキュリティクリティカルなフックで失敗時もブロックするオプション

### Claude Code

- **最多イベント数**: 28 イベント（Cursor: 17, Codex: 5）
- **4種のハンドラー型**: command, http, prompt, agent（agent は サブエージェントとしてツール使用可能な検証器）
- `if` フィールド: permission rule syntax による細粒度フィルタ（`"Bash(rm *)"`, `"Edit(*.ts)"`）
- `once` フィールド: スキル/エージェント内で1回だけ実行
- `async` フィールド: バックグラウンド実行（ブロックしない）
- **Skill/Agent frontmatter**: スキル定義の YAML frontmatter 内でフック定義可能
- `CLAUDE_ENV_FILE`: SessionStart で環境変数を永続化
- `disableAllHooks`: 一時的な全フック無効化
- `hookSpecificOutput`: イベント固有の構造化出力（`hookEventName` 必須）
- **Plugin hooks**: `hooks/hooks.json` でプラグインにバンドル可能

### Codex

- **実験的機能**: `config.toml` で `codex_hooks = true` が必要
- **最小イベント数**: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop の 5 イベント
- **command のみ**: prompt/http/agent ハンドラーなし
- **matcher は現時点で `Bash` のみ**: PreToolUse/PostToolUse の matcher はツール名だが、emit されるのは Bash のみ
- **Windows 未対応**

## 共通基盤の設計指針

3ツール間でスクリプトを共有するための設計方針:

### 1. canonical スクリプトは stdin JSON + exit code プロトコルで書く

- 入力: JSON を stdin から読む（`jq` で必要フィールド抽出）
- 出力: JSON を stdout に書く
- exit 0 = 許可、exit 2 = ブロック
- これは3ツール共通

### 2. イベントマッピングレイヤー

Cursor の camelCase と Claude Code/Codex の PascalCase を吸収する設定ファイルジェネレーター:

- `canonical/hooks/scripts/` にロジック本体を配置
- `canonical/hooks/cursor.hooks.json` — Cursor 用設定（`beforeShellExecution` イベント名）
- `canonical/hooks/claude.hooks.json` — Claude Code 用設定（`PreToolUse` + matcher）
- `canonical/hooks/codex.hooks.json` — Codex 用設定（`PreToolUse` + matcher）

### 3. 入力フィールドの差異吸収

シェル実行コマンドの取得:

- Cursor `beforeShellExecution`: `.command`
- Claude Code `PreToolUse` (Bash): `.tool_input.command`
- Codex `PreToolUse` (Bash): `.tool_input.command`

→ 各ツール用のラッパースクリプトか、スクリプト内で両方のパスを試すアプローチ

### 4. 設定ファイルの sync

`scripts/sync/` の既存パターンに従い:

- `sync-cursor.sh`: `canonical/hooks/cursor.hooks.json` → `~/.cursor/hooks.json`
- `sync-claude.sh`: `canonical/hooks/claude.hooks.json` → `~/.claude/settings.json` の hooks キーにマージ
- `sync-codex.sh`: `canonical/hooks/codex.hooks.json` → `~/.codex/hooks.json`

## ルール → フック移行候補の分析

### フック化適性: 高


| 既存ルール                           | フック化方法                           | 対応イベント                                                                                       | 備考                    |
| ------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------- | --------------------- |
| behavioral-rule: 破壊的操作停止        | コマンドパターンマッチで deny                | Cursor: `beforeShellExecution` / Claude Code: `PreToolUse(Bash)` / Codex: `PreToolUse(Bash)` | Issue #17 の最初のフック実装候補 |
| branch-naming: master 直 push 禁止 | `git push` コマンドの宛先チェック           | 同上                                                                                           | 安全例外リスト不要でシンプル        |
| conventional-commits: コミット形式    | `git commit -m` のメッセージフォーマットチェック | 同上                                                                                           | commitlint 相当をフックで    |
| shellcheck 必須                   | `.sh` 編集後に shellcheck 実行         | Cursor: `afterFileEdit` / Claude Code: `PostToolUse(Edit|Write)`                             | 既存のリンターフックパターン        |


### フック化適性: 中（段階的に検討）


| 既存ルール                             | フック化方法                  | 対応イベント                                      | 備考                    |
| --------------------------------- | ----------------------- | ------------------------------------------- | --------------------- |
| execution-policy: read-only→変更    | ツール使用順序の追跡・警告           | `preToolUse` / `PreToolUse`                 | 状態追跡が必要で複雑            |
| implementation-gate: Plan mode 提案 | 編集ツール初回使用時に警告           | `preToolUse(Write)`                         | UX と自動化のバランスが課題       |
| output-format: 応答構造               | Stop 時の応答テンプレチェック       | `stop` / `Stop`                             | prompt-based hook が適任 |
| pr-conventions: `--assignee @me`  | `gh pr create` のフラグチェック | `beforeShellExecution` / `PreToolUse(Bash)` | gh wrapper 相当         |


### 新規フック候補（ルール由来でない）


| フック                         | 目的                            | 対応イベント                                                        | 期待効果                                   |
| --------------------------- | ----------------------------- | ------------------------------------------------------------- | -------------------------------------- |
| セッション初期化コンテキスト注入            | Git ブランチ・最近の変更・関連 Issue を自動注入 | `sessionStart` / `SessionStart`                               | コンテキスト欠落の削減                            |
| 監査ログ                        | 全ツール使用を記録                     | 全イベント                                                         | 事後分析・改善の基盤                             |
| ループ検出                       | 同一エラーの繰り返しを検出して停止             | `postToolUseFailure` / `PostToolUseFailure` + `stop` / `Stop` | ハーネスエンジニアリングの loop detection パターン      |
| pre-completion verification | Stop 前にチェックリスト検証              | `stop` / `Stop` (prompt-based)                                | implementation-principles の「完了前自問」を機械化 |


