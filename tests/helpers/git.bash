#!/usr/bin/env bash

git_sandbox_create() {
  sandbox_create
  SANDBOX_GIT="$(command -v git)"
  SANDBOX_GIT_WORKTREE="$SANDBOX_ROOT/worktree"
  SANDBOX_GIT_LOCAL="$SANDBOX_HOME/.config/git/config.local"
  SANDBOX_GIT_SYSTEM="$SANDBOX_ROOT/git-system.config"
  mkdir -p "$SANDBOX_HOME/.config/git" "$SANDBOX_ROOT/bin"
  : > "$SANDBOX_GIT_SYSTEM"

  sandbox_chezmoi apply --exclude scripts || return
  sandbox_git init --quiet "$SANDBOX_GIT_WORKTREE"
}

git_sandbox_run() (
  cd "$SANDBOX_ROOT" || return

  # Let Git discover the deployed XDG file itself. Do not inherit host identity,
  # credentials, system configuration, or Git environment overrides.
  env -i \
    PATH="$SANDBOX_ROOT/bin:$PATH" \
    HOME="$SANDBOX_HOME" \
    XDG_CONFIG_HOME="$SANDBOX_HOME/.config" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" \
    XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    TMPDIR="$SANDBOX_ROOT/tmp" \
    LC_ALL=C \
    GIT_CONFIG_SYSTEM="$SANDBOX_GIT_SYSTEM" \
    GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS=/usr/bin/false \
    GIT_ALLOW_PROTOCOL=file \
    "$@"
)

sandbox_git() {
  git_sandbox_run "$SANDBOX_GIT" "$@"
}

git_identity_initialize() {
  # Shell snippets expand only in the isolated child process.
  # shellcheck disable=SC2016
  git_sandbox_run bash -euo pipefail -c '
    source "$1/scripts/lib/git.sh"
    shift
    initialize_git_identity "$@"
  ' _ "$SANDBOX_REPOSITORY" "$@"
}

git_assert_local_identity() {
  run -0 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --includes --get user.name
  [ "$output" = "$1" ] || return

  run -0 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --includes --get user.email
  [ "$output" = "$2" ]
}

git_fixture_identity() {
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" user.name 'Dotfiles test'
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" user.email test@example.invalid
}

git_fixture_included_identity() {
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" include.path identity.config
  sandbox_git config --file "$SANDBOX_HOME/.config/git/identity.config" user.name 'Included Name'
  sandbox_git config --file "$SANDBOX_HOME/.config/git/identity.config" user.email included@example.invalid
}
