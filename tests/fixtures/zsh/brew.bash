#!/bin/bash

# Model the shellenv boundary without invoking Homebrew or installing packages.
if [ "$#" -ne 2 ] || [ "$1" != shellenv ] || [ "$2" != zsh ]; then
  printf 'Expected: brew shellenv zsh\n' >&2
  exit 1
fi

prefix="${0%/bin/brew}"
printf 'brew\n' >> "$ZSH_TEST_TRACE"
printf 'export HOMEBREW_PREFIX=%q\n' "$prefix"
printf 'export HOMEBREW_CELLAR=%q\n' "$prefix/Cellar"
printf 'export HOMEBREW_REPOSITORY=%q\n' "$prefix"
# Preserve PATH for expansion by the calling Zsh process.
# shellcheck disable=SC2016
printf 'export PATH=%q:"$PATH"\n' "$prefix/bin:$prefix/sbin"
