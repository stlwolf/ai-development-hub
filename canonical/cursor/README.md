# Cursor

Cursor AI エディタ固有のファイル。

共通リソース（rules, skills, agents, commands）は `canonical/` 直下に配置済み。
ここには Cursor でしか使わないファイルのみ配置する。

## ディレクトリ構成

```
canonical/cursor/
└── command/thread/       # Cursor 固有コマンド（archive-title）
```

MCP 設定は `canonical/mcp/cursor.json` に配置。

## デプロイ

```bash
# Cursor 向け一括 sync（canonical/ の共通リソース + Cursor 固有ファイル）
./scripts/sync.sh cursor

# または個別スクリプト
./scripts/sync/sync-cursor.sh
```

## ルール

- 共通ルール（`canonical/rules/`）は Cursor の User Rules として設定
- プロジェクト固有ルールは各プロジェクトの `.cursor/rules/` に配置
