#!/usr/bin/env bash

set -euo pipefail

# Exercise Git's helper protocol without authenticating or contacting a server.
test "$*" = 'auth git-credential get'
printf '%s\n' "$*" > "$HOME/gh-arguments"
cat > "$HOME/gh-input"
if [ -e "$HOME/gh-unavailable" ]; then
  exit 1
fi

printf 'username=fixture-user\npassword=fixture-password\n'
