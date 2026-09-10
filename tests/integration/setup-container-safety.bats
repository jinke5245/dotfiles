#!/usr/bin/env bats

setup_file() {
  bats_require_minimum_version 1.5.0
}

@test "container setup reports missing Docker before attempting installation" {
  mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/home"

  # An empty PATH makes Docker unavailable without changing the host tools.
  # The snippet expands only in the isolated child shell.
  # shellcheck disable=SC2016
  run -1 env -i HOME="$BATS_TEST_TMPDIR/home" PATH="$BATS_TEST_TMPDIR/bin" \
    /bin/bash --noprofile --norc -c \
    'source "$1"; setup_container_create' _ "$BATS_TEST_DIRNAME/../helpers/setup.bash"

  [[ "$output" == *'Docker is required'* ]]
  [[ "$output" != *'command not found'* ]]
}
