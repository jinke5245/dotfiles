#!/usr/bin/env bats

# Snippets expand in the isolated Zsh process, with real prepared tools.
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

@test "login shells expose Homebrew language tools and the prepared Node default" {
  run -0 sandbox_zsh -lic '
    for tool in go fnm uv uvx; do
      [[ $(command -v "$tool") = "$HOMEBREW_PREFIX/bin/$tool" ]] || exit 1
    done
    for tool in node corepack pnpm; do
      [[ $(command -v "$tool") = "$FNM_MULTISHELL_PATH/bin/$tool" ]] || exit 1
    done

    [[ ":$PATH:" = *":$HOME/go/bin:"* ]] &&
    [[ -z ${GOROOT:-} && -z ${GOPATH:-} && -z ${VIRTUAL_ENV:-} ]] &&
    [[ $(node --version) = $(fnm default) ]] &&
    go version && fnm --version && uv --version && uvx --version && corepack --version
  '
}
