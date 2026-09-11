#!/usr/bin/env bats

# Shell snippets expand in Zsh. Bats isolates each test; helpers read scenario variables.
# shellcheck disable=SC2016,SC2030,SC2031

load '../../helpers/sandbox.bash'
load '../../helpers/zsh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  zsh_sandbox_create
  zsh_fixture_oh_my_zsh
}

@test "deploys both startup files with valid Zsh syntax" {
  local startup_file
  for startup_file in .zprofile .zshrc; do
    [ -f "$SANDBOX_HOME/$startup_file" ]
    run -0 sandbox_zsh -n "$SANDBOX_HOME/$startup_file"
    [ -z "$output" ]
  done
}

@test "initializes the login environment before loading configured Oh My Zsh" {
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:$SANDBOX_ZSH_PATH"

  run -0 sandbox_zsh -lic '[[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" ]]'

  [ -z "$output" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf 'brew\nomz:robbyrussell:git:%s' "$SANDBOX_ROOT/brew")" ]
}

@test "interactive child shells inherit PATH without reinitializing Homebrew" {
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:$SANDBOX_ZSH_PATH"

  run -0 sandbox_zsh -lic 'export ZSH_TEST_PARENT_PATH=$PATH; "$ZSH_TEST_BIN" -dic '\''[[ $PATH = "$ZSH_TEST_PARENT_PATH" ]] && print -r -- "$HOMEBREW_PREFIX"'\'

  [ "$output" = "$SANDBOX_ROOT/brew" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf 'brew\nomz:robbyrussell:git:%s\nomz:robbyrussell:git:%s' "$SANDBOX_ROOT/brew" "$SANDBOX_ROOT/brew")" ]
}

@test "noninteractive login shells initialize paths without loading Oh My Zsh" {
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:$SANDBOX_ZSH_PATH"

  run -0 sandbox_zsh -lc '[[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" ]] && print -r -- "$HOMEBREW_PREFIX"'

  [ "$output" = "$SANDBOX_ROOT/brew" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = brew ]
}

@test "noninteractive nonlogin shells leave paths and Oh My Zsh untouched" {
  run -0 sandbox_zsh -c 'print -r -- "$PATH"'

  [ "$output" = "$SANDBOX_ZSH_PATH" ]
  [ ! -s "$SANDBOX_ROOT/startup.log" ]
}

@test "starts without Homebrew and still adds the user executable directories" {
  run -0 sandbox_zsh -lic '[[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" && -z ${HOMEBREW_PREFIX:-} ]]'

  [ -z "$output" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = omz:robbyrussell:git:none ]
}

@test "renders the platform's default Homebrew location before shell startup" {
  local platform architecture expected
  for expected in apple intel linux; do
    zsh_fixture_brew "$SANDBOX_ROOT/prefixes/$expected"
  done

  while read -r platform architecture expected; do
    zsh_sandbox_apply "$platform" "$architecture"
    run -0 sandbox_zsh -n "$SANDBOX_HOME/.zprofile"
    [ -z "$output" ]
    run -0 sandbox_zsh -lc 'print -r -- "$HOMEBREW_PREFIX"'
    [ "$output" = "$SANDBOX_ROOT/prefixes/$expected" ]
  done << 'EOF'
darwin arm64 apple
darwin amd64 intel
linux amd64 linux
linux arm64 linux
EOF
}

@test "prefers Homebrew already on PATH over a default installation" {
  zsh_sandbox_apply darwin arm64
  zsh_fixture_brew "$SANDBOX_ROOT/prefixes/apple"
  zsh_fixture_brew "$SANDBOX_ROOT/chosen brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/chosen brew/bin:$SANDBOX_ZSH_PATH"

  run -0 sandbox_zsh -lc 'print -r -- "$HOMEBREW_PREFIX"'

  [ "$output" = "$SANDBOX_ROOT/chosen brew" ]
}

@test "repeated login initialization preserves existing paths without duplicates" {
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:/usr/bin:/bin:/usr/bin"

  run -0 sandbox_zsh -lc 'source "$HOME/.zprofile"; source "$HOME/.zprofile"; print -r -- "$PATH"'

  [ "$output" = "$SANDBOX_HOME/bin:$SANDBOX_HOME/.local/bin:$SANDBOX_ROOT/prefixes/intel/bin:$SANDBOX_ROOT/brew/bin:$SANDBOX_ROOT/brew/sbin:/usr/bin:/bin" ]
}

@test "reports missing Oh My Zsh while keeping the interactive shell usable" {
  rm "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"

  run -0 --separate-stderr sandbox_zsh -ic 'print -r -- ready'

  [ "$output" = ready ]
  [[ "$stderr" == *'Oh My Zsh'* ]] || return 1
  [ ! -s "$SANDBOX_ROOT/startup.log" ]
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]
}
