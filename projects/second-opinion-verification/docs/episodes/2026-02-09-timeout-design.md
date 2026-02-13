# Episode: claude-safe タイムアウト機能の設計と検証

- 日付: 2026-02-09
- 参加者: Cascade (Primary), Claude Code (Second)
- 目的: `claude-safe` にタイムアウト機能を実装し、プロセスハング時の安全策を設ける

## 1. Primary Design Proposal (by Cascade)

### 概要
`claude-safe` は現在、`nohup` とバックグラウンド実行を使ってプロセスを分離しているが、実行時間の制限がない。
API応答が返ってこない場合や、予期せぬハング時にプロセスが残り続ける問題がある。
これを防ぐため、環境変数で制御可能なタイムアウト機能を追加する。

### 仕様案

1.  **制御**: 環境変数 `CLAUDE_TIMEOUT` で秒数を指定可能にする（デフォルト: 設定なし=無制限）。
2.  **実装方針**:
    - macOSにはGNU coreutilsの `timeout` コマンドが標準ではない。
    - 外部依存（`brew install coreutils` 等）を避けるため、シェルスクリプト標準の機能で実装する。
    - バックグラウンドで `claude` を実行した後、監視プロセスを別途起動する方式とする。
3.  **シグナル**:
    - タイムアウト時はまず `SIGTERM` を送り、それでも終了しなければ数秒後に `SIGKILL` する。

### 擬似コード

```bash
# ... (前略)

# タイムアウト設定
TIMEOUT=${CLAUDE_TIMEOUT:-0}

# 実行
nohup claude "$@" > "$OUTPUT_FILE" 2> "$ERROR_FILE" &
PID=$!

if [ "$TIMEOUT" -gt 0 ]; then
    # 監視プロセスをバックグラウンドで起動
    (
        sleep "$TIMEOUT"
        if kill -0 "$PID" 2>/dev/null; then
            echo "Timeout reached ($TIMEOUT s). Killing PID $PID" >&2
            kill "$PID"
            sleep 2
            kill -9 "$PID" 2>/dev/null
        fi
    ) &
    WATCHDOG_PID=$!
fi

wait "$PID"
EXIT_CODE=$?

# 正常終了したら監視プロセスを殺す
if [ -n "${WATCHDOG_PID:-}" ]; then
    kill "$WATCHDOG_PID" 2>/dev/null
fi

# ... (後略)
```

### 懸念点（Self Review）
- 監視プロセス (`WATCHDOG_PID`) が残る可能性があるか？
- `wait` がシグナルで中断されたときの終了コードの扱い。

---

## 2. Second Opinion Request

この設計案に対し、Claude Code (反証担当) にレビューを依頼する。

### Claude Code からの反証（要約）

**結論: このまま実装すべきではない。**

#### 致命的な問題点 (P0)
1.  **ゾンビ `sleep` プロセス**: `kill "$WATCHDOG_PID"` しても、サブシェル内の `sleep` プロセスが孤立して残り続ける（特に長時間タイムアウト設定時に実害大）。
2.  **`set -e` の罠**: `wait` が非ゼロで終了した際、`set -e` によって即座にスクリプトが落ち、`kill "$WATCHDOG_PID"` のクリーンアップが走らない。

#### 改善すべき点 (P1-P2)
1.  **終了コードの曖昧さ**: タイムアウトによる強制終了なのか、`claude` 自体のエラーなのか区別できない（タイムアウト時は `124` 等を返すべき）。
2.  **バリデーション欠如**: `CLAUDE_TIMEOUT` に非数値が入った場合のエラーハンドリングがない。
3.  **シグナル猶予**: `SIGTERM` から `SIGKILL` までの猶予時間が固定値。

---

## 3. Revised Design (Action Plan)

反証を受け、実装方針を以下のように修正する。

### 修正方針
1.  **trap による確実なクリーンアップ**: `EXIT` シグナルを trap し、スクリプト終了時には必ず watchdog を殺す。
2.  **PIDベースの sleep 制御**: サブシェルではなく、バックグラウンドで `sleep` を回し、その PID を控えて `kill` できるようにする。
3.  **終了コードの明確化**: タイムアウト発生時はフラグファイルを作成し、終了コードを `124` で上書きする。

### 修正後の擬似コード構造

```bash
setup_watchdog() {
    if [ "$TIMEOUT" -gt 0 ]; then
        # フラグファイル
        TIMEOUT_FLAG="${OUTPUT_DIR}/timeout_$$.flag"
        
        # 監視プロセス (sleep 自体を殺せるように工夫)
        (
            sleep "$TIMEOUT"
            if kill -0 "$MAIN_PID" 2>/dev/null; then
                touch "$TIMEOUT_FLAG"
                kill -TERM "$MAIN_PID"
                sleep "$KILL_GRACE"
                kill -KILL "$MAIN_PID"
            fi
        ) &
        WATCHDOG_PID=$!
    fi
}

cleanup() {
    # watchdog プロセスグループごと殺す、または sleep PID を特定して殺す
    if [ -n "${WATCHDOG_PID:-}" ]; then
        kill "$WATCHDOG_PID" 2>/dev/null
        # pkill -P "$WATCHDOG_PID" ... (macOSだとpgrep/pkillの挙動に注意が必要)
    fi
    # ...
}
trap cleanup EXIT
```

この修正方針で実装フェーズへ進む。
