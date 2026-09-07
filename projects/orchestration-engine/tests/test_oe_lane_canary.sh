#!/usr/bin/env bash
# test_oe_lane_canary.sh — oe-lane-canary（#303 M-2・実験）の検証
#
# 固定する契約:
#   - **既定では実際に CLI を呼ばない。** OE_LANE_CANARY=1 のときだけ呼ぶ。
#   - 空で返ったレーンだけを対象にする（返っているレーンには投げない）。
#   - 分類は宣言した期待値どおり（成功 / 上限 / 認証切れ / 環境 / 不明）。
#   - **期待値は測る前に宣言してある**（verb のヘッダ）。ここではその宣言を固定する。
#
# **CLI はスタブに差し替える。** 実際の CLI を呼ぶと使用量を消費し、結果がその日の
# アカウントの状態に依存してテストにならない。**実機での確認は別に1回行い、episode に書く。**
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERB="$SCRIPT_DIR/../bin/oe-lane-canary"
[[ -x "$VERB" ]] || { echo "FAIL: verb not found: $VERB"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$_TMP"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

# 空で返ったレーンの出力ディレクトリを作る
mk_empty_lane() {
  local dir="$1" tool="$2" status="$3" ec="$4"
  mkdir -p "$dir"
  printf 'tool=%s\nattempt=1\nattempt_state=finished\ntimeout_limit_seconds=240\nexit_code=%s\ntimeout_status=%s\nelapsed_seconds=240\nstdout_bytes=0\n' \
    "$tool" "$ec" "$status" > "$dir/${tool}-meta.txt"
  : > "$dir/${tool}-stdout.txt"; : > "$dir/${tool}-stderr.txt"
}

val_of() { printf '%s' "$1" | sed -n "s/.*\"$2\":\"\\([^\"]*\\)\".*/\\1/p"; }

echo "[1] 既定では実際に呼ばない"
D="$_TMP/d1"; mk_empty_lane "$D" claude timeout_empty 124
OUT="$("$VERB" "$D" 2>&1)"; RC=$?
ck  "exit 0" "0" "$RC"
ckc "canary_ran=false" "$OUT" '"canary_ran":false'
ckc "何を投げるかを出す" "$OUT" 'would_run'
ckc "使用量を消費すると書く" "$OUT" '使用量を消費'

echo "[2] 返っているレーンには投げない"
D="$_TMP/d2"; mkdir -p "$D"
printf 'tool=codex\nattempt=1\nattempt_state=finished\nexit_code=0\ntimeout_status=success\nstdout_bytes=42\n' > "$D/codex-meta.txt"
printf 'VERDICT: survived\n' > "$D/codex-stdout.txt"; : > "$D/codex-stderr.txt"
OUT="$("$VERB" "$D" 2>&1)"; RC=$?
ck  "対象なし = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "空で返ったレーンが見つかりませんでした"

echo "[3] 宣言した期待値どおりに分類する（CLI はスタブ）"
STUB="$_TMP/stub"; mkdir -p "$STUB"
# 時間切れの本走行 → canary は成功する
printf '#!/bin/sh\necho 2\nexit 0\n' > "$STUB/claude-safe"; chmod +x "$STUB/claude-safe"
D="$_TMP/d3"; mk_empty_lane "$D" claude timeout_empty 124
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" "$D" 2>/dev/null)"
ck "時間切れ → canary success" "success" "$(val_of "$OUT" canary_state)"
ckc "canary を走らせた" "$OUT" '"canary_ran":true'

# 使用量上限（claude は stdout に出す）
printf '#!/bin/sh\nprintf "%%s\\n" "You'"'"'ve hit your session limit · resets 12:50am (Asia/Tokyo)"\nexit 1\n' > "$STUB/claude-safe"
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" "$D" 2>/dev/null)"
ck "claude の上限 → usage_limit" "usage_limit" "$(val_of "$OUT" canary_state)"
ck "証拠"                        "claude-stdout" "$(val_of "$OUT" canary_evidence)"

# 使用量上限（codex は stderr に出す）
printf '#!/bin/sh\nprintf "%%s\\n" "ERROR: You'"'"'ve hit your usage limit. Upgrade to Pro" >&2\nexit 1\n' > "$STUB/codex"; chmod +x "$STUB/codex"
D="$_TMP/d4"; mk_empty_lane "$D" codex timeout_empty 124
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" "$D" 2>/dev/null)"
ck "codex の上限 → usage_limit" "usage_limit" "$(val_of "$OUT" canary_state)"
ck "証拠"                       "codex-stderr" "$(val_of "$OUT" canary_evidence)"

# 認証切れ（cursor）
printf '#!/bin/sh\nprintf "%%s\\n" "Error: Authentication required. Please run '"'"'agent login'"'"' first" >&2\nexit 1\n' > "$STUB/agent"; chmod +x "$STUB/agent"
D="$_TMP/d5"; mk_empty_lane "$D" cursor timeout_empty 124
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" "$D" 2>/dev/null)"
ck "cursor の認証切れ → auth_required" "auth_required" "$(val_of "$OUT" canary_state)"

# 環境エラー（codex）
printf '#!/bin/sh\nprintf "%%s\\n" "Not inside a trusted directory and --skip-git-repo-check was not specified." >&2\nexit 1\n' > "$STUB/codex"
D="$_TMP/d6"; mk_empty_lane "$D" codex error 1
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" "$D" 2>/dev/null)"
ck "codex の環境エラー → environment" "environment" "$(val_of "$OUT" canary_state)"

# 文言が無い非ゼロ → 断定しない
printf '#!/bin/sh\nexit 1\n' > "$STUB/codex"
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" "$D" 2>/dev/null)"
ck "文言なしの非ゼロ → unknown" "unknown" "$(val_of "$OUT" canary_state)"
ck "証拠も none"                "none"    "$(val_of "$OUT" canary_evidence)"

echo "[4] 散文にエコーされた文言を拾わない（陰性対照）"
# oe-lane-explain と同じ罠。行頭でない文言は当てない。
printf '#!/bin/sh\nprintf "%%s\\n" "説明: 過去に ERROR: You'"'"'ve hit your usage limit が出た件について" >&2\nexit 1\n' > "$STUB/codex"
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" "$D" 2>/dev/null)"
ck "行の途中の文言は当てない" "unknown" "$(val_of "$OUT" canary_state)"

echo "[5] CLI が無ければ unavailable（黙って success にしない）"
# **verb が使う道具は残し、レーンの CLI だけを消した PATH を作る。** PATH を空にすると
# jq や grep まで消えて verb 自体が動かず、測りたいことを測れない。
COREBIN="$_TMP/corebin"; mkdir -p "$COREBIN"
for c in jq grep cut tail awk wc date mktemp timeout rm sed head tr env bash sh; do
  src="$(command -v "$c" 2>/dev/null)" || continue
  [[ -n "$src" ]] && ln -sf "$src" "$COREBIN/$c"
done
D="$_TMP/d7"; mk_empty_lane "$D" cursor timeout_empty 124
OUT="$(OE_LANE_CANARY=1 PATH="$COREBIN" "$VERB" "$D" 2>/dev/null)" || true
ckc "unavailable と書く" "$OUT" '"canary_state":"unavailable"'
ckc "どのコマンドが無いか書く" "$OUT" 'command not found: agent'

echo "[6] 呼び方の誤り"
"$VERB" >/dev/null 2>&1; ck "引数なし = exit 2" "2" "$?"
"$VERB" --bogus "$_TMP/d1" >/dev/null 2>&1; ck "不明オプション = exit 2" "2" "$?"
"$VERB" --lane bogus "$_TMP/d1" >/dev/null 2>&1; ck "不明レーン = exit 2" "2" "$?"
"$VERB" --timeout 0 "$_TMP/d1" >/dev/null 2>&1; ck "上限 0 = exit 2" "2" "$?"
"$VERB" --help >/dev/null 2>&1; ck "--help = exit 0" "0" "$?"

echo "[7] --lane で絞れる"
D="$_TMP/d8"; mk_empty_lane "$D" codex timeout_empty 124; mk_empty_lane "$D" cursor timeout_empty 124
OUT="$("$VERB" --lane codex "$D" 2>/dev/null)"
ck "1 行だけ出る" "1" "$(printf '%s\n' "$OUT" | grep -c '^{')"
ckc "codex の行"  "$OUT" '"lane":"codex"'

echo "[8] so-compare を触っていない"
if [[ -f "$SCRIPT_DIR/../../../scripts/so-compare.sh" ]]; then
  if grep -qF 'so-compare.sh' "$VERB"; then
    echo "  FAIL: verb が so-compare.sh に触れている"; FAIL=$((FAIL+1))
  else
    echo "  PASS: verb は so-compare.sh に触れていない"; PASS=$((PASS+1))
  fi
fi

echo "[9] canary 自身の時間切れを unknown に畳まない（実測で踏んだ形）"
# 上限を短く置くと canary 自身が落ちる。それは「証拠が無い」とは別の情報である。
printf '#!/bin/sh\nsleep 30\n' > "$STUB/agent"; chmod +x "$STUB/agent"
D="$_TMP/d9"; mk_empty_lane "$D" cursor timeout_empty 124
OUT="$(OE_LANE_CANARY=1 PATH="$STUB:$PATH" "$VERB" --timeout 2 "$D" 2>/dev/null)"
ck "canary が上限に達した" "canary_timeout" "$(val_of "$OUT" canary_state)"
ck "exit は 124"           "124"            "$(val_of "$OUT" canary_exit)"

echo "[10] 既定の上限は実測から決めてある"
DEF="$(grep -m1 '^CANARY_TIMEOUT=' "$VERB" | cut -d= -f2)"
if [[ -n "$DEF" ]] && (( DEF >= 40 )); then
  echo "  PASS: 既定は ${DEF} 秒（実測の最大 17 秒に対して余裕がある）"; PASS=$((PASS+1))
else
  echo "  FAIL: 既定が ${DEF} 秒。極小の1往復の実測は 9〜17 秒なので、ここに置くと偽陰性が出る"; FAIL=$((FAIL+1))
fi

echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
