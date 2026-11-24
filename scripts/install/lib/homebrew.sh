#!/usr/bin/env bash

find_homebrew() {
  if command -v brew; then
    return 0
  fi

  # Installers do not update the calling shell's PATH.
  local brew
  for brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$brew" ]]; then
      printf '%s\n' "$brew"
      return 0
    fi
  done

  return 1
}

install_homebrew() {
  if find_homebrew > /dev/null; then
    return 0
  fi

  # Linux support is limited to Debian and Ubuntu.
  if [[ "$(uname -s)" = Linux ]]; then
    if ! command -v apt-get > /dev/null 2>&1; then
      printf 'Homebrew: apt-get is required on Linux (Debian / Ubuntu).\n' >&2
      return 1
    fi
    sudo apt-get update || return
    sudo apt-get install --yes build-essential procps curl file git || return
  fi

  local installer
  installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return
  /bin/bash -c "$installer"
}

install_homebrew_packages() {
  local brew
  brew="$(find_homebrew)" || {
    printf 'Homebrew: brew executable was not found after installation.\n' >&2
    return 1
  }

  "$brew" bundle install --file="$1" --no-upgrade
}
