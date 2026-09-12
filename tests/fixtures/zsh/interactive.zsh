# Test-only observers. Read ZLE after plugin hooks without sending extra keystrokes.
PROMPT='> '
RPROMPT=

# The leading underscore keeps autosuggestions from wrapping this observer.
_dotfiles_test_snapshot() {
  print -r -- "$BUFFER" > "$TMPDIR/zle-buffer"
  print -rl -- "${region_highlight[@]}" > "$TMPDIR/zle-highlights"
}

_dotfiles_test_ready() {
  print -rn -- $'\x1eREADY\x1f'
}

autoload -Uz add-zle-hook-widget add-zsh-hook
add-zle-hook-widget line-pre-redraw _dotfiles_test_snapshot
add-zsh-hook precmd _dotfiles_test_ready
