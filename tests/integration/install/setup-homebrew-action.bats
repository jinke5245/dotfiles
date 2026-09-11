#!/usr/bin/env bats

# Bats isolates tests; the execution helper reads each scenario's PATH.
# shellcheck disable=SC2030,SC2031

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'
load '../../helpers/homebrew-action.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  homebrew_action_sandbox_create
}

assert_action_paths() {
  local expected
  # GitHub prepends later entries first, so bin must be written after sbin.
  printf -v expected '%s/sbin\n%s/bin' "$1" "$1"
  [ "$(cat "$ACTION_PATH_FILE")" = "$expected" ]
}

@test "the Homebrew action installs on macOS and publishes paths" {
  install_sandbox_platform Darwin

  run -0 setup_homebrew_action macOS

  [ -x "$SANDBOX_ROOT/prefixes/apple/bin/brew" ]
  [ "$(cat "$SANDBOX_HOME/.install-test/noninteractive")" = 1 ]
  assert_action_paths "$SANDBOX_ROOT/prefixes/apple"
  [ ! -e "$SANDBOX_HOME/.install-test/bundle.log" ]
  [ "$(cat "$SANDBOX_HOME/.install-test/events.log")" = 'download homebrew' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
  [ ! -e "$SANDBOX_HOME/.zshrc" ]
}

@test "the Homebrew action installs on Ubuntu and publishes paths" {
  run -0 setup_homebrew_action Linux

  [ -x "$SANDBOX_ROOT/prefixes/linux/bin/brew" ]
  [ "$(cat "$SANDBOX_HOME/.install-test/noninteractive")" = 1 ]
  assert_action_paths "$SANDBOX_ROOT/prefixes/linux"
  [ ! -e "$SANDBOX_HOME/.install-test/bundle.log" ]
  [ "$(cat "$SANDBOX_HOME/.install-test/events.log")" = $'apt-get update\napt-get install --yes build-essential procps curl file git\ndownload homebrew' ]
}

@test "the Homebrew action prefers the installation on PATH" {
  install_fixture_brew "$SANDBOX_ROOT/chosen brew"
  install_fixture_brew "$SANDBOX_ROOT/prefixes/linux"
  SANDBOX_PATH="$SANDBOX_ROOT/chosen brew/bin:$SANDBOX_PATH"

  run -0 setup_homebrew_action Linux

  assert_action_paths "$SANDBOX_ROOT/chosen brew"
  [ ! -e "$SANDBOX_HOME/.install-test/homebrew.log" ]
}

@test "the Homebrew action reuses default installations outside PATH" {
  local prefix runner_os
  for prefix in apple intel linux; do
    runner_os=macOS
    if [[ "$prefix" = linux ]]; then
      runner_os=Linux
    fi
    install_fixture_brew "$SANDBOX_ROOT/prefixes/$prefix"
    : > "$ACTION_PATH_FILE"

    run -0 setup_homebrew_action "$runner_os"

    assert_action_paths "$SANDBOX_ROOT/prefixes/$prefix" || return 1
    [ ! -e "$SANDBOX_HOME/.install-test/homebrew.log" ] || return 1

    # Each iteration must discover its own installation.
    rm "$SANDBOX_ROOT/prefixes/$prefix/bin/brew"
  done
}

@test "the Homebrew action appends paths without discarding previous entries" {
  printf '/existing/path\n' > "$ACTION_PATH_FILE"

  run -0 setup_homebrew_action Linux

  local expected
  printf -v expected '/existing/path\n%s/sbin\n%s/bin' \
    "$SANDBOX_ROOT/prefixes/linux" "$SANDBOX_ROOT/prefixes/linux"
  [ "$(cat "$ACTION_PATH_FILE")" = "$expected" ]
}

@test "the Homebrew action propagates installation failures without publishing paths" {
  touch "$SANDBOX_HOME/.install-test/fail-homebrew"

  run -92 setup_homebrew_action Linux

  [ ! -s "$ACTION_PATH_FILE" ]
}

@test "the Homebrew action can run twice without reinstalling Homebrew" {
  run -0 setup_homebrew_action Linux
  : > "$ACTION_PATH_FILE"

  run -0 setup_homebrew_action Linux

  [ "$(cat "$SANDBOX_HOME/.install-test/homebrew.log")" = install ]
  assert_action_paths "$SANDBOX_ROOT/prefixes/linux"
}

@test "the Homebrew action stops before downloading when Linux prerequisites fail" {
  touch "$SANDBOX_HOME/.install-test/fail-apt-install"

  run -100 setup_homebrew_action Linux

  [ ! -e "$SANDBOX_HOME/.install-test/download.log" ]
  [ ! -s "$ACTION_PATH_FILE" ]
}

@test "the Homebrew action fails when a download leaves brew unavailable" {
  touch "$SANDBOX_HOME/.install-test/fail-download"

  # Inline installation may execute a partial response; the prefix lookup
  # detects the missing executable and prevents publishing an invalid PATH.
  run -127 setup_homebrew_action Linux

  [ ! -e "$SANDBOX_HOME/.install-test/homebrew.log" ]
  [ ! -s "$ACTION_PATH_FILE" ]
}

@test "the Homebrew action rejects an installer that leaves no executable" {
  printf '#!/bin/bash\nexit 0\n' > "$SANDBOX_HOME/.install-test/homebrew-installer.bash"

  run -127 setup_homebrew_action Linux

  [ ! -s "$ACTION_PATH_FILE" ]
}

@test "the Homebrew action stops when the existing installation's prefix lookup fails" {
  install_fixture_brew "$SANDBOX_ROOT/prefixes/linux"
  printf '#!/bin/bash\nexit 77\n' > "$SANDBOX_ROOT/prefixes/linux/bin/brew"

  run -77 setup_homebrew_action Linux

  [ ! -s "$ACTION_PATH_FILE" ]
}
