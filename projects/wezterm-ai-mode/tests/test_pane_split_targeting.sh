#!/usr/bin/env bash
set -uo pipefail

# test_pane_split_targeting.sh — wez pane split の --target ターゲティング規約を検証する (#174)
#
# 単体テストハーネスは無いため (shellcheck + 手動 E2E 規約)、mock shim 方式を新設する:
#   - PATH 先頭に mock `wezterm` を置き、`wezterm cli split-pane` の引数を log に記録する。
#     `wezterm cli list` は固定 fixture JSON を返す (window_id / is_active / pane_id を含む)。
#   - lib/common.sh + lib/pane.sh を source し、対象関数 `_wez_pane_split` を直接呼ぶ。
#     socket discovery (wez_cmd_pane) は本テストの対象外のため経由しない。
#
# 前例:
#   - projects/orchestration-engine/tests/e2e_real_agent/bin/wez (PATH 先頭の shim)
#   - projects/orchestration-engine/tests/test_oe_select.sh:6-11 (export PATH で stub 分離)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/pathbin" "$_TMP_DIR/logs"

SPLIT_LOG="$_TMP_DIR/logs/split-pane-args.log"

# --- Fixtures: `wezterm cli list --format json` の出力 (実機例の構造) ---
# 既定 fixture (numeric pane_id):
#   window 0: pane 0 (active=false), pane 1 (active=true) ← parent-window で期待される基準ペイン
#   window 5: pane 9 (active=true) ← 別ウィンドウ。誤って選ばれないことの確認用
FIXTURE_DEFAULT="$_TMP_DIR/fixture-default.json"
cat > "$FIXTURE_DEFAULT" <<'JSON'
[
  {"window_id":0,"tab_id":0,"pane_id":0,"is_active":false,"tty_name":"/dev/ttys000"},
  {"window_id":0,"tab_id":0,"pane_id":1,"is_active":true,"tty_name":"/dev/ttys001"},
  {"window_id":5,"tab_id":2,"pane_id":9,"is_active":true,"tty_name":"/dev/ttys009"}
]
JSON

# 文字列型 fixture (R1): pane_id / window_id を JSON 文字列型にしても解決されること。
#   self=0 → window "0" の active pane = pane "1"
FIXTURE_STRING_IDS="$_TMP_DIR/fixture-string-ids.json"
cat > "$FIXTURE_STRING_IDS" <<'JSON'
[
  {"window_id":"0","tab_id":"0","pane_id":"0","is_active":false,"tty_name":"/dev/ttys000"},
  {"window_id":"0","tab_id":"0","pane_id":"1","is_active":true,"tty_name":"/dev/ttys001"},
  {"window_id":"5","tab_id":"2","pane_id":"9","is_active":true,"tty_name":"/dev/ttys009"}
]
JSON

# self 不在 (R1) は専用 fixture を要しない: 既定 fixture (pane 0/1/9) に対し
# self=7 を指定すれば self が list に不在となり window_id が引けない (null) →
# parent-window は失敗すべき。FIXTURE_DEFAULT をそのまま使う。

# どの fixture を `wezterm cli list` が返すかをテストごとに切り替える (既定は FIXTURE_DEFAULT)。
export WEZ_TEST_FIXTURE="$FIXTURE_DEFAULT"

# --- mock wezterm: split-pane は引数を log に記録し固定 pane id を返す。list は fixture を返す ---
cat > "$_TMP_DIR/pathbin/wezterm" <<EOF
#!/usr/bin/env bash
# \$1 == "cli", \$2 == subcommand
if [[ "\${1:-}" == "cli" && "\${2:-}" == "split-pane" ]]; then
  shift 2
  : > "$SPLIT_LOG"
  for a in "\$@"; do printf '%s\n' "\$a" >> "$SPLIT_LOG"; done
  printf '%s\n' "42"   # 新ペイン id (固定)
  exit 0
fi
if [[ "\${1:-}" == "cli" && "\${2:-}" == "list" ]]; then
  cat "\${WEZ_TEST_FIXTURE:-$FIXTURE_DEFAULT}"
  exit 0
fi
if [[ "\${1:-}" == "cli" && "\${2:-}" == "get-text" ]]; then
  # --wait-ready 用: 安定した非空出力を返す (stable tail で即 ready 判定)
  printf 'ready\n'
  exit 0
fi
echo "mock wezterm: unexpected args: \$*" >&2
exit 1
EOF
chmod +x "$_TMP_DIR/pathbin/wezterm"

export PATH="$_TMP_DIR/pathbin:$PATH"

# shellcheck source=../lib/common.sh
source "$PROJECT_DIR/lib/common.sh"
# shellcheck source=../lib/pane.sh
source "$PROJECT_DIR/lib/pane.sh"

# --- Test harness ---
PASS=0
FAIL=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}
ok() {
  printf 'ok: %s\n' "$1"
  PASS=$((PASS + 1))
}

# split log に記録された --pane-id の値を返す (無ければ空)
split_pane_id_from_log() {
  [[ -f "$SPLIT_LOG" ]] || return 0
  awk '/^--pane-id$/{getline; print; exit}' "$SPLIT_LOG"
}
reset_log() { rm -f "$SPLIT_LOG"; }

# 関数を呼んで exit code と (任意で) 期待 pane-id を検証する共通ルーチン。
# 引数: <name> <wezterm_pane|UNSET> <expected_exit> <expected_pane_id|SKIP> -- <split args...>
# WEZTERM_PANE はここで設定/解除する (subshell を使わず PASS/FAIL を親に反映させるため)。
run_case() {
  local name="$1" wpane="$2" exp_exit="$3" exp_pane="$4"
  shift 5   # name wpane exp_exit exp_pane "--"

  if [[ "$wpane" == "UNSET" ]]; then
    unset WEZTERM_PANE
  else
    export WEZTERM_PANE="$wpane"
  fi

  reset_log
  local out rc
  out=$(_wez_pane_split "$@" 2>/dev/null); rc=$?
  unset WEZTERM_PANE

  if [[ "$rc" -ne "$exp_exit" ]]; then
    fail "$name: exit code expected=$exp_exit got=$rc (stdout=$out)"
    return
  fi
  if [[ "$exp_pane" != "SKIP" ]]; then
    local got; got="$(split_pane_id_from_log)"
    if [[ "$got" != "$exp_pane" ]]; then
      fail "$name: --pane-id expected='$exp_pane' got='$got'"
      return
    fi
  fi
  ok "$name"
}

# run_case <name> <WEZTERM_PANE|UNSET> <expected_exit> <expected_pane_id|SKIP> -- <args...>

# ============================================================
# 1) --target 引数パース
# ============================================================

# 不正値 → usage error (64)
run_case "parse: invalid --target value" UNSET 64 SKIP -- --target bogus

# --target に値なし → usage error
run_case "parse: --target without value" UNSET 64 SKIP -- --target

# --target explicit で --pane-id 欠落 → usage error
run_case "parse: --target explicit without --pane-id" UNSET 64 SKIP -- --target explicit

# ============================================================
# 2) self 解決
# ============================================================

# WEZTERM_PANE セット時に --target self → その id が --pane-id として渡る
# (R2: 明示 self は実在確認するため、fixture に存在する pane 1 を使う)
run_case "self: WEZTERM_PANE resolves to --pane-id" 1 0 1 -- --target self

# 省略 (--target/--pane-id なし) + WEZTERM_PANE セット → self を試行し id が渡る (後方互換: 既存挙動同等)
run_case "default: omitted resolves to self via WEZTERM_PANE" 3 0 3 -- --bottom --percent 30

# 省略 + WEZTERM_PANE 未セット → active-pane フォールバック (--pane-id 渡さない) + warn。exit 0
run_case "default: omitted + no WEZTERM_PANE falls back to active pane" UNSET 0 "" -- --bottom --percent 30

# 省略時フォールバックで warn が出ることを確認
reset_log
unset WEZTERM_PANE
warn_out=$(_wez_pane_split --bottom --percent 30 2>&1 >/dev/null)
if [[ "$warn_out" == *"WARNING"* && "$warn_out" == *"native default"* ]]; then
  ok "default: fallback emits warning"
else
  fail "default: fallback warning missing (got: $warn_out)"
fi

# M1: B3 default + 非数値 WEZTERM_PANE → fallback (--pane-id 省略) + warn。
# warn 文言が「active pane」を断定せず native 既定 (WEZTERM_PANE→active pane) と
# 表現することを確認する (WezTerm native は --pane-id 省略時 WEZTERM_PANE を使い、
# 未設定時のみ active pane にフォールバックする — 公式仕様)。
reset_log
export WEZTERM_PANE="not-a-number"
m1_out=$(_wez_pane_split --bottom --percent 30 2>&1 >/dev/null)
m1_rc=$?
unset WEZTERM_PANE
m1_pane="$(split_pane_id_from_log)"
if [[ "$m1_rc" -eq 0 && -z "$m1_pane" \
  && "$m1_out" == *"WARNING"* \
  && "$m1_out" == *"WEZTERM_PANE if set, else active pane"* ]]; then
  ok "M1: non-numeric WEZTERM_PANE falls back to native default with accurate warn"
else
  fail "M1: expected fallback (rc=0,no --pane-id) + native-default warn (rc=$m1_rc pane='$m1_pane' out=$m1_out)"
fi

# ============================================================
# 3) parent-window 解決
# ============================================================

# self=0 → window 0 の active pane = pane 1 が --pane-id として渡る
run_case "parent-window: resolves active pane in self's window" 0 0 1 -- --target parent-window

# self=1 (それ自身 active) → 同 window の active pane = 1
run_case "parent-window: self already active" 1 0 1 -- --target parent-window

# R1: pane_id / window_id が JSON 文字列型でも active pane が解決される (tostring 比較)
WEZ_TEST_FIXTURE="$FIXTURE_STRING_IDS"
run_case "parent-window: string-typed ids still resolve active pane" 0 0 1 -- --target parent-window
WEZ_TEST_FIXTURE="$FIXTURE_DEFAULT"

# R1: self が list に不在 (self=7 は fixture の 0/1/9 に無い → window_id を引けない=null)
# → parent-window は失敗。明示 --target parent-window なので解決不能はエラー (exit 3)。
# 誤って null window の pane を採用しないことを確認する (既定 fixture を使用)。
run_case "parent-window: self absent from list fails (no null-window pane)" 7 3 SKIP -- --target parent-window

# ============================================================
# 4) 明示 self / parent-window で解決不能 → エラー終了 (フォールバックしない)
# ============================================================

# 明示 --target self で WEZTERM_PANE 未セット → PANE_NOT_FOUND (3)
run_case "self: explicit unresolved is an error (no fallback)" UNSET 3 SKIP -- --target self

# R2: 明示 --target self で WEZTERM_PANE は数値だが list に不在 (stale) → PANE_NOT_FOUND (3)。
# pane 7 は既定 fixture (0/1/9) に存在しない。split 失敗 (OP_FAILED=5) ではなく実在確認で 3。
run_case "self: explicit numeric but stale pane is NOT_FOUND" 7 3 SKIP -- --target self

# 明示 --target parent-window で WEZTERM_PANE 未セット → PANE_NOT_FOUND (3)
run_case "parent-window: explicit unresolved is an error" UNSET 3 SKIP -- --target parent-window

# ============================================================
# 5) explicit / 後方互換 (--pane-id)
# ============================================================

# 既存 --pane-id N が従来どおり渡る (後方互換)
run_case "compat: bare --pane-id passes through" UNSET 0 12 -- --pane-id 12

# --target explicit + --pane-id N → その id が渡る
run_case "explicit: --target explicit + --pane-id" UNSET 0 8 -- --target explicit --pane-id 8

# 明示 --pane-id は self より優先 (priority: explicit > self)
run_case "priority: --pane-id wins over WEZTERM_PANE/self" 99 0 4 -- --pane-id 4

# orchestration-engine spawn.sh / self_verify_attach.sh の呼び出し型 (--pane-id/--target なし) が壊れないこと
# WEZTERM_PANE 未セット環境 (CI 的) → フォールバックで exit 0、pane-id 無し
run_case "compat: engine spawn-style omitted call" UNSET 0 "" -- --bottom --percent 30 --wait-ready --timeout 10

# ============================================================
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
