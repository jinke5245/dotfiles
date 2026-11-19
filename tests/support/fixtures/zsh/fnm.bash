#!/bin/bash

# Model the shell integration boundary without running a version manager.
# Generated expressions expand in the test-owned Zsh process.
# shellcheck disable=SC2016

case "$*" in
  'env --use-on-cd --shell zsh')
    printf 'fnm-env\n' >> "$ZSH_TEST_TRACE"
    printf 'export FNM_MULTISHELL_PATH=%q\n' "$HOME/.fnm-test/multishell"
    printf 'export PATH=%q:"$PATH"\n' "$HOME/.fnm-test/multishell/bin"
    ;;
  'completions --shell zsh')
    printf 'fnm-completions\n' >> "$ZSH_TEST_TRACE"
    printf '_fnm() { _arguments "--version[Print version]"; }\ncompdef _fnm fnm\n'
    ;;
  *)
    printf 'Unexpected fnm invocation during shell startup: %s\n' "$*" >&2
    exit 90
    ;;
esac
