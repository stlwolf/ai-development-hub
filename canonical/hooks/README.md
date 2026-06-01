# Hooks — ルールの機械的強制

`canonical/hooks/` は Cursor / Claude Code / Codex のフック機構を使い、散文ルールで「お願い」していたガードレールを機械的に強制する基盤。

## 前提条件

- `jq` が必要（Homebrew で管理: `etc/init/assets/brew/Brewfile`）
- Codex は hooks 機能が必要（実験的機能）。`config.toml` の `[features].hooks = true`。旧名 `codex_hooks` は現行版（v0.135 で確認）では `hooks` の legacy alias として扱われ、`codex_hooks = true` のままでも有効（ただし非推奨警告が出るため `hooks` への移行が推奨）
- 通知フック（`notify.sh`）の配信は **WezTerm の OSC 777 通知**を主とする（tmux 内は DCS passthrough で `#{pane_tty}` へ直書き、非 tmux は `/dev/tty`）。**前提: tmux は `set -g allow-passthrough on`（3.3+, dotfiles の `tmux.conf`）、WezTerm.app に macOS 通知許可**。非 WezTerm / headless 環境では `terminal-notifier`（dotfiles の Brewfile で管理）→ `osascript` にフォールバックする
  - 背景: macOS では CLI/フック文脈から `osascript`/`terminal-notifier` を叩いても通知が表示されないことがある（GUI 権限を持つアプリが出す必要がある）。WezTerm は GUI アプリなので OSC を受けて通知を出せる。詳細は `docs/research/2026-03-30-ai-tool-hooks-specification-survey.md` の追記参照

## フック一覧

| フック | スクリプト | 目的 |
|--------|-----------|------|
| 破壊コマンドブロック | `scripts/block-destructive.sh` | `rm -rf /`, `chmod -R 777 /`, `DROP TABLE` 等の破壊的コマンドをブロック |
| force push ブロック | `scripts/block-force-push.sh` | `git push --force` をブロック（`--force-with-lease` は許可） |
| コミットゲート | `scripts/commit-gate.sh` | タスク完了時に未コミット変更があれば通知（advisory、ブロックしない） |
| CC 形式チェック | `scripts/cc-lint.sh` | `git commit -m` のメッセージが Conventional Commits 形式に準拠しているかチェック |
| 通知 | `scripts/notify.sh` | エージェントの完了・入力待ちを macOS 通知（advisory）。並走時のポーリング解消が目的 |

## ツール別カバレッジ

| フック | Cursor | Claude Code | Codex |
|--------|--------|-------------|-------|
| 破壊コマンドブロック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |
| force push ブロック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |
| コミットゲート | — | `TaskCompleted` | — |
| CC 形式チェック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |
| 通知: 完了 | — | `Stop` hook → notify.sh | `notify`(config.toml) → notify.sh |
| 通知: 入力待ち | — | `Notification`（matcher `permission_prompt\|idle_prompt`） → notify.sh | `[tui] notifications=["approval-requested"]` + `notification_method="osc9"`（ネイティブ）※ |

※ Codex は通知に lifecycle hook を**使わない**（`Stop` は対話で発火しない報告 [openai/codex#17532]、`PermissionRequest` は対話で承認プロンプトが出ても**発火しないことを実機確認**）。完了は `config.toml` の `notify`→notify.sh（Claude と統一フォーマット）で出る。入力待ちは Codex ネイティブ `[tui] notifications=["approval-requested"]`(osc9) を設定するが、**Codex は OSC を tmux passthrough で包まないため tmux 環境では通知が出ない（実機確認＝既知ギャップ）**。`notify` / `[tui]` は `scripts/sync/apply-codex-notify-config.sh` が `~/.codex/config.toml` へ冪等適用する（symlink 不可な状態ファイルのためキー単位で適用）。

**Codex まとめ**: 完了通知は動作。入力待ち通知は tmux 環境では出ない（best-effort・既知ギャップ。tmux 外なら `[tui] osc9` が機能）。Cursor は既存の通知機構があるため対象外。

## block-destructive.sh

### ブロック対象

`sudo` prefix は自動 strip してからマッチ。

- `rm -rf /`, `rm -rf ~`, `rm -rf $HOME`, `rm -rf /*`, `rm -rf .`, `rm -rf ..`
- `rm` のオプション順序変形（`-rf`, `-fr`, `-r -f`）に対応
- `chmod -R 777 /`, `chown -R ... /`
- `DROP TABLE`, `DROP DATABASE`, `TRUNCATE TABLE`（大文字小文字不問）
- `mkfs*`
- `dd` + `of=/dev/`
- `git reset --hard`, `git clean -fdx`

### 安全例外

以下は安全判定の早期 allow に使う相対ディレクトリ名の完全一致リスト:

`node_modules`, `dist`, `.next`, `build`, `coverage`, `__pycache__`, `.cache`, `tmp`, `.turbo`, `.parcel-cache`

これら以外の通常の相対パス（例: `rm -rf mydir`）も、上記「ブロック対象」に該当しなければそのまま許可される。絶対パス（`/tmp`, `/build` 等）はこの早期 allow リストの対象には含めない。

### 対象外（将来の拡充候補）

- パイプ・サブシェル経由の破壊コマンド
- fork bomb
- 変数展開による偶発的破壊（`rm -rf $EMPTY_VAR`）

## block-force-push.sh

### ブロック対象

- `git push --force`, `git push -f`（リモート・ブランチ問わず）

### 許可

- `--force-with-lease`（safer alternative）
- `--force-if-includes`

## commit-gate.sh

タスク完了時（`TaskCompleted` イベント）に未コミット変更を検知し、エージェントに通知する advisory フック。ブロックはしない。

### 発火条件

- `TaskCompleted` イベントが発火（タスクが completed に遷移）
- `cwd` が git リポジトリ内
- 現在のブランチが `main` / `master` 以外（detached HEAD も対象外）
- `git status --porcelain` で未コミット変更がある

### 出力

変更がある場合、`user_message` でエージェントに以下を通知:

- 変更ファイル一覧（上限10件）
- コミットまたはスキップ理由の記録を促すガイダンス
- スキップ理由フォーマット: `Skip-Reason: {WIP / batch with next step / investigation only}`

### 対象ツール

Claude Code のみ。Cursor / Codex は `TaskCompleted` 相当のイベントを持たないため対象外。

## cc-lint.sh

`git commit -m "..."` のコミットメッセージが Conventional Commits 形式に準拠しているかチェックする。

### チェック対象

`git commit` コマンドで `-m` フラグを含むもの。`&&` チェーン内の `git commit` も抽出して検証する。

### 許可される型

`conventional-commits` スキル定義に準拠する13型:

`feat`, `fix`, `ui`, `refactor`, `style`, `test`, `docs`, `revert`, `ci`, `infra`, `chore`, `local`, `wip`

### CC 形式

```
<type>(<optional scope>): <description>
```

### allow されるケース

- `-m` なし（エディタ起動）: `git commit`, `git commit --amend`
- `--fixup=<sha>` / `--squash=<sha>`: 一時コミットのため無条件 allow
- HEREDOC / コマンド置換を含むメッセージ: パース困難なため allow（保守的設計）

### deny 時の出力

フォーマット例と型リストを含むメッセージを出力する。

## notify.sh

エージェントの「完了」「入力待ち」を macOS 通知し、複数セッション並走時のポーリング（まだ動いてる？の見に行き）をやめるための advisory フック。

### 配信経路（WezTerm OSC 777）

CLI/フック文脈からは macOS 通知 API（osascript/terminal-notifier）が表示されないことがあるため、**WezTerm（GUI アプリ）に OSC 777 通知を出させる**:

- tmux 内: DCS passthrough（`\ePtmux;\e\e]777;notify;…\a\e\\`）で包み、`tmux display-message -t "$TMUX_PANE" -p '#{pane_tty}'` で得たペイン TTY へ直接書く（フックは controlling TTY を持たないため `/dev/tty` 不可）
- 非 tmux: `/dev/tty` へ OSC 777
- どちらも不可: `terminal-notifier` → `osascript` にフォールバック（非 WezTerm / headless 用）

前提: tmux `set -g allow-passthrough on`、WezTerm.app の macOS 通知許可。

### 呼ばれ方（意図は引数で明示渡し）

- Claude Code hooks: 第1引数 `done`/`wait`（任意 第2引数 tool 名）+ stdin JSON（underscore キー）
- Codex notify: 第1引数が JSON 文字列（hyphen キー, agent-turn-complete=完了）→ tool=Codex

| ツール | 完了 | 入力待ち |
|--------|------|----------|
| Claude Code | `Stop` hook → `notify.sh done` | `Notification`(matcher `permission_prompt\|idle_prompt`) → `notify.sh wait` |
| Codex | `notify`(config.toml) → `notify.sh`（JSON 判定で done） | `[tui] notifications`(osc9 ネイティブ・notify.sh 経由せず) |

### 通知フォーマット

- title: `{tool} {✅ / ⌨️} {repo}`（✅=完了 / ⌨️=入力待ち）
- body: `{branch} · {session}:{window}.{pane}`（tmux の居場所。入力待ちは ` — {message を80字 truncate}` を追加）
  - 居場所は `$TMUX_PANE` が取れる発火元のみ表示。取れない場合（一部フック環境）はアクティブペインを誤って指さないよう省略する
- 完了通知に assistant メッセージ本文は載せない（画面共有・録画時の漏えい防止）
- 制限: OSC 777 はサウンド指定不可のため完了/入力待ちで通知音の出し分けはできない（区別は絵文字）

### advisory 安全性

- `set -e` を使わず非ゼロ exit を出さない（エージェントを止めない）
- `jq` 不在は no-op、外部呼び出しは全て `|| true`、**stdout 無出力**（制御 JSON 誤返却の副作用回避）、末尾は無条件 `exit 0`

### デバッグ

`NOTIFY_DEBUG=1` または `~/.notify-hook-debug` で `/tmp/notify-hook.log` に記録（tool / mode / repo / branch / loc / tmux）。

## 設定ファイル

| ファイル | 形式 | 配布先 |
|---------|------|--------|
| `cursor.hooks.json` | Cursor native (version: 1) | `~/.cursor/hooks.json` |
| `claude.hooks.json` | Claude Code (hooks セクション) | `~/.claude/settings.json` の `hooks` キーにマージ |
| `codex.hooks.json` | Codex | `~/.codex/hooks.json`（block 系のみ。通知は config.toml 経由） |
| Codex 通知設定 | `config.toml` キー（`notify` / `[tui]`） | `scripts/sync/apply-codex-notify-config.sh` が `~/.codex/config.toml` へ冪等適用 |

## 設計判断

### Cursor で `beforeShellExecution` を採用する理由

shell 専用イベントで誤爆が少なく、コマンド抽出が単純（`.command` で直接取得）。`preToolUse(Shell)` でも同等機能は実現可能だが、matcher 設定が不要な分シンプル。Third Party Hooks（Claude Code hooks 読み込み）による一本化は将来の最適化候補。

### fail-open リスク

- **Cursor**: `failClosed: true` を設定済み。フック失敗時もブロックする
- **Claude Code / Codex**: fail-close 機構がない。exit code 0/2 以外は non-blocking（fail-open）。スクリプト内で `set -euo pipefail` + 明示的な exit 制御で対処

### Claude Code の手動 hooks について

`sync-claude.sh` は `~/.claude/settings.json` の `hooks` キーを canonical の内容で上書きする。手動で追加した hooks は sync 時に失われる。手動 hooks は `.claude/settings.local.json` に書くこと。

## 新規フック追加手順

1. `scripts/` に新規スクリプトを追加（`chmod +x` 忘れずに）
2. `cursor.hooks.json` に適切なイベントで追加
3. `claude.hooks.json` に適切なイベント + matcher で追加
4. `codex.hooks.json` に適切なイベント + matcher で追加（対応していれば）
5. この README のフック一覧とカバレッジ表を更新
6. `./scripts/sync.sh` を実行して配布

## 配布

```bash
./scripts/sync.sh          # 全ターゲット
./scripts/sync.sh cursor   # Cursor のみ
./scripts/sync.sh claude   # Claude Code のみ
./scripts/sync.sh codex    # Codex のみ
```
