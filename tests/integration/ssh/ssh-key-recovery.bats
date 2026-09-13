#!/usr/bin/env bats

# Shell snippets expand their arguments in the isolated child process.
# shellcheck disable=SC2016

load '../../helpers/sandbox.bash'
load '../../helpers/ssh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  ssh_sandbox_create
}

@test "recovers the public key while preserving the original private key" {
  ssh_fixture_key
  cp "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/expected.pub"
  rm "$SANDBOX_SSH_KEY.pub"
  chmod 400 "$SANDBOX_SSH_KEY"
  touch -t 200001010000 "$SANDBOX_SSH_KEY"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"

  run -0 ssh_sandbox_run /bin/bash -c '
    umask 077
    source "$1"
    initialize_ssh_keys
  ' _ "$SANDBOX_REPOSITORY/scripts/lib/ssh.sh"

  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  [ "$(ssh_file_mode "$SANDBOX_SSH_KEY.pub")" = 644 ]
  [ "$(cut -d ' ' -f 1,2 "$SANDBOX_SSH_KEY.pub")" = \
    "$(cut -d ' ' -f 1,2 "$SANDBOX_ROOT/expected.pub")" ]
  ssh_assert_key_pair

  cp -p "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"

  run -0 ssh_sandbox_initialize

  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  ssh_assert_preserved "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"
}

@test "recovers from an encrypted private key when its passphrase is supplied" {
  ssh_fixture_key 'dotfiles test passphrase'
  rm "$SANDBOX_SSH_KEY.pub"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/ssh/askpass.bash" "$SANDBOX_ROOT/askpass"
  chmod +x "$SANDBOX_ROOT/askpass"

  # Only the human input boundary is substituted; key decryption remains real.
  run -0 ssh_sandbox_run env SSH_ASKPASS="$SANDBOX_ROOT/askpass" \
    /bin/bash -c 'source "$1" && initialize_ssh_keys' _ \
    "$SANDBOX_REPOSITORY/scripts/lib/ssh.sh"

  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  [ "$(ssh_file_mode "$SANDBOX_SSH_KEY.pub")" = 644 ]
  ssh_assert_key_pair 'dotfiles test passphrase'
}

@test "fails without leaving a public key when an existing passphrase is unavailable" {
  ssh_fixture_key 'unavailable test passphrase'
  rm "$SANDBOX_SSH_KEY.pub"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"

  run ! ssh_sandbox_initialize

  [ -n "$output" ]
  [ ! -e "$SANDBOX_SSH_KEY.pub" ]
  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
}

@test "fails without leaving a public key when the private key is invalid" {
  mkdir -m 700 "$SANDBOX_HOME/.ssh"
  printf 'invalid private key\n' > "$SANDBOX_SSH_KEY"
  chmod 600 "$SANDBOX_SSH_KEY"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"

  run ! ssh_sandbox_initialize

  [ -n "$output" ]
  [ ! -e "$SANDBOX_SSH_KEY.pub" ]
  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
}

@test "preserves a dangling private-key symlink instead of replacing the identity" {
  mkdir -m 700 "$SANDBOX_HOME/.ssh"
  ln -s "$SANDBOX_ROOT/absent-key" "$SANDBOX_SSH_KEY"

  run ! ssh_sandbox_initialize

  [ -n "$output" ]
  [ -L "$SANDBOX_SSH_KEY" ]
  [ "$(readlink "$SANDBOX_SSH_KEY")" = "$SANDBOX_ROOT/absent-key" ]
  [ ! -e "$SANDBOX_ROOT/absent-key" ]
  [ ! -e "$SANDBOX_SSH_KEY.pub" ]
}

@test "rejects non-Ed25519 private keys without writing a public key" {
  mkdir -m 700 "$SANDBOX_HOME/.ssh"
  local algorithm

  # ssh-keygen accepts both algorithms; recovery must enforce Ed25519 itself.
  for algorithm in rsa ecdsa; do
    ssh_sandbox_run ssh-keygen -q -t "$algorithm" -N '' -f "$SANDBOX_SSH_KEY"
    rm "$SANDBOX_SSH_KEY.pub"
    chmod 400 "$SANDBOX_SSH_KEY"
    cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/$algorithm.before"

    run ! ssh_sandbox_initialize

    [[ "$output" == *Ed25519* ]]
    [ ! -e "$SANDBOX_SSH_KEY.pub" ]
    ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/$algorithm.before"

    rm -f "$SANDBOX_SSH_KEY"
  done
}
