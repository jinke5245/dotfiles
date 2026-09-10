# Record the configuration supplied at the framework boundary, not its internals.
print -r -- "omz:$ZSH_THEME:${(j:,:)plugins}:${HOMEBREW_PREFIX:-none}" >> "$ZSH_TEST_TRACE"
