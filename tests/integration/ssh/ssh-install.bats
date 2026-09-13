#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'
load '../../helpers/ssh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
  SANDBOX_SSH_KEY="$SANDBOX_HOME/.ssh/id_ed25519"
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

@test "repeated apply preserves the generated SSH key pair" {
  sandbox_chezmoi apply
  chmod 400 "$SANDBOX_SSH_KEY"
  chmod 640 "$SANDBOX_SSH_KEY.pub"
  touch -t 200001010000 "$SANDBOX_SSH_KEY" "$SANDBOX_SSH_KEY.pub"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  cp -p "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"

  run -0 sandbox_chezmoi apply

  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  ssh_assert_preserved "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"
}

@test "a later apply recovers a deleted public key without changing the private key" {
  sandbox_chezmoi apply
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  rm "$SANDBOX_SSH_KEY.pub"

  run -0 sandbox_chezmoi apply

  ssh_assert_key_pair
  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  [ "$(ssh_file_mode "$SANDBOX_SSH_KEY.pub")" = 644 ]
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
