#!/usr/bin/env bash

# Shell snippets and generated fixtures expand in their child processes.
# shellcheck disable=SC2016

install_sandbox_create() {
  sandbox_create

  # Keep paths with spaces to exercise quoting in the entry point and adapter.
  SANDBOX_HOME="$SANDBOX_ROOT/home with spaces"
  SANDBOX_PATH="$SANDBOX_ROOT/bin:/usr/bin:/bin"

  # Fixtures read failure switches and write call logs under .install-test.
  mkdir -p "$SANDBOX_HOME/.install-test" "$SANDBOX_ROOT/bin"
  install_sandbox_platform Linux

  # Shadow external commands so tests cannot reach the network or package manager.
  local fixture
  for fixture in apt-get curl git sudo uname; do
    cp "$SANDBOX_REPOSITORY/tests/fixtures/install/$fixture.bash" "$SANDBOX_ROOT/bin/$fixture"
    chmod +x "$SANDBOX_ROOT/bin/$fixture"
  done

  # curl serves these scripts instead of downloading the real installers.
  for fixture in homebrew oh-my-zsh; do
    cp "$SANDBOX_REPOSITORY/tests/fixtures/install/$fixture-installer.bash" \
      "$SANDBOX_HOME/.install-test/$fixture-installer.bash"
  done
  cp "$SANDBOX_REPOSITORY/tests/fixtures/install/brew.bash" "$SANDBOX_HOME/.install-test/brew.bash"

  for fixture in fnm npm corepack unexpected-command; do
    cp "$SANDBOX_REPOSITORY/tests/fixtures/install/$fixture.bash" "$SANDBOX_HOME/.install-test/$fixture.bash"
  done

  # Catch accidental use of an unrelated runtime or package manager on PATH.
  for fixture in fnm node npm corepack pnpm go uv; do
    cp "$SANDBOX_HOME/.install-test/unexpected-command.bash" "$SANDBOX_ROOT/bin/$fixture"
    chmod +x "$SANDBOX_ROOT/bin/$fixture"
  done

  # Redirect fixed system prefixes only in the disposable repository copy.
  sed \
    -e "s|/opt/homebrew|$SANDBOX_ROOT/prefixes/apple|g" \
    -e "s|/usr/local|$SANDBOX_ROOT/prefixes/intel|g" \
    -e "s|/home/linuxbrew/.linuxbrew|$SANDBOX_ROOT/prefixes/linux|g" \
    "$SANDBOX_REPOSITORY/scripts/lib/homebrew.sh" > "$SANDBOX_ROOT/homebrew.sh"
  mv "$SANDBOX_ROOT/homebrew.sh" "$SANDBOX_REPOSITORY/scripts/lib/homebrew.sh"
}

install_sandbox_run() (
  cd "$SANDBOX_ROOT" || return

  env -i \
    HOME="$SANDBOX_HOME" \
    PATH="$SANDBOX_PATH" \
    XDG_CONFIG_HOME="$SANDBOX_ROOT/config" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" \
    XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    TMPDIR="$SANDBOX_ROOT/tmp" \
    LC_ALL=C \
    "$@"
)

install_sandbox_library() {
  # The child process sources the library, then calls the requested function.
  install_sandbox_run /bin/bash -c 'source "$1" && "$2"' _ \
    "$SANDBOX_REPOSITORY/scripts/lib/$1.sh" "$2"
}

install_sandbox_platform() {
  printf '%s\n' "$1" > "$SANDBOX_HOME/.install-test/platform"

  # The installer fixture writes to the corresponding temporary prefix.
  case "$1" in
    Darwin) printf '%s\n' "$SANDBOX_ROOT/prefixes/apple" ;;
    Linux) printf '%s\n' "$SANDBOX_ROOT/prefixes/linux" ;;
  esac > "$SANDBOX_HOME/.install-test/prefix"
}

install_fixture_brew() {
  mkdir -p "$1/bin"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/install/brew.bash" "$1/bin/brew"
  chmod +x "$1/bin/brew"
}
