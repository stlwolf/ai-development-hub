# Cursor

Cursor AI エディタ固有のファイル。

共通リソース（rules, skills, agents, commands）は `canonical/` に移動済み。
ここには Cursor でしか使わないファイルのみ配置する。

## ディレクトリ構成

```
cursor/
├── command/thread/       # Cursor 固有コマンド（archive-title）
├── knowledge/            # 知識ベース（セットアップガイド等）
├── mcp.json              # MCP サーバー設定
└── project-rules/        # プロジェクト固有ルール (.mdc, alwaysApply)
```

## デプロイ

```bash
# Cursor 向け一括 sync（canonical/ の共通リソース + cursor/ 固有ファイル）
./scripts/sync.sh cursor

# または個別スクリプト
./scripts/sync/sync-cursor.sh
```

## ルール

- **`project-rules/`**: `.mdc` 形式。プロジェクトの `.cursor/rules/` にコピーして使用
- 共通ルール（`canonical/rules/`）は Cursor の User Rules として設定
