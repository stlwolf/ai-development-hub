# Hooks — ルールの機械的強制

`canonical/hooks/` は Cursor / Claude Code / Codex のフック機構を使い、散文ルールで「お願い」していたガードレールを機械的に強制する基盤。

## 前提条件

- `jq` と `grep` が必要（Homebrew で管理: `etc/init/assets/brew/Brewfile`）。**満たさないとどうなるかが #309 / #310 で変わった** — 以前は止める側の3本が非 0 で落ち、Claude Code と Codex では non-blocking なので**素通り**していた。現在は内部エラーとして `deny`（exit 2）へ収束するので、3ツールすべてで**ブロック**になる。詳細は「発火記録」節
- Codex は hooks 機能が必要（実験的機能）。`config.toml` の `[features].hooks = true`。旧名 `codex_hooks` は現行版（v0.135 で確認）では `hooks` の legacy alias で、`codex_hooks = true` のままでも有効だが非推奨警告が出る。`sync-codex.sh` → `apply-codex-notify-config.sh` が `[features].hooks = true` を冪等適用し、旧 `codex_hooks` を自動で `hooks` へ移行する（手動編集は不要）
- 通知フック（`notify.sh`）の配信は **WezTerm の OSC 777 通知**を主とする（tmux 内は DCS passthrough で `#{pane_tty}` へ直書き、非 tmux は `/dev/tty`）。**前提: tmux は `set -g allow-passthrough on`（3.3+, dotfiles の `tmux.conf`）、WezTerm.app に macOS 通知許可**。非 WezTerm / headless 環境では `terminal-notifier`（dotfiles の Brewfile で管理）→ `osascript` にフォールバックする
  - 背景: macOS では CLI/フック文脈から `osascript`/`terminal-notifier` を叩いても通知が表示されないことがある（GUI 権限を持つアプリが出す必要がある）。WezTerm は GUI アプリなので OSC を受けて通知を出せる。詳細は `docs/research/2026-03-30-ai-tool-hooks-specification-survey.md` の追記参照

## フック一覧

| フック | スクリプト | 目的 |
|--------|-----------|------|
| 破壊コマンドブロック | `scripts/block-destructive.sh` | `rm -rf /`, `chmod -R 777 /`, `DROP TABLE` 等の破壊的コマンドをブロック |
| force push ブロック | `scripts/block-force-push.sh` | `git push --force` をブロック（`--force-with-lease` は許可） |
| コミットゲート | `scripts/commit-gate.sh` | タスク完了時に未コミット変更があれば通知（advisory、ブロックしない） |
| 仮説ゲート | `scripts/hypothesis-gate.sh` | バグ調査で `tmp/hypothesis-*.md` が N=3 に初めて達したら、外部要因の結論前にコードパス未読確認を 1 回 advisory 通知（Claude のみ・ブロックしない・#78 code-path-exhaustion） |
| CC 形式チェック | `scripts/cc-lint.sh` | `git commit -m` のメッセージが Conventional Commits 形式に準拠しているかチェック |
| 発火記録 | 止める側3本に内蔵（`hfr`）＋ `projects/orchestration-engine/bin/oe-hookfire` | 発火したことを1イベント1バイトで記録し、直近 N 日で発火したかに答える（#309）。読み出しは read-only の3値検査 |
| 通知 | `scripts/notify.sh` | エージェントの完了・入力待ちを macOS 通知（advisory）。並走時のポーリング解消が目的 |
| セッション命名 | `scripts/session-name.sh` ＋ リポジトリルートの `scripts/wt/wt-pane-issue.sh` | セッション名を自動設定し並列セッションを識別（Claude のみ・advisory）。`wt switch` の worktree は `#<issue> <slug>`、非 wt は現在 git ブランチ名（issue規約→`#<issue> <slug>` / デフォルト→リポ名）でブランチ変化に追従 |

## ツール別カバレッジ

| フック | Cursor | Claude Code | Codex |
|--------|--------|-------------|-------|
| 破壊コマンドブロック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |
| force push ブロック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |
| コミットゲート | — | `TaskCompleted` | — |
| 仮説ゲート | — | `PostToolUse(Write\|Edit\|MultiEdit)` → hypothesis-gate.sh | — |
| CC 形式チェック | `beforeShellExecution` | `PreToolUse(Bash)` | `PreToolUse(Bash)` |
| 通知: 完了 | — | `Stop` hook → notify.sh | `notify`(config.toml) → notify.sh |
| セッション命名 | — | `UserPromptSubmit` → session-name.sh | — |
| 取り込み印（#299） | — | `UserPromptSubmit` → oe-prompt-receipt.sh | — |
| 通知: 入力待ち | — | `Notification`（matcher `permission_prompt\|idle_prompt`） → notify.sh | `[tui] notifications=["approval-requested"]` + `notification_method="osc9"`（ネイティブ）※ |

※ Codex は通知に lifecycle hook を**使わない**（`Stop` は対話で発火しない報告 [openai/codex#17532]、`PermissionRequest` は対話で承認プロンプトが出ても**発火しないことを実機確認**）。完了は `config.toml` の `notify`→notify.sh（Claude と統一フォーマット）で出る。入力待ちは Codex ネイティブ `[tui] notifications=["approval-requested"]`(osc9) を設定するが、**Codex は OSC を tmux passthrough で包まないため tmux 環境では通知が出ない（実機確認＝既知ギャップ）**。`notify` / `[tui]` は `scripts/sync/apply-codex-notify-config.sh` が `~/.codex/config.toml` へ冪等適用する（symlink 不可な状態ファイルのためキー単位で適用）。

**Codex まとめ**: 完了通知は動作。入力待ち通知は tmux 環境では出ない（best-effort・既知ギャップ。tmux 外なら `[tui] osc9` が機能）。Cursor は既存の通知機構があるため対象外。

## session-name.sh + wt-pane-issue.sh（セッション命名）

並列セッションを識別するため、セッション名を自動設定する（Claude Code のみ）。(1) `wt switch` で入った worktree のセッションは Issue 番号＝`#<issue> <slug>`。(2) それ以外のセッションは **`cwd` の現在 git ブランチ**で命名（issue規約→`#<issue> <slug>` / デフォルト・非git→リポ名 / その他→ブランチ名）し、**ブランチ変化で再命名**する（wt 同等）。同一ブランチ内の手動 `/rename` は次のブランチ変化まで尊重、plan-accept も尊重。

### 背景

`wt switch` は Claude セッションの cwd を worktree に移さない（シェルの `cd` は親プロセス＝Claude に伝わらず、`!pwd` はリポジトリルートのまま）。よって cwd からは active worktree を知れない。代わりに `$TMUX_PANE` を共有キーに、worktrunk の post-switch hook と Claude の `UserPromptSubmit` hook を繋ぐ。

### 仕組み（3 パート）

- `scripts/wt/wt-pane-issue.sh`（worktrunk post-switch hook、`scripts/sync/sync-bin.sh` で `~/bin/wt-pane-issue` へ配備）: `{{ branch }}` から `#<issue> <slug>` を導出し `~/.claude/state/pane-issue/<tmux server PID>_<pane>` に記録（非 issue ブランチは clear）。`wt switch` のたびに発火（エージェント/人間どちらも）。worktrunk が `{{ branch }}` をシェルクォートするため自前のクォートは付けない。キーに tmux server PID を含めるのは、`tmux kill-server`/再起動で pane id（`%N`）が再採番されても旧 server の stale state と衝突させないため（誤命名防止）。24h 触れられない marker は GC。
- `~/.config/worktrunk/config.toml`（worktrunk user config、テンプレートは `scripts/wt/worktrunk-config.toml`）: 上記を post-switch hook として登録。**hub の sync 対象外領域**（手動セットアップ。全リポ横断のため user config）。
- `scripts/session-name.sh`（Claude `UserPromptSubmit` hook）:
  - **Path1（issue・sticky）**: 同じ `$TMUX_PANE` の pane-issue state があれば、その `#<issue> <slug>` を `sessionTitle` に出力（tmux pane title にも伝播）。**毎プロンプトで現 session_title と突合し、ズレていれば再表明（sticky）** — リポ名/組み込み命名/手動 `/rename` に上書きされても次プロンプトで #issue を取り戻す（`wt switch` は cwd を動かさず Path2 が worktree を見られないため、pane-issue が唯一の意味ある名前）。一致時は no-op（冪等）。marker は sticky の source of truth なので Path1 で `touch` し 24h GC から延命（idle で 24h 放置なら GC され Path2 落ち）。**issue pane は早期 return**し Path2 に落ちない。
  - **Path2（ブランチ認識）**: state 無しの非 plan セッションは、`git -C "$cwd" symbolic-ref --short HEAD` の現在ブランチで命名する — issue規約 `^[a-z]+/#([0-9]+)_(.+)$`→`#<issue> <slug>`、`master`/`main`/空(非git・detached)→**リポ名**、その他→**ブランチ名**。prompt 文字列は**使わない**（pane title / 通知に伝播するため秘密混入を避ける）。**session_id キーの state**（専用 dir `~/.claude/state/session-branch/<sid>.json`、`last_branch` を保持、pane-issue の GC 対象外）を使い、**ブランチ変化時に再命名**する（wt の per-switch rename と同等。命名済みセッションへの sessionTitle 再emitが効くことは実機検証済み）。冪等（既に出す名前なら no-op）＆同一ブランチ内の手動 `/rename` は尊重。plan-accept / スラッシュコマンド始まりは命名しない。30日触れられない state は GC。

### 注意

- `UserPromptSubmit` の stdout は**モデル文脈に注入される**ため、`jq` で構築した sessionTitle JSON 以外を stdout に出さない（診断は出さない）。
- グローバル設定ゆえ全セッション・全リポで発火する。issue worktree は `#issue`、それ以外は**現在ブランチ名**（デフォルト/非gitはリポ名）で命名し**ブランチ変化で再命名**する（prompt 文字列は出さない＝秘密漏洩を避ける）。**ブランチ名そのものが Claude UI / tmux pane title / OS 通知に表示される**点に留意（顧客名・内部識別子をブランチ名に含める運用では露出面が増える）。
- `jq` / `tmux` が前提。無い場合は no-op（advisory・非ゼロ終了しない）。

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
- body: `{branch} · {window}:{window名} [{pane}]`（tmux ステータスバーの `#I:#W` + status-left `[#P]` と一致させ、番号で移動しやすく。入力待ちは ` — {message を80字 truncate}` を追加）
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
- **止める側の3本は `trap` で内部エラーを `deny` へ収束させる（#309）。** 実際にブロックするのは exit 2 だけなので、内部エラーで 1 や 127 を返すと Claude Code と Codex では素通りしていた。現在は3ツールとも止まる
- **記録の失敗でブロックが解除されてはならない（要求Aの鏡）。** 記録は判定経路に影響しない best-effort だが、`deny()` が `exit 2` に到達できなくなる形の失敗だけは別で、これは「止めるべきものが通る」方向の静かな故障になる。
  - だから**3つの追記先すべて**（`tally/...` / `deny.jsonl` / `diag.jsonl`）に「存在するのに通常ファイルでないなら触らない」ガードを通している。FIFO への `>>` は reader が現れるまで `open(2)` でブロックし、サブシェル隔離でも `set +e` でも解けない。
  - tally だけを守っても足りない。`deny.jsonl` は **deny のたびに必ず**書かれるので、そこが FIFO なら deny 経路が丸ごと止まる。`diag.jsonl` は tally が書けないときに通るので、そこが FIFO なら allow 側が止まる（要求A違反）。
- **ハングは封じ込められない。** `( ... ) || :` が捨てるのは終了した子の exit code であって、子が終わらなければ親も進まない。hot path をローカル FS の builtin 追記だけに限って面を最小化しているが、固まったネットワーク FS 上では残る。**deny 優先**で受け入れている

## 発火記録（#309）

止める側の3本が、発火したことを記録する。**「強制点が本当に発火したか」を当事者以外が確かめられるようにするため**の Sensor である。

### 何をどこに書くか

```text
${HOOK_FIRING_DIR:-$HOME/.claude/state/hook-firing}/
├── tally/<tool>/<hook>.allow    # 通した（1イベント1バイト）
├── tally/<tool>/<hook>.deny     # 止めた（trap 収束ぶんを含む）
├── deny.jsonl                   # deny の詳細（rule / argv0 / cmd_len）
└── diag.jsonl                   # 記録そのものが失敗したときの環境エラー
```

- ファイルサイズが件数、`mtime` が最終発火時刻。1 Bash コマンドあたり3バイトなので100万コマンドで約 3MB に収まり、**ローテーションは要らない**。
- `<tool>` は `$0`（ホストが使った呼び出しパス）から `codex` / `cursor` / `claude` / `unknown` を判別する。環境変数（`CURSOR_PROJECT_DIR` / `CLAUDE_PROJECT_DIR`）だと Codex を識別できず、いちばん恐れている故障型を名指しできないため。
- **コマンドの生文字列は残さない。** `deny.jsonl` は発火した規則・先頭トークン・長さだけを持つ。全文は `user_message` としてエージェントの transcript に既にある。
- **この記録は当事者が書ける場所にある。** 改ざん耐性は保証しない（そう書かない）。

### 読み方

```bash
projects/orchestration-engine/bin/oe-hookfire --days 7
```

`ok` / `broken` / `indeterminate` / `info` の3値 + 報告で返す（`oe-selfcheck` と同じ契約）。exit は broken≥1 → 1 / indeterminate≥1 → 2 / 全部 ok → 0。**`indeterminate` を成功にしない。**

### 欠測と非発火を区別する（陽性対照）

**「記録が0件」を「発火しなかった」と読んではいけない。** 0件は次のどれでも起きる。

- フックが動いていない（未登録・dangling symlink・Codex が trust されず黙って skip）
- エージェントがそもそも Bash を使っていない（idle）
- 記録機構だけが壊れている

区別できるのは**意図的に撃つプローブ**だけである。allow の流量は受動的な傍証にとどめる。

プローブは**2段**で撃つ。1段目だけで済ませない。

**1段目（配備物を直接叩く・弱い）** — 3配備パスすべてを対象にする。

| フック | 対照コマンド | フックが死んでいた場合 |
|--------|------------|--------------------|
| `block-destructive.sh` | SQL の `DROP TABLE` 文を含む `echo` | `echo` が文字列を表示するだけ |
| `block-force-push.sh` | `git push --force` に存在しない remote 名 | git が未知の remote でエラー終了する |
| `cc-lint.sh` | 使い捨て repo で非 CC 形式のメッセージで `git commit` | 使い捨て repo なので実害なし |

```bash
for root in ~/.cursor ~/.claude ~/.codex; do
  jq -cn '{tool_input:{command:"echo hello"}}' | bash "$root/hooks/block-destructive.sh" >/dev/null; echo "$root rc=$?"
done
```

**対照コマンドを検査スクリプトの外側のコマンド行に置かないこと。** 生きているフックが検査コマンド自体をブロックする（実際に踏んだ）。payload はファイルの中で組み立てる。

**1段目で確かめられないもの**（ここを曖昧にすると「緑なのに死んでいる」を作る）: `~/.claude/settings.json` への登録、Cursor の `hooks.json`、Codex の `hooks.json`、matcher、フックの順序と short-circuit、dispatcher が実際にフックを起動すること、Codex の workspace trust。

**2段目（ツール自身にシェルを撃たせる・強い）** — 各ツールのセッションから実際に対照コマンドを実行し、前後の tally 差と操作結果の両方を見る。dispatcher を通る唯一の形なので、これが本来の陽性対照である。Codex の trust は **workspace 単位**なので、ある trusted workspace で成功しても別 workspace の silent skip を否定できない。

### 成立条件（正直に書く）

- **この台帳の値打ちは「読み手が実際に走ること」に条件付けられている。** 定期実行の配線は #301 で未着手で、人が `oe-hookfire` を打つまで動かない。溜まっているだけの台帳は Sensor が埋まったことを意味しない。
- `O_APPEND` の原子性はローカルの通常ファイルでの実測である。NFS / FUSE / 同期ドライブ上では件数性が崩れる。`fsync` していないのでクラッシュ時の耐久性も保証しない。
- `trap` は「走ったが途中で死んだ」を捕まえるが「**そもそも走らなかった**」は捕まえられない。走らないフックに trap は張れないので、そこは tally とプローブが担う。

### 保持方針

- **tally は truncate しない。** 伸ばし続ける（1ツール・100万コマンドで約 3MB）。読み出しは**サイズ 0 の tally を発火の証拠にしない**（`indeterminate` を返す）。
  - **前回との比較（サイズ後退の検出）は行っていない。** それには読み出しが状態を持つ必要があり、`oe-hookfire` は read-only を保つ側に倒した。単発で分かるのはサイズ 0 までである。
- `deny.jsonl` / `diag.jsonl` は低頻度。上限が要るなら日付分割にし、`copytruncate` は使わない（追記中のファイルを切ると件数が壊れる）。rename して次回追記で新規作成させる。
- **保守処理はフックの中に入れない。** 読み出し／保守の側に置く（hot path に失敗要因を足さない）。

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
