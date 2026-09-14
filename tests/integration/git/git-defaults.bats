#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/git.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  git_sandbox_create
}

@test "Git discovers shared configuration without a local file or legacy gitconfig" {
  run -0 sandbox_git config --show-origin --get user.useConfigOnly

  [ "$output" = "$(printf 'file:%s\ttrue' "$SANDBOX_HOME/.config/git/config")" ]
  [ ! -e "$SANDBOX_GIT_LOCAL" ]
  [ ! -e "$SANDBOX_HOME/.gitconfig" ]

  run -1 sandbox_git config --get-regexp '^user\.(name|email)$'
  [ -z "$output" ]

  run -1 sandbox_git config --get-regexp '^alias\.'
  [ -z "$output" ]
}

@test "Git loads branch, pull, fetch, and filename defaults from shared configuration" {
  # Read effective values through normal discovery, including their source file.
  run -0 sandbox_git config --show-origin --get init.defaultBranch
  [ "$output" = "$(printf 'file:%s\tmain' "$SANDBOX_HOME/.config/git/config")" ]

  run -0 sandbox_git config --show-origin --get pull.ff
  [ "$output" = "$(printf 'file:%s\tonly' "$SANDBOX_HOME/.config/git/config")" ]

  run -0 sandbox_git config --type=bool --show-origin --get fetch.prune
  [ "$output" = "$(printf 'file:%s\ttrue' "$SANDBOX_HOME/.config/git/config")" ]

  run -0 sandbox_git config --type=bool --show-origin --get core.quotePath
  [ "$output" = "$(printf 'file:%s\tfalse' "$SANDBOX_HOME/.config/git/config")" ]

  run -1 sandbox_git config --get pull.rebase
  [ -z "$output" ]
}

@test "LFS filtering is configured without running git lfs install" {
  run -0 sandbox_git config --get filter.lfs.clean
  [ "$output" = 'git-lfs clean -- %f' ]

  run -0 sandbox_git config --get filter.lfs.smudge
  [ "$output" = 'git-lfs smudge -- %f' ]

  run -0 sandbox_git config --get filter.lfs.process
  [ "$output" = 'git-lfs filter-process' ]

  run -0 sandbox_git config --type=bool --get filter.lfs.required
  [ "$output" = true ]
}
