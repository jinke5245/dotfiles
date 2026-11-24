#!/usr/bin/env bats

# These snippets expand in the isolated child shell, not in Bats.
# shellcheck disable=SC2016

load '../../support/helpers/sandbox.bash'
load '../../support/helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
}

@test "sourcing installation libraries has no installation side effects" {
  run -0 install_sandbox_run bash -c '
    source "$1/lib/homebrew.sh" &&
      source "$1/lib/node.sh" &&
      source "$1/lib/oh-my-zsh.sh" &&
      source "$1/lib/git.sh" &&
      source "$1/lib/ssh.sh" &&
      source "$1/lib/iterm2.sh"
  ' _ "$SANDBOX_REPOSITORY/scripts/install"

  [ -z "$output" ]
  [ ! -e "$SANDBOX_HOME/.install-test/download.log" ]
  [ ! -e "$SANDBOX_HOME/.install-test/oh-my-zsh.log" ]
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh" ]
  [ ! -e "$SANDBOX_HOME/.ssh" ]
  [ ! -e "$SANDBOX_HOME/.config/git/config.local" ]
  [ ! -e "$SANDBOX_HOME/.install-test/fnm.log" ]
}

@test "chezmoi installs dependencies before writing managed configuration" {
  install_sandbox_platform Darwin
  printf 'ready\n' > "$SANDBOX_REPOSITORY/home/dot_install-order"

  # Fail inside the installer if chezmoi has already written managed files.
  cat >> "$SANDBOX_HOME/.install-test/homebrew-installer.bash" << 'EOF'
[ ! -e "$HOME/.zshrc" ] && [ ! -e "$HOME/.install-order" ] || exit 93
EOF

  run -0 sandbox_chezmoi apply

  [ -f "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]

  # The managed zshrc must replace the template created by the OMZ installer.
  cmp "$SANDBOX_REPOSITORY/home/dot_zshrc" "$SANDBOX_HOME/.zshrc"
  [ "$(cat "$SANDBOX_HOME/.install-order")" = ready ]
  [ ! -e "$SANDBOX_HOME/scripts" ]
}

@test "a Homebrew failure stops apply before Oh My Zsh or managed files change" {
  install_sandbox_platform Darwin
  touch "$SANDBOX_HOME/.install-test/fail-homebrew"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run ! sandbox_chezmoi apply --force

  [[ "$output" == *Homebrew* ]] || return 1

  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
  [ ! -e "$SANDBOX_HOME/.install-test/oh-my-zsh.log" ]
}

@test "an Oh My Zsh failure stops apply before managed files change" {
  touch "$SANDBOX_HOME/.install-test/fail-oh-my-zsh"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run ! sandbox_chezmoi apply --force

  [[ "$output" == *'Oh My Zsh'* ]] || return 1

  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
}

@test "a Bundle failure stops apply before managed files change" {
  touch "$SANDBOX_HOME/.install-test/fail-bundle"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run ! sandbox_chezmoi apply --force

  [[ "$output" == *'Homebrew Bundle'* ]] || return 1
  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
  [ ! -e "$SANDBOX_HOME/.install-test/oh-my-zsh.log" ]
}

@test "reapplying unchanged configuration skips the installer" {
  install_sandbox_platform Darwin
  sandbox_chezmoi apply

  # Keep both content and modification time for comparison after the second apply.
  cp -p "$SANDBOX_HOME/.zshrc" "$SANDBOX_ROOT/before-apply"

  run -0 sandbox_chezmoi apply

  cmp "$SANDBOX_HOME/.zshrc" "$SANDBOX_ROOT/before-apply"
  [ ! "$SANDBOX_HOME/.zshrc" -nt "$SANDBOX_ROOT/before-apply" ]
  [ ! "$SANDBOX_HOME/.zshrc" -ot "$SANDBOX_ROOT/before-apply" ]

  # A single log entry means each dependency was installed only once.
  [ "$(cat "$SANDBOX_HOME/.install-test/oh-my-zsh.log")" = install ]
  [ "$(cat "$SANDBOX_HOME/.install-test/homebrew.log")" = install ]
  [ "$(cat "$SANDBOX_HOME/.install-test/bundle.log")" = install ]
}

@test "shell configuration changes apply without rerunning the installer" {
  sandbox_chezmoi apply
  printf '\n# Updated shared shell configuration\n' >> "$SANDBOX_REPOSITORY/home/dot_zshrc"

  run -0 sandbox_chezmoi apply

  cmp "$SANDBOX_REPOSITORY/home/dot_zshrc" "$SANDBOX_HOME/.zshrc"
  [ "$(cat "$SANDBOX_HOME/.install-test/bundle.log")" = install ]
}

@test "a failed installer is retried without changing its inputs" {
  touch "$SANDBOX_HOME/.install-test/fail-bundle"
  run ! sandbox_chezmoi apply

  [ ! -e "$SANDBOX_HOME/.zshrc" ]
  rm "$SANDBOX_HOME/.install-test/fail-bundle"

  run -0 sandbox_chezmoi apply

  cmp "$SANDBOX_REPOSITORY/home/dot_zshrc" "$SANDBOX_HOME/.zshrc"
  [ "$(grep -c '^bundle install$' "$SANDBOX_HOME/.install-test/events.log")" -eq 2 ]
}

@test "a changed installation library reruns the installer" {
  sandbox_chezmoi apply

  cat >> "$SANDBOX_REPOSITORY/scripts/install/lib/oh-my-zsh.sh" << 'EOF'
install_oh_my_zsh() {
  printf 'library changed\n' >&2
  return 7
}
EOF

  run -1 sandbox_chezmoi apply

  [[ "$output" == *'library changed'* ]]
}

@test "a changed installation entry point reruns the installer" {
  sandbox_chezmoi apply

  cat > "$SANDBOX_REPOSITORY/scripts/install/install.sh" << 'EOF'
#!/bin/bash
printf 'entry changed\n' >&2
exit 8
EOF

  run -1 sandbox_chezmoi apply

  [[ "$output" == *'entry changed'* ]]
}
