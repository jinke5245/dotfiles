#!/usr/bin/env bash

initialize_ssh_keys() {
  local ssh_dir private_key public_key
  ssh_dir="$HOME/.ssh"
  private_key="$ssh_dir/id_ed25519"
  public_key="$private_key.pub"

  # A dangling symlink is still an existing path and must not be overwritten.
  if [[ -e "$public_key" || -L "$public_key" ]]; then
    if [[ -e "$private_key" || -L "$private_key" ]]; then
      return 0
    fi

    printf 'SSH: %s exists without its private key; resolve this manually.\n' "$public_key" >&2
    return 1
  fi

  if [[ -e "$private_key" || -L "$private_key" ]]; then
    local recovered_public_key
    # Read successfully before creating the file. Encrypted keys may prompt
    # for their existing passphrase; a failed read must leave no empty .pub.
    recovered_public_key="$(ssh-keygen -y -f "$private_key")" || return

    # Preserve a public key that may have appeared while waiting for input.
    (
      set -o noclobber
      printf '%s\n' "$recovered_public_key" > "$public_key"
    ) || return
    chmod 644 "$public_key"
    return
  fi

  # Set permissions only on files and directories created by this operation.
  [[ -d "$ssh_dir" ]] || mkdir -m 700 "$ssh_dir" || return
  ssh-keygen -q -t ed25519 -N '' -f "$private_key" || return
  chmod 600 "$private_key" || return
  chmod 644 "$public_key"
}
