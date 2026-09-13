#!/usr/bin/env bats

# Shell snippets expand only inside the isolated login shell.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'
load '../helpers/zsh.bash'
load '../helpers/flow.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
  flow_suite_setup
}

setup() {
  flow_sandbox_create
}

@test "login shells discover shared defaults and the initialized local Git identity" {
  sandbox_chezmoi apply

  run -0 sandbox_zsh -lc 'git config --show-origin --get user.useConfigOnly'

  [ "$output" = "$(printf 'file:%s\ttrue' "$SANDBOX_HOME/.config/git/config")" ]
  [ -f "$SANDBOX_HOME/.config/git/config.local" ]

  run -0 sandbox_zsh -lc 'git config --show-origin --get user.name'
  [ "$output" = "$(printf 'file:%s\tDotfiles test' "$SANDBOX_HOME/.config/git/config.local")" ]

  run -0 sandbox_zsh -lc 'git config --get user.email'
  [ "$output" = test@example.invalid ]
}

@test "first and repeated apply preserve local Git identity and overrides" {
  mkdir -p "$SANDBOX_HOME/.config/git"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/git/local.config" "$SANDBOX_HOME/.config/git/config.local"
  touch -t 200001010000 "$SANDBOX_HOME/.config/git/config.local"
  cp -p "$SANDBOX_HOME/.config/git/config.local" "$SANDBOX_ROOT/local.before"

  local attempt
  for attempt in first repeated; do
    run -0 sandbox_chezmoi apply

    cmp "$SANDBOX_HOME/.config/git/config.local" "$SANDBOX_ROOT/local.before"
    [ ! "$SANDBOX_HOME/.config/git/config.local" -nt "$SANDBOX_ROOT/local.before" ]
    [ ! "$SANDBOX_HOME/.config/git/config.local" -ot "$SANDBOX_ROOT/local.before" ]
    run -0 sandbox_zsh -lc '
      [[ $(git config --get user.name) = "Dotfiles test" ]] &&
      [[ $(git config --get user.email) = test@example.invalid ]] &&
      [[ $(git config --get core.quotePath) = true ]]
    '
    [ -z "$output" ]
  done
}

@test "real LFS filters round-trip binary content and project setup preserves global files" {
  mkdir -p "$SANDBOX_HOME/.config/git"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/git/local.config" "$SANDBOX_HOME/.config/git/config.local"
  sandbox_chezmoi apply

  run -0 sandbox_zsh -lc '
    source "$1"
    git_flow_check
  ' _ "$SANDBOX_REPOSITORY/tests/helpers/git-flow.bash"
}
