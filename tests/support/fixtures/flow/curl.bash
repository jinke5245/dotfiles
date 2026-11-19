#!/usr/bin/env bash

# Serve the unmodified upstream installer; refuse every other download.
if [ "$#" -ne 2 ] || [ "$1" != -fsSL ] \
  || [ "$2" != https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh ] \
  || [ -e "$HOME/.test-upstream/no-download" ]; then
  printf 'E2E: unexpected installer download.\n' >&2
  exit 1
fi

cat "$HOME/.test-upstream/install.sh"
