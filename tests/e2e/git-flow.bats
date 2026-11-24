#!/usr/bin/env bats

# Shell snippets expand only inside the isolated login shell.
# shellcheck disable=SC2016

load '../support/helpers/sandbox.bash'
load '../support/helpers/zsh.bash'
load '../support/helpers/flow.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
  flow_suite_setup
}

setup() {
  flow_sandbox_create
}

@test "login shells expose Git LFS and shared configuration" {
  mkdir -p "$SANDBOX_HOME/.config/git"
  cp "$SANDBOX_REPOSITORY/tests/support/fixtures/git/local.config" "$SANDBOX_HOME/.config/git/config.local"
  sandbox_chezmoi apply

  run -0 sandbox_zsh -lc '
    source "$1"
    git_flow_check
  ' _ "$SANDBOX_REPOSITORY/tests/support/helpers/git-flow.bash"
}
