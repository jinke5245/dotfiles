#!/usr/bin/env bash

set -euo pipefail

main() {
  local user_name="${1:-}" user_email="${2:-}"
  local script_dir repository_root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  repository_root="$(cd "$script_dir/.." && pwd -P)"

  # shellcheck source=scripts/lib/homebrew.sh
  source "$script_dir/lib/homebrew.sh"
  # shellcheck source=scripts/lib/node.sh
  source "$script_dir/lib/node.sh"
  # shellcheck source=scripts/lib/oh-my-zsh.sh
  source "$script_dir/lib/oh-my-zsh.sh"
  # shellcheck source=scripts/lib/git.sh
  source "$script_dir/lib/git.sh"
  # shellcheck source=scripts/lib/ssh.sh
  source "$script_dir/lib/ssh.sh"
  # shellcheck source=scripts/lib/iterm2.sh
  source "$script_dir/lib/iterm2.sh"

  install_homebrew
  install_homebrew_packages "$repository_root/Brewfile"
  initialize_node
  install_oh_my_zsh
  initialize_git_identity "$user_name" "$user_email"
  initialize_ssh_keys "$user_email"
  configure_iterm2 "$repository_root/home/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
}

main "$@"
