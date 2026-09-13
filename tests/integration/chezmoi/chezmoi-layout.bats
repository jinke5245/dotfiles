#!/usr/bin/env bats

load '../../helpers/sandbox.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  sandbox_create

  # Add small probes to the real source copy without replacing its configuration.
  mkdir -p "$SANDBOX_REPOSITORY/home/dot_config/layout-test"
  printf '%s\n' 'top-level fixture' > "$SANDBOX_REPOSITORY/home/dot_layout-test"
  printf '%s\n' 'nested fixture' > "$SANDBOX_REPOSITORY/home/dot_config/layout-test/config"
}

@test "discovers home as the repository's chezmoi source root" {
  run -0 sandbox_chezmoi execute-template '{{ .chezmoi.sourceDir }}'

  [ "$output" = "$SANDBOX_REPOSITORY/home" ]
}

@test "applies a dot-prefixed source file to the target home directory" {
  run -0 sandbox_chezmoi apply --exclude scripts

  [ "$(cat "$SANDBOX_HOME/.layout-test")" = 'top-level fixture' ]
}

@test "applies nested configuration at its target path" {
  run -0 sandbox_chezmoi apply --exclude scripts

  [ "$(cat "$SANDBOX_HOME/.config/layout-test/config")" = 'nested fixture' ]
}

@test "keeps repository documentation, tooling, and test libraries out of the target home" {
  run -0 sandbox_chezmoi apply --exclude scripts

  local entry
  for entry in README.md Brewfile package.json scripts tests .chezmoiscripts; do
    if [ -e "$SANDBOX_HOME/$entry" ] || [ -L "$SANDBOX_HOME/$entry" ]; then
      printf 'Unexpected deployed repository entry: %s\n' "$entry" >&2
      return 1
    fi
  done
}

@test "reapplying unchanged configuration leaves managed files unchanged" {
  sandbox_init
  sandbox_chezmoi apply --exclude scripts
  [ -f "$SANDBOX_HOME/.layout-test" ]
  touch -t 200001010000 "$SANDBOX_HOME/.layout-test"
  cp -p "$SANDBOX_HOME/.layout-test" "$SANDBOX_ROOT/before-apply"

  run -0 sandbox_chezmoi apply --exclude scripts

  cmp "$SANDBOX_HOME/.layout-test" "$SANDBOX_ROOT/before-apply"
  [ ! "$SANDBOX_HOME/.layout-test" -nt "$SANDBOX_ROOT/before-apply" ]
  [ ! "$SANDBOX_HOME/.layout-test" -ot "$SANDBOX_ROOT/before-apply" ]

  run -0 sandbox_chezmoi diff --exclude scripts
  [ -z "$output" ]
}

@test "preserves unrelated files already present in the target home" {
  printf '%s\n' 'keep my notes' > "$SANDBOX_HOME/notes.txt"

  run -0 sandbox_chezmoi apply --exclude scripts

  [ "$(cat "$SANDBOX_HOME/notes.txt")" = 'keep my notes' ]
}
