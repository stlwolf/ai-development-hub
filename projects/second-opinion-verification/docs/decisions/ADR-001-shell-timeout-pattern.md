# ADR-001: Portable Shell Timeout Pattern

## Context
`claude-safe` は macOS/Linux 環境で動作するシェルスクリプトであり、外部依存（GNU coreutils の `timeout` コマンド等）を避けつつ、サブプロセス（Claude CLI）の実行時間制限を行う必要があった。
特に macOS のデフォルト環境では `timeout` コマンドが存在せず、Perl/Ruby への依存も将来的なリスクがあるため、シェルスクリプト標準機能のみでの実装が求められた。

## Decision
バックグラウンドで監視プロセス（Watchdog）を起動し、タイムアウト時にメインプロセスを `kill` する「Watchdog パターン」を採用する。

### 実装詳細
1.  **Watchdog 起動**: メイン処理の直前に、バックグラウンドで `sleep $TIMEOUT` するサブシェルを起動。
2.  **強制終了**: `sleep` 完了後、対象プロセスが生きていれば `SIGTERM` → `sleep $GRACE` → `SIGKILL` を送る。
3.  **プロセス分離**: 監視対象は `nohup` + `&` でバックグラウンド実行し、シグナル伝播の影響を制御する。
4.  **終了コード**: タイムアウト発生時はフラグファイルを作成し、スクリプトの終了コードを `124`（GNU timeout 準拠）に上書きする。

## Consequences

### Positive
- **移植性**: 追加インストールなしで macOS/Linux 両対応が可能。
- **制御性**: `SIGTERM` から `SIGKILL` までの猶予時間（Grace Period）を細かく制御できる。

### Negative
- **複雑性**: プロセスグループ管理、シグナルハンドリング、競合状態（Race Condition）の考慮が必要。
- **リスク**: 実装を誤るとゾンビプロセス（孤児プロセス）が大量に残る危険性がある。

## Mitigation Strategies (リスク軽減策)
検証プロセス（Episode: 2026-02-09）により、以下の安全策が必須と判断された：

1.  **確実なクリーンアップ**: `trap cleanup EXIT INT TERM` を使用し、ユーザーによる中断（Ctrl+C）時も Watchdog とメインプロセス両方を確実に殺す。
2.  **PID再利用対策**: メインプロセス完了直後に Watchdog を `kill` し、OSによるPID再利用時の誤爆を防ぐ。
3.  **Watchdogの構成**: Watchdog 自体も `pkill -P` 等で子プロセス（`sleep`）を含めてクリーンアップ可能にする。
