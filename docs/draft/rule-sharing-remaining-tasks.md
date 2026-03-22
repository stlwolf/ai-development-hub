# ルール共通化: 残課題と方針

## 完了済み（2026-03-22）

- `sync-claude-rules.sh` 作成・実行
- `cursor/user-rules/*.md`（8ファイル）を `~/.claude/rules/` にシンリンク配置
- README 更新（`scripts/README.md`, `cursor/README.md`）

## 残課題

### 1. project-rules MDC の重複整理

`cursor/project-rules/behavioral-execution-output-rule.mdc` は `user-rules/` 3ファイルの簡易版。

| MDC セクション | 対応する user-rule | 差分 |
|---|---|---|
| §1 Behavioral Rules (6項目) | `behavioral-rule.md` | 完全一致 |
| §2 Execution Policy (2項目) | `execution-policy-rule.md` | user-rule 側に +2項目（gate/checkpoint、想定外停止） |
| §3 Output Format (4項目) | `output-format-rule.md` | user-rule 側に +2項目（関連リンク、URL→Markdown形式） |

**方針案:**
- user-rules が `alwaysApply` で Cursor にも効いているなら MDC は冗長 → 削除可能
- ただし Cursor の User Rules と project-rules の適用タイミング・優先度を要確認
  - User Rules はプロンプト最上位に挿入される
  - project-rules (`alwaysApply: true`) はコンテキスト内に挿入される
  - 両方適用されるなら重複、一方のみなら残す意味がある

**確認事項:**
- [ ] Cursor で User Rules と project-rules MDC が同時に効くか検証
- [ ] 重複確認後、MDC を削除するか統合するか判断

### 2. Claude Code 向け project-rules の扱い

Claude Code には `.claude/rules/` にユーザーレベルルールを配置した。
プロジェクトレベルルール（Cursor の `.cursor/rules/*.mdc` 相当）は Claude Code では `CLAUDE.md` が担う。

**現状の survey リポジトリでの対応:**
- `survey/.cursor/rules/survey.mdc` の内容（ドメイン知識、命名規則）は `CLAUDE.md` と `AGENTS.md` でカバー済み
- よって Claude Code 向けの追加対応は不要

**他リポジトリへの展開時の注意:**
- 各リポジトリに `.cursor/rules/*.mdc` がある場合、Claude Code で同等の効果を得るには `CLAUDE.md` に記載が必要
- `behavioral-execution-output-rule.mdc` のような汎用ルールは `~/.claude/rules/` 経由で自動適用されるため対応不要

### 3. skills / agents / commands のツール間対応

各コンセプトの現状と、ツール非依存化に向けた課題。

**現状の対応関係:**

| コンセプト | 正本 | Cursor | Claude Code | 備考 |
|---|---|---|---|---|
| rules | `cursor/user-rules/` | User Rules として設定 | `~/.claude/rules/` にシンリンク済 | フォーマット同一、変換不要 |
| skills | `cursor/skill/` | `~/.cursor/skills/` にシンリンク | `~/.claude/skills/` にシンリンク済 | `sync-cursor-skills.sh` が両方に配置 |
| agents | `cursor/agents/` | `~/.cursor/agents/` にシンリンク | `~/.claude/agents/` にシンリンク済 | `sync-cursor-agents.sh` が両方に配置 |
| commands | `cursor/command/` | `~/.cursor/commands/` にシンリンク | **未対応** | 下記参照 |

**commands の課題:**
- Cursor の commands（`/peer-ai-review`, `/arena-perspectives` 等）は Claude Code では「スキル」として動作する
- Claude Code のスキルは `~/.claude/commands/` に `.md` ファイルとして配置（Cursor の commands と同じフォーマット）
- 現状 6 コマンド中、Claude Code で使えるものと Cursor 固有のものの仕分けが必要
  - `/pr-review`, `/peer-ai-review`, `/arena-perspectives` → ツール非依存で使える可能性あり
  - `/copilot-review-response` → Cursor 固有（Copilot レビューへの対応）
  - `/issue-debug` → ツール非依存で使える可能性あり
  - `/archive-title` → Cursor の会話エクスポート固有

**非依存化に向けて:**
- skills と agents は既に Cursor / Claude Code 両対応だが、sync スクリプト名が `sync-cursor-*.sh` のままで紛らわしい
- commands はツール間でフォーマット互換があるため、汎用的なものは canonical に移行し sync で配置可能

### 4. リポジトリ構造のツール非依存化（中期方針）

現在 `cursor/` ディレクトリがルール・スキル・エージェント定義の事実上の正本になっている。
Claude Code 向け sync も「Cursor のファイルをそのままシンリンク」しており、Cursor 依存の構造。

**問題:**
- ツールが増えるたびに「Cursor のファイルを別ツールに流用」するアドホック対応になる
- フォーマット差異が出た時点で破綻する（現状は `.md` / `.mdc` がほぼ同一のため偶然動いている）
- `cursor/` というディレクトリ名が正本としてミスリーディング

**目指す構造:**

```
canonical/              # ツール非依存の正本（single source of truth）
├── rules/              # 行動ルール (.md)
├── skills/             # スキル定義
├── agents/             # エージェント定義
└── knowledge/          # ドメイン知識

scripts/sync/
├── sync-cursor.sh      # canonical → ~/.cursor/{rules,skills,commands,...}
├── sync-claude-code.sh # canonical → ~/.claude/{rules,skills,...}
├── sync-codex.sh       # canonical → ~/.codex/skills/ (フォーマット変換あり)
└── sync-all.sh         # 全ツール一括
```

**判断ポイント:**
- canonical のフォーマットをどうするか（現状の `.md` + YAML frontmatter で十分か）
- Cursor 固有機能（`.mdc` の `globs`, `alwaysApply` 等）をどう扱うか
  - canonical 側にメタデータとして持つか、sync 時に付与するか
- 移行は段階的に可能（まず `cursor/` → `canonical/` のリネーム + sync 書き換えから）

**優先度: 中** — 今は 2 ツール（Cursor + Claude Code）で済んでいるが、Codex CLI や他ツール追加時に着手。

### 4. sync スクリプトの統合検討

現在 sync スクリプトが 6 つに増加。ツール非依存化（課題 3）と合わせて、ツール単位の統合スクリプトへ再編する方が自然。

**優先度: 低** — 課題 3 の構造変更と同時に対応。
