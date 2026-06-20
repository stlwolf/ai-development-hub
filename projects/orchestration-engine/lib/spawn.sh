# shellcheck shell=bash
# shellcheck disable=SC2034
# spawn.sh — ペイン生成 + セッション開始（source 専用）

# グローバル変数: oe_spawn() の戻り値
OE_SPAWN_PANE_ID=""

# #175: 盤面（wez layout apply）由来のペイン pool（step 順）と消費カーソル。
# oe_board_apply が積み、oe_spawn_prepare_pane が FIFO で pop する。
# 空（board 無効 / apply 失敗 / 使い切り）のときは従来の都度 split にフォールバックする。
OE_BOARD_PANE_IDS=()
OE_BOARD_CURSOR=0

# oe_board_apply — #175: 機械1サイクルの盤面を wez layout で宣言的に構築する（盤面初期化の責務）。
#
# `wez layout apply "$OE_BOARD_LAYOUT" --json` を **1 回だけ** 呼び、返る pane_id map から
# `panes[].pane_id` を step 順で OE_BOARD_PANE_IDS（pool）へ積む。以降の都度 spawn
# (oe_spawn_prepare_pane) はこの pool から pop する（= 盤面初期化と都度 spawn の責務分離）。
#
# 設計（discussions/2026-06-20-discussion-175-spawn-layout.md・oe-refute 2 回反映）:
#   - 非冪等な layout を二重 apply しないよう bin/oe で 1 回だけ呼ぶ前提。
#   - 全 board ペインを OE_BOARD_MANAGED_PANES に登録し cleanup で回収する（消費済み／未消費を問わず
#     orphan を残さない。cleanup は 3 配列を dedup union して kill）。
#   - max-panes ガード: board ペイン数が OE_CB_MAX_PANES を超えると CB 不変条件を board pre-create が
#     迂回するため、pool には積まず（fallback split に倒す）回収登録のみ行う。
#   - 失敗時はすべて「board 無し」に静かに劣化（pool 空 → 従来 split）。後方互換のため engine は止めない。
#     status=="partial" は生存 orphan（rollback_failed のみ。created は layout が逆順 kill 済）を回収登録。
oe_board_apply() {
  OE_BOARD_PANE_IDS=()
  OE_BOARD_CURSOR=0

  # board 無効（kill switch）: 従来の都度 split のみ。
  if [[ -z "${OE_BOARD_LAYOUT:-}" ]]; then
    return 0
  fi

  local map rc=0
  map="$(wez layout apply "$OE_BOARD_LAYOUT" --json 2>/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 || -z "$map" ]]; then
    echo "oe_board_apply: wez layout apply '${OE_BOARD_LAYOUT}' failed (rc=${rc}); falling back to on-demand split" >&2
    return 0
  fi

  local status
  status="$(printf '%s' "$map" | jq -r '.status // "unknown"' 2>/dev/null || echo unknown)"

  # partial: layout は created を逆順 rollback kill 済。生存 orphan は rollback_failed のみ。
  if [[ "$status" == "partial" ]]; then
    local rf_str rf
    rf_str="$(printf '%s' "$map" | jq -r '.rollback_failed[]?' 2>/dev/null || true)"
    while IFS= read -r rf; do
      [[ -n "$rf" ]] || continue
      OE_BOARD_MANAGED_PANES+=("$rf")
    done <<< "$rf_str"
    echo "oe_board_apply: board '${OE_BOARD_LAYOUT}' apply partial; registered rollback_failed orphans for cleanup, falling back to split" >&2
    return 0
  fi

  if [[ "$status" != "ok" ]]; then
    echo "oe_board_apply: board '${OE_BOARD_LAYOUT}' returned status='${status}'; falling back to split" >&2
    return 0
  fi

  # status==ok: pane_id を step 順で収集。
  local ids_str line
  ids_str="$(printf '%s' "$map" | jq -r '.panes[].pane_id' 2>/dev/null || true)"
  local pane_ids=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    pane_ids+=("$line")
  done <<< "$ids_str"

  local count="${#pane_ids[@]}"
  if [[ "$count" -eq 0 ]]; then
    echo "oe_board_apply: board '${OE_BOARD_LAYOUT}' returned no panes; falling back to split" >&2
    return 0
  fi

  local p
  # max-panes ガード: board pre-create が monitor の OE_CB_MAX_PANES 判定を迂回しないよう守る。
  if [[ "$count" -gt "$OE_CB_MAX_PANES" ]]; then
    for p in ${pane_ids[@]+"${pane_ids[@]}"}; do
      OE_BOARD_MANAGED_PANES+=("$p")
    done
    echo "oe_board_apply: board '${OE_BOARD_LAYOUT}' has ${count} panes > OE_CB_MAX_PANES=${OE_CB_MAX_PANES}; not using board (registered for cleanup, falling back to split)" >&2
    return 0
  fi

  # 通常: pool に積み、全 board ペインを cleanup 回収登録。
  for p in ${pane_ids[@]+"${pane_ids[@]}"}; do
    OE_BOARD_PANE_IDS+=("$p")
    OE_BOARD_MANAGED_PANES+=("$p")
  done
}

# oe_board_wait_ready — #175: pool から pop した board ペインの readiness を engine 側で保証する。
#
# layout apply 経路は内部 split に --wait-ready を渡さず（layout.sh）、standalone な readiness verb も
# 無いため、`wez pane capture` の出力が非空かつ安定（2 連続一致）になるまで待つ pane.sh:_wez_wait_pane_ready
# の最小ミラーを engine 側に持つ。timeout 時は warn + 続行（best-effort・split --wait-ready の挙動に整合）。
oe_board_wait_ready() {
  local pane_id="$1"
  local timeout="${2:-$OE_SPAWN_WAIT_READY_SEC}"
  local interval_ms=500
  local timeout_ms=$(( timeout * 1000 ))
  local elapsed_ms=0
  local prev_tail=""

  while (( elapsed_ms < timeout_ms )); do
    local curr
    curr="$(wez pane capture "$pane_id" --lines 5 2>/dev/null)" || true
    if [[ "$curr" == *[!$' \t\n']* ]]; then
      local curr_tail
      curr_tail="$(printf '%s' "$curr" | tail -n 5)"
      if [[ -n "$prev_tail" && "$curr_tail" == "$prev_tail" ]]; then
        return 0
      fi
      prev_tail="$curr_tail"
    fi
    sleep 0.5
    elapsed_ms=$(( elapsed_ms + interval_ms ))
  done

  echo "oe_board_wait_ready: pane ${pane_id} not ready within ${timeout}s; proceeding best-effort" >&2
  return 0
}

# oe_spawn_prepare_pane — ペインを用意し OE_SPAWN_PANE_ID に保存（都度 spawn の責務）。
#
# #175: board pool（oe_board_apply 済）に未消費ペインがあれば FIFO で pop（step 順）。
# pool が空（board 無効 / 使い切り / 動的 N>pool）のときは従来どおり都度 split にフォールバックする。
# どちらの経路でも OE_SPAWN_PANE_ID の意味（呼び出し側が消費する単一の pane_id）は変わらない。
oe_spawn_prepare_pane() {
  OE_SPAWN_PANE_ID=""

  if [[ "${OE_BOARD_CURSOR:-0}" -lt "${#OE_BOARD_PANE_IDS[@]}" ]]; then
    OE_SPAWN_PANE_ID="${OE_BOARD_PANE_IDS[$OE_BOARD_CURSOR]}"
    OE_BOARD_CURSOR=$(( OE_BOARD_CURSOR + 1 ))
    # layout 経路は --wait-ready を持たないため、送信前に engine 側で readiness を保証する。
    oe_board_wait_ready "$OE_SPAWN_PANE_ID"
    return 0
  fi

  # pool 空: 従来の都度 split（DJ-8 省略時デフォルトで self 起点・解決不能時は native 既定）。
  # --wait-ready: 新ペインが入力受付可能になるまで待機（tmux auto-attach 等のタイミング問題の緩和）。
  OE_SPAWN_PANE_ID="$(wez pane split --bottom --percent "$OE_SPAWN_PERCENT" --wait-ready --timeout "$OE_SPAWN_WAIT_READY_SEC")"
}

# _oe_spawn_build_cli_command — AI CLI ごとに正しい invocation を組み立てる
# (Step 4-4 Phase A #91 反映、Phase A Step 1 物理前提実機確認結果に従う)
#
# 引数:
#   ai_cli         "cursor-agent" | "cursor" | "claude" | "claude-safe" | "codex"
#   ai_model       モデル名 (例: "composer-2", "claude-sonnet-4-6")
#   envelope_path  envelope JSON のパス (target / verify 両用)
#   [workspace]    workspace ディレクトリ (cursor-agent --workspace 用、デフォルト = PROJECT_DIR)
#
# stdout に組み立てた CLI コマンド文字列を出力。未対応 CLI は exit 1。
#
# Phase A Step 1 で確認した invocation 仕様:
# - cursor-agent: --print --model <model> --workspace <path> --force '<prompt>'
# - claude: -p '<prompt>' --model <model> --add-dir <repo_root> --add-dir /tmp \
#           --output-format text --no-session-persistence --max-budget-usd 1.0
# - codex: スタブ (claude と同形式、本 Step では動作確認なし)
#
# 引数の値に関する前提 (caller 側で保証):
#   envelope_path / workspace / repo_root のいずれにも **single quote `'` を含まない**ことを前提に、
#   prompt を single quotes でラップして出力する。`'` が混入した場合、pane 内 shell が
#   組み立てたコマンドを parse できず silent な `verification_protocol_error`
#   (exit_without_verify_marker) に発展する可能性がある。
#   MVP では envelope_path は `/tmp/oe-${session_id}-envelope.json`、workspace / repo_root は
#   `cd ... && pwd` で得るリポジトリ作業ディレクトリのため、上記前提は自動的に満たされる。
#   将来 user 指定パスを受け取るパス (例: `bin/oe --task-file <path>` の検証 envelope 化等) を
#   足す場合は、本関数の caller でパス正常化 (or single quote escape) を行うこと。
#   [Copilot PR #97 review 反映、2026-05-18]
_oe_spawn_build_cli_command() {
  local ai_cli="$1"
  local ai_model="$2"
  local envelope_path="$3"
  local workspace="${4:-${PROJECT_DIR}}"

  local prompt="Read ${envelope_path} and execute the task"

  # repo_root は claude の --add-dir 用 (skill ファイル workspace 外アクセス)
  local repo_root
  repo_root="$(cd "${PROJECT_DIR}/../.." && pwd)"

  case "$ai_cli" in
    cursor-agent|cursor)
      printf "cursor-agent --print --model %s --workspace %s --force '%s'" \
        "$ai_model" "$workspace" "$prompt"
      ;;
    claude|claude-safe)
      # claude 直接 (wez pane の独立 pty で TTY 競合なし、Step 4-4 Phase A Step 1 F-7 確認)
      printf "claude -p '%s' --model %s --add-dir %s --add-dir /tmp --output-format text --no-session-persistence --max-budget-usd 1.0" \
        "$prompt" "$ai_model" "$repo_root"
      ;;
    codex)
      # Step 4-4 ではスタブ。動作確認は Step 4-5 以降で必要なら実施
      printf "codex -p '%s' --model %s -w %s" \
        "$prompt" "$ai_model" "$workspace"
      ;;
    *)
      echo "_oe_spawn_build_cli_command: unsupported ai_cli '${ai_cli}' (supported: cursor-agent, cursor, claude, claude-safe, codex)" >&2
      return 1
      ;;
  esac
}

# oe_spawn_send — 既存ペインに AI CLI コマンド + マーカー emit を送信
#
# 引数:
#   session_id, pane_id, envelope_path,
#   [ai_cli]    (デフォルト: ${OE_TARGET_AI_CLI:-cursor-agent})
#   [ai_model]  (デフォルト: ${OE_TARGET_AI_MODEL:-composer-2})
#   [workspace] (デフォルト: ${PROJECT_DIR})
#
# Step 4-4 Phase A 反映: ai_cli / ai_model の伝播 + ディスパッチャ経由化 (F-8)
oe_spawn_send() {
  local session_id="$1"
  local pane_id="$2"
  local envelope_path="$3"
  local ai_cli="${4:-${OE_TARGET_AI_CLI:-cursor-agent}}"
  local ai_model="${5:-${OE_TARGET_AI_MODEL:-composer-2}}"
  local workspace="${6:-${PROJECT_DIR}}"

  local base_cli_command
  base_cli_command="$(_oe_spawn_build_cli_command "$ai_cli" "$ai_model" "$envelope_path" "$workspace")"

  local cli_command
  cli_command="${base_cli_command} ; printf '\\n@@OE_EXIT:%d\\n' \$?"

  wez pane send "$pane_id" "$cli_command"

  # session_start の state は audit schema（failure-taxonomy）と整合するため null
  oe_audit_emit "session_start" "$session_id" "$pane_id" "" "{}"
}

# oe_spawn — 後方互換ラッパー（prepare → send）
#
# 引数: session_id, envelope_path,
#       [ai_cli]    (デフォルト: ${OE_TARGET_AI_CLI:-cursor-agent})
#       [ai_model]  (デフォルト: ${OE_TARGET_AI_MODEL:-composer-2})
# 戻り値: OE_SPAWN_PANE_ID にペイン ID を設定
#
# Step 4-4 Phase A 反映 (F-8): ai_model 引数追加 + oe_spawn_send への伝播
oe_spawn() {
  local session_id="$1"
  local envelope_path="$2"
  local ai_cli="${3:-${OE_TARGET_AI_CLI:-cursor-agent}}"
  local ai_model="${4:-${OE_TARGET_AI_MODEL:-composer-2}}"

  oe_spawn_prepare_pane
  oe_spawn_send "$session_id" "$OE_SPAWN_PANE_ID" "$envelope_path" "$ai_cli" "$ai_model"
}
