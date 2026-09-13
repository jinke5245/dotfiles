#!/usr/bin/env bash

zsh_fixture_development() {
  local prefix="$1" command
  mkdir -p "$prefix/bin" "$SANDBOX_HOME/.fnm-test/multishell/bin"
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/fnm.bash" "$prefix/bin/fnm"
  chmod +x "$prefix/bin/fnm"

  # A startup-time runtime or package-manager invocation must be visible.
  for command in node npm corepack pnpm go uv uvx; do
    cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/runtime-command.bash" "$prefix/bin/$command"
    chmod +x "$prefix/bin/$command"
  done
  cp "$prefix/bin/node" "$SANDBOX_HOME/.fnm-test/multishell/bin/node"

  zsh_fixture_uv_completions "$prefix"
}

zsh_fixture_uv_completions() {
  local directory="$1/opt/uv/share/zsh/site-functions" command
  mkdir -p "$directory"
  for command in uv uvx; do
    printf '#compdef %s\n_arguments "--version[Print version]"\n' "$command" > "$directory/_$command"
  done
}
