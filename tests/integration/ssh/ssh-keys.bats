#!/usr/bin/env bats

# Shell snippets expand their arguments in the isolated child process.
# shellcheck disable=SC2016
# Each Bats case has its own sandbox; overrides are intentionally local to it.
# shellcheck disable=SC2030,SC2031

load '../../helpers/sandbox.bash'
load '../../helpers/ssh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  ssh_sandbox_create
}

@test "sourcing the SSH library does not create keys or directories" {
  run -0 ssh_sandbox_run /bin/bash -c 'source "$1"' _ \
    "$SANDBOX_REPOSITORY/scripts/lib/ssh.sh"

  [ -z "$output" ]
  [ ! -e "$SANDBOX_HOME/.ssh" ]
}

@test "generates a matching unencrypted Ed25519 pair with the default comment" {
  run -0 ssh_sandbox_initialize

  ssh_assert_key_pair
  [ "$(cut -d ' ' -f 3- "$SANDBOX_SSH_KEY.pub")" = "$(id -un)@$(hostname)" ]
}

@test "a supplied email becomes the comment in both new keys" {
  run -0 ssh_sandbox_initialize saved@example.invalid

  ssh_assert_key_pair
  [ "$(cut -d ' ' -f 3- "$SANDBOX_SSH_KEY.pub")" = saved@example.invalid ]
  [ "$(cut -d ' ' -f 3- "$SANDBOX_ROOT/derived.pub")" = saved@example.invalid ]
}

@test "an explicitly empty email keeps the default key comment" {
  run -0 ssh_sandbox_initialize ''

  ssh_assert_key_pair
  [ "$(cut -d ' ' -f 3- "$SANDBOX_SSH_KEY.pub")" = "$(id -un)@$(hostname)" ]
}

@test "a supplied comment preserves quotes, spaces, and shell syntax literally" {
  local comment="O'Brien"
  comment+=' 李 "Test" \ $(touch "$HOME/injected")'

  run -0 ssh_sandbox_initialize "$comment"

  ssh_assert_key_pair
  [ "$(cut -d ' ' -f 3- "$SANDBOX_SSH_KEY.pub")" = "$comment" ]
  [ "$(cut -d ' ' -f 3- "$SANDBOX_ROOT/derived.pub")" = "$comment" ]
  [ ! -e "$SANDBOX_HOME/injected" ]
}

@test "SSH initialization never queries Git for an email" {
  local email
  for email in saved@example.invalid ''; do
    run -0 ssh_sandbox_run /bin/bash -c '
      git() {
        touch "$HOME/git-queried"
        printf "git@example.invalid\n"
      }
      source "$1"
      initialize_ssh_keys "$2"
    ' _ "$SANDBOX_REPOSITORY/scripts/lib/ssh.sh" "$email"

    [ ! -e "$SANDBOX_HOME/git-queried" ]
    ssh_assert_key_pair
    rm "$SANDBOX_SSH_KEY" "$SANDBOX_SSH_KEY.pub"
  done
}

@test "sets new directory and key permissions despite the caller's umask" {
  local mask
  for mask in 000 077; do
    SANDBOX_HOME="$SANDBOX_ROOT/home with umask $mask"
    SANDBOX_SSH_KEY="$SANDBOX_HOME/.ssh/id_ed25519"
    mkdir -p "$SANDBOX_HOME"

    run -0 ssh_sandbox_run /bin/bash -c '
      umask "$1"
      source "$2"
      initialize_ssh_keys
    ' _ "$mask" "$SANDBOX_REPOSITORY/scripts/lib/ssh.sh"

    [ "$(ssh_file_mode "$SANDBOX_HOME/.ssh")" = 700 ]
    [ "$(ssh_file_mode "$SANDBOX_SSH_KEY")" = 600 ]
    [ "$(ssh_file_mode "$SANDBOX_SSH_KEY.pub")" = 644 ]
    ssh_assert_key_pair
  done
}

@test "repeated initialization preserves existing encrypted keys and their permissions" {
  ssh_fixture_key 'existing test passphrase'
  chmod 400 "$SANDBOX_SSH_KEY"
  chmod 640 "$SANDBOX_SSH_KEY.pub"
  touch -t 200001010000 "$SANDBOX_SSH_KEY" "$SANDBOX_SSH_KEY.pub"
  cp -p "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  cp -p "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"

  # No passphrase is available here: a complete pair must be left alone.
  run -0 ssh_sandbox_initialize changed@example.invalid
  run -0 ssh_sandbox_initialize another@example.invalid

  ssh_assert_preserved "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private.before"
  ssh_assert_preserved "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"
}

@test "preserves an existing SSH directory and keys at other paths" {
  mkdir -m 750 "$SANDBOX_HOME/.ssh"
  ssh_sandbox_run ssh-keygen -q -t ed25519 -N '' \
    -f "$SANDBOX_HOME/.ssh/another-key"
  cp -p "$SANDBOX_HOME/.ssh/another-key" "$SANDBOX_ROOT/other-private.before"
  cp -p "$SANDBOX_HOME/.ssh/another-key.pub" "$SANDBOX_ROOT/other-public.before"

  run -0 ssh_sandbox_initialize

  ssh_assert_key_pair
  [ "$(ssh_file_mode "$SANDBOX_HOME/.ssh")" = 750 ]
  ssh_assert_preserved "$SANDBOX_HOME/.ssh/another-key" "$SANDBOX_ROOT/other-private.before"
  ssh_assert_preserved "$SANDBOX_HOME/.ssh/another-key.pub" "$SANDBOX_ROOT/other-public.before"
}

@test "reports a lone public key without replacing it or creating a private key" {
  ssh_fixture_key
  rm "$SANDBOX_SSH_KEY"
  cp -p "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"

  run ! ssh_sandbox_initialize

  [[ "$output" == *id_ed25519.pub* ]]
  [ ! -e "$SANDBOX_SSH_KEY" ]
  ssh_assert_preserved "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public.before"
}

@test "preserves a dangling public-key symlink instead of generating over it" {
  mkdir -m 700 "$SANDBOX_HOME/.ssh"
  ln -s "$SANDBOX_ROOT/absent.pub" "$SANDBOX_SSH_KEY.pub"

  run ! ssh_sandbox_initialize

  [[ "$output" == *id_ed25519.pub* ]]
  [ -L "$SANDBOX_SSH_KEY.pub" ]
  [ "$(readlink "$SANDBOX_SSH_KEY.pub")" = "$SANDBOX_ROOT/absent.pub" ]
  [ ! -e "$SANDBOX_ROOT/absent.pub" ]
  [ ! -e "$SANDBOX_SSH_KEY" ]
}

@test "reports an SSH directory creation failure without replacing the conflicting file" {
  printf 'existing file\n' > "$SANDBOX_HOME/.ssh"
  cp -p "$SANDBOX_HOME/.ssh" "$SANDBOX_ROOT/ssh.before"

  run ! ssh_sandbox_initialize

  [[ "$output" == *'.ssh'* ]]
  ssh_assert_preserved "$SANDBOX_HOME/.ssh" "$SANDBOX_ROOT/ssh.before"
}

@test "rejects directories at either key path even when the other key exists" {
  ssh_fixture_key
  local key

  for key in "$SANDBOX_SSH_KEY" "$SANDBOX_SSH_KEY.pub"; do
    mv "$key" "$SANDBOX_ROOT/key.before"
    mkdir -m 750 "$key"
    printf 'keep directory contents\n' > "$key/keep"

    run ! ssh_sandbox_initialize

    [[ "$output" == *"$key"* ]]
    [ "$(ssh_file_mode "$key")" = 750 ]
    [ "$(cat "$key/keep")" = 'keep directory contents' ]

    rm "$key/keep"
    rmdir "$key"
    mv "$SANDBOX_ROOT/key.before" "$key"
  done

  ssh_assert_key_pair
}

@test "rejects dangling symlinks at either key path even when the other key exists" {
  ssh_fixture_key
  local key

  for key in "$SANDBOX_SSH_KEY" "$SANDBOX_SSH_KEY.pub"; do
    mv "$key" "$SANDBOX_ROOT/key.before"
    ln -s "$SANDBOX_ROOT/absent-key" "$key"

    run ! ssh_sandbox_initialize

    [[ "$output" == *"$key"* ]]
    [ -L "$key" ]
    [ "$(readlink "$key")" = "$SANDBOX_ROOT/absent-key" ]
    [ ! -e "$SANDBOX_ROOT/absent-key" ]

    rm "$key"
    mv "$SANDBOX_ROOT/key.before" "$key"
  done

  ssh_assert_key_pair
}

@test "preserves a complete key pair reached through valid symlinks" {
  ssh_fixture_key 'existing test passphrase'
  mv "$SANDBOX_SSH_KEY" "$SANDBOX_ROOT/private-target"
  mv "$SANDBOX_SSH_KEY.pub" "$SANDBOX_ROOT/public-target"
  cp -p "$SANDBOX_ROOT/private-target" "$SANDBOX_ROOT/private.before"
  cp -p "$SANDBOX_ROOT/public-target" "$SANDBOX_ROOT/public.before"
  ln -s "$SANDBOX_ROOT/private-target" "$SANDBOX_SSH_KEY"
  ln -s "$SANDBOX_ROOT/public-target" "$SANDBOX_SSH_KEY.pub"

  run -0 ssh_sandbox_initialize

  [ "$(readlink "$SANDBOX_SSH_KEY")" = "$SANDBOX_ROOT/private-target" ]
  [ "$(readlink "$SANDBOX_SSH_KEY.pub")" = "$SANDBOX_ROOT/public-target" ]
  ssh_assert_preserved "$SANDBOX_ROOT/private-target" "$SANDBOX_ROOT/private.before"
  ssh_assert_preserved "$SANDBOX_ROOT/public-target" "$SANDBOX_ROOT/public.before"
}
