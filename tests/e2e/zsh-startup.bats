#!/usr/bin/env bats

# Shell snippets must expand in the isolated Zsh process, not in Bats.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'
load '../helpers/zsh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
  if [ -z "${OMZ_SOURCE:-}" ] || [ ! -f "$OMZ_SOURCE/oh-my-zsh.sh" ]; then
    printf 'Set OMZ_SOURCE to a local Oh My Zsh Git checkout before running e2e tests.\n' >&2
    return 1
  fi
  git -C "$OMZ_SOURCE" rev-parse --verify HEAD > /dev/null
}

setup() {
  zsh_sandbox_create
  mkdir -p "$SANDBOX_HOME/.oh-my-zsh"
  # Use only committed upstream files, excluding local customizations and caches.
  (
    set -o pipefail
    git -C "$OMZ_SOURCE" archive HEAD \
      | tar -xf - -C "$SANDBOX_HOME/.oh-my-zsh"
  )
}

@test "real Oh My Zsh loads the theme, git plugin, history, and completion" {
  local mode
  for mode in -lic -ic; do
    run -0 sandbox_zsh "$mode" '
      [[ $ZSH_THEME = robbyrussell ]] &&
      [[ $PROMPT = *git_prompt_info* ]] &&
      [[ ${aliases[gst]} = "git status" ]] &&
      [[ $HISTFILE = "$HOME/.zsh_history" ]] &&
      (( $+functions[compdef] ))
    '
    [ -z "$output" ]
  done
}
