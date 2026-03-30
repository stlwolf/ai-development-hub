# Hooks — ルールの機械的強制

`canonical/hooks/` は Cursor / Claude Code / Codex のフック機構を使い、散文ルールで「お願い」していたガードレールを機械的に強制する基盤。

## 前提条件

- `jq` が必要（Homebrew で管理: `etc/init/assets/brew/Brewfile`）
- Codex は `config.toml` に `codex_hooks = true` が必要（実験的機能）

## フック一覧

| フック | スクリプト | 目的 |
|--------|-----------|------|
| 破壊コマンドブロック | `scripts/block-destructive.sh` | `rm -rf /`, `chmod -R 777 /`, `DROP TABLE` 等の破壊的コマンドをブロック |
| force push ブロック | `scripts/block-force-push.sh` | `git push --force` をブロック（`--force-with-lease` は許可） |

## ツール別カバレッジ

| フック | Cursor | Claude Code | Codex |
|--------|--------|-------------|-------|
| 破壊コマンドブロック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |
| force push ブロック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |

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

## 設定ファイル

| ファイル | 形式 | 配布先 |
|---------|------|--------|
| `cursor.hooks.json` | Cursor native (version: 1) | `~/.cursor/hooks.json` |
| `claude.hooks.json` | Claude Code (hooks セクション) | `~/.claude/settings.json` の `hooks` キーにマージ |
| `codex.hooks.json` | Codex | `~/.codex/hooks.json` |

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
