#!/usr/bin/env bash

install_oh_my_zsh() {
  [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] && return 0

  local installer
  installer="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || return

  # Keep existing configuration and return to chezmoi without changing shells.
  ZSH="$HOME/.oh-my-zsh" ZDOTDIR="$HOME" sh -c "$installer" -- --unattended --keep-zshrc
}
