#!/usr/bin/env bash

# Shared assertions run in the isolated login shell on both platforms.
git_flow_check() (
  set -eu
  export GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL=file

  test "$(git config --get user.useConfigOnly)" = true
  test "$(git config --get user.name)" = 'Dotfiles test'
  test "$(git config --get user.email)" = test@example.invalid
  test "$(git config --get core.quotePath)" = true

  test "$(command -v git-lfs)" = "$HOMEBREW_PREFIX/bin/git-lfs"
  git lfs version

  # Verify the deployed filter settings through Git's normal configuration lookup.
  test "$(git config --get filter.lfs.clean)" = 'git-lfs clean -- %f'
  test "$(git config --get filter.lfs.smudge)" = 'git-lfs smudge -- %f'
  test "$(git config --get filter.lfs.process)" = 'git-lfs filter-process'
  test "$(git config --type=bool --get filter.lfs.required)" = true
)
