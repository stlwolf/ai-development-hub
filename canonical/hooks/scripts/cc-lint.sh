#!/usr/bin/env bash
set -euo pipefail

CC_TYPES="feat|fix|ui|refactor|style|test|docs|revert|ci|infra|chore|local|wip"

deny() {
  jq -n --arg msg "$1" '{"permission":"deny","user_message":$msg}'
  exit 2
}

allow() {
  echo '{"permission":"allow"}'
  exit 0
}

extract_commit_segment() {
  local cmd="$1"
  if [[ "$cmd" == *"&&"* ]]; then
    local segment
    segment="$(echo "$cmd" | grep -oE '(^|&&)[[:space:]]*git[[:space:]]+commit[^&]*' | head -1 | sed 's/^[[:space:]]*&&[[:space:]]*//')"
    if [[ -n "$segment" ]]; then
      echo "$segment"
      return 0
    fi
  fi
  echo "$cmd"
}

extract_message() {
  local cmd="$1"
  if [[ "$cmd" =~ \$\( ]] || [[ "$cmd" =~ \` ]]; then
    return 1
  fi

  local msg=""
  local -a tokens
  local in_m=false

  read -ra tokens <<< "$cmd"
  for token in "${tokens[@]}"; do
    if $in_m; then
      if [[ -z "$msg" ]]; then
        msg="$token"
      else
        msg="$msg $token"
      fi
      if [[ "$msg" == \"*\" ]] || [[ "$msg" == \'*\' ]]; then
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
      fi
      if [[ "$msg" != \"* ]] && [[ "$msg" != \'* ]]; then
        echo "$msg"
        return 0
      fi
      if [[ "$msg" == *\" ]] || [[ "$msg" == *\' ]]; then
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
      fi
      continue
    fi
    case "$token" in
      -m|--message)
        in_m=true
        ;;
      -m=*)
        msg="${token#-m=}"
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
        ;;
      --message=*)
        msg="${token#--message=}"
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
        ;;
      -[a-zA-Z]*m)
        in_m=true
        ;;
    esac
  done

  if $in_m && [[ -n "$msg" ]]; then
    msg="${msg#[\"\']}"
    msg="${msg%[\"\']}"
    echo "$msg"
    return 0
  fi

  return 1
}

main() {
  local input cmd

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  local commit_segment
  commit_segment="$(extract_commit_segment "$cmd")"

  if [[ ! "$commit_segment" =~ ^[[:space:]]*git[[:space:]]+(.*[[:space:]]+)?commit([[:space:]]|$) ]]; then
    allow
  fi

  if [[ "$commit_segment" =~ --fixup[=[:space:]] ]] || [[ "$commit_segment" =~ --squash[=[:space:]] ]]; then
    allow
  fi

  if [[ ! "$commit_segment" =~ [[:space:]]-[a-zA-Z]*m ]] && [[ ! "$commit_segment" =~ --message ]]; then
    allow
  fi

  local message
  if ! message="$(extract_message "$commit_segment")"; then
    allow
  fi

  if [[ -z "$message" ]]; then
    allow
  fi

  local cc_pattern="^(${CC_TYPES})(\(.+\))?: .+"
  if [[ "$message" =~ $cc_pattern ]]; then
    allow
  fi

  deny "Commit message does not follow Conventional Commits format.
Expected: <type>(<optional scope>): <description>
Types: feat, fix, ui, refactor, style, test, docs, revert, ci, infra, chore, local, wip
Example: feat(hooks): add cc-lint pre-command hook
Got: $message"
}

main
