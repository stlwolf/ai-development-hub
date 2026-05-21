# Cursor

Cursor AI エディタ固有のファイル。

共通リソース（rules, skills, agents, commands）は `canonical/` 直下に配置済み。
ここには Cursor でしか使わないファイルのみ配置する。

## ディレクトリ構成

```text
canonical/cursor/
├── command/thread/               # Cursor 固有コマンド（archive-title）
├── rules/cursor-first-turn.mdc   # Composer 2.5 向け alwaysApply User Rule
└── skills/cursor-kickoff/        # 壁打ち〜計画立案 wrapper Skill
```

MCP 設定は `canonical/mcp/cursor.json` に配置。

## デプロイ

```bash
# Cursor 向け一括 sync（canonical/ の共通リソース + Cursor 固有ファイル）
./scripts/sync.sh cursor

# または個別スクリプト
./scripts/sync/sync-cursor.sh
```

`sync-cursor.sh` で配布される Cursor 固有レイヤー:

- `canonical/cursor/rules/*.mdc` → `~/.cursor/rules/`
- `canonical/cursor/skills/*/`   → `~/.cursor/skills/`
- `canonical/cursor/command/thread/archive-title.md` → `~/.cursor/commands/`

## ルール

- 共通ルール（`canonical/rules/`）は Cursor の User Rules として設定
- Cursor 固有 `.mdc` rule（`canonical/cursor/rules/`）は `sync-cursor.sh` で `~/.cursor/rules/` に自動配置（Issue #106 で実装）
- プロジェクト固有ルールは各プロジェクトの `.cursor/rules/` に配置
