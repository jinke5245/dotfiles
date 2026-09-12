#!/usr/bin/env bash

zsh_sandbox_create() {
  sandbox_create
  zsh_sandbox_prepare
  zsh_sandbox_apply "$@"
}

zsh_sandbox_prepare() {
  SANDBOX_ZSH="$(command -v zsh)" || {
    printf 'zsh must be available on PATH to run shell tests.\n' >&2
    return 1
  }
  SANDBOX_HOME="$SANDBOX_ROOT/home with spaces"
  SANDBOX_ZSH_PATH=/usr/bin:/bin
  mkdir -p "$SANDBOX_HOME"
  : > "$SANDBOX_ROOT/startup.log"

  # Disable network updates only in the test-owned startup environment.
  printf "zstyle ':omz:update' mode disabled\n" > "$SANDBOX_HOME/.zshenv"
}

zsh_sandbox_apply() {
  # Replace the test's relocated paths with freshly rendered configuration.
  if [ "$#" -eq 2 ]; then
    local template_data
    printf -v template_data '{"chezmoi":{"os":"%s","arch":"%s"}}' "$1" "$2"
    sandbox_chezmoi --override-data "$template_data" apply --force --exclude scripts || return
  else
    sandbox_chezmoi apply --force --exclude scripts || return
  fi

  # Relocate only installation paths in the applied copy, never the real system.
  # Shell logic stays intact; each test provisions its own Homebrew executables.
  if [ -f "$SANDBOX_HOME/.zprofile" ]; then
    sed \
      -e "s|/opt/homebrew|$SANDBOX_ROOT/prefixes/apple|g" \
      -e "s|/usr/local|$SANDBOX_ROOT/prefixes/intel|g" \
      -e "s|/home/linuxbrew/.linuxbrew|$SANDBOX_ROOT/prefixes/linux|g" \
      "$SANDBOX_HOME/.zprofile" > "$SANDBOX_ROOT/zprofile"
    mv "$SANDBOX_ROOT/zprofile" "$SANDBOX_HOME/.zprofile"
  fi
}

zsh_fixture_brew() {
  local prefix="$1"
  mkdir -p "$prefix/bin" "$prefix/sbin"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/brew.bash" "$prefix/bin/brew"
  chmod +x "$prefix/bin/brew"
}

zsh_fixture_oh_my_zsh() {
  mkdir -p "$SANDBOX_HOME/.oh-my-zsh"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/oh-my-zsh.zsh" \
    "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"
}

zsh_fixture_plugins() {
  local prefix="$1" plugin
  mkdir -p "$prefix/share/zsh-completions"
  printf '#compdef dotfiles-test\n_arguments "--example[Example option]"\n' \
    > "$prefix/share/zsh-completions/_dotfiles-test"

  # Homebrew exposes autojump through its shell-selecting profile entry point.
  mkdir -p "$prefix/etc/profile.d"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/plugin.zsh" "$prefix/etc/profile.d/autojump.sh"

  for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
    mkdir -p "$prefix/share/$plugin"
    cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/plugin.zsh" "$prefix/share/$plugin/$plugin.zsh"
  done
}

sandbox_zsh() (
  cd "$SANDBOX_ROOT" || return
  # Python-based integrations must not write bytecode into installed packages.
  env -i \
    PATH="$SANDBOX_ZSH_PATH" \
    HOME="$SANDBOX_HOME" \
    ZDOTDIR="$SANDBOX_HOME" \
    XDG_CONFIG_HOME="$SANDBOX_ROOT/config" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" \
    XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    TMPDIR="$SANDBOX_ROOT/tmp" \
    TERM=xterm-256color \
    LC_ALL=C \
    PYTHONDONTWRITEBYTECODE=1 \
    ZSH_TEST_BIN="$SANDBOX_ZSH" \
    ZSH_TEST_TRACE="$SANDBOX_ROOT/startup.log" \
    "$SANDBOX_ZSH" -d "$@"
)
