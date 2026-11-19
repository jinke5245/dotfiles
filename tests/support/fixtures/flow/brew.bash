#!/bin/bash

set -eu

real_brew="$(cat "$HOME/.test-upstream/brew-path")"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_CACHE="$HOME/.test-upstream/homebrew-cache"

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

  # API mode recognizes installed casks without requiring a Homebrew cask tap.
  if [ ! -d "$HOMEBREW_CACHE/api" ]; then
    printf 'E2E: a prepared Homebrew API cache is required; run setup in an isolated environment first.\n' >&2
    exit 1
  fi
  # Fail closed if an incompatible or corrupt cache triggers a download fallback.
  export HOMEBREW_CURLRC="$HOME/.test-upstream/brew.curlrc"
  printf 'proto = "=file"\n' > "$HOMEBREW_CURLRC"

  if "$real_brew" bundle check "$3" --no-upgrade --verbose; then
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
