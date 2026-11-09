# Scripts

リポジトリ運用のユーティリティスクリプト。

## ディレクトリ構成

```
scripts/
├── sync.sh                    # 統合 sync ランナー（配置・--check・--prune）
├── arena-compare.sh           -> ../projects/arena-compare/arena-compare.sh
├── so-compare.sh              # セカンドオピニオン比較
├── check-codex-guardrails.sh  # canonical/rules と canonical/codex/AGENTS.md の整合検証
├── harness-check.sh           # rule / skill の発動効果を CLI agent で実測するランナー
├── cloud/
│   └── link-project-context.sh # クラウドのコンテナの作業ツリーにだけ、規則と規約のスキルへのリンクを作る（環境の setup から呼ぶ）
├── wt/
│   ├── wt-pane-issue.sh       # worktrunk の post-switch hook（tmux ペインごとに作業中の issue を記録）
│   └── worktrunk-config.toml  # worktrunk のユーザー設定に入れる [post-switch] の例
└── sync/
    ├── sync-bin.sh
    ├── sync-claude.sh
    ├── sync-codex.sh
    ├── sync-cursor.sh
    ├── apply-claude-settings.sh       # 宣言した項目だけを ~/.claude/settings.json へ適用（sync-claude.sh が呼ぶ）
    ├── check-claude-settings.sh       # 宣言と ~/.claude/settings.json の差分を報告（sync.sh --check claude が呼ぶ）
    ├── apply-codex-notify-config.sh   # Codex の通知・hooks 設定を ~/.codex/config.toml へ冪等適用（sync-codex.sh が呼ぶ）
    └── check-orphan-links.sh          # 正本から消えたファイルを指す配布先の symlink を列挙（sync.sh --check / --prune が呼ぶ）
```

## sync/

`canonical/` を正本として、各AIツールの設定ディレクトリにシンボリックリンクを配置するスクリプト群。

### 統合ランナー

```bash
./scripts/sync.sh                # 全ターゲット実行
./scripts/sync.sh cursor         # Cursor のみ
./scripts/sync.sh claude codex   # 複数指定
./scripts/sync.sh --list         # 利用可能ターゲット一覧
./scripts/sync.sh --check        # 全ターゲットの整合チェック（配置はしない）
./scripts/sync.sh --check cursor # cursor のみチェック
./scripts/sync.sh --prune claude # 孤児 symlink を削除（検査も行う・既定は報告のみ）
```

### 個別スクリプト

| スクリプト | ソース | 配置先 |
|---|---|---|
| `sync-cursor.sh` | `canonical/{commands,skills,orchestration-spec,agents}` + `canonical/hooks/{cursor.hooks.json,scripts/}` + `canonical/mcp/cursor.json` + Cursor 固有（`canonical/cursor/{rules/*.mdc,skills/,command/thread/archive-title.md}`） | `~/.cursor/` |
| `sync-claude.sh` | `canonical/{rules,orchestration-spec,skills,agents,commands,output-styles}` + `canonical/hooks/scripts/` + `canonical/claude/statusline/`。settings は `canonical/claude/settings.harness.json` の宣言項目だけを `apply-claude-settings.sh` で `~/.claude/settings.json` へ適用。`canonical/mcp/claude.json` は `~/.claude.json` の `mcpServers` へマージ | `~/.claude/`（MCP は `~/.claude.json`） |
| `sync-codex.sh` | `canonical/{skills,orchestration-spec}` + `canonical/codex/{AGENTS.md,commands-registry}` + `canonical/agents`（toml 生成） + `canonical/hooks/{codex.hooks.json,scripts/}`。通知・hooks の設定は `apply-codex-notify-config.sh` で `~/.codex/config.toml` へ適用 | `~/.codex/` |
| `sync-bin.sh` | CLI スクリプト8件（`so-compare` / `arena-compare` / `wez` / `wt-pane-issue` / `oe-tree` / `oe-hookfire` / `validate-knowledge` / `knowledge-list`。リンク名と実体の対応は同スクリプトの `CMD_NAMES` / `CMD_SOURCES`） | `~/bin/` |

`sync-codex.sh` は実行前に `check-codex-guardrails.sh` を呼び出し、`canonical/rules` と `canonical/codex/AGENTS.md` の整合を検証する。

`sync.sh --check bin` は `sync-bin.sh --check` へ委譲する。配備と検査が同じ `CMD_NAMES` / `CMD_SOURCES` を通るので、配布対象を増やしても検査側を触る必要はない。

`sync.sh --check claude` は settings の検査を `check-claude-settings.sh` へ委譲する。cursor / claude / codex の検査は、正本から消えたファイルを指す配布先の symlink（孤児）も `check-orphan-links.sh` で列挙する。孤児を削除するのは `--prune` を付けたときだけである。

### 設定の適用と検査（`sync/` の apply / check 系）

symlink で配れない設定ファイル（CLI が実行時に書き換えるもの）は、宣言した項目だけを適用・検査するスクリプトで扱う。通常は sync / `--check` から呼ばれるが、単体でも実行できる。

| スクリプト | 役割 | 終了コード |
|---|---|---|
| `apply-claude-settings.sh` | `canonical/claude/settings.harness.json` の宣言項目だけを `~/.claude/settings.json` へ適用する。宣言に無い項目には触らない | 0 適用した、または安全のために触らなかった（対象が symlink・通常ファイル以外・JSON として読めない等。stderr に警告が出る）/ 1 適用できなかった / 2 実行できない。適用されたかは `check-claude-settings.sh` で確かめる |
| `check-claude-settings.sh` | 宣言と `~/.claude/settings.json` を突き合わせて差分を報告する（読み取り専用） | 0 差分なし / 1 差分あり / 2 検査を実行できない |
| `apply-codex-notify-config.sh` | Codex の `notify`・`tui.notifications`・`tui.notification_method`・`features.hooks` を `~/.codex/config.toml` へ冪等適用する | 0 適用した、変更が要らなかった、または安全のために変更しなかった（作業ファイルを作れない・置き換えに失敗した等。stderr に警告が出る）/ 1 適用後の TOML が壊れたのでバックアップへ戻した |
| `check-orphan-links.sh` | 配布先の symlink のうち正本から消えたものを列挙する（既定は読み取り専用・`--prune` で削除） | 0 孤児なし / 1 孤児あり（`--prune` 時は消せなかった孤児が残った）/ 2 検査を実行できない |

```bash
./scripts/sync/check-claude-settings.sh
./scripts/sync/check-orphan-links.sh claude
./scripts/sync/check-orphan-links.sh claude --prune
```

## cloud/

クラウドのエージェント（Claude Code on the web・Codex のクラウド）のコンテナには、手元のホーム（`~/.claude/` など）が無いので、sync で配った規則とスキルが届かない（#591）。repo にリンクを commit すると手元の hub で二重に読まれるので、commit はしない。代わりに、クラウドの環境の setup からこの script を呼び、そのコンテナの作業ツリーにだけリンクを作る。

| スクリプト | 作るもの | 終了コード |
|---|---|---|
| `link-project-context.sh` | `canonical/` への相対のリンク。`.claude/rules/` に `canonical/rules/*.md` の全部、`.claude/skills/` と `.agents/skills/` に規約の4つのスキル（一覧は script の `CONVENTION_SKILLS`）。作ったディレクトリは git の `info/exclude` に足す | 0 すべて作った / 1 一部を作れなかった（正本に無いスキル・リンクでないファイルが先にある）/ 2 実行できない（`--cloud` が無い等） |

- 手元で誤って走らせないよう、`--cloud` を付けたときだけ動く。
- Claude は `.agents/` を、Codex は `.claude/` を読まないので、両方を作っても互いに影響しない。
- 正本から消えたものを指して壊れたリンクは外す。人が置いたファイルとほかのリンクには触らない。
- テストは `bash tests/scripts/test_link_project_context.sh`（偽の hub を一時ディレクトリに組んで流す）。

環境の setup script（Claude）と install script（Codex）には、次を書く。repo の checkout を含むディレクトリから走る前提である。

```bash
if [ -f ai-development-hub/scripts/cloud/link-project-context.sh ]; then
  bash ai-development-hub/scripts/cloud/link-project-context.sh --cloud
fi
```

- Claude：setup script は新しいコンテナを作るたびに走るので、正本に足した規則は次のセッションで入る。
- Codex：install script は環境を公開したときにだけ走る。スキルや規則を足したら、環境を編集して公開し直す。Codex のクラウドは、置いたスキルを仕組みとして読み込むとは限らない（#591 の観測）。

## ユーティリティ

### `check-codex-guardrails.sh`

`canonical/rules` の主要行動原則が `canonical/codex/AGENTS.md` に反映されているかを検証する。

```bash
./scripts/check-codex-guardrails.sh
```

### `so-compare.sh`

セカンドオピニオン比較実行スクリプト。同一プロンプトを Codex CLI / Claude Code に投げて結果をファイルに保存する。

**終了コード**: `0` 全プロバイダ成功 / `1` 部分成功 / `2` 全プロバイダ失敗（起動はした）/ **`4` 入力を拒否した（レーンを1本も起動していない・#344）**。`4` の理由は stderr に型で出る（`invalid:<種別>` は入力の誤り、`unavailable:<コマンド>` は環境の不足）。**`3` は使わない** — `oe-refute` / `oe-review` が反証に割り当てており、入力の不備が「設計が反証された」として上位に届かないようにしてある。詳細は `canonical/skills/so-compare/SKILL.md` の「終了コード」節。

```bash
# 推奨: -w でワークスペースパスを渡す
so-compare.sh -w "$(pwd)" "プロンプトテキスト"

# プロンプトファイルから
so-compare.sh -f prompt.txt -w "$(pwd)"

# イテレーション（前回の回答を踏まえて再質問）
so-compare.sh --prev tmp/so-YYYYMMDD-HHMMSS -w "$(pwd)" "再評価してください"

# Codex のみ / Claude のみ
so-compare.sh -w "$(pwd)" "プロンプト" --codex-only
so-compare.sh -w "$(pwd)" "プロンプト" --claude-only

# 任意のプロバイダ組み合わせ（1〜3社）
so-compare.sh --with codex,cursor -w "$(pwd)" "プロンプト"
so-compare.sh --with claude,cursor -w "$(pwd)" "プロンプト"
```

主要オプション:

| オプション | 説明 |
|-----------|------|
| `--with LIST` | 実行プロバイダ明示（`codex,claude,cursor` のカンマ区切り。レガシー only/cursor フラグと併用不可） |
| `--codex-only` / `--claude-only` / `--cursor-only` | そのプロバイダのみ実行 |
| `--cursor` | Cursor CLI（`agent`）も実行（デフォルト: 無効） |
| `-w PATH` | ワークスペースパス（推奨。codex に `-C`、claude に `--add-dir` として渡される） |
| `-c FILE...` | コンテキストファイル添付（非推奨。プロンプト肥大化の原因） |
| `-f FILE` | プロンプトをファイルから読み込み |
| `-o DIR` | 出力ディレクトリ指定（デフォルト: `tmp/so-YYYYMMDD-HHMMSS`） |
| `-s MODE` | Codex の sandbox モード。受け付けるのは `read-only` だけで、ほかの値は `invalid:sandbox-not-read-only` で拒否する（終了コード `4`） |
| `--prev DIR` | 前回出力を追記（イテレーション用） |
| `--codex-model MODEL` | Codex のモデル（デフォルト: CLI 既定） |
| `--claude-model MODEL` | Claude のモデル（エイリアス `opus` / `sonnet` / `haiku` 可。デフォルト: CLI 既定） |
| `--cursor-model MODEL` | Cursor のモデル（デフォルト: `composer-2.5`） |
| `--claude-effort LEVEL` | Claude のエフォート（`low` / `medium` / `high` / `xhigh` / `max`。デフォルト: CLI 既定） |
| `--claude-web` | Claude Code に WebFetch を許可（外部 URL の参照を要するタスク用） |

環境変数:

| 変数 | 説明 | デフォルト |
|---|---|---|
| `SO_TIMEOUT` | codex / cursor のタイムアウト秒数 | 240 |
| `SO_CLAUDE_TIMEOUT` | claude のタイムアウト秒数 | 1200 |
| `SO_CODEX_MODEL` / `SO_CLAUDE_MODEL` / `SO_CURSOR_MODEL` | 各プロバイダのデフォルトモデル（`--*-model` で上書き可） | CLI 既定（cursor のみ `composer-2.5`） |
| `SO_CLAUDE_EFFORT` | Claude のデフォルトエフォート（`--claude-effort` で上書き可） | CLI 既定 |
| `PREV_MAX_BYTES` | `--prev` で追記する回答の上限バイト数 | 4000 |

全オプションは `so-compare.sh -h` を参照。

関連スキル: `canonical/skills/so-compare/SKILL.md`

### `harness-check.sh`

ハーネス（rule / skill）の発動効果を確かめるランナー。指定したディレクトリの各プロンプトを CLI agent の fresh session で実行し、結果をファイルに保存する。1 prompt = 1 fresh session なので、first-turn の挙動の観測に向く。現状は `--cli cursor` のみ実装（#106 の検証から派生）。

```bash
scripts/harness-check.sh --prompts-dir docs/issues/106/harness-check-prompts/cursor-composer-2.5/ --runs 3
scripts/harness-check.sh --prompts-dir <DIR> --model composer-2.5-fast --runs 3
scripts/harness-check.sh --prompts-dir <DIR> --dry-run   # 実行せずコマンドだけ表示
```

全オプションは `scripts/harness-check.sh -h` を参照。

### `wt/`

worktrunk（`wt switch`）と Claude Code のセッション名の連携。`wt-pane-issue.sh` は worktrunk の post-switch hook から呼ばれ、tmux ペインごとに作業中の issue を記録する。Claude Code の hook（`session-name.sh`）がそれを読み、セッションの名前を `#<issue> <slug>` にする。`~/bin/wt-pane-issue` として `sync-bin.sh` が配置する。worktrunk 側の設定は `wt/worktrunk-config.toml` の `[post-switch]` ブロックを `~/.config/worktrunk/config.toml` にマージする。

### `arena-compare.sh`

複数AIモデルへの並列投入と回答比較スクリプト。`projects/arena-compare/arena-compare.sh` へのシンボリックリンク。

詳細は [projects/arena-compare/README.md](../projects/arena-compare/README.md) を参照。
