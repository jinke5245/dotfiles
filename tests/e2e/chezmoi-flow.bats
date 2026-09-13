#!/usr/bin/env bats

# Shell snippets expand in the isolated child processes.
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
}

@test "a fresh apply installs real Oh My Zsh and starts the configured shells" {
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh" ]
  [ ! -e "$SANDBOX_HOME/.ssh" ]

  run -0 sandbox_chezmoi apply

  [ -f "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]
  [ ! -e "$SANDBOX_HOME/.zshrc.local" ]
  cmp "$SANDBOX_REPOSITORY/home/dot_zshrc" "$SANDBOX_HOME/.zshrc"

  run -0 sandbox_zsh -lc '
    source "$1/tests/helpers/ssh-flow.bash"
    ssh_flow_check test@example.invalid
  ' _ "$SANDBOX_REPOSITORY"
  [ -z "$output" ]

  local startup_file
  for startup_file in .zprofile .zshrc; do
    run -0 sandbox_zsh -n "$SANDBOX_HOME/$startup_file"
    [ -z "$output" ]
  done

  # Use native chezmoi platform data and the real, preinstalled Homebrew.
  run -0 sandbox_zsh -lc '
    [[ $HOMEBREW_PREFIX = "$1" ]] &&
    [[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" ]]
  ' _ "$FLOW_BREW_PREFIX"
  [ -z "$output" ]

  local mode
  for mode in -lic -ic; do
    run -0 sandbox_zsh "$mode" '
      [[ $ZSH_THEME = robbyrussell ]] &&
      [[ $PROMPT = *git_prompt_info* ]] &&
      [[ ${aliases[gst]} = "git status" ]] &&
      [[ $HISTFILE = "$HOME/.zsh_history" ]] &&
      (( $+functions[compdef] ))
    '
    [ -z "$output" ]
  done
}

@test "first and repeated apply preserve local configuration and the installed framework" {
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"
  sandbox_chezmoi apply
  cmp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"

  local file before
  for file in .zprofile .zshrc .zshrc.local .oh-my-zsh/oh-my-zsh.sh \
    .ssh/id_ed25519 .ssh/id_ed25519.pub; do
    cp -p "$SANDBOX_HOME/$file" "$SANDBOX_ROOT/$(basename "$file").before"
  done
  printf 'keep\n' > "$SANDBOX_HOME/.oh-my-zsh/custom/personal-note"

  # Any attempt to download an installer again must now fail.
  touch "$SANDBOX_HOME/.test-upstream/no-download"

  run -0 sandbox_chezmoi apply

  for file in .zprofile .zshrc .zshrc.local .oh-my-zsh/oh-my-zsh.sh \
    .ssh/id_ed25519 .ssh/id_ed25519.pub; do
    before="$SANDBOX_ROOT/$(basename "$file").before"
    cmp "$SANDBOX_HOME/$file" "$before"
    [ ! "$SANDBOX_HOME/$file" -nt "$before" ]
    [ ! "$SANDBOX_HOME/$file" -ot "$before" ]
  done
  [ "$(cat "$SANDBOX_HOME/.oh-my-zsh/custom/personal-note")" = keep ]

  run -0 sandbox_zsh -lc '
    source "$1/tests/helpers/ssh-flow.bash"
    ssh_flow_check test@example.invalid
  ' _ "$SANDBOX_REPOSITORY"
  [ -z "$output" ]

  run -0 sandbox_chezmoi diff --exclude scripts
  [ -z "$output" ]
}

@test "the next apply runs changed external scripts without changing the adapter" {
  sandbox_chezmoi apply

  # Change a function and the entry point only in the disposable repository.
  cat >> "$SANDBOX_REPOSITORY/scripts/lib/oh-my-zsh.sh" << 'EOF'
install_oh_my_zsh() {
  printf 'library\n' >> "$HOME/script-runs"
  test -f "$HOME/.oh-my-zsh/oh-my-zsh.sh"
}
EOF

  cat >> "$SANDBOX_REPOSITORY/scripts/install.sh" << 'EOF'
printf 'entry\n' >> "$HOME/script-runs"
EOF

  run -0 sandbox_chezmoi apply

  [ "$(cat "$SANDBOX_HOME/script-runs")" = "$(printf 'library\nentry')" ]
}
