# shellcheck shell=bash
# shellcheck disable=SC2034
# constants.sh — OE グローバル定数定義（source 専用）

# マーカープレフィックス
OE_MARKER_PREFIX="@@OE_"

# EXIT マーカー正規表現（行頭・行末アンカー付き）
OE_EXIT_MARKER_RE='^@@OE_EXIT:([0-9]{1,3})$'

# 将来マーカー種別の予約（MVP では未使用）:
#   @@OE_STATUS:{state}  — 進捗状態の報告
#   @@OE_READY           — サブエージェント準備完了
#   @@OE_OUTPUT:{path}   — 成果物パスの通知
#   @@OE_BLOCKED:{reason} — ブロック理由の報告

# サーキットブレーカー閾値
OE_CB_TIMEOUT=1800
OE_CB_MAX_TURNS=10
OE_CB_MAX_PANES=5

# SLO: マーカー検出目標（秒）
OE_SLO_DETECT_SEC=5

# ポーリング間隔（秒）
OE_POLL_INTERVAL=2

# wez pane split --wait-ready のタイムアウト（秒）。ADR-003 に準拠。
OE_SPAWN_WAIT_READY_SEC="${OE_SPAWN_WAIT_READY_SEC:-10}"

# KVS パス（OE_DATA_DIR でオーバーライド可能、デフォルトはプロジェクトルート相対）
OE_STATE_DIR="${OE_DATA_DIR:-${PROJECT_DIR}}/state"

# 監査ログパス
OE_AUDIT_DIR="${OE_DATA_DIR:-${PROJECT_DIR}}/audit"
