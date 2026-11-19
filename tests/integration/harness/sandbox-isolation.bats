#!/usr/bin/env bats

load '../../support/helpers/sandbox.bash'

@test "repository snapshots preserve current changes and exclude ignored local files" {
  local source="$BATS_TEST_TMPDIR/source"
  local snapshot="$BATS_TEST_TMPDIR/snapshot"
  mkdir -p "$source/.codex" "$BATS_TEST_TMPDIR/home"

  printf '.env\n.codex/\n' > "$source/.gitignore"
  printf 'original\n' > "$source/config"
  printf 'removed\n' > "$source/deleted"
  env -i HOME="$BATS_TEST_TMPDIR/home" PATH="$PATH" git -C "$source" init --quiet
  env -i HOME="$BATS_TEST_TMPDIR/home" PATH="$PATH" git -C "$source" add --all

  # Capture working-tree edits and new files, while keeping private local data out.
  printf 'modified\n' > "$source/config"
  printf 'new\n' > "$source/new-config"
  printf 'private fixture\n' > "$source/.env"
  printf 'private fixture\n' > "$source/.codex/config.local.toml"
  rm "$source/deleted"

  sandbox_copy_repository "$snapshot" "$source"

  [ "$(cat "$snapshot/config")" = modified ]
  [ "$(cat "$snapshot/new-config")" = new ]
  [ ! -e "$snapshot/deleted" ]
  [ ! -e "$snapshot/.git" ]
  [ ! -e "$snapshot/.env" ]
  [ ! -e "$snapshot/.codex" ]
}

@test "repository snapshots ignore inherited Git directory selection" {
  local source="$BATS_TEST_TMPDIR/source" external="$BATS_TEST_TMPDIR/external"
  local snapshot="$BATS_TEST_TMPDIR/snapshot"
  mkdir -p "$source" "$external" "$BATS_TEST_TMPDIR/home"
  printf 'source content\n' > "$source/config"
  printf 'config\n' > "$source/.gitignore"
  printf 'external content\n' > "$external/unrelated"
  env -i HOME="$BATS_TEST_TMPDIR/home" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 \
    /bin/bash -e -c '
      git -C "$1" init --quiet
      git -C "$1" add --force config .gitignore
      git -C "$2" init --quiet
      git -C "$2" add unrelated
    ' _ "$source" "$external"

  GIT_DIR="$external/.git" sandbox_copy_repository "$snapshot" "$source"

  [ -f "$snapshot/config" ]
  [ "$(cat "$snapshot/config")" = 'source content' ]
  [ ! -e "$snapshot/unrelated" ]
}

@test "repository snapshots honor personal HOME and XDG excludes" {
  local source="$BATS_TEST_TMPDIR/source" snapshot="$BATS_TEST_TMPDIR/snapshot"
  local personal_home="$BATS_TEST_TMPDIR/personal home" personal_config="$BATS_TEST_TMPDIR/personal config"
  mkdir -p "$source" "$personal_home" "$personal_config/git"
  printf 'tracked\n' > "$source/config"
  printf 'private fixture\n' > "$source/private.local"
  env -i HOME="$personal_home" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 \
    git -C "$source" init --quiet
  env -i HOME="$personal_home" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 \
    git -C "$source" add config
  printf 'private.local\n' > "$personal_home/ignore"
  git config --file "$personal_home/.gitconfig" core.excludesFile "$personal_home/ignore"

  HOME="$personal_home" XDG_CONFIG_HOME="$personal_config" GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null \
    sandbox_copy_repository "$snapshot/home" "$source"

  [ -f "$snapshot/home/config" ]
  [ ! -e "$snapshot/home/private.local" ]

  rm "$personal_home/.gitconfig"
  printf 'private.local\n' > "$personal_config/git/ignore"

  HOME="$personal_home" XDG_CONFIG_HOME="$personal_config" \
    sandbox_copy_repository "$snapshot/xdg" "$source"

  [ -f "$snapshot/xdg/config" ]
  [ ! -e "$snapshot/xdg/private.local" ]
}

@test "repository snapshots do not invoke personal filesystem monitors" {
  local source="$BATS_TEST_TMPDIR/source" snapshot="$BATS_TEST_TMPDIR/snapshot"
  local personal_home="$BATS_TEST_TMPDIR/monitor-home"
  mkdir -p "$source" "$personal_home"
  printf 'tracked\n' > "$source/config"
  env -i HOME="$personal_home" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 \
    git -C "$source" init --quiet
  env -i HOME="$personal_home" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 \
    git -C "$source" add config
  printf '#!/bin/sh\n: > "$0.ran"\n' > "$personal_home/monitor"
  chmod +x "$personal_home/monitor"
  git config --file "$personal_home/.gitconfig" core.fsmonitor "$personal_home/monitor"

  HOME="$personal_home" XDG_CONFIG_HOME="$personal_home/.config" \
    sandbox_copy_repository "$snapshot" "$source"

  [ -f "$snapshot/config" ]
  [ ! -e "$personal_home/monitor.ran" ]
}
