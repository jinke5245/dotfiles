#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'
load '../../helpers/node.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  node_sandbox_create
}

@test "the entry point prepares Node after Bundle and before Oh My Zsh" {
  run -0 install_sandbox_run bash "$SANDBOX_REPOSITORY/scripts/install.sh"

  local events
  events="$(cat "$NODE_TEST_STATE/events.log")"
  [[ "$events" == *$'bundle install\nfnm env --shell bash'* ]] || return 1
  [[ "$events" == *$'fnm use default\ndownload oh-my-zsh'* ]] || return 1
  [ -x "$NODE_TEST_DATA/aliases/default/bin/pnpm" ]
}

@test "a new installation selects the latest LTS and enables bundled Corepack" {
  run -0 node_initialize

  [ "$(readlink "$NODE_TEST_DATA/aliases/default")" = "$NODE_TEST_DATA/node-versions/v24.0.0/installation" ]
  [ -x "$NODE_TEST_DATA/aliases/default/bin/pnpm" ]
  [ ! -e "$NODE_TEST_STATE/npm.log" ]
  [ "$(cat "$NODE_TEST_STATE/selected-fnm")" = "$NODE_TEST_PREFIX/bin/fnm" ]
}

@test "an existing default is preserved even when a newer Node is installed" {
  node_fixture_version v22.22.2
  node_fixture_version v24.0.0
  local previous
  previous="$(readlink "$NODE_TEST_DATA/aliases/default")"

  run -0 node_initialize

  [ "$(readlink "$NODE_TEST_DATA/aliases/default")" = "$previous" ]
  [ -x "$previous/bin/pnpm" ]
  [ ! -e "$NODE_TEST_DATA/node-versions/v24.0.0/installation/bin/pnpm" ]
  [[ "$(cat "$NODE_TEST_STATE/fnm.log")" != *install* ]]
}

@test "installed versions without a default receive an LTS default" {
  node_fixture_version v22.22.2
  rm "$NODE_TEST_DATA/aliases/default"

  run -0 node_initialize

  [ "$(readlink "$NODE_TEST_DATA/aliases/default")" = "$NODE_TEST_DATA/node-versions/v24.0.0/installation" ]
  [ -x "$NODE_TEST_DATA/node-versions/v22.22.2/installation/bin/node" ]
}

@test "missing Corepack is installed through the selected Node's npm" {
  touch "$NODE_TEST_STATE/without-bundled-corepack"

  run -0 node_initialize

  [ "$(cat "$NODE_TEST_STATE/npm.log")" = "$NODE_TEST_STATE/fnm-shell/bin/npm" ]
  [ "$(cat "$NODE_TEST_STATE/corepack.log")" = "$NODE_TEST_STATE/fnm-shell/bin/corepack" ]
  [ -x "$NODE_TEST_DATA/aliases/default/bin/pnpm" ]
}

@test "a custom fnm directory is respected" {
  local directory="$SANDBOX_ROOT/custom fnm"

  run -0 node_initialize FNM_DIR="$directory"

  [ -x "$directory/aliases/default/bin/pnpm" ]
  [ ! -e "$NODE_TEST_DATA" ]
}

@test "an inherited fnm Corepack option cannot fail before Corepack is prepared" {
  touch "$NODE_TEST_STATE/without-bundled-corepack"

  run -0 node_initialize FNM_COREPACK_ENABLED=true

  [ -x "$NODE_TEST_DATA/aliases/default/bin/pnpm" ]
}

@test "a broken default stops preparation without replacing it" {
  node_fixture_version v22.22.2
  local previous
  previous="$(readlink "$NODE_TEST_DATA/aliases/default")"
  rm -r "$previous"

  run -1 node_initialize

  [ "$(readlink "$NODE_TEST_DATA/aliases/default")" = "$previous" ]
  [[ "$(cat "$NODE_TEST_STATE/fnm.log")" != *install* ]] || return 1
  [ ! -e "$NODE_TEST_STATE/npm.log" ]
}

@test "preparation preserves project environments and the user's npm prefix" {
  mkdir -p "$SANDBOX_ROOT/project/.venv" "$SANDBOX_HOME/custom npm"
  printf 'prefix=%s\n' "$SANDBOX_HOME/custom npm" > "$SANDBOX_HOME/.npmrc"
  printf '22\n' > "$SANDBOX_ROOT/.node-version"
  printf 'keep\n' > "$SANDBOX_ROOT/project/.venv/marker"
  cp "$SANDBOX_HOME/.npmrc" "$SANDBOX_ROOT/npmrc.before"
  touch "$NODE_TEST_STATE/without-bundled-corepack"

  run -0 node_initialize

  [ "$(readlink "$NODE_TEST_DATA/aliases/default")" = "$NODE_TEST_DATA/node-versions/v24.0.0/installation" ]
  [ ! -e "$SANDBOX_HOME/custom npm/bin" ]
  cmp "$SANDBOX_HOME/.npmrc" "$SANDBOX_ROOT/npmrc.before"
  [ "$(cat "$SANDBOX_ROOT/.node-version")" = 22 ]
  [ "$(cat "$SANDBOX_ROOT/project/.venv/marker")" = keep ]
}

@test "repeated preparation does not reinstall Node or Corepack" {
  touch "$NODE_TEST_STATE/without-bundled-corepack"
  node_initialize
  cp -p "$NODE_TEST_DATA/aliases/default/bin/corepack" "$SANDBOX_ROOT/corepack.before"

  # Any new installation on the second run must fail the test.
  touch "$NODE_TEST_STATE/fail-fnm-install" "$NODE_TEST_STATE/fail-npm"

  run -0 node_initialize

  cmp "$NODE_TEST_DATA/aliases/default/bin/corepack" "$SANDBOX_ROOT/corepack.before"
  [ ! "$NODE_TEST_DATA/aliases/default/bin/corepack" -nt "$SANDBOX_ROOT/corepack.before" ]
  [ ! "$NODE_TEST_DATA/aliases/default/bin/corepack" -ot "$SANDBOX_ROOT/corepack.before" ]
  [ -x "$NODE_TEST_DATA/aliases/default/bin/pnpm" ]
}

@test "a failed fnm environment is not evaluated" {
  touch "$NODE_TEST_STATE/fail-fnm-env"

  run -95 node_initialize

  [ ! -e "$SANDBOX_HOME/partial-fnm-env" ]
  [ ! -e "$NODE_TEST_DATA/aliases/default" ]
  [ ! -e "$NODE_TEST_STATE/corepack.log" ]
}

@test "a Node download failure stops preparation" {
  touch "$NODE_TEST_STATE/fail-fnm-install"

  run -96 node_initialize

  [ ! -e "$NODE_TEST_STATE/npm.log" ]
  [ ! -e "$NODE_TEST_STATE/corepack.log" ]
}

@test "a default activation failure cannot fall back to other tools on PATH" {
  node_fixture_version v22.22.2
  touch "$NODE_TEST_STATE/fail-fnm-use"

  run -97 node_initialize

  [ ! -e "$NODE_TEST_STATE/npm.log" ]
  [ ! -e "$NODE_TEST_STATE/corepack.log" ]
}

@test "a failed Corepack installation is propagated before enabling pnpm" {
  touch "$NODE_TEST_STATE/without-bundled-corepack" "$NODE_TEST_STATE/fail-npm"

  run -98 node_initialize

  [ ! -e "$NODE_TEST_STATE/corepack.log" ]
  [ ! -e "$NODE_TEST_DATA/aliases/default/bin/pnpm" ]
}

@test "a Corepack enable failure stops apply before managed files change" {
  touch "$NODE_TEST_STATE/fail-corepack"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run -99 node_initialize
  run ! sandbox_chezmoi apply --force

  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
  [ ! -e "$NODE_TEST_STATE/oh-my-zsh.log" ]
}

@test "Node preparation does not change the caller's environment" {
  # Shell initialization is confined to the function's subprocess.
  # shellcheck disable=SC2016
  run -0 install_sandbox_run bash -euo pipefail -c '
    source "$1/scripts/lib/homebrew.sh"
    source "$1/scripts/lib/node.sh"
    previous_path="$PATH"
    initialize_node
    [ "$PATH" = "$previous_path" ]
    [ -z "${FNM_MULTISHELL_PATH:-}" ]
  ' _ "$SANDBOX_REPOSITORY"
}
