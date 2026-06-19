#!/usr/bin/env bash
set -uo pipefail

# test_wez_layout.sh — wez layout apply/list の規約を検証する (#165)
#
# 単体テストハーネスは無いため、test_pane_split_targeting.sh と同型の mock shim 方式:
#   - PATH 先頭に mock `wezterm` を置く。
#       cli split-pane   → 引数を SPLIT_LOG に追記し、新 pane id を返す（インクリメント）。
#                          WEZ_TEST_FAIL_SPLIT_AT が「N 回目の split」を指すとき exit 1（失敗注入）。
#       cli kill-pane     → 引数を KILL_LOG に追記。
#       cli activate-pane → 引数を ACTIVATE_LOG に追記。
#       cli list          → 固定 fixture JSON（root の存在確認・window_id 解決用）。
#   - lib/common.sh + lib/pane.sh + lib/layout.sh を source し、対象関数を直接呼ぶ。
#     socket discovery (wez_cmd_layout) は対象外のため経由せず _wez_layout_apply / _wez_layout_list を呼ぶ。
#
# 前例: tests/test_pane_split_targeting.sh（PATH 差し替え wezterm + fixture JSON）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  printf 'SKIP: jq not installed; layout tests require jq\n' >&2
  exit 0
fi

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/pathbin" "$_TMP_DIR/logs"

SPLIT_LOG="$_TMP_DIR/logs/split-pane-args.log"
KILL_LOG="$_TMP_DIR/logs/kill-pane-args.log"
ACTIVATE_LOG="$_TMP_DIR/logs/activate-pane-args.log"
SPLIT_COUNT="$_TMP_DIR/logs/split-count"

# --- Fixtures: `wezterm cli list --format json` ---
# 既定: root=1（window 0, active）が存在する。別 window 5 の active pane 9 もある。
FIXTURE_DEFAULT="$_TMP_DIR/fixture-default.json"
cat > "$FIXTURE_DEFAULT" <<'JSON'
[
  {"window_id":0,"tab_id":0,"pane_id":0,"is_active":false,"tty_name":"/dev/ttys000"},
  {"window_id":0,"tab_id":0,"pane_id":1,"is_active":true,"tty_name":"/dev/ttys001"},
  {"window_id":5,"tab_id":2,"pane_id":9,"is_active":true,"tty_name":"/dev/ttys009"}
]
JSON

# 再現性 fixture: active pane が「別 window 5」側 (pane 9) でも root=self(=1) 起点で同一 split 列になること。
# root pane 1 は window 0・非 active だが list には存在する。
FIXTURE_ACTIVE_ELSEWHERE="$_TMP_DIR/fixture-active-elsewhere.json"
cat > "$FIXTURE_ACTIVE_ELSEWHERE" <<'JSON'
[
  {"window_id":0,"tab_id":0,"pane_id":1,"is_active":false,"tty_name":"/dev/ttys001"},
  {"window_id":5,"tab_id":2,"pane_id":9,"is_active":true,"tty_name":"/dev/ttys009"}
]
JSON

# window_id 解決失敗 fixture: root=1 は存在するが window_id が null。
# _wez_pane_exists は通るが _wez_layout_root_window は空を返す → JSON は window_id:null。
FIXTURE_NULL_WINDOW="$_TMP_DIR/fixture-null-window.json"
cat > "$FIXTURE_NULL_WINDOW" <<'JSON'
[
  {"window_id":null,"tab_id":0,"pane_id":1,"is_active":true,"tty_name":"/dev/ttys001"}
]
JSON

export WEZ_TEST_FIXTURE="$FIXTURE_DEFAULT"

# --- mock wezterm ---
cat > "$_TMP_DIR/pathbin/wezterm" <<EOF
#!/usr/bin/env bash
sub="\${2:-}"
if [[ "\${1:-}" == "cli" && "\$sub" == "split-pane" ]]; then
  shift 2
  # split 呼び出し回数をインクリメント
  n=0
  [[ -f "$SPLIT_COUNT" ]] && n=\$(cat "$SPLIT_COUNT")
  n=\$(( n + 1 ))
  printf '%s' "\$n" > "$SPLIT_COUNT"
  # 引数ログ（追記。区切りに ---SPLIT--- を入れる）
  printf -- '---SPLIT---\n' >> "$SPLIT_LOG"
  for a in "\$@"; do printf '%s\n' "\$a" >> "$SPLIT_LOG"; done
  # 失敗注入
  if [[ -n "\${WEZ_TEST_FAIL_SPLIT_AT:-}" && "\$n" -eq "\${WEZ_TEST_FAIL_SPLIT_AT}" ]]; then
    echo "mock wezterm: injected split failure at call \$n" >&2
    exit 1
  fi
  # 新 pane id: 100 + 呼び出し回数（root と衝突しない）
  printf '%s\n' "\$(( 100 + n ))"
  exit 0
fi
if [[ "\${1:-}" == "cli" && "\$sub" == "kill-pane" ]]; then
  shift 2
  printf -- '---KILL---\n' >> "$KILL_LOG"
  for a in "\$@"; do printf '%s\n' "\$a" >> "$KILL_LOG"; done
  # 失敗注入: WEZ_TEST_FAIL_KILL に列挙された pane-id の kill を失敗させる（空白区切り）。
  if [[ -n "\${WEZ_TEST_FAIL_KILL:-}" ]]; then
    prev=""
    for a in "\$@"; do
      if [[ "\$prev" == "--pane-id" ]]; then
        for fk in \${WEZ_TEST_FAIL_KILL}; do
          if [[ "\$a" == "\$fk" ]]; then
            echo "mock wezterm: injected kill failure for pane \$a" >&2
            exit 1
          fi
        done
      fi
      prev="\$a"
    done
  fi
  exit 0
fi
if [[ "\${1:-}" == "cli" && "\$sub" == "activate-pane" ]]; then
  shift 2
  printf -- '---ACTIVATE---\n' >> "$ACTIVATE_LOG"
  for a in "\$@"; do printf '%s\n' "\$a" >> "$ACTIVATE_LOG"; done
  exit 0
fi
if [[ "\${1:-}" == "cli" && "\$sub" == "list" ]]; then
  cat "\${WEZ_TEST_FIXTURE:-$FIXTURE_DEFAULT}"
  exit 0
fi
echo "mock wezterm: unexpected args: \$*" >&2
exit 1
EOF
chmod +x "$_TMP_DIR/pathbin/wezterm"

export PATH="$_TMP_DIR/pathbin:$PATH"

# shellcheck source=../lib/common.sh
source "$PROJECT_DIR/lib/common.sh"
# shellcheck source=../lib/discover.sh
source "$PROJECT_DIR/lib/discover.sh"
# shellcheck source=../lib/pane.sh
source "$PROJECT_DIR/lib/pane.sh"
# shellcheck source=../lib/layout.sh
source "$PROJECT_DIR/lib/layout.sh"

# layout はプリインストールの preset を lib/layouts/ から読む。テストでは独自 preset を
# 使いたいので、_wez_layout_presets_dir を一時ディレクトリに差し替える。
_LAYOUT_PRESET_DIR="$_TMP_DIR/layouts"
mkdir -p "$_LAYOUT_PRESET_DIR"
_wez_layout_presets_dir() { printf '%s\n' "$_LAYOUT_PRESET_DIR"; }

# 正常 preset: 親1 + 子2（bottom 30, right 50）, focus root
cat > "$_LAYOUT_PRESET_DIR/parent-children.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "root", "dir": "bottom", "percent": 30},
    {"id": "worker2", "from": "root", "dir": "right", "percent": 50}
  ],
  "focus": "root"
}
JSON

# focus を step id に向ける preset
cat > "$_LAYOUT_PRESET_DIR/focus-worker.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "root", "dir": "bottom", "percent": 30}
  ],
  "focus": "worker1"
}
JSON

# schema 不正: dir が不正値
cat > "$_LAYOUT_PRESET_DIR/bad-dir.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "root", "dir": "diagonal", "percent": 30}
  ],
  "focus": "root"
}
JSON

# schema 不正: percent 範囲外
cat > "$_LAYOUT_PRESET_DIR/bad-percent.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "root", "dir": "bottom", "percent": 0}
  ],
  "focus": "root"
}
JSON

# schema 不正: from が root 以外（PoC 制約違反）
cat > "$_LAYOUT_PRESET_DIR/bad-from.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "worker0", "dir": "bottom", "percent": 30}
  ],
  "focus": "root"
}
JSON

# schema 不正: percent が小数（W2: 整数制約）
cat > "$_LAYOUT_PRESET_DIR/decimal-percent.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "root", "dir": "bottom", "percent": 30.5}
  ],
  "focus": "root"
}
JSON

# schema 不正: step id が全桁数値（W3: focus の numeric=リテラル pane-id と衝突）
cat > "$_LAYOUT_PRESET_DIR/numeric-id.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "101", "from": "root", "dir": "bottom", "percent": 30}
  ],
  "focus": "root"
}
JSON

# focus 不正: preset の focus が未知の step id（C3: split 前に 64 で弾く）
cat > "$_LAYOUT_PRESET_DIR/bad-focus.json" <<'JSON'
{
  "version": 1,
  "root": "self",
  "steps": [
    {"id": "worker1", "from": "root", "dir": "bottom", "percent": 30}
  ],
  "focus": "nonexistent"
}
JSON

# --- 実 Unix domain socket（wez_cmd_layout の discovery 経路テスト用） ---
# discover.sh の `[[ -S "$socket" ]]` を満たす本物の socket ファイルを作る。
# 接続検証 (wez_verify_connection) は mock `wezterm cli list` が応答するため通る。
TEST_SOCKET="$_TMP_DIR/gui-sock-test"
python3 - "$TEST_SOCKET" <<'PY'
import socket, sys
p = sys.argv[1]
s = socket.socket(socket.AF_UNIX)
s.bind(p)
s.close()
PY

# --- Test harness ---
PASS=0
FAIL=0
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
ok()   { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }

# expect_rc <expected> <actual> <name>
expect_rc() {
  if [[ "$2" -eq "$1" ]]; then
    ok "$3"
  else
    fail "$3 (expected exit $1, got $2)"
  fi
}

reset_logs() {
  rm -f "$SPLIT_LOG" "$KILL_LOG" "$ACTIVATE_LOG" "$SPLIT_COUNT"
}

# SPLIT_LOG を「(dir,percent,pane-id) のシーケンス」として正規化して表示する。
# 各 split ブロックから --pane-id / 方向 / --percent を抽出し "dir:percent:paneid" を1行に。
split_sequence() {
  [[ -f "$SPLIT_LOG" ]] || return 0
  awk '
    /^---SPLIT---$/ { if (have) emit(); have=1; dir=""; pct=""; pid=""; next }
    /^--(bottom|right|left|top)$/ { sub(/^--/,"",$0); dir=$0; next }
    /^--percent$/ { getline; pct=$0; next }
    /^--pane-id$/ { getline; pid=$0; next }
    END { if (have) emit() }
    function emit() { printf "%s:%s:%s\n", dir, pct, pid }
  ' "$SPLIT_LOG"
}

# KILL_LOG の --pane-id 値を出現順に返す
kill_sequence() {
  [[ -f "$KILL_LOG" ]] || return 0
  awk '/^--pane-id$/{getline; print}' "$KILL_LOG"
}

# ACTIVATE_LOG の最後の --pane-id 値を返す
last_activate_pane() {
  [[ -f "$ACTIVATE_LOG" ]] || return 0
  awk '/^--pane-id$/{v=$0; getline; v=$0} END{print v}' "$ACTIVATE_LOG"
}

# ============================================================
# 1) apply: preset 通りの split 引数列
# ============================================================
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
seq="$(split_sequence)"
expected=$'bottom:30:1\nright:50:1'
if [[ "$rc" -eq 0 && "$seq" == "$expected" ]]; then
  ok "apply: emits preset split sequence with explicit --pane-id ROOT"
else
  fail "apply: split sequence mismatch (rc=$rc)
expected:
$expected
got:
$seq"
fi

# ============================================================
# 2) 再現性: active pane が別 window でも root=self 起点で同一 split 列
# ============================================================
reset_logs
export WEZ_TEST_FIXTURE="$FIXTURE_ACTIVE_ELSEWHERE"
export WEZTERM_PANE="1"
_wez_layout_apply parent-children >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
export WEZ_TEST_FIXTURE="$FIXTURE_DEFAULT"
seq="$(split_sequence)"
if [[ "$rc" -eq 0 && "$seq" == "$expected" ]]; then
  ok "reproducibility: same split sequence even when active pane is in another window"
else
  fail "reproducibility: expected same sequence (rc=$rc got=$seq)"
fi

# ============================================================
# 3) --json: {status:ok, root_pane_id, window_id, panes:[{id,pane_id,index}]}
# ============================================================
reset_logs
export WEZTERM_PANE="1"
json=$(_wez_layout_apply parent-children --json 2>/dev/null); rc=$?
unset WEZTERM_PANE
if [[ "$rc" -eq 0 ]] && \
   jq -e '.status == "ok"' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.root_pane_id == 1' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.window_id == 0' <<< "$json" >/dev/null 2>&1 && \
   jq -e '(.panes | length) == 2' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.panes[0] == {"id":"worker1","pane_id":101,"index":0}' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.panes[1] == {"id":"worker2","pane_id":102,"index":1}' <<< "$json" >/dev/null 2>&1; then
  ok "json: ok-status map with root_pane_id/window_id/panes"
else
  fail "json: unexpected map (rc=$rc json=$json)"
fi

# ============================================================
# 4) 部分失敗: 2番目 split 失敗 → 逆順 kill + exit 5 + partial JSON
# ============================================================
reset_logs
export WEZTERM_PANE="1"
export WEZ_TEST_FAIL_SPLIT_AT=2
json=$(_wez_layout_apply parent-children --json 2>/dev/null); rc=$?
unset WEZ_TEST_FAIL_SPLIT_AT
unset WEZTERM_PANE
killed="$(kill_sequence)"
# 1番目 split 成功 (pane 101) → 2番目失敗 → rollback で 101 を kill。
if [[ "$rc" -eq 5 && "$killed" == "101" ]] && \
   jq -e '.status == "partial"' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.failed_step == 1' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.root_pane_id == 1' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.created == [101]' <<< "$json" >/dev/null 2>&1; then
  ok "partial: 2nd split fails → reverse kill + exit 5 + partial JSON"
else
  fail "partial: expected exit5/kill 101/partial JSON (rc=$rc killed='$killed' json=$json)"
fi

# 4b) 失敗注入で harness（apply）が落ちる（非ゼロ終了）ことを確認
reset_logs
export WEZTERM_PANE="1"
export WEZ_TEST_FAIL_SPLIT_AT=1
_wez_layout_apply parent-children >/dev/null 2>&1; rc=$?
unset WEZ_TEST_FAIL_SPLIT_AT
unset WEZTERM_PANE
killed="$(kill_sequence)"
# 1番目で失敗 → created 0 件 → kill 無し → exit 5
if [[ "$rc" -eq 5 && -z "$killed" ]]; then
  ok "partial: 1st split fails → no created panes, no kill, exit 5"
else
  fail "partial(first): expected exit5/no-kill (rc=$rc killed='$killed')"
fi

# ============================================================
# 5) 非冪等: 2 回 apply で split が倍発行される
# ============================================================
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children >/dev/null 2>&1
_wez_layout_apply parent-children >/dev/null 2>&1
unset WEZTERM_PANE
n_splits="$(split_sequence | wc -l | tr -d '[:space:]')"
if [[ "$n_splits" -eq 4 ]]; then
  ok "non-idempotent: two applies issue 4 splits (2x)"
else
  fail "non-idempotent: expected 4 splits got $n_splits"
fi

# ============================================================
# 6) focus 復帰: 既定 root / --focus 上書き / preset focus=step
# ============================================================
# 6a) 既定 root へ activate
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children >/dev/null 2>&1
unset WEZTERM_PANE
if [[ "$(last_activate_pane)" == "1" ]]; then
  ok "focus: default restores focus to root"
else
  fail "focus: expected activate root(1) got '$(last_activate_pane)'"
fi

# 6b) --focus <step-id> が created pane に解決される
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children --focus worker2 >/dev/null 2>&1
unset WEZTERM_PANE
# worker2 は 2番目 split = pane 102
if [[ "$(last_activate_pane)" == "102" ]]; then
  ok "focus: --focus <step-id> resolves to created pane"
else
  fail "focus: expected activate worker2(102) got '$(last_activate_pane)'"
fi

# 6c) preset focus=step-id（--focus 無し）が created pane に解決される
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply focus-worker >/dev/null 2>&1
unset WEZTERM_PANE
# focus-worker preset: focus=worker1（1番目 split = pane 101）
if [[ "$(last_activate_pane)" == "101" ]]; then
  ok "focus: preset focus=step resolves to created pane"
else
  fail "focus: expected activate worker1(101) got '$(last_activate_pane)'"
fi

# 6d) --focus <numeric pane id> がそのまま使われる
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children --focus 999 >/dev/null 2>&1
unset WEZTERM_PANE
if [[ "$(last_activate_pane)" == "999" ]]; then
  ok "focus: --focus <numeric> used as literal pane id"
else
  fail "focus: expected activate 999 got '$(last_activate_pane)'"
fi

# ============================================================
# 7) 異常系: preset 不在 / schema 不正 / root 不在 / 未知オプション
# ============================================================
# 7a) preset 不在 → exit 1
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply does-not-exist >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 1 "$rc" "error: missing preset → exit 1"

# 7b) schema 不正（bad dir）→ exit 64
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply bad-dir >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "error: invalid dir schema → exit 64"

# 7c) schema 不正（bad percent）→ exit 64
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply bad-percent >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "error: percent out of range → exit 64"

# 7d) schema 不正（from != root）→ exit 64
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply bad-from >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "error: from!=root → exit 64"

# 7e) root 不在（WEZTERM_PANE 未設定）→ exit 3
reset_logs
unset WEZTERM_PANE
_wez_layout_apply parent-children >/dev/null 2>&1; rc=$?
expect_rc 3 "$rc" "error: no WEZTERM_PANE → exit 3"

# 7f) root 数値だが stale（list に不在）→ exit 3
reset_logs
export WEZTERM_PANE="777"
_wez_layout_apply parent-children >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 3 "$rc" "error: stale WEZTERM_PANE → exit 3"

# 7g) 未知オプション → exit 64
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children --bogus >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "error: unknown option → exit 64"

# 7h) 引数過多 → exit 64
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children extra >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "error: too many args → exit 64"

# 7i) preset 名なし → exit 64
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "error: missing preset name → exit 64"

# ============================================================
# 8) list
# ============================================================
list_out="$(_wez_layout_list 2>/dev/null)"; rc=$?
if [[ "$rc" -eq 0 ]] && grep -qx "parent-children" <<< "$list_out" && grep -qx "focus-worker" <<< "$list_out"; then
  ok "list: lists preset names"
else
  fail "list: expected preset names (rc=$rc out=$list_out)"
fi

# list 未知オプション → 64
_wez_layout_list --bogus >/dev/null 2>&1; rc=$?
expect_rc 64 "$rc" "list: unknown option → exit 64"

# ============================================================
# 9) --help
# ============================================================
help_out="$(_wez_layout_apply --help 2>/dev/null)"; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q "Usage: wez layout apply" <<< "$help_out" && grep -qi "NON-IDEMPOTENT" <<< "$help_out"; then
  ok "help: apply --help shows usage + non-idempotent note"
else
  fail "help: apply --help missing usage/non-idempotent (rc=$rc)"
fi

dispatch_help="$(_wez_layout_help 2>/dev/null)"; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q "Usage: wez layout" <<< "$dispatch_help"; then
  ok "help: dispatcher help shows usage"
else
  fail "help: dispatcher help missing usage (rc=$rc)"
fi

# ============================================================
# 10) schema/引数/focus エッジ（_wez_layout_apply 直叩き）
# ============================================================
# 10a) path traversal: preset 名に '../' → split せず 64（C2）
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply "../bad-dir" >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
seq="$(split_sequence)"
if [[ "$rc" -eq 64 && -z "$seq" ]]; then
  ok "security: path traversal preset name (../) → exit 64, no split (C2)"
else
  fail "security: expected 64/no-split for ../ (rc=$rc seq='$seq')"
fi

# 10b) path traversal: preset 名に '/' → 64
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply "sub/preset" >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "security: preset name with '/' → exit 64 (C2)"

# 10c) decimal percent → schema 段階で 64（W2、rollback 5 ではない）
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply decimal-percent >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
seq="$(split_sequence)"
if [[ "$rc" -eq 64 && -z "$seq" ]]; then
  ok "schema: decimal percent → exit 64 at schema stage, no split (W2)"
else
  fail "schema: expected 64/no-split for decimal percent (rc=$rc seq='$seq')"
fi

# 10d) numeric step id → schema 段階で 64（W3）
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply numeric-id >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
expect_rc 64 "$rc" "schema: numeric step id → exit 64 (W3)"

# 10e) 不正 --focus（未知 step id）→ split せず 64（C3）
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children --focus bogus >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
seq="$(split_sequence)"
if [[ "$rc" -eq 64 && -z "$seq" ]]; then
  ok "focus: invalid --focus step id → exit 64 before any split (C3)"
else
  fail "focus: expected 64/no-split for invalid --focus (rc=$rc seq='$seq')"
fi

# 10f) preset の focus が不正 step id → split せず 64（C3）
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply bad-focus >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
seq="$(split_sequence)"
if [[ "$rc" -eq 64 && -z "$seq" ]]; then
  ok "focus: invalid preset focus → exit 64 before any split (C3)"
else
  fail "focus: expected 64/no-split for invalid preset focus (rc=$rc seq='$seq')"
fi

# 10g) numeric --focus は step id 照合より先にリテラル pane id として使われる（W3）
#   注: schema が numeric step id を禁止するので衝突は起き得ないが、
#   numeric spec がリテラルとして解決されることを明示的に確認する。
reset_logs
export WEZTERM_PANE="1"
_wez_layout_apply parent-children --focus 555 >/dev/null 2>&1
unset WEZTERM_PANE
if [[ "$(last_activate_pane)" == "555" ]]; then
  ok "focus: numeric --focus resolved as literal pane id (W3)"
else
  fail "focus: expected activate 555 got '$(last_activate_pane)'"
fi

# 10h) rollback の kill 失敗が partial JSON の rollback_failed に反映される（W4）
reset_logs
export WEZTERM_PANE="1"
export WEZ_TEST_FAIL_SPLIT_AT=2   # 2番目 split 失敗 → pane 101 を rollback
export WEZ_TEST_FAIL_KILL="101"   # その kill を失敗させる
json=$(_wez_layout_apply parent-children --json 2>/dev/null); rc=$?
unset WEZ_TEST_FAIL_SPLIT_AT WEZ_TEST_FAIL_KILL WEZTERM_PANE
if [[ "$rc" -eq 5 ]] && \
   jq -e '.status == "partial"' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.created == [101]' <<< "$json" >/dev/null 2>&1 && \
   jq -e '.rollback_failed == [101]' <<< "$json" >/dev/null 2>&1; then
  ok "rollback: failed kill reflected in partial JSON rollback_failed (W4)"
else
  fail "rollback: expected exit5/rollback_failed=[101] (rc=$rc json=$json)"
fi

# 10i) rollback の kill 成功時は rollback_failed が空配列（W4 回帰）
reset_logs
export WEZTERM_PANE="1"
export WEZ_TEST_FAIL_SPLIT_AT=2
json=$(_wez_layout_apply parent-children --json 2>/dev/null); rc=$?
unset WEZ_TEST_FAIL_SPLIT_AT WEZTERM_PANE
if [[ "$rc" -eq 5 ]] && jq -e '.rollback_failed == []' <<< "$json" >/dev/null 2>&1; then
  ok "rollback: successful kill → rollback_failed is empty (W4)"
else
  fail "rollback: expected empty rollback_failed (rc=$rc json=$json)"
fi

# 10j) window_id 解決失敗 → JSON は window_id:null
reset_logs
export WEZ_TEST_FIXTURE="$FIXTURE_NULL_WINDOW"
export WEZTERM_PANE="1"
json=$(_wez_layout_apply parent-children --json 2>/dev/null); rc=$?
unset WEZTERM_PANE
export WEZ_TEST_FIXTURE="$FIXTURE_DEFAULT"
if [[ "$rc" -eq 0 ]] && jq -e '.window_id == null' <<< "$json" >/dev/null 2>&1; then
  ok "json: unresolved window_id → window_id:null"
else
  fail "json: expected window_id:null (rc=$rc json=$json)"
fi

# ============================================================
# 11) wez_cmd_layout 経由（socket 1回解決+export / list discovery前 / unknown / --socket 位置）
# ============================================================
# 11a) apply 経由: socket 解決 → WEZTERM_UNIX_SOCKET export → split 列
reset_logs
unset WEZTERM_UNIX_SOCKET
export WEZTERM_PANE="1"
wez_cmd_layout --socket "$TEST_SOCKET" apply parent-children >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
seq="$(split_sequence)"
if [[ "$rc" -eq 0 && "$seq" == "$expected" && "${WEZTERM_UNIX_SOCKET:-}" == "$TEST_SOCKET" ]]; then
  ok "cmd: apply via wez_cmd_layout resolves+exports socket and splits"
else
  fail "cmd: expected ok/exported-socket/split (rc=$rc sock='${WEZTERM_UNIX_SOCKET:-}' seq='$seq')"
fi
unset WEZTERM_UNIX_SOCKET

# 11b) list は discovery 前に処理される（bogus socket でも成功）
reset_logs
export WEZTERM_UNIX_SOCKET="/nonexistent/socket"
list_out="$(wez_cmd_layout list 2>/dev/null)"; rc=$?
unset WEZTERM_UNIX_SOCKET
if [[ "$rc" -eq 0 ]] && grep -qx "parent-children" <<< "$list_out"; then
  ok "cmd: list served before socket discovery (W5)"
else
  fail "cmd: expected list before discovery (rc=$rc out='$list_out')"
fi

# 11c) unknown subcommand → discovery 前に 64（socket 不在でも socket 系 exit にしない、W5）
reset_logs
export WEZTERM_UNIX_SOCKET="/nonexistent/socket"  # discovery が走れば 1 になる値
wez_cmd_layout bogus-subcommand >/dev/null 2>&1; rc=$?
unset WEZTERM_UNIX_SOCKET
expect_rc 64 "$rc" "cmd: unknown subcommand → exit 64 before discovery (W5)"

# 11d) --socket は subcommand より前でなければならない（後置は subcommand 扱い）
reset_logs
export WEZTERM_PANE="1"
wez_cmd_layout apply parent-children --socket "$TEST_SOCKET" >/dev/null 2>&1; rc=$?
unset WEZTERM_PANE
# apply の --socket は _wez_layout_apply にとって未知オプション → 64
expect_rc 64 "$rc" "cmd: --socket after subcommand is rejected (must precede)"

# 11e) unknown option（subcommand 前）→ 64
reset_logs
wez_cmd_layout --bogus-flag apply parent-children >/dev/null 2>&1; rc=$?
expect_rc 64 "$rc" "cmd: unknown option before subcommand → exit 64"

# ============================================================
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
