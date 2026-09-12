#!/usr/bin/env bats

# Shell snippets expand only in the isolated Zsh process.
# shellcheck disable=SC2016

load '../../helpers/sandbox.bash'
load '../../helpers/zsh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  zsh_sandbox_create
  zsh_fixture_oh_my_zsh
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  zsh_fixture_plugins "$SANDBOX_ROOT/brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:$SANDBOX_ZSH_PATH"
}

@test "interactive shells start quietly without creating a local configuration" {
  local mode
  for mode in -lic -ic; do
    run -0 sandbox_zsh "$mode" 'print -r -- ready'

    [ "$output" = ready ]
    [ ! -e "$SANDBOX_HOME/.zshrc.local" ]
  done
}

@test "local aliases, functions, environment, and key bindings take effect after shared defaults" {
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"

  local mode
  for mode in -lic -ic; do
    run -0 sandbox_zsh "$mode" '
      [[ ${aliases[gst]} = "git status --short" ]] &&
      [[ $EDITOR = nvim ]] &&
      [[ $(project) = "$HOME/projects" ]] &&
      [[ $(bindkey "^[[A") = *beginning-of-line ]]
    '

    [ -z "$output" ]
  done
}

@test "interactive startup skips an unreadable local configuration" {
  printf 'print -r -- unexpected\n' > "$SANDBOX_HOME/.zshrc.local"
  chmod 000 "$SANDBOX_HOME/.zshrc.local"
  if [ -r "$SANDBOX_HOME/.zshrc.local" ]; then
    skip 'The current user can bypass file read permissions.'
  fi

  run -0 sandbox_zsh -lic 'print -r -- ready'

  [ "$output" = ready ]
}

@test "noninteractive shells do not load local interactive configuration" {
  printf 'print -r -- loaded > "$HOME/local-loaded"\n' > "$SANDBOX_HOME/.zshrc.local"

  local mode
  for mode in -lc -c; do
    run -0 sandbox_zsh "$mode" 'print -r -- ready'

    [ "$output" = ready ]
    [ ! -e "$SANDBOX_HOME/local-loaded" ]
  done
}

@test "repeated apply preserves local configuration even when a source copy exists" {
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"
  touch -t 200001010000 "$SANDBOX_HOME/.zshrc.local"
  cp -p "$SANDBOX_HOME/.zshrc.local" "$SANDBOX_ROOT/local.before"
  # An accidental source copy must not take ownership of the machine's file.
  printf '# unwanted replacement\n' > "$SANDBOX_REPOSITORY/home/dot_zshrc.local"

  zsh_sandbox_apply
  zsh_sandbox_apply

  cmp "$SANDBOX_HOME/.zshrc.local" "$SANDBOX_ROOT/local.before"
  [ ! "$SANDBOX_HOME/.zshrc.local" -nt "$SANDBOX_ROOT/local.before" ]
  [ ! "$SANDBOX_HOME/.zshrc.local" -ot "$SANDBOX_ROOT/local.before" ]
}

@test "apply does not create local configuration from an accidental source copy" {
  printf '# unwanted local file\n' > "$SANDBOX_REPOSITORY/home/dot_zshrc.local"

  run -0 zsh_sandbox_apply

  [ ! -e "$SANDBOX_HOME/.zshrc.local" ]
}

@test "Git ignores local configuration and its chezmoi source filename" {
  git -C "$SANDBOX_REPOSITORY" init --quiet

  run -0 git -C "$SANDBOX_REPOSITORY" check-ignore .zshrc.local home/dot_zshrc.local

  [ "$output" = "$(printf '.zshrc.local\nhome/dot_zshrc.local')" ]
}
