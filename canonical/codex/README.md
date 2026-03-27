# Codex Extension Layer

Codex専用の拡張レイヤー。既存の`canonical/{rules,skills,agents,commands}`を変更せず、Codex向け運用導線だけをここに追加する。

## Directory Layout

- `commands-registry/`: 疑似コマンドと`canonical/commands`の対応定義
- `agents/`: Codex向けsubagent定義のドキュメント/オーバーライド置き場（生成物は`~/.codex/agents/*.toml`）

## Policy

- 行動ガードレールは`AGENTS.md`で運用する
- Codexの`rules`機構は権限昇格コマンド制御専用として扱う
- Cursor/Claude向け設定要素には影響を与えない
