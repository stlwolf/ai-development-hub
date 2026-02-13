# Episode: claude-safe タイムアウト機能の実装レビュー (Second Opinion)

- 日付: 2026-02-09
- 参加者: Cascade (Primary), Claude Code (Second)
- 目的: 実装コードの安全性検証

## 1. Implementation for Review

- **Commit**: (draft)
- **Feature**: タイムアウト機能、数値バリデーション、watchdogによるプロセス監視

## 2. Second Opinion Feedback (by Claude Code)

### 致命的な問題点 (Blocker)

1.  **Ctrl+C (SIGINT) でのプロセス孤児化**
    - `trap cleanup EXIT` だけでは `INT` や `TERM` を捕捉できない場合がある（`set -e` との兼ね合い）。
    - ユーザーが中断した際、`claude` プロセスが `kill` されずバックグラウンドで生き残る。
    - **対策**: `trap cleanup EXIT INT TERM` に変更し、`cleanup` 内で `CLAUDE_PID` も明示的に殺す。

2.  **PID再利用による誤爆リスク (Race Condition)**
    - メイン処理が完了した後、watchdog が生き残っていると、OSが PID を再利用して別のプロセスに割り当てた瞬間に誤って `kill` する可能性がある（確率は低いがゼロではない）。
    - **対策**: `wait` が終わったら即座に watchdog を殺す処理をメインフローに入れる。

### その他の改善点

- `KILL_GRACE` の数値バリデーション欠如。
- 古い一時ファイルの掃除（起動時に行う）。

---

## 3. Refix Plan

指摘に基づき、以下の修正を行う。

1.  **Signal Handling 強化**: `trap cleanup EXIT INT TERM`
2.  **Cleanup Logic 修正**: `CLAUDE_PID` が存在すれば殺す処理を追加。
3.  **Watchdog Immediate Kill**: `wait` 完了直後に `cleanup` を呼ぶか、明示的に watchdog を止める。
4.  **Grace Validation**: `KILL_GRACE` にも数値チェックを追加。
