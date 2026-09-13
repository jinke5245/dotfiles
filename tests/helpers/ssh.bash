#!/usr/bin/env bash

# The child shell expands its own arguments when loading the library.
# shellcheck disable=SC2016

ssh_sandbox_create() {
  # SSH tests reuse repository copying without requiring chezmoi itself.
  SANDBOX_ROOT="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  SANDBOX_REPOSITORY="$SANDBOX_ROOT/repository with spaces"
  SANDBOX_HOME="$SANDBOX_ROOT/home with spaces"
  SANDBOX_SSH_KEY="$SANDBOX_HOME/.ssh/id_ed25519"
  mkdir -p "$SANDBOX_HOME" "$SANDBOX_ROOT/cache" \
    "$SANDBOX_ROOT/data" "$SANDBOX_ROOT/state" "$SANDBOX_ROOT/tmp"
  sandbox_copy_repository "$SANDBOX_REPOSITORY"
}

ssh_sandbox_run() (
  cd "$SANDBOX_ROOT" || return

  # Never inherit an agent or askpass program from the user's session. The
  # default askpass fails immediately, even when Bats has a controlling terminal.
  env -i \
    PATH=/usr/bin:/bin \
    HOME="$SANDBOX_HOME" \
    XDG_CONFIG_HOME="$SANDBOX_HOME/.config" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" \
    XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    TMPDIR="$SANDBOX_ROOT/tmp" \
    LC_ALL=C \
    SSH_ASKPASS=/usr/bin/false \
    SSH_ASKPASS_REQUIRE=force \
    DISPLAY=dotfiles-test:0 \
    "$@" < /dev/null
)

ssh_sandbox_initialize() {
  ssh_sandbox_run /bin/bash -c 'source "$1" && initialize_ssh_keys' _ \
    "$SANDBOX_REPOSITORY/scripts/lib/ssh.sh"
}

ssh_fixture_key() {
  mkdir -m 700 "$SANDBOX_HOME/.ssh"
  ssh_sandbox_run ssh-keygen -q -t ed25519 -N "${1:-}" \
    -C fixture@example.invalid -f "$SANDBOX_SSH_KEY"
}

ssh_file_mode() {
  case "$(uname -s)" in
    Darwin) stat -f '%Lp' "$1" ;;
    *) stat -c '%a' "$1" ;;
  esac
}

ssh_assert_preserved() {
  cmp "$1" "$2" || return
  [ ! "$1" -nt "$2" ] || return
  [ ! "$1" -ot "$2" ] || return
  [ "$(ssh_file_mode "$1")" = "$(ssh_file_mode "$2")" ]
}

ssh_assert_key_pair() {
  # Compare key material independently of the public-key comment. Supplying an
  # empty passphrase also verifies that newly generated keys are unencrypted.
  ssh_sandbox_run ssh-keygen -y -P "${1:-}" -f "$SANDBOX_SSH_KEY" \
    > "$SANDBOX_ROOT/derived.pub" || return

  [ "$(cut -d ' ' -f 1 "$SANDBOX_SSH_KEY.pub")" = ssh-ed25519 ] || return
  [ "$(cut -d ' ' -f 1,2 "$SANDBOX_SSH_KEY.pub")" = \
    "$(cut -d ' ' -f 1,2 "$SANDBOX_ROOT/derived.pub")" ]
}
