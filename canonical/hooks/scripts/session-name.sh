#!/usr/bin/env bash
#
# session-name.sh — Claude Code UserPromptSubmit hook.
#
# Gives every session an identifiable name (shown in Claude's UI and written to
# the tmux pane title), so parallel sessions — and the notifications built from
# the pane title (notify.sh) — can be told apart. Two behaviors, in priority:
#
#   1. Active issue worktree: when wt-pane-issue.sh recorded "#<issue> <slug>"
#      for this tmux pane (on `wt switch`), title the session with it, once per
#      switch (the "pending" flag is consumed). An issue pane is handled here
#      and NEVER falls through to the fallback below (which would clobber it).
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

# --- 1) Active issue worktree (tmux pane keyed; recorded by wt-pane-issue.sh) ---
pane="${TMUX_PANE:-}"
if [ -n "$pane" ]; then
  server="${TMUX:-}"; server="${server#*,}"; server="${server%%,*}"
  key="${server}_${pane}"; key="${key//[^A-Za-z0-9]/_}"
  state_file="${state_dir}/${key}"
  if [ -f "$state_file" ]; then
    # Issue pane: Path 1 owns naming and must not fall through to the fallback.
    if [ "$(jq -r '.pending // false' "$state_file" 2>/dev/null)" = "true" ]; then
      name="$(jq -r '.name // empty' "$state_file" 2>/dev/null)"
      if [ -n "$name" ]; then
        tmp="${state_file}.tmp.$$"
        if jq -c '.pending=false' "$state_file" >"$tmp" 2>/dev/null; then
          mv -f "$tmp" "$state_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
        fi
        emit_title "$name"
      fi
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
