#!/usr/bin/env bash

# Scenario paths are also consumed by the Bats suites.
# shellcheck disable=SC2034

node_sandbox_create() {
  install_sandbox_create
  NODE_TEST_STATE="$SANDBOX_HOME/.install-test"
  NODE_TEST_PREFIX="$SANDBOX_ROOT/prefixes/linux"
  NODE_TEST_DATA="$NODE_TEST_STATE/fnm"
  install_fixture_brew "$NODE_TEST_PREFIX"
  cp "$NODE_TEST_STATE/fnm.bash" "$NODE_TEST_PREFIX/bin/fnm"
  chmod +x "$NODE_TEST_PREFIX/bin/fnm"
}

node_fixture_version() {
  install_sandbox_run "$NODE_TEST_PREFIX/bin/fnm" install "$1"
  rm "$NODE_TEST_STATE/fnm.log"
}

node_initialize() {
  # The real installation function runs without inherited shell configuration.
  # shellcheck disable=SC2016
  install_sandbox_run env "$@" bash -euo pipefail -c '
    source "$1/scripts/lib/homebrew.sh"
    source "$1/scripts/lib/node.sh"
    initialize_node
  ' _ "$SANDBOX_REPOSITORY"
}
