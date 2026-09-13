#!/usr/bin/env bash

identity_sandbox_create() {
  sandbox_create
  SANDBOX_GIT="$(command -v git)"
  SANDBOX_GIT_SYSTEM="$SANDBOX_ROOT/git-system.config"
  : > "$SANDBOX_GIT_SYSTEM"
}

identity_init() {
  sandbox_chezmoi init --config-path "$SANDBOX_CONFIG" "$@"
}

identity_assert_data() {
  run -0 sandbox_chezmoi execute-template '{{ .user.name }}'
  [ "$output" = "$1" ] || return

  run -0 sandbox_chezmoi execute-template '{{ .user.email }}'
  [ "$output" = "$2" ]
}

identity_saved_data() {
  cat > "$SANDBOX_CONFIG" << 'TOML'
[data.user]
name = "Saved Name"
email = "saved@example.invalid"
TOML
}

identity_xdg_configuration() {
  local directory="$SANDBOX_HOME/.config/git"
  mkdir -p "$directory"
  sandbox_git config --file "$directory/config" include.path config.local
  sandbox_git config --file "$directory/config.local" user.name 'Included Name'
  sandbox_git config --file "$directory/config.local" user.email included@example.invalid
}
