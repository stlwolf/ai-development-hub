#!/usr/bin/env bash
set -euo pipefail

deny() {
  local msg="$1"
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    jq -n --arg msg "$msg" '{"permission":"deny","user_message":$msg}'
  else
    echo "$msg" >&2
  fi
  exit 2
}

allow() {
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo '{"permission":"allow"}'
  fi
  exit 0
}

main() {
  local input cmd

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  # Match `git push` even with intervening git options like `git -C . push`
  if [[ ! "$cmd" =~ ^[[:space:]]*git([[:space:]]+[^[:space:]]+)*[[:space:]]+push([[:space:]]|$) ]]; then
    allow
  fi

  # Parse arguments to distinguish plain --force/-f from lease-style options
  local -a args
  local has_plain_force=false
  local has_lease=false

  read -r -a args <<< "$cmd"
  for arg in "${args[@]}"; do
    case "$arg" in
      --force-with-lease|--force-with-lease=*)
        has_lease=true
        ;;
      --force-if-includes)
        has_lease=true
        ;;
      --force|-f)
        has_plain_force=true
        ;;
    esac
  done

  # Plain --force present → deny regardless of lease options
  if [[ "$has_plain_force" == true ]]; then
    deny "Force push blocked: $cmd. Use --force-with-lease instead."
  fi

  # Only lease-style force → allow
  if [[ "$has_lease" == true ]]; then
    allow
  fi

  allow
}

main
