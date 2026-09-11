#!/usr/bin/env bats

# The child shell, not Bats, expands the sourced library path.
# shellcheck disable=SC2016

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
}

@test "installs missing Oh My Zsh through the official installer" {
  run -0 install_sandbox_library oh-my-zsh install_oh_my_zsh

  [ -f "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]
  [ -f "$SANDBOX_HOME/.zshrc" ]
  [ "$(cat "$SANDBOX_HOME/.install-test/download.log")" = oh-my-zsh ]
}

@test "preserves an existing Oh My Zsh installation and local customizations" {
  install_sandbox_library oh-my-zsh install_oh_my_zsh
  printf 'keep\n' > "$SANDBOX_HOME/.oh-my-zsh/personal-note"

  # Any unexpected attempt to reinstall the framework now fails.
  touch "$SANDBOX_HOME/.install-test/fail-oh-my-zsh"

  run -0 install_sandbox_library oh-my-zsh install_oh_my_zsh

  [ "$(cat "$SANDBOX_HOME/.install-test/oh-my-zsh.log")" = install ]
  [ "$(cat "$SANDBOX_HOME/.oh-my-zsh/personal-note")" = keep ]
}

@test "keeps an existing zshrc when installing the framework" {
  printf 'existing config\n' > "$SANDBOX_HOME/.zshrc"

  run -0 install_sandbox_library oh-my-zsh install_oh_my_zsh

  [ -f "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]
  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'existing config' ]
}

@test "uses the managed home paths despite inherited Oh My Zsh settings" {
  # Simulate a caller whose shell settings point to a different installation.
  run -0 install_sandbox_run env \
    ZSH="$SANDBOX_HOME/elsewhere" \
    ZDOTDIR="$SANDBOX_HOME/elsewhere" \
    /bin/bash -c 'source "$1" && install_oh_my_zsh' _ \
    "$SANDBOX_REPOSITORY/scripts/lib/oh-my-zsh.sh"

  [ -f "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]
  [ ! -e "$SANDBOX_HOME/elsewhere" ]
}

@test "propagates installer errors without replacing an existing directory" {
  # This directory has user content but no framework startup file.
  mkdir -p "$SANDBOX_HOME/.oh-my-zsh"
  printf 'keep\n' > "$SANDBOX_HOME/.oh-my-zsh/personal-note"

  run -93 install_sandbox_library oh-my-zsh install_oh_my_zsh

  [[ "$output" == *'Oh My Zsh'* ]] || return 1
  [ "$(cat "$SANDBOX_HOME/.oh-my-zsh/personal-note")" = keep ]
}

@test "does not execute a partial Oh My Zsh installer after a download failure" {
  # curl emits executable text, then fails; none of that text may run.
  touch "$SANDBOX_HOME/.install-test/fail-download"

  run -22 install_sandbox_library oh-my-zsh install_oh_my_zsh

  [[ "$output" == *curl* ]] || return 1
  [ ! -e "$SANDBOX_HOME/partial-download-was-executed" ]
  [ ! -e "$SANDBOX_HOME/.install-test/oh-my-zsh.log" ]
}

@test "propagates an Oh My Zsh installation failure" {
  touch "$SANDBOX_HOME/.install-test/fail-oh-my-zsh"

  # Preserve the installer fixture's exit code and diagnostic.
  run -93 install_sandbox_library oh-my-zsh install_oh_my_zsh

  [[ "$output" == *'Oh My Zsh'* ]] || return 1
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh" ]
}
