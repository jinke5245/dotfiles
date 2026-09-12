#!/usr/bin/env bash

# Shared assertions run in the isolated login shell on both platforms.
git_flow_check() (
  set -eu
  export GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL=file

  test "$(git config --get user.useConfigOnly)" = true
  test "$(git config --get user.name)" = 'Dotfiles test'
  test "$(git config --get user.email)" = test@example.invalid
  test "$(git config --get core.quotePath)" = true

  local project
  project="$(mktemp -d "$HOME/git-lfs.XXXXXX")"
  git init --quiet "$project"
  cd "$project"
  test "$(git symbolic-ref --short HEAD)" = main
  cp "$HOME/.config/git/config" "$project/shared.before"
  cp "$HOME/.config/git/config.local" "$project/local.before"
  cp "$HOME/.gitconfig" "$project/legacy.before"

  # Use attributes directly: running `git lfs install` here could mask missing
  # shared filters by installing repository-level overrides.
  printf '*.bin filter=lfs diff=lfs merge=lfs -text\n' > .gitattributes
  printf 'Dotfiles LFS fixture\000with binary content\n' > sample.bin
  cp sample.bin "$project/original"
  git add .gitattributes sample.bin
  git show :sample.bin > "$project/pointer"
  git lfs pointer --check --file="$project/pointer"

  git commit --quiet -m 'Track LFS fixture'
  test "$(git log -1 --format='%an <%ae>')" = 'Dotfiles test <test@example.invalid>'
  rm sample.bin
  git checkout -- sample.bin
  cmp sample.bin "$project/original"
  git lfs fsck

  if git config --local --get-regexp '^filter\.lfs\.'; then
    printf 'LFS round-trip must use shared filters, not repository overrides.\n' >&2
    exit 1
  fi

  # Follow the documented project setup separately, keeping global files intact.
  git lfs install --local
  git lfs track '*.bin'
  test -x .git/hooks/pre-push
  cmp "$HOME/.config/git/config" "$project/shared.before"
  cmp "$HOME/.config/git/config.local" "$project/local.before"
  cmp "$HOME/.gitconfig" "$project/legacy.before"
)
