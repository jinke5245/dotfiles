#!/usr/bin/env bats

# Each test runs the entry point with its own command search path.
# shellcheck disable=SC2030,SC2031

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
}

@test "installs the repository Brewfile immediately after installing Homebrew" {
  local platform
  for platform in Darwin Linux; do
    install_sandbox_platform "$platform"

    run -0 install_sandbox_run bash "$SANDBOX_REPOSITORY/scripts/install.sh"

    [ "$(cat "$SANDBOX_HOME/.install-test/bundle-brew")" = "$(cat "$SANDBOX_HOME/.install-test/prefix")/bin/brew" ]
    [ "$(cat "$SANDBOX_HOME/.install-test/bundle-file")" = "$SANDBOX_REPOSITORY/Brewfile" ]
    cmp "$SANDBOX_REPOSITORY/Brewfile" "$SANDBOX_HOME/.install-test/bundle-input"

    # The next platform must start without the previous Homebrew installation.
    rm -rf "$SANDBOX_ROOT/prefixes"
  done
}

@test "prefers Homebrew on PATH when a default installation also exists" {
  install_fixture_brew "$SANDBOX_ROOT/chosen brew"
  install_fixture_brew "$SANDBOX_ROOT/prefixes/apple"
  SANDBOX_PATH="$SANDBOX_ROOT/chosen brew/bin:$SANDBOX_PATH"

  run -0 install_sandbox_run bash "$SANDBOX_REPOSITORY/scripts/install.sh"

  [ "$(cat "$SANDBOX_HOME/.install-test/bundle-brew")" = "$SANDBOX_ROOT/chosen brew/bin/brew" ]
  [ ! -e "$SANDBOX_HOME/.install-test/homebrew.log" ]
}

@test "uses default Homebrew prefixes when brew is absent from PATH" {
  local prefix
  for prefix in apple intel linux; do
    install_fixture_brew "$SANDBOX_ROOT/prefixes/$prefix"

    run -0 install_sandbox_run bash "$SANDBOX_REPOSITORY/scripts/install.sh"

    [ "$(cat "$SANDBOX_HOME/.install-test/bundle-brew")" = "$SANDBOX_ROOT/prefixes/$prefix/bin/brew" ]
    [ ! -e "$SANDBOX_HOME/.install-test/homebrew.log" ]

    rm "$SANDBOX_ROOT/prefixes/$prefix/bin/brew"
  done
}

@test "reports a missing brew executable after an incomplete installation" {
  # A successful installer exit is insufficient if it leaves no executable.
  printf 'exit 0\n' > "$SANDBOX_HOME/.install-test/homebrew-installer.bash"

  run -1 install_sandbox_run bash "$SANDBOX_REPOSITORY/scripts/install.sh"

  [[ "$output" == *'Homebrew'* && "$output" == *'executable'* ]]
  [ ! -e "$SANDBOX_HOME/.install-test/bundle.log" ]
  [ ! -e "$SANDBOX_HOME/.install-test/oh-my-zsh.log" ]
}

@test "propagates Bundle failure before installing Oh My Zsh" {
  install_fixture_brew "$SANDBOX_ROOT/prefixes/linux"
  touch "$SANDBOX_HOME/.install-test/fail-bundle"

  run -94 install_sandbox_run bash "$SANDBOX_REPOSITORY/scripts/install.sh"

  [[ "$output" == *'Homebrew Bundle'* ]]
  [ ! -e "$SANDBOX_HOME/.install-test/oh-my-zsh.log" ]
}

@test "each apply reads the current Brewfile without reinstalling Homebrew" {
  install_fixture_brew "$SANDBOX_ROOT/prefixes/linux"
  sandbox_chezmoi apply

  printf '\nbrew "test-new-package"\n' >> "$SANDBOX_REPOSITORY/Brewfile"

  run -0 sandbox_chezmoi apply

  cmp "$SANDBOX_REPOSITORY/Brewfile" "$SANDBOX_HOME/.install-test/bundle-input"
  [ "$(cat "$SANDBOX_HOME/.install-test/bundle.log")" = $'install\ninstall' ]
  [ ! -e "$SANDBOX_HOME/.install-test/homebrew.log" ]
}
