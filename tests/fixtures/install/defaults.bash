#!/bin/bash

set -eu

# Record writes without accessing macOS preferences or implementing a plist store.
if [[ "$#" -lt 5 || "$1" != write || "$2" != "$HOME/Library/Preferences/com.googlecode.iterm2" ]]; then
  printf 'Unexpected defaults invocation: %s\n' "$*" >&2
  exit 90
fi

if [[ -e "$HOME/.install-test/fail-iterm2" ]]; then
  printf 'iTerm2: preference write failed\n' >&2
  exit 97
fi

mkdir -p "$HOME/.install-test/defaults"
printf '%s\n' "${@:4}" > "$HOME/.install-test/defaults/$3"
