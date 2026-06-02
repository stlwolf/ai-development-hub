#!/usr/bin/env bash
#
# session-name.sh — Claude Code UserPromptSubmit hook.
#
# Titles the session "#<issue> <slug>" using the active worktree recorded by
# wt-pane-issue.sh for this tmux pane. The session name is what Claude Code
# shows in its UI and writes to the terminal (tmux pane) title, so this is how
# parallel sessions become identifiable.
#
# Emits the title once per worktree switch (the "pending" flag is consumed), so
# a manual /rename afterwards is preserved. Emits nothing when there is no pane
# marker — so sessions not on an issue worktree (other repos, master, plain
# research) keep Claude's automatic naming untouched. This conditional emit is
# essential: the hook is registered globally and fires for every session.
#
# `sessionTitle` is a documented hookSpecificOutput field for UserPromptSubmit
# (Claude Code hooks reference) and was verified live (session + tmux pane title
# rename on submit). UserPromptSubmit stdout is injected into the model context,
# so this emits ONLY a single hookSpecificOutput JSON object (built with jq), or
# nothing at all. Diagnostics never go to stdout.
#
set -uo pipefail

# Drain the hook payload on stdin (unused here).
cat >/dev/null 2>&1 || true

pane="${TMUX_PANE:-}"
home="${HOME:-}"
[ -n "$pane" ] || exit 0
[ -n "$home" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Same key as wt-pane-issue.sh: tmux server PID + pane id (restart-safe).
server="${TMUX:-}"; server="${server#*,}"; server="${server%%,*}"
key="${server}_${pane}"
key="${key//[^A-Za-z0-9]/_}"
state_file="${home}/.claude/state/pane-issue/${key}"
[ -f "$state_file" ] || exit 0

# Only act on a freshly recorded switch (pending). Otherwise leave the title
# alone, so a manual /rename is respected.
[ "$(jq -r '.pending // false' "$state_file" 2>/dev/null)" = "true" ] || exit 0

name="$(jq -r '.name // empty' "$state_file" 2>/dev/null)"
[ -n "$name" ] || exit 0

# Consume the pending flag (one-shot), then emit. Ordering note: a concurrent
# `wt switch` between read and write could roll a fresh marker back to
# pending:false (a rare lost-update), and a crash between consume and emit drops
# this turn's rename. Both windows are tiny and self-correct on the next
# switch/prompt. Re-emitting the same title is benign EXCEPT if `mv` permanently
# fails (e.g. disk full) it could re-assert over a manual /rename — accepted
# given the rarity.
tmp="${state_file}.tmp.$$"
if jq -c '.pending=false' "$state_file" >"$tmp" 2>/dev/null; then
  mv -f "$tmp" "$state_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
fi

# Emit the session title (and nothing else on stdout).
jq -cn --arg t "$name" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}'
exit 0
