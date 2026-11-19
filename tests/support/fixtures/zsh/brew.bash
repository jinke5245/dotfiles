#!/bin/bash

# Model read-only queries without invoking Homebrew or installing packages.
prefix="${0%/bin/brew}"
if [ "$#" -eq 1 ] && [ "$1" = --prefix ]; then
  printf 'brew-prefix\n' >> "$ZSH_TEST_TRACE"
  printf '%s\n' "$prefix"
  exit 0
fi

if [ "$#" -ne 2 ] || [ "$1" != shellenv ] || [ "$2" != zsh ]; then
  printf 'Expected: brew shellenv zsh or brew --prefix\n' >&2
  exit 1
fi

printf 'brew\n' >> "$ZSH_TEST_TRACE"
printf 'export HOMEBREW_PREFIX=%q\n' "$prefix"
printf 'export HOMEBREW_CELLAR=%q\n' "$prefix/Cellar"
printf 'export HOMEBREW_REPOSITORY=%q\n' "$prefix"
# Preserve PATH for expansion by the calling Zsh process.
# shellcheck disable=SC2016
printf 'export PATH=%q:"$PATH"\n' "$prefix/bin:$prefix/sbin"
