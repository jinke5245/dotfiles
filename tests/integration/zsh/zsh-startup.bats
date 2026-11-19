#!/usr/bin/env bats

# Shell snippets expand in Zsh. Bats isolates each test; helpers read scenario variables.
# shellcheck disable=SC2016,SC2030,SC2031

load '../../support/helpers/sandbox.bash'
load '../../support/helpers/zsh.bash'

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

@test "Linux login starts and reuses the cached agent and adds the local key" {
  zsh_sandbox_apply linux amd64
  mkdir -p "$SANDBOX_HOME/.ssh"
  printf 'test key\n' > "$SANDBOX_HOME/.ssh/id_ed25519"
  cat >> "$SANDBOX_HOME/.zshenv" << 'EOF'
unset SSH_AUTH_SOCK
ps() { print -r -- '123 ssh-agent -s'; }
ssh-agent() {
  [[ "$*" = -s ]] || return 1
  print -r -- agent-start >> "$ZSH_TEST_TRACE"
  printf 'SSH_AUTH_SOCK=%q; export SSH_AUTH_SOCK;\necho Agent pid 12345;\n' "$HOME/.ssh/test.sock"
}
ssh-add() {
  if [[ "$*" = -l ]]; then
    return "$(cat "$HOME/.ssh/agent-status")"
  fi
  [[ "$#" = 1 && "$1" = "$HOME/.ssh/id_ed25519" ]] || return 1
  print -r -- agent-add >> "$ZSH_TEST_TRACE"
}
EOF

  local agent_status
  for agent_status in 2 0 1; do
    printf '%s\n' "$agent_status" > "$SANDBOX_HOME/.ssh/agent-status"
    run -0 --separate-stderr sandbox_zsh -lc 'print -r -- "$SSH_AUTH_SOCK"'

    [ "$output" = "$SANDBOX_HOME/.ssh/test.sock" ]
    [ -z "$stderr" ]
  done
  [ "$(grep -c '^agent-start$' "$SANDBOX_ROOT/startup.log")" = 1 ]
  [ "$(grep -c '^agent-add$' "$SANDBOX_ROOT/startup.log")" = 3 ]
}

@test "Linux login replaces a stale cached agent even when another agent exists" {
  zsh_sandbox_apply linux amd64
  mkdir -p "$SANDBOX_HOME/.ssh"
  printf 'test key\n' > "$SANDBOX_HOME/.ssh/id_ed25519"
  printf 'SSH_AUTH_SOCK=%q; export SSH_AUTH_SOCK;\n' \
    "$SANDBOX_HOME/.ssh/stale.sock" > "$SANDBOX_HOME/.ssh/ssh-agent"
  cat >> "$SANDBOX_HOME/.zshenv" << 'EOF'
unset SSH_AUTH_SOCK
ps() { print -r -- '123 ssh-agent -s'; }
ssh-agent() {
  [[ "$*" = -s ]] || return 1
  print -r -- agent-start >> "$ZSH_TEST_TRACE"
  printf 'SSH_AUTH_SOCK=%q; export SSH_AUTH_SOCK;\n' "$HOME/.ssh/live.sock"
}
ssh-add() {
  if [[ "$*" = -l ]]; then
    [[ ${SSH_AUTH_SOCK:-} = "$HOME/.ssh/live.sock" ]] || return 2
  else
    [[ "$#" = 1 && "$1" = "$HOME/.ssh/id_ed25519" ]] || return 1
    [[ ${SSH_AUTH_SOCK:-} = "$HOME/.ssh/live.sock" ]] || return 2
    print -r -- agent-add >> "$ZSH_TEST_TRACE"
  fi
}
EOF

  run -0 --separate-stderr sandbox_zsh -lc 'print -r -- "$SSH_AUTH_SOCK"'

  [ "$output" = "$SANDBOX_HOME/.ssh/live.sock" ]
  [ -z "$stderr" ]
  [ "$(grep -c '^agent-start$' "$SANDBOX_ROOT/startup.log")" = 1 ]
  [ "$(grep -c '^agent-add$' "$SANDBOX_ROOT/startup.log")" = 1 ]
}

@test "Linux login creates a private agent cache when the SSH directory is absent" {
  zsh_sandbox_apply linux amd64
  cat >> "$SANDBOX_HOME/.zshenv" << 'EOF'
unset SSH_AUTH_SOCK
ssh-add() { return 2; }
ssh-agent() { printf 'export SSH_AUTH_SOCK=%q\n' "$HOME/.ssh/test.sock"; }
EOF

  run -0 --separate-stderr sandbox_zsh -lc 'print -r -- "$SSH_AUTH_SOCK"'

  [ "$output" = "$SANDBOX_HOME/.ssh/test.sock" ]
  [ -z "$stderr" ]
  [ -f "$SANDBOX_HOME/.ssh/ssh-agent" ]
  [ "$(find "$SANDBOX_HOME/.ssh" -type f -perm 600)" = "$SANDBOX_HOME/.ssh/ssh-agent" ]
  [ "$(find "$SANDBOX_HOME/.ssh" -type d -perm 700)" = "$SANDBOX_HOME/.ssh" ]
}

@test "Linux login leaves a symlink at the agent cache path and its target intact" {
  zsh_sandbox_apply linux amd64
  mkdir -p "$SANDBOX_HOME/.ssh"
  printf 'print -r -- unexpected > "$HOME/cache-was-evaluated"\n' > "$SANDBOX_ROOT/unrelated"
  ln -s "$SANDBOX_ROOT/unrelated" "$SANDBOX_HOME/.ssh/ssh-agent"
  cat >> "$SANDBOX_HOME/.zshenv" << 'EOF'
unset SSH_AUTH_SOCK
ssh-add() { return 2; }
ssh-agent() { printf 'export SSH_AUTH_SOCK=%q\n' "$HOME/.ssh/test.sock"; }
EOF

  run -0 --separate-stderr sandbox_zsh -lc 'print -r -- ready'

  [ "$output" = ready ]
  [ -z "$stderr" ]
  [ -L "$SANDBOX_HOME/.ssh/ssh-agent" ]
  [ "$(cat "$SANDBOX_ROOT/unrelated")" = 'print -r -- unexpected > "$HOME/cache-was-evaluated"' ]
  [ ! -e "$SANDBOX_HOME/cache-was-evaluated" ]
}

@test "Linux login keeps the previous agent cache when starting an agent fails" {
  zsh_sandbox_apply linux amd64
  mkdir -p "$SANDBOX_HOME/.ssh"
  printf '# previous cache\n' > "$SANDBOX_HOME/.ssh/ssh-agent"
  cat >> "$SANDBOX_HOME/.zshenv" << 'EOF'
unset SSH_AUTH_SOCK
ssh-add() { return 2; }
ssh-agent() {
  print -r -- 'print -r -- unexpected > "$HOME/failed-agent-output-was-evaluated"'
  return 1
}
EOF

  run -0 --separate-stderr sandbox_zsh -lc 'print -r -- ready'

  [ "$output" = ready ]
  [ -z "$stderr" ]
  [ "$(cat "$SANDBOX_HOME/.ssh/ssh-agent")" = '# previous cache' ]
  [ ! -e "$SANDBOX_HOME/failed-agent-output-was-evaluated" ]
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
