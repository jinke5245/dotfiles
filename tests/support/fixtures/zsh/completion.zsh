# Exercise Zsh's real completion discovery at Oh My Zsh's initialization boundary.
autoload -Uz compinit
compinit -i -d "$HOME/.zcompdump"
print -r -- "completion:${_comps[dotfiles-test]:-missing}" >> "$ZSH_TEST_TRACE"
