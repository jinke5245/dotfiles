#!/usr/bin/env bash

set -euo pipefail

main() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

  # shellcheck source=scripts/lib/homebrew.sh
  source "$script_dir/lib/homebrew.sh"
  # shellcheck source=scripts/lib/oh-my-zsh.sh
  source "$script_dir/lib/oh-my-zsh.sh"

  install_homebrew
  install_oh_my_zsh
}

main "$@"
