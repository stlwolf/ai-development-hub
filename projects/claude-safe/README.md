# claude-safe

Cursor/VS Code 統合ターミナルから Claude CLI を安全に実行するためのラッパースクリプト。

## 概要

Cursor Agent が統合ターミナルで `claude -p` を実行するとハングする問題を、`nohup` + 出力リダイレクトによるプロセス分離で解決する。

- Zenn記事: [Cursor AgentにClaude CLIを実行させたらハングした。nohupラッパーで解決する](https://zenn.dev/stlwolf/articles/cursor-agent-claude-cli-nohup-wrapper)
- Gist: [claude-safe](https://gist.github.com/stlwolf/1ef2b492966da929af1288b715c6e501)
- 関連Issue: [GitHub Issue #11707](https://github.com/anthropics/claude-code/issues/11707)

## 問題

| 実行方法 | 実行環境 | 結果 |
|----------|----------|------|
| `claude -p "..."` | Cursor Agent 経由 | ❌ ハング（60秒超） |
| `echo "..." \| claude` | Cursor Agent 経由 | ✅ 動作（約5秒） |
| `claude-safe -p "..."` | Cursor Agent 経由 | ✅ 動作（約6秒） |
| `claude -p "..."` | 外部ターミナル | ✅ 動作（約5秒） |

## 仕組み

```
Cursor Agent のターミナル (独自の PTY 環境)
  └─ claude-safe（ラッパー）
       └─ nohup claude ... > file 2> file &（stdout/stderrをファイルへ → 非TTY判定）
            └─ API呼び出し → 一時ファイルに書き出し
       └─ wait → cat → 標準出力に表示
```

ポイントは出力リダイレクトにより Claude CLI の stdout/stderr が TTY ではなくファイルに向けられること。CLI 側の TTY 検出（`isatty()` 等）が「非 TTY」と判定され、TTY 制御のセットアップがスキップされる。

`nohup` 自体は SIGHUP 耐性のための安全策。本質はリダイレクトによる非 TTY 化。

## セットアップ

```bash
# パスの通った場所にコピー
cp claude-safe ~/.local/bin/claude-safe
chmod +x ~/.local/bin/claude-safe
```

## 使い方

```bash
# 基本（claude と同じ引数を渡せる）
claude-safe -p "プロンプト" --output-format text

# セッション継続
claude-safe -c -p "前の会話の続き"

# デバッグモード
DEBUG=1 claude-safe -p "テスト"
```

## 運用フロー

```
ai-development-hub/projects/claude-safe/  ← 開発・検証
    ↓ 安定版を
dotfiles/bin/claude-safe                  ← デプロイ用にコピー
    ↓ make deploy
~/bin/claude-safe                         ← 実行環境
```

## ファイル構成

```
claude-safe/
├── README.md                 # このファイル
├── claude-safe               # メインスクリプト（検証用）
└── docs/
    └── orchestration.md      # 疑似オーケストレーション構想
```

## 今後の方向性

### 短期: claude-safe 自体の改善

- [ ] タイムアウト設定
- [ ] リトライ機能
- [ ] ストリーミング出力対応
- [ ] JSON 出力モードの最適化

### 中期: 疑似オーケストレーションツール

- [ ] `ai-review` - 複数視点コードレビュー
- [ ] `ai-refactor` - リファクタ提案の比較検討
- [ ] コンテキスト・エンベロープ（JSON構造）の実装

### 長期: フレームワーク統合検討

- [ ] 複雑な状態管理が必要になった場合に LangGraph 等を検討
- [ ] MCP 経由での連携強化

## 動作環境

| 項目 | 要件 |
|------|------|
| OS | macOS（`setsid` がないため `nohup` を使用） |
| Shell | Bash 4.x+（Homebrew bash 推奨） |
| Claude CLI | インストール・認証済みであること |

## 由来

`ideas/20260204/` での検証実験から発展。アイデア段階のドキュメントは ideas ディレクトリに凍結保存。
