#!/usr/bin/env bash

# Scenario variables are consumed by Bats and the shared Zsh helper.
# shellcheck disable=SC2034

flow_suite_setup() {
  if [ -z "${OMZ_SOURCE:-}" ] || [ ! -f "$OMZ_SOURCE/oh-my-zsh.sh" ]; then
    printf 'Set OMZ_SOURCE to a local Oh My Zsh Git checkout before running e2e tests.\n' >&2
    return 1
  fi
  if ! command -v brew > /dev/null 2>&1; then
    printf 'Homebrew must already be available on PATH; e2e tests never install it.\n' >&2
    return 1
  fi

  # Snapshot committed upstream files once; the real installer fetches this local
  # repository. Neither local customizations nor changes to the source are needed.
  git -c init.defaultBranch=master init --bare --quiet "$BATS_FILE_TMPDIR/ohmyzsh.git"
  git -C "$BATS_FILE_TMPDIR/ohmyzsh.git" fetch --quiet --depth=1 \
    "$OMZ_SOURCE" HEAD:refs/heads/master
}

flow_sandbox_create() {
  sandbox_create
  zsh_sandbox_prepare

  local real_brew brew_directory
  real_brew="$(command -v brew)"
  brew_directory="$(dirname "$real_brew")"
  SANDBOX_PATH="$SANDBOX_ROOT/bin:$brew_directory:/usr/bin:/bin"
  SANDBOX_ZSH_PATH="$SANDBOX_PATH"
  mkdir -p "$SANDBOX_ROOT/bin" "$SANDBOX_HOME/.test-upstream"

  # Keep the real Homebrew in place, but permit only read-only calls through the
  # adapter. The installer may check dependencies without changing host packages.
  printf '%s\n' "$real_brew" > "$SANDBOX_HOME/.test-upstream/brew-path"
  ln -s "$SANDBOX_ZSH" "$SANDBOX_ROOT/bin/zsh"
  local command
  for command in brew curl; do
    cp "$SANDBOX_REPOSITORY/tests/fixtures/flow/$command.bash" "$SANDBOX_ROOT/bin/$command"
    chmod +x "$SANDBOX_ROOT/bin/$command"
  done

  git -C "$BATS_FILE_TMPDIR/ohmyzsh.git" show master:tools/install.sh \
    > "$SANDBOX_HOME/.test-upstream/install.sh"

  # Rewrite only the upstream fetch URL inside this temporary HOME. Git runs for
  # real, but all network protocols are disabled for the installation and shells.
  git config --file "$SANDBOX_HOME/.gitconfig" \
    "url.file://$BATS_FILE_TMPDIR/ohmyzsh.git.insteadOf" https://github.com/ohmyzsh/ohmyzsh.git
  git config --file "$SANDBOX_HOME/.gitconfig" protocol.allow never
  git config --file "$SANDBOX_HOME/.gitconfig" protocol.file.allow always

  FLOW_BREW_PREFIX="$(env -i HOME="$SANDBOX_HOME" PATH="$SANDBOX_PATH" brew --prefix)"
}
