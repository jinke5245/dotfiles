#!/usr/bin/env bats

# Snippets run in a child shell with isolated environment variables.
# shellcheck disable=SC2016

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  MACOS_SETUP_HELPER="$BATS_TEST_DIRNAME/../helpers/setup-macos.bash"
  mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/home"
  # Exercise the macOS guards even when this suite runs on Linux.
  printf '#!/bin/sh\nprintf "Darwin\\n"\n' > "$BATS_TEST_TMPDIR/bin/uname"
  chmod +x "$BATS_TEST_TMPDIR/bin/uname"
}

macos_setup_guard() {
  env -i HOME="$BATS_TEST_TMPDIR/home" \
    PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin" \
    RUNNER_TEMP="$BATS_TEST_TMPDIR" "$@" \
    /bin/bash -c 'source "$1"; setup_macos_require_runner' _ "$MACOS_SETUP_HELPER"
}

@test "macOS setup rejects a local invocation" {
  run -1 macos_setup_guard
  [[ "$output" == *'GitHub-hosted macOS runner'* ]]
}

@test "macOS setup rejects act and self-hosted runners" {
  run -1 macos_setup_guard GITHUB_ACTIONS=true RUNNER_OS=macOS \
    RUNNER_ENVIRONMENT=github-hosted ACT=true

  run -1 macos_setup_guard GITHUB_ACTIONS=true RUNNER_OS=macOS \
    RUNNER_ENVIRONMENT=self-hosted
}

@test "macOS setup permits the GitHub-hosted runner context" {
  # Only check the predicate; this test never calls setup or an uninstaller.
  run -0 macos_setup_guard GITHUB_ACTIONS=true RUNNER_OS=macOS \
    RUNNER_ENVIRONMENT=github-hosted
  [ -z "$output" ]
}
