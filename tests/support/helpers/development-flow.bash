#!/usr/bin/env bash

# Markers stand in for user-owned tools and environments; no builds or downloads.
DEVELOPMENT_STATE_FILES=(
  go/bin/dotfiles-test
  projects/node/node_modules/.dotfiles-test
  projects/python/.venv/.dotfiles-test
)

development_flow_prepare() (
  set -eu

  local test_home="$1" snapshot="$2" file
  for file in "${DEVELOPMENT_STATE_FILES[@]}"; do
    mkdir -p "$test_home/$(dirname "$file")" "$snapshot/$(dirname "$file")"
    printf 'Preserve local development state.\n' > "$test_home/$file"
    cp -p "$test_home/$file" "$snapshot/$file"
  done
)

development_flow_check() (
  set -eu

  local test_home="$1" snapshot="$2" file
  for file in "${DEVELOPMENT_STATE_FILES[@]}"; do
    cmp "$test_home/$file" "$snapshot/$file"
    test ! "$test_home/$file" -nt "$snapshot/$file"
    test ! "$test_home/$file" -ot "$snapshot/$file"
  done
)
