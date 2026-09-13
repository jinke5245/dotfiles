#!/usr/bin/env bash

sandbox_create() {
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

  sandbox_copy_repository "$SANDBOX_REPOSITORY"
}

sandbox_copy_repository() {
  local project_root
  project_root="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
  mkdir -p "$1"

  # Copy current contents, including new files, without ignored local data.
  (
    set -o pipefail
    git -C "$project_root" ls-files --cached --others --exclude-standard -z \
      | while IFS= read -r -d '' file; do
        # Deleted tracked files remain in the index until staged.
        if [ -e "$project_root/$file" ] || [ -L "$project_root/$file" ]; then
          printf '%s\0' "$file"
        fi
      done \
      | tar -C "$project_root" --null --no-recursion --exclude=.git \
        --exclude=node_modules --exclude=.cache -T - -cf - \
      | tar -C "$1" -xf -
  )
}

sandbox_chezmoi() (
  cd "$SANDBOX_ROOT" || return

  env -i \
    PATH="${SANDBOX_PATH:-$PATH}" \
    HOME="$SANDBOX_HOME" \
    XDG_CONFIG_HOME="$SANDBOX_HOME/.config" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" \
    XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    TMPDIR="$SANDBOX_ROOT/tmp" \
    LC_ALL=C \
    GIT_CONFIG_NOSYSTEM=1 \
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

sandbox_init() {
  # Initialize with real Git before testing apply; installer substitutes remain
  # available for subsequent commands through SANDBOX_PATH.
  SANDBOX_PATH="$PATH" sandbox_chezmoi init --config-path "$SANDBOX_CONFIG" \
    --promptString 'User name=Dotfiles test,User email=test@example.invalid' < /dev/null
}
