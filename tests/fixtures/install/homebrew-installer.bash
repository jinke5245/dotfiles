#!/usr/bin/env bash

set -eu

printf 'install\n' >> "$HOME/.install-test/homebrew.log"
printf '%s\n' "${NONINTERACTIVE:-}" > "$HOME/.install-test/noninteractive"

if [ -e "$HOME/.install-test/fail-homebrew" ]; then
  printf 'Homebrew: installer failed\n' >&2
  exit 92
fi

prefix="$(cat "$HOME/.install-test/prefix")"
[ -n "$prefix" ] || exit 90
mkdir -p "$prefix/bin"

cp "$HOME/.install-test/brew.bash" "$prefix/bin/brew"
chmod +x "$prefix/bin/brew"
