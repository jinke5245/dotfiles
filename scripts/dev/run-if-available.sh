#!/usr/bin/env bash

set -euo pipefail

main() {
  local executable="${1:?Usage: run-if-available.sh <command> [args...]}"

  if ! command -v "$executable" > /dev/null 2>&1; then
    printf '%s is not installed; skipping.\n' "$executable"
    return 0
  fi

  exec "$@"
}

main "$@"
