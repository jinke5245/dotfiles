#!/bin/bash

set -eu

# Only Corepack may be installed, inside the selected Node installation.
if [ "$#" -ne 5 ] || [ "$1" != install ] || [ "$2" != --global ] \
  || [ "$3" != --prefix ] || [ "$4" != "$FNM_MULTISHELL_PATH" ] || [ "$5" != corepack ]; then
  printf 'Unexpected npm invocation: %s\n' "$*" >&2
  exit 90
fi

printf '%s\n' "$0" >> "$HOME/.install-test/npm.log"
[ ! -e "$HOME/.install-test/fail-npm" ] || exit 98
cp "$HOME/.install-test/corepack.bash" "$4/bin/corepack"
chmod +x "$4/bin/corepack"
