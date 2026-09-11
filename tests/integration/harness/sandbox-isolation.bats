#!/usr/bin/env bats

load '../../helpers/sandbox.bash'

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
