#!/usr/bin/env bash

# Replace the privilege boundary; never execute a real package manager.
[ "$1" = apt-get ] || exit 90
shift

case "$*" in
  update | 'install --yes build-essential procps curl file git') ;;
  *) exit 90 ;;
esac

printf 'apt-get %s\n' "$*" >> "$HOME/.install-test/events.log"

if [ -e "$HOME/.install-test/fail-apt-$1" ]; then
  printf 'apt-get: %s failed\n' "$1" >&2
  exit 100
fi
