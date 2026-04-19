#!/usr/bin/env bash
# common.sh - Shared utilities for wez CLI
#
# Sourced by bin/wez. Not intended for standalone execution.

# Exit codes (DJ-4) — used by other sourced scripts (discover.sh, etc.)
# shellcheck disable=SC2034
readonly WEZ_EXIT_SUCCESS=0
# shellcheck disable=SC2034
readonly WEZ_EXIT_NOT_FOUND=1
# shellcheck disable=SC2034
readonly WEZ_EXIT_CONN_FAIL=2
# shellcheck disable=SC2034
readonly WEZ_EXIT_NO_WEZTERM=127

# Color codes (disabled when stdout is not a terminal)
if [[ -t 2 ]]; then
  readonly WEZ_COLOR_RED=$'\033[0;31m'
  readonly WEZ_COLOR_YELLOW=$'\033[0;33m'
  readonly WEZ_COLOR_GREEN=$'\033[0;32m'
  readonly WEZ_COLOR_RESET=$'\033[0m'
else
  readonly WEZ_COLOR_RED=""
  readonly WEZ_COLOR_YELLOW=""
  readonly WEZ_COLOR_GREEN=""
  readonly WEZ_COLOR_RESET=""
fi

wez_info() {
  echo "${WEZ_COLOR_GREEN}[wez]${WEZ_COLOR_RESET} $*" >&2
}

wez_warn() {
  echo "${WEZ_COLOR_YELLOW}[wez]${WEZ_COLOR_RESET} WARNING: $*" >&2
}

wez_error() {
  echo "${WEZ_COLOR_RED}[wez]${WEZ_COLOR_RESET} ERROR: $*" >&2
}
