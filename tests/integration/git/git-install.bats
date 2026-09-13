#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'
load '../../helpers/git.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
  SANDBOX_GIT="$(command -v git)"
  SANDBOX_GIT_LOCAL="$SANDBOX_HOME/.config/git/config.local"
  SANDBOX_GIT_SYSTEM="$SANDBOX_ROOT/git-system.config"
  : > "$SANDBOX_GIT_SYSTEM"

  # Git configuration stays real; dependency installers use offline fixtures.
  ln -sf "$SANDBOX_GIT" "$SANDBOX_ROOT/bin/git"
  sandbox_init
}

@test "apply initializes local Git identity from saved inputs after a read-only preview" {
  run -0 sandbox_chezmoi diff
  [ ! -e "$SANDBOX_GIT_LOCAL" ]

  run -0 sandbox_chezmoi apply

  git_assert_local_identity 'Dotfiles test' test@example.invalid
  [ -f "$SANDBOX_HOME/.ssh/id_ed25519" ]
  [ -f "$SANDBOX_HOME/.zprofile" ]

  run -0 sandbox_chezmoi managed
  [[ "$output" != *'config.local'* ]]
}

@test "repeated apply preserves manually changed Git identity and file timestamps" {
  sandbox_chezmoi apply
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" user.name 'Manual Name'
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" user.email manual@example.invalid
  touch -t 200001010000 "$SANDBOX_GIT_LOCAL"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"

  run -0 sandbox_chezmoi apply

  git_assert_local_identity 'Manual Name' manual@example.invalid
  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  [ ! "$SANDBOX_GIT_LOCAL" -nt "$SANDBOX_ROOT/local.before" ]
  [ ! "$SANDBOX_GIT_LOCAL" -ot "$SANDBOX_ROOT/local.before" ]
}

@test "invalid local Git configuration stops apply before SSH and managed configuration" {
  mkdir -p "$(dirname "$SANDBOX_GIT_LOCAL")"
  printf '[broken\n' > "$SANDBOX_GIT_LOCAL"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"

  run ! sandbox_chezmoi apply

  [[ "$output" == *'config.local'* ]]
  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  [ ! -e "$SANDBOX_HOME/.ssh" ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
}

@test "saved identity reaches Git without interpreting shell syntax" {
  local name="O'Brien"
  name+=' 李 "Test" \ $(touch "$HOME/injected")'
  sandbox_git config --global user.name "$name"
  sandbox_git config --global user.email quoted@example.invalid
  sandbox_init
  cp -p "$SANDBOX_HOME/.gitconfig" "$SANDBOX_ROOT/global.before"

  run -0 sandbox_chezmoi apply

  git_assert_local_identity "$name" quoted@example.invalid
  [ ! -e "$SANDBOX_HOME/injected" ]
  cmp "$SANDBOX_HOME/.gitconfig" "$SANDBOX_ROOT/global.before"
}
