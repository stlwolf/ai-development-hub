#!/usr/bin/env bash
set -euo pipefail

# validate-board.sh — cockpit 統括 succession board（declared 層）の advisory 検証
#
# 使用例:
#   ./scripts/validate-board.sh path/to/board.md
#   ./scripts/validate-board.sh path/to/board.md --verbose
#   OE_BOARD_MAX_AGE_DAYS=14 ./scripts/validate-board.sh board.md   # 鮮度しきい値の上書き
#
# Exit codes:
#   0 = valid（すべての check を満たす）
#   1 = invalid（1件以上の WARN。board 構造/鮮度に問題）
#   2 = file not found / jq not found / usage エラー
#
# 位置づけ:
#   #238 succession board の schema（frontmatter + 必須 section）を強制する。board は
#   markdown なので、JSON を検証する validate-envelope.sh / validate-session-state.sh とは
#   入力形式が違う。exit code・VERBOSE・helper 構造の idiom は踏襲しつつ、検証対象は
#   (1) YAML frontmatter の必須キー存在 / (2) 鮮度 date が N 日以内 / (3) 必須 section 見出しの存在。
#   schema 定義の正本は docs/decisions/2026-07-10-decision-238-board-schema.md。
#
# advisory（warn・非ブロッキング）:
#   read-only/HG 姿勢 + #78 advisory-hook 前例に整合し、本 validator は何もブロックしない。
#   問題は WARN 行として stderr に出し、呼び出し側（人/cron）が対処を判断する。exit 1 は
#   「flag された」ことを programmatic に伝える信号であって、build/hook を落とすためのものではない。
#   fail-fast はせず、1回の実行で全 WARN を出す（board のどこが崩れているか一望できる）。
#
# jq の用途:
#   鮮度 date（YYYY-MM-DD）→ epoch 変換に jq の strptime|mktime を使う。BSD/GNU date の
#   パース差（-j -f vs -d）を避けられる可搬な方法。now は date +%s（両系可搬）。

VERBOSE=0
if [[ "${2:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

log() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[validate-board] $*" >&2
  fi
}

WARN_COUNT=0
warn() {
  echo "WARN: $*" >&2
  WARN_COUNT=$((WARN_COUNT + 1))
}

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is not installed" >&2
  exit 2
fi

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <board.md> [--verbose]" >&2
  exit 2
fi

if [[ ! -f "$TARGET" ]]; then
  echo "ERROR: file not found: $TARGET" >&2
  exit 2
fi

# 鮮度しきい値（日数）と now（テスト決定化用の epoch 上書き）。
# 既定 7 日は運用ヒューリスティック（証拠に基づく閾値ではない・運用でチューニング）。
MAX_AGE_DAYS="${OE_BOARD_MAX_AGE_DAYS:-7}"
NOW_EPOCH="${OE_BOARD_NOW_EPOCH:-$(date +%s)}"

# 非数値の env は算術比較前に弾く（set -u 下の cryptic な arithmetic エラーでなく、
# doc どおり exit 2 = 環境エラーで返す）。
if ! [[ "$MAX_AGE_DAYS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: OE_BOARD_MAX_AGE_DAYS must be a non-negative integer: $MAX_AGE_DAYS" >&2
  exit 2
fi
if ! [[ "$NOW_EPOCH" =~ ^[0-9]+$ ]]; then
  echo "ERROR: OE_BOARD_NOW_EPOCH must be a non-negative integer (epoch): $NOW_EPOCH" >&2
  exit 2
fi

# --- (1) YAML frontmatter 抽出 + 必須キー ---
log "checking YAML frontmatter block..."

# frontmatter = 1行目が '---' で、以降に閉じ '---' がある場合のみ block ありと判定する。
# block の有無（FM_PRESENT）と中身（FRONTMATTER・空でありうる）を区別する:
# 空 block（--- のみ）を valid 扱いしないため、block がある限りキー検査は走らせる。
FM_PRESENT=0
FRONTMATTER=""
if [[ "$(sed -n '1p' "$TARGET")" == "---" ]] \
  && sed -n '2,$p' "$TARGET" | grep -qxF -- '---'; then
  FM_PRESENT=1
  FRONTMATTER="$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$TARGET")"
else
  warn "YAML frontmatter block not found (1行目 '---' + 閉じ '---' が必要)"
fi

if [[ "$FM_PRESENT" -eq 1 ]]; then
  log "checking required frontmatter keys..."
  # 必須 frontmatter キー（存在のみを必須。値の形式は advisory では強制しない＝
  # 正当な variation の誤検知を避ける）。キー宣言の有無を見るため colon の直後は問わない。
  REQUIRED_KEYS=("鮮度" "現統括" "succession")
  for key in "${REQUIRED_KEYS[@]}"; do
    if ! printf '%s\n' "$FRONTMATTER" | grep -qE "^${key}:"; then
      warn "missing required frontmatter key: ${key}"
    fi
  done

  # --- (2) 鮮度 date が N 日以内か ---
  log "checking 鮮度 freshness (<= ${MAX_AGE_DAYS} days)..."
  # 鮮度 キーが宣言されている場合のみ値を検査する（キー欠落は REQUIRED_KEYS ループで WARN 済み・
  # ここで二重に出さない）。値が空なら date check を素通りさせず format 不正として WARN する。
  # 到達判定の grep は if 条件（set -e 抑止）。抽出側は { grep || true; } で pipefail 死を回避する。
  if printf '%s\n' "$FRONTMATTER" | grep -qE '^鮮度:'; then
    FRESH_RAW="$(printf '%s\n' "$FRONTMATTER" \
      | { grep -E '^鮮度:' || true; } | head -1 \
      | sed -E 's/^鮮度:[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')"
    if [[ -z "$FRESH_RAW" ]]; then
      warn "鮮度 has an empty value (must be YYYY-MM-DD)"
    elif [[ "$FRESH_RAW" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      BOARD_EPOCH="$(jq -n --arg d "$FRESH_RAW" '$d | strptime("%Y-%m-%d") | mktime' 2>/dev/null || true)"
      if [[ -z "$BOARD_EPOCH" ]]; then
        warn "鮮度 is not a parseable date: ${FRESH_RAW}"
      else
        AGE_DAYS=$(( (NOW_EPOCH - BOARD_EPOCH) / 86400 ))
        if [[ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ]]; then
          warn "board is stale: 鮮度=${FRESH_RAW} (${AGE_DAYS} days old > ${MAX_AGE_DAYS})"
        fi
      fi
    else
      warn "鮮度 must be YYYY-MM-DD, got: ${FRESH_RAW}"
    fi
  fi
fi

# --- (3) 必須 section 見出しの存在 ---
log "checking required section headings..."
# 現 board 準拠の H2 見出し。実見出しは接尾（括弧付き注記）を持つため部分一致で判定する。
REQUIRED_SECTIONS=("戦略" "in-flight" "repo / 環境 state" "統括規律" "succession 手順")
H2_LINES="$(grep -E '^##[[:space:]]' "$TARGET" || true)"
for section in "${REQUIRED_SECTIONS[@]}"; do
  if ! printf '%s\n' "$H2_LINES" | grep -qF -- "$section"; then
    warn "missing required section heading: ${section}"
  fi
done

# --- 結果 ---
if [[ "$WARN_COUNT" -eq 0 ]]; then
  echo "OK: $TARGET"
  exit 0
else
  echo "INVALID: $TARGET (${WARN_COUNT} issue(s); advisory)" >&2
  exit 1
fi
