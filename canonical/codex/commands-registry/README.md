# Codex Commands Registry

Codex CLIにはCursor/Claudeのような任意Markdownコマンド配布をそのまま移植できないため、
このレジストリで「疑似コマンド -> 実体ドキュメント」の対応を管理する。

## Conventions

- 疑似コマンドの実体は`canonical/commands/**/*.md`
- 実行時は対応ドキュメントを読み、定義された手順に従う
- ここはCodex専用の導線定義であり、既存コマンド本文は変更しない
