#!/usr/bin/env bash
#
# wt-pane-issue.sh — worktrunk post-switch hook helper.
#
# Records the active issue for the current tmux pane so the Claude Code
# UserPromptSubmit hook (session-name.sh) can title the session
# "#<issue> <slug>".
#
# Why this exists: `wt switch` does NOT move the Claude session's cwd (the
# shell cd is not consumed by the parent process), so neither Claude hooks nor
# notify.sh can learn the active worktree from cwd. worktrunk's own post-switch
# hook fires on every `wt switch` (agent or human) with the resolved branch, so
# we capture it here, keyed by the tmux pane the session lives in.
#
# Invoked from ~/.config/worktrunk/config.toml (worktrunk shell-quotes
# {{ branch }}, so do NOT add your own quotes):
#   [post-switch]
#   claude-session-name = 'wt-pane-issue {{ branch }}'
#
# Advisory: never fails the wt operation (always exits 0), writes nothing to
# stdout. No-op outside tmux or without jq.
#
set -uo pipefail

branch="${1:-}"
pane="${TMUX_PANE:-}"
home="${HOME:-}"

# Need a tmux pane to key on, $HOME for state, and jq to write JSON safely.
[ -n "$pane" ] || exit 0
[ -n "$home" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Key by tmux server PID + pane id. $TMUX_PANE (%N) is only unique within one
# tmux server; after `tmux kill-server`/restart panes renumber from %0. Folding
# in the server PID (field 2 of $TMUX = "socket,pid,session") means a reused
# pane id under a new server gets a fresh key, so stale state from a previous
# server can never misname an unrelated session.
server="${TMUX:-}"; server="${server#*,}"; server="${server%%,*}"
key="${server}_${pane}"
key="${key//[^A-Za-z0-9]/_}"

state_dir="${home}/.claude/state/pane-issue"
state_file="${state_dir}/${key}"

# Derive "#<issue> <slug>" from "{prefix}/#<issue>_<desc>"; empty otherwise.
# Cap slug length defensively (jq --arg already makes it JSON-safe, and git ref
# names forbid control chars, so there is no escape-injection surface).
name=""
if [[ "$branch" =~ ^[a-z]+/#([0-9]+)_(.+)$ ]]; then
  slug="${BASH_REMATCH[2]//_/-}"
  name="#${BASH_REMATCH[1]} ${slug:0:48}"
fi

mkdir -p "$state_dir" 2>/dev/null || exit 0

# Opportunistic GC: markers untouched for >24h are orphans (consumed long ago,
# or left by a now-dead server). Bounds unbounded growth. Runs before we write.
find "$state_dir" -maxdepth 1 -type f -mmin +1440 -delete 2>/dev/null || true

# Non-issue branch (master, `wt switch ^`, pr:, etc.) → clear the marker.
if [ -z "$name" ]; then
  rm -f "$state_file" 2>/dev/null || true
  exit 0
fi

# Record {name, pending:true} atomically. `pending` drives a one-shot rename
# on the next UserPromptSubmit, after which a manual /rename is respected.
tmp="${state_file}.tmp.$$"
if jq -cn --arg n "$name" '{name:$n, pending:true}' >"$tmp" 2>/dev/null; then
  mv -f "$tmp" "$state_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
fi
exit 0
