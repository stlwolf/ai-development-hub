#!/usr/bin/env bash
#
# oe-heartbeat-hook.sh — hook で書く拍動（#562 DJ-6）。Codex の PostModelRequest と UserPromptSubmit に配線する。
#
# Claude Code の statusLine（canonical/claude/statusline/statusline-oe-heartbeat.sh）が書くのと同じ形の sidecar
# （${OE_HEARTBEAT_DIR:-~/.claude/state/oe-heartbeat}/<session_id>.json）を、hook の標準入力と環境から書く。
# 読む側（oe-tree・oe-threads・oe-vitals・lib/heartbeat-resolve.sh）は変えない。
#
#   - session_id: 標準入力の .session_id（Codex の thread の ID）
#   - pane / server_pid: 環境の TMUX_PANE と $TMUX（statusLine の書き手と同じ導出）
#   - model: 標準入力の .model（文字列）を {id, display_name} の object に直す（読む側が .model.display_name を使う）
#   - context_pct: PostModelRequest の .token_usage（その要求の使用量・累積ではない）の total_tokens（文脈の中のトークン数。
#       Codex の TokenUsage::tokens_in_context_window と同じ。input_tokens は cached のぶんを含むので足し合わせない）を
#       model_context_window で割る。model_context_window は標準入力に無いので、.transcript_path の記録を末尾から
#       上限付き（OE_HB_TAIL_LINES・既定 200 行）に1行ずつ読んで token_count の値を取る（壊れた行は飛ばす）。
#       取れないとき・token_usage が null のとき（取り消し・失敗した要求）・UserPromptSubmit では、前の sidecar の値を
#       残す（無ければ 0）
#   - lease_id / generation: 環境の OE_LEASE_ID と OE_GENERATION（形が正しいときだけ）
#   - agent: "codex"（この hook は Codex にだけ配る。ほかのエージェントに配るなら OE_HB_AGENT で上書き）
#
# 標準出力には何も出さない（UserPromptSubmit の標準出力はモデルの文脈に足される）。exit は常に 0。
# 同期の hook は後続を待たせるので、記録の全件走査はせず tail の上限で短く終える。上限の時間は hooks.json の側で持つ
# （PostModelRequest は async と timeout 付きで配線する）。
# 失敗は診断ファイル（oe-receipt-diag.jsonl と同じ置き場の oe-heartbeat-diag.jsonl）に1行残す。
#
set -uo pipefail

payload="$(cat 2>/dev/null || true)"
home="${HOME:-}"
[ -n "$home" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

dir="${OE_HEARTBEAT_DIR:-${home}/.claude/state/oe-heartbeat}"
diag_dir="${OE_EVENT_DIR:-${home}/.claude/state}"
diag_file="${diag_dir}/oe-heartbeat-diag.jsonl"
tail_lines="${OE_HB_TAIL_LINES:-200}"
case "$tail_lines" in ''|*[!0-9]*) tail_lines=200 ;; esac

_diag() {
  mkdir -p "$diag_dir" 2>/dev/null || return 0
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" --arg reason "$1" --arg detail "${2:-}" \
    '{ts:$ts, hook:"oe-heartbeat-hook", kind:"env-error", reason:$reason, detail:$detail}' >> "$diag_file" 2>/dev/null || true
}

sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)" || sid=""
[ -n "$sid" ] || { _diag "session-id-missing" "標準入力に session_id が無い（hook の契約の変更を疑う）"; exit 0; }
case "$sid" in *[!A-Za-z0-9._-]*) _diag "session-id-unsafe" "session_id に使えない文字がある"; exit 0 ;; esac

event="$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)" || event=""
model="$(printf '%s' "$payload" | jq -r '(.model // "") | if type=="string" then . else "" end' 2>/dev/null)" || model=""

ts="$(date +%s 2>/dev/null)" || exit 0
case "$ts" in ''|*[!0-9]*) exit 0 ;; esac
pane="${TMUX_PANE:-}"
server_pid="${TMUX:-}"; server_pid="${server_pid#*,}"; server_pid="${server_pid%%,*}"
case "$server_pid" in ''|*[!0-9]*) server_pid="" ;; esac
lease_id="${OE_LEASE_ID:-}"; generation="${OE_GENERATION:-}"
if ! printf '%s' "$lease_id" | grep -Eq '^[0-9A-HJKMNP-TV-Z]{26}$' || ! printf '%s' "$generation" | grep -Eq '^[1-9][0-9]*$'; then
  lease_id=""; generation=""
fi
agent="${OE_HB_AGENT:-codex}"

# context_pct
pct=""
if [ "$event" = "PostModelRequest" ]; then
  # 文脈の中のトークン数は total_tokens（無ければ input_tokens + output_tokens。input_tokens は cached を含むので
  # cached_input_tokens は足さない）。token_usage が null（取り消し・失敗した要求）なら空のままにして前の値を残す。
  used="$(printf '%s' "$payload" | jq -r 'if (.token_usage | type) == "object" then (.token_usage | (.total_tokens // ((.input_tokens // 0) + (.output_tokens // 0))) | tostring) else empty end' 2>/dev/null)" || used=""
  transcript="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)" || transcript=""
  window=""
  if [ -n "$transcript" ] && [ -r "$transcript" ]; then
    # 記録を末尾から上限付きで1行ずつ読み（壊れた行・書きかけの最終行は飛ばす）、いちばん新しい token_count の
    # model_context_window を取る。
    window="$(tail -n "$tail_lines" "$transcript" 2>/dev/null \
      | jq -R -r 'fromjson? | select(.type=="event_msg" and .payload.type=="token_count") | .payload.info.model_context_window // empty' 2>/dev/null \
      | tail -n 1)" || window=""
  fi
  case "$used" in ''|*[!0-9]*) used="" ;; esac
  case "$window" in ''|*[!0-9]*|0) window="" ;; esac
  if [ -n "$used" ] && [ -n "$window" ]; then
    pct="$(awk -v u="$used" -v w="$window" 'BEGIN { p = (u / w) * 100; if (p > 100) p = 100; printf "%.1f", p }')"
  fi
fi
if [ -z "$pct" ]; then
  # UserPromptSubmit か、使用量を取れないときは前の sidecar の値を残す（無ければ 0）。
  pct="$(jq -r '.context_pct // 0' "${dir}/${sid}.json" 2>/dev/null)" || pct=0
  case "$pct" in ''|null) pct=0 ;; esac
fi

mkdir -p "$dir" 2>/dev/null || { _diag "dir-unwritable" "$dir"; exit 0; }
tmp=""
trap 'rm -f "$tmp" 2>/dev/null; exit 143' TERM
trap 'rm -f "$tmp" 2>/dev/null; exit 130' INT
tmp="$(mktemp "${dir}/.hb.XXXXXX" 2>/dev/null)" || { trap - TERM INT; _diag "mktemp-failed" "$dir"; exit 0; }
if jq -cn --argjson ts "$ts" --argjson pct "$pct" --arg pane "$pane" --arg spid "$server_pid" --arg model "$model" \
      --arg lid "$lease_id" --arg gen "$generation" --arg agent "$agent" \
      '{ts:$ts, context_pct:$pct, pane:$pane, server_pid:$spid,
        model:(if $model != "" then {id:$model, display_name:$model} else {} end), agent:$agent}
       + (if $lid != "" then {lease_id:$lid, generation:($gen|tonumber)} else {} end)' > "$tmp" 2>/dev/null; then
  mv -f "$tmp" "${dir}/${sid}.json" 2>/dev/null || rm -f "$tmp" 2>/dev/null
else
  rm -f "$tmp" 2>/dev/null
  _diag "jq-failed" "sidecar を組めない"
fi
trap - TERM INT
exit 0
