#!/usr/bin/env bash

initialize_git_identity() (
  local name="${1:-}" email="${2:-}"
  [[ -n "$name" || -n "$email" ]] || return 0

  local config="$HOME/.config/git/config.local"
  if [[ (-e "$config" || -L "$config") && ! -f "$config" ]]; then
    printf 'Git: %s is not a regular file; resolve this manually.\n' "$config" >&2
    return 1
  fi

  local field value status target link lock="" mode offset=1
  for field in name email; do
    case "$field" in
      name) value="$name" ;;
      email) value="$email" ;;
    esac
    [[ -n "$value" ]] || continue

    # A defined key, even empty or supplied by an include, belongs to this machine.
    # Repository-specific includes must not decide whether defaults are missing.
    if git --git-dir=/dev/null config --file "$config" --includes --get "user.$field" > /dev/null; then
      continue
    else
      status=$?
      # Only exit 1 means undefined; read and parse errors must stop apply.
      [[ "$status" -eq 1 ]] || return "$status"
    fi

    if [[ -z "$lock" ]]; then
      mkdir -p "$HOME/.config/git" || return
      target="$config"
      while [[ -L "$target" ]]; do
        link="$(readlink "$target")" || return
        if [[ "$link" = /* ]]; then
          target="$link"
        else
          target="$(dirname "$target")/$link"
        fi
      done
      lock="$target.lock"
      (
        umask 077
        set -o noclobber
        : > "$lock"
      ) || return
      trap '[[ $? -eq 0 ]] || rm -f "$lock"' EXIT
      # Keep an existing UTF-8 BOM ahead of the generated defaults.
      if [[ -f "$config" && "$(head -c 3 "$config")" = $'\357\273\277' ]]; then
        printf '\357\273\277\n' > "$lock" || return
        offset=4
      fi
    fi
    git config --file "$lock" "user.$field" "$value" || return
  done

  [[ -n "$lock" ]] || return 0
  # Defaults come first so machine-local conditional includes can override them.
  if [[ -f "$config" ]]; then
    tail -c "+$offset" "$config" >> "$lock" || return
    mode="$(stat -c '%a' "$target" 2> /dev/null)" || mode="$(stat -f '%Lp' "$target")" || return
    chmod "$mode" "$lock" || return
  fi
  git --git-dir=/dev/null config --file "$lock" --list > /dev/null || return
  mv -f "$lock" "$target"
)
