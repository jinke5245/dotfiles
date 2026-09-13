#!/bin/bash

set -eu

# Enabling shims must not fetch pnpm or choose a project version.
if [ "$#" -ne 4 ] || [ "$1" != enable ] || [ "$2" != pnpm ] \
  || [ "$3" != --install-directory ] || [ "$4" != "$FNM_MULTISHELL_PATH/bin" ]; then
  printf 'Unexpected Corepack invocation: %s\n' "$*" >&2
  exit 90
fi

printf '%s\n' "$0" >> "$HOME/.install-test/corepack.log"
[ ! -e "$HOME/.install-test/fail-corepack" ] || exit 99
[ -e "$4/pnpm" ] || ln -s corepack "$4/pnpm"
