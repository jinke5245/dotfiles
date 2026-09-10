#!/usr/bin/env bash

install_homebrew() {
  if command -v brew > /dev/null 2>&1 \
    || [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew || -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
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
