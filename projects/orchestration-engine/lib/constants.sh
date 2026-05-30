# shellcheck shell=bash
# shellcheck disable=SC2034
# constants.sh — OE グローバル定数定義（source 専用）

# マーカープレフィックス
OE_MARKER_PREFIX="@@OE_"

# EXIT マーカー正規表現（先頭/末尾空白を許容、行末アンカーは維持）
# #112: 対話 Claude Code TUI が応答本文を字下げするため `  @@OE_EXIT:0` を拾えるよう先頭空白を許容。
# 行末アンカー維持で「マーカー後にテキストが続く行＝プロンプトのエコー」を除外する。
OE_EXIT_MARKER_RE='^[[:space:]]*@@OE_EXIT:([0-9]{1,3})[[:space:]]*$'

# VERIFY マーカー正規表現 (Step 4-3 検証ゲート v1、先頭/末尾空白を許容、行末アンカーは維持)
OE_VERIFY_MARKER_RE='^[[:space:]]*@@OE_VERIFY:(pass|fail|warn)[[:space:]]*$'

# 将来マーカー種別の予約（MVP では未使用）:
#   @@OE_STATUS:{state}  — 進捗状態の報告
#   @@OE_READY           — サブエージェント準備完了
#   @@OE_OUTPUT:{path}   — 成果物パスの通知
#   @@OE_BLOCKED:{reason} — ブロック理由の報告

# サーキットブレーカー閾値
# Step 4-4 Phase C 発見: 実 agent (cursor-agent/composer-2) では mock 想定の MAX_TURNS=10 (=20s @ 2s poll) が短すぎる。
# env override 可能にしつつデフォルトは mock テスト互換のため維持。
OE_CB_TIMEOUT="${OE_CB_TIMEOUT:-1800}"
OE_CB_MAX_TURNS="${OE_CB_MAX_TURNS:-10}"
OE_CB_MAX_PANES="${OE_CB_MAX_PANES:-5}"

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

# Step 4-3 Phase E: 検証ペイン管理用配列 (F2: 通常ペイン OE_MANAGED_PANES / OE_DONE_PANES と分離)
OE_VERIFY_MANAGED_PANES=()
OE_VERIFY_DONE_PANES=()

# Step 4-3 Phase E: 検証フェーズ完走フラグ (cleanup の wez notify 発火条件、CB 発動時は未設定のまま)
OE_VERIFY_PHASE_COMPLETED=0

# Step 4-4 Phase A: target / 検証 agent の AI CLI + モデル選択 (DI-4 + #91)
# Phase A Step 1 物理前提実機確認で確定したデフォルト値:
#   - target = cursor-agent (composer-2)
#   - 検証   = claude (claude-sonnet-4-6)
# env var で override 可能。CLI ディスパッチャ (_oe_spawn_build_cli_command in spawn.sh) は
# "cursor-agent" / "cursor" / "claude" / "claude-safe" / "codex" を解釈する。
OE_TARGET_AI_CLI="${OE_TARGET_AI_CLI:-cursor-agent}"
OE_TARGET_AI_MODEL="${OE_TARGET_AI_MODEL:-composer-2}"
OE_VERIFY_AI_CLI="${OE_VERIFY_AI_CLI:-claude}"
OE_VERIFY_AI_MODEL="${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}"

# Step 4-4 Phase C: reviewer 一時ファイル掃除用配列 (派生 Issue #93 前半)
# oe_verify_run_phase で reviewer ULID 生成時に append、oe_cleanup で対応する /tmp/oe-{rsid}-verify-* を削除
OE_VERIFY_REVIEWER_SESSION_IDS=()
