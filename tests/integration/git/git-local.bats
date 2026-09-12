#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/git.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  git_sandbox_create
}

@test "commits require both an explicitly configured name and email" {
  local missing
  for missing in user.name user.email; do
    git_fixture_identity
    sandbox_git config --file "$SANDBOX_GIT_LOCAL" --unset "$missing"

    run -128 sandbox_git -C "$SANDBOX_GIT_WORKTREE" commit --quiet --allow-empty -m 'Missing identity'

    [[ "$output" == *'auto-detection is disabled'* ]]
    run -128 sandbox_git -C "$SANDBOX_GIT_WORKTREE" rev-parse --verify HEAD
  done
}

@test "local identity is used for the author and committer" {
  git_fixture_identity

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" commit --quiet --allow-empty -m 'Local identity'

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" log -1 --format='%an <%ae>%n%cn <%ce>'
  [ "$output" = "$(printf 'Dotfiles test <test@example.invalid>\nDotfiles test <test@example.invalid>')" ]
}

@test "local overrides load after shared defaults and repository settings take precedence" {
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" core.quotePath true

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" config --show-origin --get core.quotePath
  [ "$output" = "$(printf 'file:%s\ttrue' "$SANDBOX_GIT_LOCAL")" ]

  sandbox_git -C "$SANDBOX_GIT_WORKTREE" config user.name 'Project test'
  sandbox_git -C "$SANDBOX_GIT_WORKTREE" config user.email project@example.invalid
  sandbox_git -C "$SANDBOX_GIT_WORKTREE" config core.quotePath false
  git_fixture_identity

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" config --get core.quotePath
  [ "$output" = false ]

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" commit --quiet --allow-empty -m 'Project identity'
  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" log -1 --format='%an <%ae>'
  [ "$output" = 'Project test <project@example.invalid>' ]
}

@test "an existing legacy gitconfig retains its normal precedence and is preserved" {
  git_fixture_identity
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" user.name 'Legacy test'
  cp "$SANDBOX_HOME/.gitconfig" "$SANDBOX_ROOT/legacy.before"

  run -0 sandbox_chezmoi apply --exclude scripts

  cmp "$SANDBOX_HOME/.gitconfig" "$SANDBOX_ROOT/legacy.before"
  run -0 sandbox_git config --show-origin --get user.name
  [ "$output" = "$(printf 'file:%s\tLegacy test' "$SANDBOX_HOME/.gitconfig")" ]
}

@test "repeated apply preserves local configuration even when a source copy exists" {
  git_fixture_identity
  touch -t 200001010000 "$SANDBOX_GIT_LOCAL"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  # Accidental source copies must not take ownership of the machine's file.
  mkdir -p "$SANDBOX_REPOSITORY/home/dot_config/git"
  printf '[user]\n\tname = Unwanted replacement\n' \
    > "$SANDBOX_REPOSITORY/home/dot_config/git/config.local"

  run -0 sandbox_chezmoi apply --exclude scripts
  run -0 sandbox_chezmoi apply --exclude scripts

  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  [ ! "$SANDBOX_GIT_LOCAL" -nt "$SANDBOX_ROOT/local.before" ]
  [ ! "$SANDBOX_GIT_LOCAL" -ot "$SANDBOX_ROOT/local.before" ]
  run -0 sandbox_git config --get user.name
  [ "$output" = 'Dotfiles test' ]
}

@test "apply does not create local configuration from an accidental source copy" {
  mkdir -p "$SANDBOX_REPOSITORY/home/dot_config/git"
  printf '# unwanted local file\n' > "$SANDBOX_REPOSITORY/home/dot_config/git/config.local"

  run -0 sandbox_chezmoi apply --exclude scripts

  [ ! -e "$SANDBOX_GIT_LOCAL" ]
}

@test "Git ignores local configuration in target and source locations" {
  sandbox_git -C "$SANDBOX_REPOSITORY" init --quiet

  run -0 sandbox_git -C "$SANDBOX_REPOSITORY" check-ignore .config/git/config.local home/dot_config/git/config.local

  [ "$output" = "$(printf '.config/git/config.local\nhome/dot_config/git/config.local')" ]
}
