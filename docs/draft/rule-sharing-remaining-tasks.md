# ルール共通化: 残課題と方針

## 完了済み（2026-03-27）

- `canonical/` ディレクトリ作成、`cursor/` から rules/skills/agents/commands を移動
- 個別 sync スクリプト再編: `sync-cursor.sh`, `sync-claude.sh`, `sync-codex.sh`
- 統合ランナー `scripts/sync.sh` 作成（デフォルト全実行、引数で個別指定可能）
- 旧 sync スクリプト（`sync-cursor-commands.sh` 等 5本）削除
- `~/.claude/commands/` への commands 配置（新規）
- `~/.codex/skills/` への skills 配置（新規）
- ドキュメント更新（CLAUDE.md, AGENTS.md, README.md, scripts/README.md, cursor/README.md）

### 以前の完了分（2026-03-22）

- `sync-claude-rules.sh` 作成・実行（→ `sync-claude.sh` に統合済み）
- `cursor/user-rules/*.md`（8ファイル）を `~/.claude/rules/` にシンリンク配置

## 残課題

### 1. project-rules MDC の重複整理

`cursor/project-rules/behavioral-execution-output-rule.mdc` は `canonical/rules/` 3ファイルの簡易版。

| MDC セクション | 対応する rule | 差分 |
|---|---|---|
| §1 Behavioral Rules (6項目) | `behavioral-rule.md` | 完全一致 |
| §2 Execution Policy (2項目) | `execution-policy-rule.md` | rule 側に +2項目（gate/checkpoint、想定外停止） |
| §3 Output Format (4項目) | `output-format-rule.md` | rule 側に +2項目（関連リンク、URL→Markdown形式） |

**方針案:**
- user-rules が `alwaysApply` で Cursor にも効いているなら MDC は冗長 → 削除可能
- ただし Cursor の User Rules と project-rules の適用タイミング・優先度を要確認

**確認事項:**
- [ ] Cursor で User Rules と project-rules MDC が同時に効くか検証
- [ ] 重複確認後、MDC を削除するか統合するか判断

### 2. Claude Code 向け project-rules の扱い

Claude Code には `~/.claude/rules/` にユーザーレベルルールを配置済み。
プロジェクトレベルルール（Cursor の `.cursor/rules/*.mdc` 相当）は Claude Code では `CLAUDE.md` が担う。
追加対応は不要。
