#!/usr/bin/env bats

# Git setup and commits stay inside temporary repositories.
# shellcheck disable=SC2016

load '../../support/helpers/sandbox.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

@test "offline E2E snapshots ignore an inherited Git repository" {
  sandbox_create
  local upstream="$SANDBOX_ROOT/ohmyzsh" external="$SANDBOX_ROOT/external"
  mkdir -p "$upstream" "$external" "$SANDBOX_ROOT/bin" "$SANDBOX_ROOT/flow"
  printf '# fixture\n' > "$upstream/oh-my-zsh.sh"
  printf '#!/bin/sh\nexit 0\n' > "$SANDBOX_ROOT/bin/brew"
  chmod +x "$SANDBOX_ROOT/bin/brew"
  env -i HOME="$SANDBOX_HOME" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 \
    /bin/bash -e -c '
      git -C "$1" init --quiet
      git -C "$1" add oh-my-zsh.sh
      git -C "$1" -c user.name="Test fixture" -c user.email=test@example.invalid \
        commit --quiet -m fixture
      git -C "$2" init --quiet --initial-branch=main
    ' _ "$upstream" "$external"

  run -0 env -i HOME="$SANDBOX_HOME" PATH="$SANDBOX_ROOT/bin:$PATH" \
    GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file GIT_DIR="$external/.git" \
    OMZ_SOURCE="$upstream" BATS_FILE_TMPDIR="$SANDBOX_ROOT/flow" \
    /bin/bash -e -c 'source "$1/tests/support/helpers/flow.bash"; flow_suite_setup' _ "$SANDBOX_REPOSITORY"

  [ ! -e "$external/.git/FETCH_HEAD" ]
  [ ! -e "$external/.git/refs/heads/master" ]
  [ -s "$SANDBOX_ROOT/flow/ohmyzsh.git/refs/heads/master" ]
}
