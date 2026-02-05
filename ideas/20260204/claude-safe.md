# claude-safe - Cursor/VS Code統合ターミナル用Claude CLIラッパー

## 概要

`claude-safe` は、Cursor/VS Code統合ターミナルからClaude CLIを安全に実行するためのラッパースクリプト。

## 背景・課題

### 問題

Cursor/VS Code統合ターミナルでClaude CLIを直接実行すると、以下の問題が発生する：

- 約33%の頻度でランダムに割り込まれる（`[Request interrupted by user]`）
- プロセスがハングする
- 出力が返ってこない
- 非インタラクティブモード（`-p`）でも同様の問題が発生

### 原因

[GitHub Issue #11707](https://github.com/anthropics/claude-code/issues/11707) によると：

1. **Claude Code拡張機能とCLIの競合**
   - 両方が同時にClaudeプロセスを管理しようとする
   - ファイルロック（`.claude/`ディレクトリ内）の競合
   - シェル統合（shell integration）の問題

2. **ターミナル環境の問題**
   - `TERM=dumb`（ダムターミナル）
   - TTYがない（`not a tty`）
   - PTY作成がサポートされない

### 検証結果

```bash
# 直接ターミナルで実行 → 成功
claude -c -p "テスト" --output-format text
# → 正常に応答が返る

# Cursor統合ターミナルで実行 → 失敗
claude -c -p "テスト" --output-format text
# → 出力なし、またはハング
```

## 解決策

プロセス分離（`nohup` + バックグラウンド実行）でCursor統合ターミナルとClaude CLIの直接的な競合を回避。

### 仕組み

```
┌─────────────────────┐
│ Cursor統合ターミナル │
└──────────┬──────────┘
           │ 実行
           ▼
┌─────────────────────┐
│   claude-safe       │ ← ラッパースクリプト
└──────────┬──────────┘
           │ nohup + &
           ▼
┌─────────────────────┐     ┌─────────────┐
│   claude CLI        │ ──> │ 一時ファイル │
│   (別プロセス)       │     │ (出力担保)   │
└─────────────────────┘     └──────┬──────┘
                                   │
           ┌───────────────────────┘
           ▼
┌─────────────────────┐
│ 出力をcat          │
│ → Cursorに表示     │
└─────────────────────┘
```

## 実装

```bash
#!/bin/bash
# claude-safe - Cursor/VS Code統合ターミナルから安全にClaude CLIを実行

set -euo pipefail

OUTPUT_DIR="${HOME}/.claude_wrapper"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/output_$$.txt"
ERROR_FILE="${OUTPUT_DIR}/error_$$.txt"

trap "rm -f $OUTPUT_FILE $ERROR_FILE" EXIT

# Claudeを実行（プロセス分離 - macOS対応）
nohup claude "$@" > "$OUTPUT_FILE" 2> "$ERROR_FILE" &
CLAUDE_PID=$!

# プロセス完了を待機
wait $CLAUDE_PID
EXIT_CODE=$?

# 出力
cat "$OUTPUT_FILE"
if [ -s "$ERROR_FILE" ]; then
    cat "$ERROR_FILE" >&2
fi

exit $EXIT_CODE
```

## 使い方

```bash
# 基本的な使い方（claude と同じ引数を渡せる）
claude-safe -c -p "テスト" --output-format text

# セッション継続
claude-safe -c -p "前の会話の続き"

# デバッグモード
DEBUG=1 claude-safe -p "テスト"
```

## ユースケース

### 疑似オーケストレーション

CursorとClaude Codeを連携させた並列エージェント的なワークフロー：

```bash
# Cursorから実行して、Claude Codeにレビューを依頼
claude-safe -c -p "@file.md を読んでレビューしてください" --output-format text
```

### CI/CD統合

VS Code/Cursor環境でのテスト自動化：

```bash
# テスト結果をClaude Codeに分析させる
npm test 2>&1 | claude-safe -p "このテスト結果を分析して" --output-format text
```

## 今後の改善案

- [ ] タイムアウト設定の追加
- [ ] リトライ機能
- [ ] ストリーミング出力対応
- [ ] JSON出力モード対応
- [ ] エラーハンドリングの強化
- [ ] ログ機能の追加

## 関連リソース

- [GitHub Issue #11707 - VS Code terminal interrupts](https://github.com/anthropics/claude-code/issues/11707)
- [Claude Code Docs - How it works](https://code.claude.com/docs/en/how-claude-code-works)

## 注意事項

- macOS専用（`setsid`がないため`nohup`を使用）
- Homebrew bashが必要（`set -euo pipefail`使用）
- Claude CLIがインストール・認証済みであること
