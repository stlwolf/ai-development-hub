#!/usr/bin/env bash
#
# wt-pane-issue.sh — worktrunk post-switch hook helper.
#
# Records the active issue for the current tmux pane so the Claude Code
# UserPromptSubmit hook (session-name.sh) can title the session
# "#<issue> <slug>". Keyed by $TMUX_PANE so parallel sessions stay isolated.
#
# Why this exists: `wt switch` does NOT move the Claude session's cwd (the
# shell cd is not consumed by the parent process), so neither Claude hooks nor
# notify.sh can learn the active worktree from cwd. worktrunk's own post-switch
# hook fires on every `wt switch` (agent or human) with the resolved branch, so
# we capture it here, keyed by the tmux pane the session lives in.
#
# Invoked from ~/.config/worktrunk/config.toml:
#   [post-switch]
#   claude-session-name = 'wt-pane-issue "{{ branch }}"'
#
# Advisory: never fails the wt operation (always exits 0), writes nothing to
# stdout. No-op outside tmux or without jq.
#
set -uo pipefail

branch="${1:-}"
pane="${TMUX_PANE:-}"

# Need a tmux pane to key on, and jq to write JSON safely.
[ -n "$pane" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

key="${pane//[^A-Za-z0-9]/_}"
state_dir="${HOME}/.claude/state/pane-issue"
state_file="${state_dir}/${key}"

# Derive "#<issue> <slug>" from "{prefix}/#<issue>_<desc>"; empty otherwise.
name=""
if [[ "$branch" =~ ^[a-z]+/#([0-9]+)_(.+)$ ]]; then
  name="#${BASH_REMATCH[1]} ${BASH_REMATCH[2]//_/-}"
fi

mkdir -p "$state_dir" 2>/dev/null || exit 0

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
