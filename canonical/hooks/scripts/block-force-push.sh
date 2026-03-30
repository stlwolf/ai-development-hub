#!/usr/bin/env bash
set -euo pipefail

deny() {
  jq -n --arg msg "$1" '{"permission":"deny","user_message":$msg}'
  exit 2
}

allow() {
  echo '{"permission":"allow"}'
  exit 0
}

main() {
  local input cmd

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  if [[ ! "$cmd" =~ git[[:space:]]+push ]]; then
    allow
  fi

  if [[ "$cmd" == *"--force-with-lease"* ]] || [[ "$cmd" == *"--force-if-includes"* ]]; then
    allow
  fi

  if [[ "$cmd" == *"--force"* ]] || [[ "$cmd" =~ [[:space:]]-f([[:space:]]|$) ]]; then
    deny "Force push blocked: $cmd. Use --force-with-lease instead."
  fi

  allow
}

main
