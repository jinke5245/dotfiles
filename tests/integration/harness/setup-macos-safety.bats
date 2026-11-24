#!/usr/bin/env bats

# Snippets run in a child shell with isolated environment variables.
# shellcheck disable=SC2016

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  MACOS_SETUP_HELPER="$BATS_TEST_DIRNAME/../../support/helpers/setup-macos.bash"
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

macos_setup_create() {
  # Relocate both prefixes before executing the real, guarded setup snippet.
  sed -e "s|/opt/homebrew|$BATS_TEST_TMPDIR/prefixes/apple|g" \
    -e "s|/usr/local|$BATS_TEST_TMPDIR/prefixes/intel|g" \
    "$MACOS_SETUP_HELPER" > "$BATS_TEST_TMPDIR/setup-macos.bash"
  printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/xcode-select"
  chmod +x "$BATS_TEST_TMPDIR/bin/xcode-select"

  env -i HOME="$BATS_TEST_TMPDIR/home" PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin" \
    RUNNER_TEMP="$BATS_TEST_TMPDIR" GITHUB_ACTIONS=true RUNNER_OS=macOS \
    RUNNER_ENVIRONMENT=github-hosted \
    /bin/bash --noprofile --norc -euo pipefail -c '
      source "$1"
      sandbox_copy_repository() { mkdir -p "$1"; }
      setup_macos_shell() { /bin/bash --noprofile --norc -euo pipefail -c "$@"; }
      setup_macos_create
    ' _ "$BATS_TEST_TMPDIR/setup-macos.bash"
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

@test "macOS setup removes only dangling completion links from either prefix" {
  local prefix directory
  for prefix in apple intel; do
    directory="$BATS_TEST_TMPDIR/prefixes/$prefix/share/zsh/site-functions"
    mkdir -p "$directory"
    printf 'keep completion\n' > "$directory/_regular"
    ln -s _regular "$directory/_valid"
    ln -s removed-azure-cli "$directory/_az"
  done

  run -0 macos_setup_create

  for prefix in apple intel; do
    directory="$BATS_TEST_TMPDIR/prefixes/$prefix/share/zsh/site-functions"
    [ ! -L "$directory/_az" ] || return 1
    [ -L "$directory/_valid" ] || return 1
    [ "$(cat "$directory/_valid")" = 'keep completion' ] || return 1
    [ -f "$directory/_regular" ] || return 1
  done
}

@test "macOS setup leaves absent completion directories untouched" {
  run -0 macos_setup_create

  [ ! -e "$BATS_TEST_TMPDIR/prefixes" ]
}
