#!/usr/bin/env bash
# discover.sh - Socket auto-discovery for wez CLI
#
# Sourced by bin/wez. Library functions are silent by default (DJ-3):
# no stderr output. CLI output control is handled by bin/wez (wez_cmd_discover).

# Stub: implemented in Step 2
wez_discover_socket() {
  return "${WEZ_EXIT_NOT_FOUND}"
}

# Stub: implemented in Step 2
wez_verify_connection() {
  return "${WEZ_EXIT_CONN_FAIL}"
}

# Stub: implemented in Step 2
wez_cmd_discover() {
  wez_error "discover subcommand not yet implemented"
  return 1
}
