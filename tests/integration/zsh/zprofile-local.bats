#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/zsh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  zsh_sandbox_create
  zsh_fixture_oh_my_zsh
  # Login tests must never start or connect to a real SSH agent.
  printf 'export SSH_AUTH_SOCK=%q\n' "$SANDBOX_ROOT/test-agent.sock" >> "$SANDBOX_HOME/.zshenv"
}

@test "login shells start quietly without creating local configuration" {
  local mode
  for mode in -lc -lic; do
    run -0 sandbox_zsh "$mode" 'print -r -- ready'

    [ "$output" = ready ]
    [ ! -e "$SANDBOX_HOME/.zprofile.local" ]
  done
}

@test "login-local settings load after shared environment on each platform" {
  cat > "$SANDBOX_HOME/.zprofile.local" << 'EOF'
[[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" ]] || return 1
export DOTFILES_TEST_LOGIN_LOCAL=loaded
export PATH="$HOME/login-local/bin:$PATH"
EOF

  local platform architecture
  while read -r platform architecture; do
    zsh_sandbox_apply "$platform" "$architecture"
    run -0 sandbox_zsh -lc '[[ $DOTFILES_TEST_LOGIN_LOCAL = loaded && $path[1] = "$HOME/login-local/bin" ]]'

    [ -z "$output" ]
    run -0 sandbox_zsh -lic '[[ $DOTFILES_TEST_LOGIN_LOCAL = loaded && ":$PATH:" = *":$HOME/login-local/bin:"* ]]'

    [ -z "$output" ]
  done << 'PLATFORMS'
darwin arm64
darwin amd64
linux amd64
PLATFORMS
}

@test "login startup skips unreadable local configuration" {
  printf 'print -r -- unexpected\n' > "$SANDBOX_HOME/.zprofile.local"
  chmod 000 "$SANDBOX_HOME/.zprofile.local"
  if [ -r "$SANDBOX_HOME/.zprofile.local" ]; then
    skip 'The current user can bypass file read permissions.'
  fi

  run -0 sandbox_zsh -lc 'print -r -- ready'

  [ "$output" = ready ]
}

@test "nonlogin shells do not load local login configuration" {
  printf 'print -r -- loaded > "$HOME/login-local-loaded"\n' > "$SANDBOX_HOME/.zprofile.local"

  local mode
  for mode in -ic -c; do
    run -0 sandbox_zsh "$mode" 'print -r -- ready'

    [ "$output" = ready ]
    [ ! -e "$SANDBOX_HOME/login-local-loaded" ]
  done
}

@test "repeated apply preserves login-local configuration despite an accidental source copy" {
  printf 'export DOTFILES_TEST_LOGIN_LOCAL=kept\n' > "$SANDBOX_HOME/.zprofile.local"
  touch -t 200001010000 "$SANDBOX_HOME/.zprofile.local"
  cp -p "$SANDBOX_HOME/.zprofile.local" "$SANDBOX_ROOT/login-local.before"
  printf '# unwanted replacement\n' > "$SANDBOX_REPOSITORY/home/dot_zprofile.local"

  zsh_sandbox_apply
  zsh_sandbox_apply

  cmp "$SANDBOX_HOME/.zprofile.local" "$SANDBOX_ROOT/login-local.before"
  [ ! "$SANDBOX_HOME/.zprofile.local" -nt "$SANDBOX_ROOT/login-local.before" ]
  [ ! "$SANDBOX_HOME/.zprofile.local" -ot "$SANDBOX_ROOT/login-local.before" ]
}

@test "apply does not create login-local configuration from an accidental source copy" {
  printf '# unwanted local file\n' > "$SANDBOX_REPOSITORY/home/dot_zprofile.local"

  run -0 zsh_sandbox_apply

  [ ! -e "$SANDBOX_HOME/.zprofile.local" ]
}
