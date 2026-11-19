#!/usr/bin/env bash

# Serve only the two official installer URLs; no network access is allowed.
[ "$#" -eq 2 ] && [ "$1" = -fsSL ] || exit 90

case "$2" in
  https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) installer=homebrew ;;
  https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) installer=oh-my-zsh ;;
  *) exit 90 ;;
esac

printf '%s\n' "$installer" >> "$HOME/.install-test/download.log"
printf 'download %s\n' "$installer" >> "$HOME/.install-test/events.log"

if [ -e "$HOME/.install-test/fail-download" ]; then
  # This partial response must never execute after curl reports a failure.
  # shellcheck disable=SC2016
  printf 'touch "$HOME/partial-download-was-executed"\n'
  printf 'curl: installer download failed\n' >&2
  exit 22
fi

cat "$HOME/.install-test/$installer-installer.bash"
