#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  USAGE_GIT="$(command -v git)"
  install_sandbox_create
  # Apply now initializes Git identity; keep Git real and installers offline.
  ln -sf "$USAGE_GIT" "$SANDBOX_ROOT/bin/git"
}

usage_chezmoi() {
  # Follow the documented command with normal config discovery in a temporary
  # HOME. The existing sandbox still isolates installers, caches, and state.
  install_sandbox_run env -u XDG_CONFIG_HOME \
    GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0 \
    "$SANDBOX_CHEZMOI" --source "$SANDBOX_REPOSITORY" --no-tty "$@"
}

@test "documented initialization saves identity at the default config path" {
  local config="$SANDBOX_HOME/.config/chezmoi/chezmoi.toml"
  local git_config="$SANDBOX_HOME/.config/git/config.local"

  run -0 usage_chezmoi init \
    --promptString 'User name=Dotfiles test,User email=test@example.invalid' < /dev/null
  [ -f "$config" ]
  cp "$config" "$SANDBOX_ROOT/config.before"

  # Saved inputs support repeat initialization before Git has any identity.
  run -0 usage_chezmoi init < /dev/null
  cmp "$config" "$SANDBOX_ROOT/config.before"
  run -0 usage_chezmoi diff < /dev/null
  [ ! -e "$git_config" ]
  [ ! -e "$SANDBOX_HOME/.ssh" ]
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh" ]

  run -0 usage_chezmoi apply < /dev/null
  run -0 install_sandbox_run "$USAGE_GIT" config --file "$git_config" user.name
  [ "$output" = 'Dotfiles test' ]
  run -0 install_sandbox_run "$USAGE_GIT" config --file "$git_config" user.email
  [ "$output" = test@example.invalid ]
  [ "$(cut -d ' ' -f 3- "$SANDBOX_HOME/.ssh/id_ed25519.pub")" = test@example.invalid ]

  run -0 usage_chezmoi apply < /dev/null
  cmp "$config" "$SANDBOX_ROOT/config.before"
  run -0 usage_chezmoi diff --exclude scripts < /dev/null
  [ -z "$output" ]
}
