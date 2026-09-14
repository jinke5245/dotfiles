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
  zsh_fixture_plugins "$SANDBOX_ROOT/brew"
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
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    brew "omz:robbyrussell:git:$SANDBOX_ROOT/brew" \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)" ]
}

@test "interactive child shells inherit PATH without reinitializing Homebrew" {
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:$SANDBOX_ZSH_PATH"

  run -0 sandbox_zsh -lic 'export ZSH_TEST_PARENT_PATH=$PATH; "$ZSH_TEST_BIN" -dic '\''[[ $PATH = "$ZSH_TEST_PARENT_PATH" ]] && print -r -- "$HOMEBREW_PREFIX"'\'

  [ "$output" = "$SANDBOX_ROOT/brew" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    brew "omz:robbyrussell:git:$SANDBOX_ROOT/brew" \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
    "omz:robbyrussell:git:$SANDBOX_ROOT/brew" \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)" ]
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

@test "noninteractive login shells add user executable directories without Homebrew" {
  run -0 sandbox_zsh -lc '[[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" && -z ${HOMEBREW_PREFIX:-} ]]'

  [ -z "$output" ]
  [ ! -s "$SANDBOX_ROOT/startup.log" ]
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

  [ "$output" = "$SANDBOX_HOME/bin:$SANDBOX_HOME/.local/bin:$SANDBOX_HOME/go/bin:$SANDBOX_ROOT/prefixes/intel/bin:$SANDBOX_ROOT/brew/bin:$SANDBOX_ROOT/brew/sbin:/usr/bin:/bin" ]
}

@test "skips missing Oh My Zsh while loading the available plugins" {
  rm "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"
  # Keep plugin paths inside the sandbox even without a brew executable on PATH.
  printf 'export HOMEBREW_PREFIX=%q\n' "$SANDBOX_ROOT/brew" >> "$SANDBOX_HOME/.zshenv"

  run -0 --separate-stderr sandbox_zsh -ic 'print -r -- ready'

  [ "$output" = ready ]
  [ -z "$stderr" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)" ]
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]
}
