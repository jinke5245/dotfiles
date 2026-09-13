#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'
load '../../helpers/git.bash'
load '../../helpers/identity.bash'
load '../../helpers/ssh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
  SANDBOX_SSH_KEY="$SANDBOX_HOME/.ssh/id_ed25519"
  SANDBOX_GIT="$(command -v git)"
  SANDBOX_GIT_SYSTEM="$SANDBOX_ROOT/git-system.config"
  : > "$SANDBOX_GIT_SYSTEM"

  # Identity initialization uses real Git; installers still use offline fixtures.
  ln -sf "$SANDBOX_GIT" "$SANDBOX_ROOT/bin/git"
}

@test "previewing configuration does not initialize SSH keys" {
  run -0 sandbox_chezmoi diff

  [ ! -e "$SANDBOX_HOME/.ssh" ]
}

@test "apply initializes SSH keys without making them managed configuration" {
  run -0 sandbox_chezmoi apply

  ssh_assert_key_pair
  cmp "$SANDBOX_REPOSITORY/home/dot_zshrc" "$SANDBOX_HOME/.zshrc"

  run -0 sandbox_chezmoi managed

  [[ "$output" != *'.ssh'* ]]
}

@test "apply uses the saved email even after the global Git email changes" {
  identity_saved_data
  sandbox_git config --global user.email git@example.invalid

  run -0 sandbox_chezmoi diff
  [ ! -e "$SANDBOX_HOME/.ssh" ]

  run -0 sandbox_chezmoi apply

  ssh_assert_key_pair
  [ "$(cut -d ' ' -f 3- "$SANDBOX_SSH_KEY.pub")" = saved@example.invalid ]
}

@test "apply without saved user data keeps the default comment despite a Git email" {
  sandbox_git config --global user.email git@example.invalid

  run -0 sandbox_chezmoi apply

  [ "$(cut -d ' ' -f 3- "$SANDBOX_SSH_KEY.pub")" = "$(id -un)@$(hostname)" ]
}

@test "apply with an empty saved email keeps the default comment despite a Git email" {
  cat > "$SANDBOX_CONFIG" << 'TOML'
[data.user]
name = "Saved Name"
email = ""
TOML
  sandbox_git config --global user.email git@example.invalid

  run -0 sandbox_chezmoi apply

  [ "$(cut -d ' ' -f 3- "$SANDBOX_SSH_KEY.pub")" = "$(id -un)@$(hostname)" ]
}

@test "repeated apply preserves the key pair after the saved email changes" {
  identity_saved_data
  sandbox_chezmoi apply
  chmod 400 "$SANDBOX_SSH_KEY"
  chmod 640 "$SANDBOX_SSH_KEY.pub"
  touch -t 200001010000 "$SANDBOX_SSH_KEY" "$SANDBOX_SSH_KEY.pub"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  cp -p "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"

  run -0 sandbox_chezmoi --override-data '{"user":{"email":"changed@example.invalid"}}' apply

  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  ssh_assert_preserved "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"
}

@test "a later apply recovers a deleted public key without changing the private key" {
  sandbox_chezmoi apply
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  cp "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/expected.pub"
  rm "$SANDBOX_SSH_KEY.pub"
  identity_saved_data

  run -0 sandbox_chezmoi apply

  ssh_assert_key_pair
  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  [ "$(ssh_file_mode "$SANDBOX_SSH_KEY.pub")" = 644 ]
  cmp "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/expected.pub"
}

@test "a lone public key stops apply before managed configuration changes" {
  ssh_fixture_key
  rm "$SANDBOX_SSH_KEY"
  cp -p "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run ! sandbox_chezmoi apply --force

  [[ "$output" == *id_ed25519.pub* ]]
  [ ! -e "$SANDBOX_SSH_KEY" ]
  ssh_assert_preserved "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"
  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
}

@test "a private-key recovery failure stops apply without creating a public key" {
  mkdir -m 700 "$SANDBOX_HOME/.ssh"
  printf 'invalid private key\n' > "$SANDBOX_SSH_KEY"
  chmod 600 "$SANDBOX_SSH_KEY"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run ! sandbox_chezmoi apply --force

  [[ "$output" == *id_ed25519* ]]
  [ ! -e "$SANDBOX_SSH_KEY.pub" ]
  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
}

@test "a conflicting public-key path stops apply before managed configuration changes" {
  ssh_fixture_key
  rm "$SANDBOX_SSH_KEY.pub"
  mkdir "$SANDBOX_SSH_KEY.pub"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run ! sandbox_chezmoi apply --force

  [[ "$output" == *id_ed25519.pub* ]]
  [ -d "$SANDBOX_SSH_KEY.pub" ]
  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
}
