#!/usr/bin/env bash
#
# session-name.sh — Claude Code UserPromptSubmit hook.
#
# Gives every session an identifiable name (shown in Claude's UI and written to
# the tmux pane title), so parallel sessions — and the notifications built from
# the pane title (notify.sh) — can be told apart. Two behaviors, in priority:
#
#   0. Supervisor seat (#576): when a seat-taking verb wrote a name request for
#      this session_id, rename once per new request_id and respect a manual
#      /rename until the next request. Details at "--- 0)" below.
#   1. Active issue worktree: when wt-pane-issue.sh recorded "#<issue> <slug>"
#      for this tmux pane (on `wt switch`), title the session with it and KEEP it
#      there — STICKY: re-assert on every prompt whenever the title has drifted
#      (repo name, built-in auto-naming, a manual /rename). `wt switch` keeps cwd
#      at the repo root, so the branch (Path 2) can't see the worktree; the
#      pane-issue is the only meaningful name, so it must win. An issue pane is
#      handled here and NEVER falls through to the fallback below.
#   2. Branch-aware (non-wt sessions): Claude's built-in auto-naming only fires
#      on plan-accept or `/rename`, so a plain session can stay nameless. Name it
#      after the current git branch of the launch dir (payload cwd): an issue
#      branch "{prefix}/#<issue>_<desc>" becomes "#<issue> <slug>" (mirroring
#      wt-pane-issue.sh), the default branch / non-git / detached HEAD falls back
#      to the repository directory name, and any other branch uses the branch
#      name. When the branch CHANGES the session is RE-NAMED — wt-equivalent: it
#      matches the per-switch rename wt-pane-issue.sh drives, and overwrites even
#      a manual /rename (a same-branch manual /rename is respected until the next
#      branch change). Names come from the branch / repo dir — NEVER the prompt
#      text, which propagates to the pane title + OS notifications and may carry
#      secrets. Per-session state (session_id keyed, dedicated dir) holds the last
#      branch seen. When `wt switch` IS used the cwd stays at the repo root, so
#      issue worktrees are named by Path 1, not here.
#
# `sessionTitle` is a documented hookSpecificOutput field for UserPromptSubmit
# (Claude Code hooks reference), verified live. UserPromptSubmit stdout is
# injected into the model context, so this emits ONLY a single hookSpecificOutput
# JSON object (built with jq), or nothing. No diagnostics to stdout.
#
set -uo pipefail

payload="$(cat 2>/dev/null || true)"
home="${HOME:-}"
[ -n "$home" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

state_dir="${home}/.claude/state/pane-issue"

# Emit a sessionTitle and exit. Nothing but this JSON reaches stdout; on jq
# failure emit nothing. jq --arg JSON-escapes the title.
emit_title() {
  local out
  out="$(jq -cn --arg t "$1" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}' 2>/dev/null)" || exit 0
  [ -n "$out" ] || exit 0
  printf '%s' "$out"
  exit 0
}

# --- 0) Supervisor seat request (session_id keyed; written by the seat-taking verbs) ---
# A supervisor (the parent session that delegates to children) runs on the default
# branch, so Path 2 would name it after the repo and it could not be told apart in
# `claude --resume`. The seat-taking verbs (oe-handoff take / oe-register root) write
# a small request keyed by session_id:
#   ~/.claude/state/session-title/<sid>.json  {"format":1,"request_id":"…","name":"…","requested_at":"…"}
# This hook knows only that file, not the engine's records. Rename ONCE per new
# request_id (a new seat), then respect a manual /rename until the next request —
# like Path 2 renames once per branch change. A session WITH a valid request is
# handled here and never falls through: Path 1 is pane keyed, and a stale pane
# record from a previous occupant would otherwise pull the title back to "#<issue>".
# No request / unreadable / empty fields -> skip to Path 1 and Path 2 unchanged.
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || true)"
if [ -n "$sid" ]; then
  sid_key="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9' '_')"
  title_dir="${home}/.claude/state/session-title"
  rfile="${title_dir}/${sid_key}.json"
  req_id=""; req_name=""
  if [ -f "$rfile" ]; then
    # Read the file ONCE (a writer may replace it between two reads: never pair one
    # request's id with another's name) and accept exactly one JSON object (-s: a
    # parse error yields nothing, so a truncated/concatenated file is "no request").
    req="$(jq -cs 'if length == 1 and (.[0] | type) == "object"
                     and (.[0].request_id | type) == "string" and (.[0].name | type) == "string"
                   then .[0] else empty end' "$rfile" 2>/dev/null || true)"
    if [ -n "$req" ]; then
      req_id="$(printf '%s' "$req" | jq -r '.request_id' 2>/dev/null || true)"
      req_name="$(printf '%s' "$req" | jq -r '.name' 2>/dev/null || true)"
    fi
    req_name="$(printf '%s' "$req_name" | tr -d '\000-\037\177' | head -c 80 | { iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || cat; })"
  fi
  if [ -n "$req_id" ] && [ -n "$req_name" ]; then
    # Plan mode / a slash command: do not rename and do NOT consume the request,
    # so the next ordinary prompt still applies it.
    [ "$(printf '%s' "$payload" | jq -r '.permission_mode // ""' 2>/dev/null || true)" != "plan" ] || exit 0
    case "$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || true)" in /*) exit 0 ;; esac
    touch -- "$rfile" 2>/dev/null || true
    # The applied request_id lives in the same per-session state as Path 2's
    # last_branch, so both share one file and one GC window.
    branch_dir="${home}/.claude/state/session-branch"
    sfile="${branch_dir}/${sid_key}.json"
    applied=""
    [ -f "$sfile" ] && applied="$(jq -r '.seat_request_id // ""' "$sfile" 2>/dev/null || true)"
    if [ "$applied" = "$req_id" ]; then
      # Same seat: our name is in place, or the user renamed it by hand — respect it.
      touch -- "$sfile" 2>/dev/null || true
      exit 0
    fi
    # New seat: record it, then (re)name. Keep last_branch; seed it when absent so
    # that if the request is later GC'd, Path 2 does not mistake "" for a branch change.
    cur_cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || true)"
    cur_branch=""
    [ -n "$cur_cwd" ] && cur_branch="$(git -C "$cur_cwd" symbolic-ref --short HEAD 2>/dev/null || true)"
    saved=0
    if mkdir -p "$branch_dir" 2>/dev/null; then
      find "$title_dir" -maxdepth 1 -type f -mmin +43200 -delete 2>/dev/null || true
      prev=""
      [ -f "$sfile" ] && prev="$(jq -cs 'if length == 1 and (.[0] | type) == "object" then .[0] else {} end' "$sfile" 2>/dev/null || true)"
      [ -n "$prev" ] || prev='{}'
      tmp="${sfile}.tmp.$$"
      if printf '%s' "$prev" | jq -c --arg r "$req_id" --arg b "$cur_branch" \
           '.seat_request_id = $r | (if has("last_branch") then . else .last_branch = $b end)' >"$tmp" 2>/dev/null; then
        if mv -f "$tmp" "$sfile" 2>/dev/null; then saved=1; else rm -f "$tmp" 2>/dev/null; fi
      else
        rm -f "$tmp" 2>/dev/null
      fi
    fi
    # Rename only when the applied id was saved. Otherwise the next prompt would see
    # the request as new again and keep overriding a manual /rename every prompt.
    [ "$saved" = 1 ] || exit 0
    session_title="$(printf '%s' "$payload" | jq -r '.session_title // ""' 2>/dev/null || true)"
    [ "$session_title" = "$req_name" ] || emit_title "$req_name"
    exit 0
  fi
fi

# --- 1) Active issue worktree (tmux pane keyed; recorded by wt-pane-issue.sh) ---
pane="${TMUX_PANE:-}"
if [ -n "$pane" ]; then
  server="${TMUX:-}"; server="${server#*,}"; server="${server%%,*}"
  key="${server}_${pane}"; key="${key//[^A-Za-z0-9]/_}"
  state_file="${state_dir}/${key}"
  if [ -f "$state_file" ]; then
    # Issue pane: Path 1 owns naming and must not fall through to the fallback.
    # STICKY — re-assert the issue name whenever the session title has drifted
    # (repo name / built-in auto-naming / manual /rename). Re-emitting works on an
    # already-named session, so the issue name wins back the title each prompt.
    # Idempotent: if the title already equals the issue name, do nothing.
    name="$(jq -r '.name // empty' "$state_file" 2>/dev/null)"
    if [ -n "$name" ]; then
      # Refresh the marker mtime: it is now the sticky source of truth, so keep an
      # active issue pane alive against wt-pane-issue.sh's 24h GC. (An idle pane
      # untouched >24h is still reaped — fine, it then falls back to Path 2.)
      touch -- "$state_file" 2>/dev/null || true
      session_title="$(printf '%s' "$payload" | jq -r '.session_title // ""' 2>/dev/null || true)"
      [ "$session_title" = "$name" ] || emit_title "$name"
    fi
    exit 0
  fi
fi

# --- 2) Branch-aware naming for non-wt sessions (issue worktrees handled above) ---
# Respect plan mode and a manual /rename in progress (slash-prefixed prompt). The
# prompt's first char is all we inspect; the prompt text is never used as a name.
[ "$(printf '%s' "$payload" | jq -r '.permission_mode // ""' 2>/dev/null || true)" != "plan" ] || exit 0
case "$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || true)" in /*) exit 0 ;; esac

sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || true)"
[ -n "$sid" ] || exit 0
cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || true)"
[ -n "$cwd" ] || exit 0

# Current branch of the launch dir; empty for a non-git dir or detached HEAD.
branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)"

# Desired name from the branch (see header): issue branch -> "#<issue> <slug>"
# (mirror wt-pane-issue.sh), default/non-git -> repo dir name, else branch name.
if [[ "$branch" =~ ^[a-z]+/#([0-9]+)_(.+)$ ]]; then
  slug="${BASH_REMATCH[2]//_/-}"
  desired="#${BASH_REMATCH[1]} ${slug:0:48}"
elif [ -z "$branch" ] || [ "$branch" = "master" ] || [ "$branch" = "main" ]; then
  desired="$(basename "$cwd" 2>/dev/null || true)"
else
  desired="$branch"
fi
# Strip control chars (incl. DEL 0x7F), cap length, keep valid UTF-8 (title -> pane title / notifications).
desired="$(printf '%s' "$desired" | tr -d '\000-\037\177' | head -c 80 | { iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || cat; })"
[ -n "$desired" ] || exit 0

# Per-session state (session_id keyed) in a DEDICATED dir, separate from the
# pane-issue dir. Holds the last branch seen, so we can re-name on branch change.
# (Our name vs a same-branch manual /rename is told apart by the idempotency
# check below — session_title == desired — so no "last emitted" field is needed.)
branch_dir="${home}/.claude/state/session-branch"
sfile="${branch_dir}/$(printf '%s' "$sid" | tr -c 'A-Za-z0-9' '_').json"
last_branch=""; state_exists=0
if [ -f "$sfile" ]; then
  state_exists=1
  last_branch="$(jq -r '.last_branch // ""' "$sfile" 2>/dev/null || true)"
fi
session_title="$(printf '%s' "$payload" | jq -r '.session_title // ""' 2>/dev/null || true)"

# First time we see an ALREADY-NAMED session (no state file yet): the title
# predates our state (a manual /rename, plan-accept, or a session from before this
# mechanism). Record the current branch as the baseline and KEEP the title — only
# a later real branch change should re-name. Without this, last_branch="" would
# look like a branch change and clobber the existing title on the very first prompt.
if [ "$state_exists" = 0 ] && [ -n "$session_title" ]; then
  mkdir -p "$branch_dir" 2>/dev/null && {
    tmp="${sfile}.tmp.$$"
    jq -cn --arg b "$branch" '{last_branch:$b}' >"$tmp" 2>/dev/null \
      && { mv -f "$tmp" "$sfile" 2>/dev/null || rm -f "$tmp" 2>/dev/null; }
  }
  exit 0
fi

# No-op when the session already shows the name we'd emit (idempotent — also
# prevents a re-emit loop if the state file can't be persisted: emit_title set the
# name, so we short-circuit here next time), OR when it's the same branch with a
# different, manual /rename title (respected until the branch changes). Touch the
# state file on no-op so a long-lived same-branch session isn't GC'd out from under
# us — losing it would reset last_branch and let the next prompt look like a branch
# change and clobber the manual title.
if [ "$session_title" = "$desired" ] || { [ "$branch" = "$last_branch" ] && [ -n "$session_title" ]; }; then
  [ -f "$sfile" ] && touch -- "$sfile" 2>/dev/null
  exit 0
fi

# Branch changed (wt-equivalent re-name — overwrites even a manual /rename, like wt
# on every switch) or the session is unnamed: (re)name it.

# About to (re)name — run the opportunistic stale-state GC now (only on a naming
# event, not every prompt). Long window bounds growth without clobbering sessions.
mkdir -p "$branch_dir" 2>/dev/null || exit 0
find "$branch_dir" -maxdepth 1 -type f -mmin +43200 -delete 2>/dev/null || true
tmp="${sfile}.tmp.$$"
if jq -cn --arg b "$branch" '{last_branch:$b}' >"$tmp" 2>/dev/null; then
  mv -f "$tmp" "$sfile" 2>/dev/null || rm -f "$tmp" 2>/dev/null
fi
emit_title "$desired"
