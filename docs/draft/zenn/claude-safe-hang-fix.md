---
title: "CursorからClaude Codeを単純実行したいのにハングするので、解決スクリプトを作った話"
emoji: "🔨"
type: "tech"
topics:
  - "ai"
  - "cli"
  - "開発"
  - "cursor"
  - "claudecode"
published: true
published_at: "2026-02-07 17:12"
---

## 結論だけほしい人向け

- Cursor のチャットから Agent に `claude -p` を実行させると無限にハングする
- パイプ（`echo ... | claude`）なら動く → stdout/stderr が TTY かどうかで挙動が変わる
- `nohup` + 出力リダイレクトでプロセスの出力先をファイルに向けるラッパーで解決
- ラッパースクリプトの[コード](https://gist.github.com/stlwolf/1ef2b492966da929af1288b715c6e501)（記事のサンプルと同じもの）

## 背景：やりたかったこと

Cursor Agent と Claude Code は別のモデル・別のコンテキストで動作します。であれば、Cursor のチャットスレッドで Agent と会話しながら「ここは Claude Code に聞いて」と `claude -p` を叩かせれば、疑似的なマルチエージェント構成が作れるはずです。

たとえば：
- **Cursor Agent** にコード実装を任せつつ、**Claude Code** にレビューやセカンドオピニオンを求める
- `-c`（セッション継続）で Claude Code 側に文脈を保持させ、段階的にタスクを投げる

手動やCursor内のターミナルペインを開いて `claude -p` を叩けばもちろん動きます。ただそれでは Cursor Agent との会話の流れの中でシームレスに連携できません。Agent にターミナル経由で実行させてセカンドオピニオンやレビューさせたい意図がありました。

この検証をしようとしたところ、そもそも Agent 経由だと `claude -p` からレスポンスが受け取れないという問題にぶつかりました。

## 環境

| 項目 | バージョン |
|------|-----------|
| macOS | 15.7.3 (24G419) |
| Cursor | 2.4.28 (arm64) |
| Claude CLI | 2.1.31 (Claude Code) |
| Node.js | 18.17.1 |

## 何が起きるか

Cursor Agent にターミナルで `claude -p` を実行させると、出力が一切返らずハングします。`cursor-agent` コマンド（Cursor CLI）から直接実行しても同様の挙動を確認しています。

```bash
# Cursor のチャットから Agent にターミナル実行させた場合
$ claude -p "Hello, respond with OK"
# → 60秒以上待っても出力なし。kill するしかない

# cursor-agent コマンドから直接実行した場合も同様
$ cursor-agent claude -p "Hello, respond with OK"
# → 同様にハング
```

一方、パイプで標準入力から渡すと正常に動きます。

```bash
$ echo "Hello, respond with OK" | claude --output-format text
OK
# → 約5秒で応答
```

外部ターミナル（WezTerm 等）から直接叩けば `-p` も問題なく動作します。

### なぜパイプだと動くのか

`-p` フラグとパイプでは、CLI 側の入力検出ロジックが異なると考えられます。

- **パイプ**: stdin が pipe であることを `isatty(0)` 等で検出 → 純粋にストリームとして読む
- **`-p` フラグ**: stdin は TTY のまま、フラグで非インタラクティブモードに切り替える → TTY 制御のセットアップが走る

Cursor Agent（および `cursor-agent` コマンド）が操作するターミナルは、通常とは異なる PTY 環境で動作しているため、後者のパスで TTY 制御の競合が起きていると推測されます。

:::message alert
上記の動かない理由はあくまで推測です。Claude CLI のソースコードを読んで確認したわけではありませんので、ご留意ください。
:::

## 解決策：nohup ラッパー

出力リダイレクトでプロセスの stdout/stderr をファイルに向け、CLI 側の TTY 検出を回避します。

### スクリプト

```bash:claude-safe
#!/bin/bash
# claude-safe - Cursor Agent 経由で安全にClaude CLIを実行するラッパー
#
# 使い方:
#   claude-safe -p "プロンプト" --output-format text
#   claude-safe -c -p "セッション継続"
#   DEBUG=1 claude-safe -p "デバッグ出力あり"

set -euo pipefail

# デバッグモード
DEBUG=${DEBUG:-0}

debug_log() {
    if [ "$DEBUG" = "1" ]; then
        echo "[DEBUG] $*" >&2
    fi
}

# 出力ファイル
OUTPUT_DIR="${HOME}/.claude_wrapper"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/output_$$.txt"
ERROR_FILE="${OUTPUT_DIR}/error_$$.txt"

# クリーンアップ
cleanup() {
    debug_log "Cleaning up..."
    rm -f "$OUTPUT_FILE" "$ERROR_FILE"
}
trap cleanup EXIT

debug_log "Running: claude $*"
debug_log "Output file: $OUTPUT_FILE"

# Claudeを実行（プロセス分離 - macOS対応）
# nohupとバックグラウンド実行でプロセス分離
nohup claude "$@" > "$OUTPUT_FILE" 2> "$ERROR_FILE" &
CLAUDE_PID=$!

# プロセス完了を待機（set -e での即死を防ぎつつ終了コードを保持）
wait $CLAUDE_PID && EXIT_CODE=0 || EXIT_CODE=$?

debug_log "Exit code: $EXIT_CODE"

# 出力
cat "$OUTPUT_FILE"
if [ -s "$ERROR_FILE" ]; then
    cat "$ERROR_FILE" >&2
fi

exit $EXIT_CODE
```

### セットアップ

```bash
# スクリプトを配置（パスの通った場所ならどこでも）
cp claude-safe ~/.local/bin/claude-safe
chmod +x ~/.local/bin/claude-safe
```

### なぜこれで動くのか

```
Cursor Agent のターミナル (独自の PTY 環境)
  └─ claude-safe（ラッパー）
       └─ nohup claude ... > file 2> file &（stdout/stderrをファイルへ → 非TTY判定）
            └─ API呼び出し → 一時ファイルに書き出し
       └─ wait → cat → 標準出力に表示
```

ここでのポイントは `> "$OUTPUT_FILE" 2> "$ERROR_FILE"` による**出力リダイレクト**です。Claude CLI の stdout/stderr が TTY ではなくファイルに向けられることで、CLI 側の TTY 検出（`isatty()` 等）が「非 TTY」と判定され、TTY 制御のセットアップがスキップされます。パイプで動くのと同じ理屈です。

`nohup` 自体は SIGHUP シグナルを無視させるコマンドで、TTY 切り離しが主目的ではありません。本質的にはリダイレクトによる非 TTY 化が効いています。極端な話、`nohup` なしでリダイレクト + バックグラウンド実行だけでも動く可能性がありますが、HUP 耐性も含めて安全側に倒しています。

なお、CLI 内部でどのファイルディスクリプタ（stdin/stdout/stderr）に対して TTY 判定を行っているかは未確認です。本記事の回避策はこの環境で有効だった実践的なワークアラウンドです。

## 動作検証

Cursorのスレッド内で実行されるターミナル経由での比較結果です（複数回実行して再現性を確認）。

### ❌ `claude -p`（ハング）

```bash
$ claude -p "Hello! This is a connectivity test. Please respond with OK."
# → 90秒以上待っても出力なし。kill で強制終了
```

### ✅ `claude-safe` 経由（正常動作）

```bash
$ claude-safe -p "Hello! This is a connectivity test. Please respond with OK."
OK - Claude Opus 4.5
# → 約6秒で応答、終了コード 0
```

### 比較

| 実行方法 | 実行環境 | 結果 | 所要時間 |
|----------|----------|------|----------|
| `claude -p "..."` | Cursor Agent 経由 | ❌ ハング | 60秒超（タイムアウトなし） |
| `echo "..." \| claude --output-format text` | Cursor Agent 経由 | ✅ 動作 | 約5秒 |
| `claude-safe -p "..."` | Cursor Agent 経由 | ✅ 動作 | 約6秒 |
| `claude -p "..."` | 外部ターミナル (WezTerm) | ✅ 動作 | 約5秒 |

パイプ経由でも動作しますが、`-p` のオプション群（`-c` によるセッション継続、`--allowedTools` 等）をそのまま使えるラッパー方式のほうが実用的かと思います。

## まとめ

- Cursor Agent 経由で `claude -p` がハングするのは、PTY 制御の競合が原因（推測）
- 出力先をファイルにリダイレクトし、CLI の TTY 検出を回避するラッパーで解決できる
- 回避策の本質は `nohup` ではなくリダイレクトによる非 TTY 化
- パイプで動くという検証結果が、TTY 制御が原因であるという仮説を裏付けている

同じような事をやってみようと思っている方の参考になれば幸いです。
