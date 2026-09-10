#!/usr/bin/env bash

sandbox_create() {
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

  SANDBOX_ROOT="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  SANDBOX_REPOSITORY="$SANDBOX_ROOT/repository with spaces"
  SANDBOX_HOME="$SANDBOX_ROOT/home"
  SANDBOX_CONFIG="$SANDBOX_ROOT/chezmoi.toml"

  SANDBOX_CHEZMOI="$(command -v chezmoi)" || {
    printf 'chezmoi must be available on PATH to run integration tests.\n' >&2
    return 1
  }

  mkdir -p "$SANDBOX_REPOSITORY" "$SANDBOX_HOME" \
    "$SANDBOX_ROOT/config" "$SANDBOX_ROOT/cache" \
    "$SANDBOX_ROOT/data" "$SANDBOX_ROOT/state" "$SANDBOX_ROOT/tmp"
  : > "$SANDBOX_CONFIG"

  # Include uncommitted configuration without Git data, dependencies, or caches.
  (
    set -o pipefail
    tar -C "$project_root" --exclude=.git --exclude=node_modules --exclude=./.cache -cf - . \
      | tar -C "$SANDBOX_REPOSITORY" -xf -
  )
}

sandbox_chezmoi() (
  cd "$SANDBOX_ROOT" || return

  env -i \
    PATH="${SANDBOX_PATH:-$PATH}" \
    HOME="$SANDBOX_HOME" \
    XDG_CONFIG_HOME="$SANDBOX_ROOT/config" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" \
    XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    TMPDIR="$SANDBOX_ROOT/tmp" \
    LC_ALL=C \
    "$SANDBOX_CHEZMOI" \
    --source "$SANDBOX_REPOSITORY" \
    --destination "$SANDBOX_HOME" \
    --config "$SANDBOX_CONFIG" \
    --cache "$SANDBOX_ROOT/cache/chezmoi" \
    --persistent-state "$SANDBOX_ROOT/state/chezmoi.boltdb" \
    --refresh-externals=never \
    --no-pager --no-tty \
    "$@"
)
