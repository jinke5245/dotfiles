#!/usr/bin/env bash

# Check newly initialized keys once during isolated first-time setup.
ssh_flow_check() (
  set -eu

  local expected_comment="$1"
  local private_key public_key derived permissions
  private_key="$HOME/.ssh/id_ed25519"
  public_key="$private_key.pub"
  test -f "$private_key"
  test -f "$public_key"

  # An explicit empty passphrase proves that the private key is usable without
  # prompting. Compare key material independently of its identifying comment.
  derived="$(ssh-keygen -y -P '' -f "$private_key")"
  test "$(cut -d ' ' -f 1 "$public_key")" = ssh-ed25519
  test "$(printf '%s\n' "$derived" | cut -d ' ' -f 1,2)" = \
    "$(cut -d ' ' -f 1,2 "$public_key")"
  test "$(cut -d ' ' -f 3- "$public_key")" = "$expected_comment"

  case "$(uname -s)" in
    Darwin) permissions="$(stat -f '%Lp' "$HOME/.ssh" "$private_key" "$public_key")" ;;
    *) permissions="$(stat -c '%a' "$HOME/.ssh" "$private_key" "$public_key")" ;;
  esac
  test "$permissions" = "$(printf '700\n600\n644')"
)
