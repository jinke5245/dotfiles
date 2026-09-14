#!/usr/bin/env bats

load '../../helpers/sandbox.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  sandbox_create
}

@test "discovers home as the repository's chezmoi source root" {
  run -0 sandbox_chezmoi execute-template '{{ .chezmoi.sourceDir }}'

  [ "$output" = "$SANDBOX_REPOSITORY/home" ]
}

@test "deploys the repository's Zsh and Git configuration at their intended paths" {
  run -0 sandbox_chezmoi apply --exclude scripts

  cmp "$SANDBOX_REPOSITORY/home/dot_zshrc" "$SANDBOX_HOME/.zshrc"
  cmp "$SANDBOX_REPOSITORY/home/dot_config/git/config" "$SANDBOX_HOME/.config/git/config"
  # Template rendering and platform-specific content belong to the Zsh suite.
  [ -s "$SANDBOX_HOME/.zprofile" ]
}

@test "keeps repository documentation, tooling, and test libraries out of the target home" {
  run -0 sandbox_chezmoi apply --exclude scripts

  local entry
  for entry in README.md AGENTS.md Brewfile package.json .github scripts tests .chezmoiscripts; do
    if [ -e "$SANDBOX_HOME/$entry" ] || [ -L "$SANDBOX_HOME/$entry" ]; then
      printf 'Unexpected deployed repository entry: %s\n' "$entry" >&2
      return 1
    fi
  done
}
