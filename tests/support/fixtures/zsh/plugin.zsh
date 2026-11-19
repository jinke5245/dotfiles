# Record sourcing at the dependency boundary; the filename identifies the plugin.
print -r -- "${${(%):-%x}:t:r}" >> "$ZSH_TEST_TRACE"

if [[ ${${(%):-%x}:t} = zsh-history-substring-search.zsh ]]; then
  history-substring-search-up() { :; }
  history-substring-search-down() { :; }
  zle -N history-substring-search-up
  zle -N history-substring-search-down
fi
