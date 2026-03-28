# Scripts

リポジトリ運用のユーティリティスクリプト。

## ディレクトリ構成

```
scripts/
├── sync.sh            # 統合 sync ランナー
├── arena-compare.sh   -> ../projects/arena-compare/arena-compare.sh
├── so-compare.sh
└── sync/
    ├── sync-bin.sh
    ├── sync-claude.sh
    ├── sync-codex.sh
    └── sync-cursor.sh
```

## sync/

`canonical/` を正本として、各AIツールの設定ディレクトリにシンボリックリンクを配置するスクリプト群。

### 統合ランナー

```bash
./scripts/sync.sh                # 全ターゲット実行
./scripts/sync.sh cursor         # Cursor のみ
./scripts/sync.sh claude codex   # 複数指定
./scripts/sync.sh --list         # 利用可能ターゲット一覧
```

### 個別スクリプト

| スクリプト | ソース | 配置先 |
|---|---|---|
| `sync-cursor.sh` | `canonical/{commands,skills,agents}` + `canonical/cursor/` 固有 + `canonical/mcp/cursor.json` | `~/.cursor/` |
| `sync-claude.sh` | `canonical/{rules,skills,agents,commands}` | `~/.claude/` |
| `sync-codex.sh` | `canonical/skills/` + `canonical/codex/{AGENTS.md,commands-registry}` + `canonical/agents`(toml生成) | `~/.codex/` |
| `sync-bin.sh` | `scripts/so-compare.sh`, `projects/arena-compare/arena-compare.sh` | `~/bin/` |

`sync-codex.sh` は実行前に `check-codex-guardrails.sh` を呼び出し、`canonical/rules` と `canonical/codex/AGENTS.md` の整合を検証する。

## ユーティリティ

### `check-codex-guardrails.sh`

`canonical/rules` の主要行動原則が `canonical/codex/AGENTS.md` に反映されているかを検証する。

```bash
./scripts/check-codex-guardrails.sh
```

### `so-compare.sh`

セカンドオピニオン比較実行スクリプト。同一プロンプトを Codex CLI / Claude Code に投げて結果をファイルに保存する。

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
```

主要オプション:

| オプション | 説明 |
|-----------|------|
| `-w PATH` | ワークスペースパス（推奨。codex に `-C`、claude に `--add-dir` として渡される） |
| `-c FILE...` | コンテキストファイル添付（非推奨。プロンプト肥大化の原因） |
| `-f FILE` | プロンプトをファイルから読み込み |
| `-o DIR` | 出力ディレクトリ指定 |
| `--prev DIR` | 前回出力を追記（イテレーション用） |

環境変数: `SO_TIMEOUT`（デフォルト: 240秒）、`PREV_MAX_BYTES`（デフォルト: 4000）

関連スキル: `canonical/skills/so-compare/SKILL.md`

### `arena-compare.sh`

複数AIモデルへの並列投入と回答比較スクリプト。`projects/arena-compare/arena-compare.sh` へのシンボリックリンク。

詳細は [projects/arena-compare/README.md](../projects/arena-compare/README.md) を参照。
