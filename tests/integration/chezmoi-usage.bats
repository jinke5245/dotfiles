#!/usr/bin/env bats

load '../helpers/sandbox.bash'
load '../helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  USAGE_GIT="$(command -v git)"
  install_sandbox_create
}

usage_git() {
  # Use real Git with a test identity and isolated configuration. Installer
  # fixtures still use their own Git substitute for dependency checks.
  install_sandbox_run "$USAGE_GIT" \
    -c user.name='Dotfiles test' -c user.email=test@example.invalid \
    -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"
}

@test "a cloned repository applies configuration changes after pulling updates" {
  local upstream="$SANDBOX_ROOT/upstream"
  mv "$SANDBOX_REPOSITORY" "$upstream"
  printf 'initial\n' > "$upstream/home/dot_usage-example"

  usage_git -C "$upstream" init --initial-branch=main
  usage_git -C "$upstream" add --all
  usage_git -C "$upstream" commit --quiet -m 'Initial configuration'
  usage_git clone "$upstream" "$SANDBOX_REPOSITORY"

  run -0 sandbox_chezmoi diff
  [ ! -e "$SANDBOX_HOME/.zshrc" ]

  run -0 sandbox_chezmoi apply
  [ -f "$SANDBOX_HOME/.zshrc" ]
  [ "$(cat "$SANDBOX_HOME/.usage-example")" = initial ]

  # Publish a configuration change to the local remote, then follow daily use.
  printf 'updated\n' > "$upstream/home/dot_usage-example"
  usage_git -C "$upstream" add --all
  usage_git -C "$upstream" commit --quiet -m 'Update configuration'

  run -0 usage_git -C "$SANDBOX_REPOSITORY" pull --ff-only
  [ "$(cat "$SANDBOX_HOME/.usage-example")" = initial ]

  run -0 sandbox_chezmoi diff
  [[ "$output" == *updated* ]]

  run -0 sandbox_chezmoi apply
  [ "$(cat "$SANDBOX_HOME/.usage-example")" = updated ]

  run -0 sandbox_chezmoi diff --exclude scripts
  [ -z "$output" ]
}
