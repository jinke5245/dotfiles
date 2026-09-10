#!/usr/bin/env bash

set -eu

printf 'install\n' >> "$HOME/.install-test/homebrew.log"

if [ -e "$HOME/.install-test/fail-homebrew" ]; then
  printf 'Homebrew: installer failed\n' >&2
  exit 92
fi

prefix="$(cat "$HOME/.install-test/prefix")"
[ -n "$prefix" ] || exit 90
mkdir -p "$prefix/bin"

# Only --version is needed to verify the installed executable.
cat > "$prefix/bin/brew" << 'EOF'
#!/bin/sh
[ "$1" = --version ]
EOF

chmod +x "$prefix/bin/brew"
