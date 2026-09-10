#!/usr/bin/env bats

# bats file_tags=network,macos,ci

# Snippets execute in the guarded GitHub runner's temporary home.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'
load '../helpers/setup.bash'
load '../helpers/setup-macos.bash'

setup_file() {
  bats_require_minimum_version 1.10.0
  setup_macos_require_runner
}

setup() {
  setup_macos_create
}

setup_shell() {
  setup_macos_shell "$@"
}

teardown() {
  setup_macos_remove
}

@test "a fresh macOS home completes the documented setup and reapplies cleanly" {
  run -0 setup_shell '
    test -z "$(command -v chezmoi)"
    test -z "$(command -v brew)"
    test ! -e "$HOME/.oh-my-zsh"
    test ! -e "$HOME/.zshrc"
  '

  setup_repository "$SETUP_SOURCE"
  setup_check_flow
}
