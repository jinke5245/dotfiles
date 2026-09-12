#!/bin/bash

set -eu

real_brew="$(cat "$HOME/.test-upstream/brew-path")"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
# A fresh sandbox has no API cache; checks must use installed formula metadata.
export HOMEBREW_NO_INSTALL_FROM_API=1

# The real setup suites own package installation; offline E2E only checks it.
if [ "$#" -eq 4 ] && [ "$1" = bundle ] && [ "$2" = install ] \
  && [[ "$3" = --file=/* ]] && [ "$4" = --no-upgrade ]; then
  # Even read-only Ruby commands can bootstrap Homebrew's runtime. Inspect its
  # prepared files first; --repository itself uses Homebrew's shell fast path.
  brew_repository="$("$real_brew" --repository)"
  vendor="$brew_repository/Library/Homebrew/vendor"
  ruby_version="$(cat "$vendor/portable-ruby-version" 2> /dev/null)" || ruby_version=
  if [[ -z "$ruby_version" || ! -x "$vendor/portable-ruby/current/bin/ruby" ||
    ! -f "$vendor/portable-ruby/current/bin/bundle" ||
    ! "$vendor/portable-ruby/current" -ef "$vendor/portable-ruby/$ruby_version" ]]; then
    printf 'E2E: a prepared Homebrew runtime is required; run setup in an isolated environment first.\n' >&2
    exit 1
  fi

  if "$real_brew" bundle check "$3" --no-upgrade; then
    exit 0
  fi
  printf 'E2E: prepare the Brewfile dependencies in an isolated environment before running this suite.\n' >&2
  exit 1
fi

if { [ "$#" -eq 1 ] && [ "$1" = --prefix ]; } \
  || { [ "$#" -eq 2 ] && [ "$1" = shellenv ] && [ "$2" = zsh ]; }; then
  exec "$real_brew" "$@"
fi

printf 'E2E: unexpected Homebrew operation: %s\n' "$*" >&2
exit 1
