#!/bin/bash

set -eu

if [ "$#" -eq 1 ] && [ "$1" = --version ]; then
  exit 0
fi

if [ "$#" -eq 1 ] && [ "$1" = --prefix ]; then
  printf '%s\n' "${0%/bin/brew}"
  exit 0
fi

# Accept only the declared installation contract; never call a package manager.
if [ "$#" -ne 4 ] || [ "$1" != bundle ] || [ "$2" != install ] \
  || [[ "$3" != --file=/* ]] || [ "$4" != --no-upgrade ]; then
  printf 'Unexpected Homebrew invocation: %s\n' "$*" >&2
  exit 90
fi

printf '%s\n' "$0" > "$HOME/.install-test/bundle-brew"
printf '%s\n' "${3#--file=}" > "$HOME/.install-test/bundle-file"
printf 'bundle install\n' >> "$HOME/.install-test/events.log"

if [ -e "$HOME/.install-test/fail-bundle" ]; then
  printf 'Homebrew Bundle: installation failed\n' >&2
  exit 94
fi

cat "${3#--file=}" > "$HOME/.install-test/bundle-input"
printf 'install\n' >> "$HOME/.install-test/bundle.log"

if grep -Fxq 'brew "fnm"' "$HOME/.install-test/bundle-input"; then
  cp "$HOME/.install-test/fnm.bash" "${0%/brew}/fnm"
  chmod +x "${0%/brew}/fnm"
fi
