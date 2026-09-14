#!/usr/bin/env bats

# Scenarios are read by Zsh inside the sandbox, not expanded by Bats.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'
load '../helpers/zsh.bash'
load '../helpers/flow.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
  flow_suite_setup
}

setup() {
  flow_sandbox_create
  sandbox_chezmoi apply
}

@test "interactive shells load configured plugins, completions, and key bindings" {
  run -0 sandbox_zsh -lic '
    # Public plugin functions and settings confirm that startup loaded each plugin.
    (( $+functions[j] )) &&
    (( $+parameters[ZSH_AUTOSUGGEST_STRATEGY] )) &&
    (( $+parameters[ZSH_HIGHLIGHT_STYLES] )) &&

    compaudit &&
    [[ ${_comps[http]} = _httpie ]] &&
    [[ ${_comps[fnm]} = _fnm ]] &&
    [[ ${_comps[uv]} = _uv ]] &&
    [[ ${_comps[uvx]} = _uvx ]] &&

    [[ $(bindkey "^[[A") = *history-substring-search-up ]] &&
    [[ $(bindkey "^[[B") = *history-substring-search-down ]]
  '
  [ -z "$output" ]
}

@test "machine-local configuration overrides Oh My Zsh and shared history bindings" {
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"

  run -0 sandbox_zsh -lic '
    [[ ${aliases[gst]} = "git status --short" ]] &&
    [[ $EDITOR = nvim ]] &&
    [[ $(project) = "$HOME/projects" ]] &&
    [[ $(bindkey "^[[A") = *beginning-of-line ]]
  '
  [ -z "$output" ]
}
