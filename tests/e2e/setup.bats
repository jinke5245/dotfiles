#!/usr/bin/env bats

# bats file_tags=network,container

# Every shell snippet executes through Docker, never against the host HOME.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'
load '../helpers/setup.bash'

setup_file() {
  bats_require_minimum_version 1.10.0
}

setup() {
  setup_container_create
  SETUP_SOURCE=/tmp/source
  # Consumed by the shared setup assertions.
  # shellcheck disable=SC2034
  SETUP_BREW_PREFIX=/home/linuxbrew/.linuxbrew
}

setup_shell() {
  setup_container_shell "$@"
}

teardown() {
  setup_container_remove
}

@test "a new Ubuntu user completes the documented setup and reapplies cleanly" {
  # Begin without chezmoi, Homebrew, Oh My Zsh, or managed shell configuration.
  run -0 setup_container_shell '
    test "$(id -u)" -ne 0
    test -z "$(command -v chezmoi)"
    test -z "$(command -v brew)"
    test ! -e /home/linuxbrew/.linuxbrew
    test ! -e "$HOME/.oh-my-zsh"
    test ! -e "$HOME/.zshrc"
    sudo apt-get update
    sudo apt-get install --yes ca-certificates curl git openssh-client zsh
  '

  setup_repository "$SETUP_SOURCE"

  setup_check_flow
}
