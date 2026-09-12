#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/git.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  git_sandbox_create
}

@test "Git discovers shared configuration without a local file or legacy gitconfig" {
  run -0 sandbox_git config --show-origin --get user.useConfigOnly

  [ "$output" = "$(printf 'file:%s\ttrue' "$SANDBOX_HOME/.config/git/config")" ]
  [ ! -e "$SANDBOX_GIT_LOCAL" ]
  [ ! -e "$SANDBOX_HOME/.gitconfig" ]

  run -1 sandbox_git config --get-regexp '^user\.(name|email)$'
  [ -z "$output" ]

  run -1 sandbox_git config --get pull.rebase
  [ -z "$output" ]

  run -1 sandbox_git config --get-regexp '^alias\.'
  [ -z "$output" ]
}

@test "new repositories start on main" {
  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" symbolic-ref --short HEAD

  [ "$output" = main ]
}

@test "status displays Chinese filenames without octal escaping" {
  printf 'example\n' > "$SANDBOX_GIT_WORKTREE/中文.txt"

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" status --short

  [ "$output" = '?? 中文.txt' ]
}

@test "pull fast-forwards to the upstream commit" {
  git_fixture_remote
  sandbox_git -C "$SANDBOX_ROOT/peer" commit --quiet --allow-empty -m 'Upstream change'
  sandbox_git -C "$SANDBOX_ROOT/peer" push --quiet
  local expected
  expected="$(sandbox_git -C "$SANDBOX_ROOT/peer" rev-parse HEAD)"

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" pull --quiet

  [ "$(sandbox_git -C "$SANDBOX_GIT_WORKTREE" rev-parse HEAD)" = "$expected" ]
}

@test "pull refuses divergent history without changing the local commit" {
  git_fixture_remote
  sandbox_git -C "$SANDBOX_ROOT/peer" commit --quiet --allow-empty -m 'Upstream change'
  sandbox_git -C "$SANDBOX_ROOT/peer" push --quiet
  sandbox_git -C "$SANDBOX_GIT_WORKTREE" commit --quiet --allow-empty -m 'Local change'
  local before
  before="$(sandbox_git -C "$SANDBOX_GIT_WORKTREE" rev-parse HEAD)"

  run -128 sandbox_git -C "$SANDBOX_GIT_WORKTREE" pull --quiet

  [[ "$output" == *'Not possible to fast-forward'* ]]
  [ "$(sandbox_git -C "$SANDBOX_GIT_WORKTREE" rev-parse HEAD)" = "$before" ]
  [ ! -e "$SANDBOX_GIT_WORKTREE/.git/MERGE_HEAD" ]
}

@test "fetch prunes a remote-tracking branch deleted upstream" {
  git_fixture_remote
  sandbox_git -C "$SANDBOX_ROOT/peer" push --quiet origin HEAD:temporary
  sandbox_git -C "$SANDBOX_GIT_WORKTREE" fetch --quiet
  sandbox_git -C "$SANDBOX_GIT_WORKTREE" show-ref --verify --quiet refs/remotes/origin/temporary
  sandbox_git -C "$SANDBOX_ROOT/peer" push --quiet origin --delete temporary

  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" fetch --quiet

  run -1 sandbox_git -C "$SANDBOX_GIT_WORKTREE" show-ref --verify --quiet refs/remotes/origin/temporary
}

@test "LFS filtering is configured without running git lfs install" {
  run -0 sandbox_git config --get filter.lfs.clean
  [ "$output" = 'git-lfs clean -- %f' ]

  run -0 sandbox_git config --get filter.lfs.smudge
  [ "$output" = 'git-lfs smudge -- %f' ]

  run -0 sandbox_git config --get filter.lfs.process
  [ "$output" = 'git-lfs filter-process' ]

  run -0 sandbox_git config --type=bool --get filter.lfs.required
  [ "$output" = true ]
}
