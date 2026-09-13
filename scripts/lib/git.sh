#!/usr/bin/env bash

initialize_git_identity() {
  local name="${1:-}" email="${2:-}"
  [[ -n "$name" || -n "$email" ]] || return 0

  local config="$HOME/.config/git/config.local"
  if [[ (-e "$config" || -L "$config") && ! -f "$config" ]]; then
    printf 'Git: %s is not a regular file; resolve this manually.\n' "$config" >&2
    return 1
  fi

  local field value status
  for field in name email; do
    case "$field" in
      name) value="$name" ;;
      email) value="$email" ;;
    esac
    [[ -n "$value" ]] || continue

    # A defined key, even empty or supplied by an include, belongs to this machine.
    if git config --file "$config" --includes --get "user.$field" > /dev/null; then
      continue
    else
      status=$?
      # Only exit 1 means undefined; read and parse errors must stop apply.
      [[ "$status" -eq 1 ]] || return "$status"
    fi

    mkdir -p "$HOME/.config/git" || return
    git config --file "$config" "user.$field" "$value" || return
  done
}
