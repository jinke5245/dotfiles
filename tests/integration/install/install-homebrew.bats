#!/usr/bin/env bats

# Bats isolates tests; the execution helper reads each scenario's PATH.
# shellcheck disable=SC2030,SC2031

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
  install_sandbox_platform Darwin
}

@test "installs missing Homebrew through the official installer" {
  run -0 install_sandbox_library homebrew install_homebrew

  run -0 "$SANDBOX_ROOT/prefixes/apple/bin/brew" --version
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
  [ ! -e "$SANDBOX_HOME/.zshrc" ]
}

@test "preserves Homebrew already available on PATH" {
  install_fixture_brew "$SANDBOX_ROOT/chosen brew"
  SANDBOX_PATH="$SANDBOX_ROOT/chosen brew/bin:$SANDBOX_PATH"

  run -0 install_sandbox_library homebrew install_homebrew

  [ ! -e "$SANDBOX_HOME/.install-test/download.log" ]
}

@test "finds existing default installations when brew is absent from PATH" {
  local prefix
  for prefix in apple intel; do
    install_fixture_brew "$SANDBOX_ROOT/prefixes/$prefix"

    run -0 install_sandbox_library homebrew install_homebrew

    [ ! -e "$SANDBOX_HOME/.install-test/download.log" ]

    # Remove this installation so the next prefix is checked independently.
    rm "$SANDBOX_ROOT/prefixes/$prefix/bin/brew"
  done
}

@test "installs missing Homebrew on Linux through the official installer" {
  install_sandbox_platform Linux

  # System dependencies must be installed before downloading Homebrew.
  local expected_events
  expected_events="$(
    cat << 'EOF'
apt-get update
apt-get install --yes build-essential procps curl file git
download homebrew
EOF
  )"

  run -0 install_sandbox_library homebrew install_homebrew

  run -0 "$SANDBOX_ROOT/prefixes/linux/bin/brew" --version
  [ "$(cat "$SANDBOX_HOME/.install-test/download.log")" = homebrew ]
  [ "$(cat "$SANDBOX_HOME/.install-test/events.log")" = "$expected_events" ]
}

@test "preserves an existing Linux installation outside PATH" {
  install_sandbox_platform Linux
  install_fixture_brew "$SANDBOX_ROOT/prefixes/linux"

  run -0 install_sandbox_library homebrew install_homebrew

  [ ! -e "$SANDBOX_HOME/.install-test/download.log" ]
  [ ! -e "$SANDBOX_HOME/.install-test/events.log" ]

  run -0 "$SANDBOX_ROOT/prefixes/linux/bin/brew" --version
}

@test "stops before downloading Homebrew when Debian or Ubuntu prerequisites fail" {
  install_sandbox_platform Linux

  local operation
  for operation in update install; do
    touch "$SANDBOX_HOME/.install-test/fail-apt-$operation"

    # The sudo fixture returns 100 for a simulated apt-get failure.
    run -100 install_sandbox_library homebrew install_homebrew

    [[ "$output" == *apt-get* ]] || return 1
    [ ! -e "$SANDBOX_HOME/.install-test/download.log" ]
    [ ! -e "$SANDBOX_ROOT/prefixes/linux/bin/brew" ]

    rm "$SANDBOX_HOME/.install-test/fail-apt-$operation"
  done
}

@test "reports missing apt-get before running sudo or downloading Homebrew" {
  install_sandbox_platform Linux
  rm "$SANDBOX_ROOT/bin/apt-get"

  # Hide the host's apt-get on Linux while retaining the fixture dependencies.
  local dependency
  for dependency in bash cat mkdir chmod; do
    ln -s "$(command -v "$dependency")" "$SANDBOX_ROOT/bin/$dependency"
  done

  SANDBOX_PATH="$SANDBOX_ROOT/bin"

  run -1 install_sandbox_library homebrew install_homebrew

  [[ "$output" == *'apt-get is required'* ]] || return 1
  [ ! -e "$SANDBOX_HOME/.install-test/events.log" ]
  [ ! -e "$SANDBOX_HOME/.install-test/download.log" ]
  [ ! -e "$SANDBOX_ROOT/prefixes/linux/bin/brew" ]
}

@test "does not execute a partial Homebrew installer after a download failure" {
  # curl emits executable text, then fails; none of that text may run.
  touch "$SANDBOX_HOME/.install-test/fail-download"

  run -22 install_sandbox_library homebrew install_homebrew

  [[ "$output" == *curl* ]] || return 1
  [ ! -e "$SANDBOX_HOME/partial-download-was-executed" ]
  [ ! -e "$SANDBOX_HOME/.install-test/homebrew.log" ]
}

@test "propagates a Homebrew installer failure" {
  touch "$SANDBOX_HOME/.install-test/fail-homebrew"

  # Preserve the fixture's exit code instead of hiding it behind a generic error.
  run -92 install_sandbox_library homebrew install_homebrew

  [[ "$output" == *Homebrew* ]] || return 1
  [ ! -e "$SANDBOX_ROOT/prefixes/apple/bin/brew" ]
}
