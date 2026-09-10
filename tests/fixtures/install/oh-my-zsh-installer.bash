#!/bin/sh

# Verify our invocation contract without reproducing the upstream installer.
[ "$#" -eq 2 ] && [ "$1" = --unattended ] && [ "$2" = --keep-zshrc ] || exit 90
[ "$ZSH" = "$HOME/.oh-my-zsh" ] && [ "$ZDOTDIR" = "$HOME" ] || exit 90

printf 'install\n' >> "$HOME/.install-test/oh-my-zsh.log"

if [ -e "$HOME/.install-test/fail-oh-my-zsh" ] || [ -e "$ZSH" ] || [ -L "$ZSH" ]; then
  printf 'Oh My Zsh: installer failed\n' >&2
  exit 93
fi

mkdir -p "$ZSH"
printf ':\n' > "$ZSH/oh-my-zsh.sh"

# Upstream preserves an existing config, but creates its template on a fresh home.
if [ ! -f "$ZDOTDIR/.zshrc" ] && [ ! -L "$ZDOTDIR/.zshrc" ]; then
  printf '# Official template fixture\n' > "$ZDOTDIR/.zshrc"
fi
