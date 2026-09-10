#!/usr/bin/env bash

# Shell snippets expand only inside the isolated test environment.
# shellcheck disable=SC2016

setup_container_create() {
  command -v docker > /dev/null

  # No bind mounts, host credentials, or Docker socket enter the container.
  SETUP_CONTAINER="$(docker create --init ubuntu:24.04 sleep infinity)"
  docker start "$SETUP_CONTAINER" > /dev/null

  # Provision an ordinary account before following the user-facing prerequisites.
  docker exec "$SETUP_CONTAINER" bash -euc '
    apt-get update
    apt-get install --yes --no-install-recommends sudo
    useradd --create-home --shell /bin/bash dotfiles
    printf "dotfiles ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/dotfiles
    chmod 0440 /etc/sudoers.d/dotfiles
    mkdir /tmp/source
  '

  sandbox_copy_repository "$BATS_TEST_TMPDIR/source"
  docker cp "$BATS_TEST_TMPDIR/source/." "$SETUP_CONTAINER:/tmp/source"
  docker exec "$SETUP_CONTAINER" chown -R dotfiles:dotfiles /tmp/source
}

setup_container_remove() {
  if [ -n "${SETUP_CONTAINER:-}" ]; then
    docker rm --force --volumes "$SETUP_CONTAINER" > /dev/null
  fi
}

setup_container_shell() {
  # Clear inherited settings; NONINTERACTIVE only answers Homebrew's CI prompts.
  docker exec --user dotfiles --workdir /home/dotfiles "$SETUP_CONTAINER" \
    env -i HOME=/home/dotfiles USER=dotfiles LOGNAME=dotfiles \
    PATH=/usr/local/bin:/usr/bin:/bin LC_ALL=C.UTF-8 TERM=dumb NONINTERACTIVE=1 \
    bash --noprofile --norc -euo pipefail -c "$@"
}

setup_repository() {
  # Clone the current workspace snapshot rather than the default branch. Only
  # this repository's URL is redirected; all dependency installers use HTTPS.
  setup_shell '
    git -C "$1" init --initial-branch=main
    git -C "$1" add --all
    git -C "$1" -c user.name="Dotfiles test" \
      -c user.email=test@example.invalid commit --quiet -m "Test snapshot"
    git config --global "url.file://$1.insteadOf" \
      https://github.com/jinke5245/dotfiles.git
  ' _ "$1"
}

setup_check_flow() {
  # Follow the README sequence, including PATH before the first login shell.
  run -0 setup_shell '
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    git clone https://github.com/jinke5245/dotfiles.git "$HOME/dotfiles"
    cd "$HOME/dotfiles"
    chezmoi --source "$PWD" diff
    test ! -e "$HOME/.oh-my-zsh"
    chezmoi --source "$PWD" apply
    test -f "$HOME/.oh-my-zsh/oh-my-zsh.sh"
    cmp home/dot_zshrc "$HOME/.zshrc"
  '

  run -0 setup_shell 'exec zsh -lic "$1" _ "$2"' _ '
    [[ $HOMEBREW_PREFIX = "$1" ]] &&
    [[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" ]] &&
    [[ $ZSH_THEME = robbyrussell ]] &&
    [[ ${aliases[gst]} = "git status" ]] &&
    (( $+functions[compdef] )) &&
    brew --version >/dev/null && chezmoi --version >/dev/null
  ' "$SETUP_BREW_PREFIX"
  [ -z "$output" ]

  # Snapshot both configuration and installed framework files before reapplying.
  setup_shell '
    mkdir "$HOME/.test-before"
    for file in .zprofile .zshrc .oh-my-zsh/oh-my-zsh.sh; do
      cp -p "$HOME/$file" "$HOME/.test-before/$(basename "$file")"
    done
    printf "keep\n" > "$HOME/.oh-my-zsh/custom/personal-note"
  '

  run -0 setup_shell '
    export PATH="$HOME/.local/bin:$PATH"
    cd "$HOME/dotfiles"
    chezmoi --source "$PWD" apply
    chezmoi --source "$PWD" diff --exclude scripts

    for file in .zprofile .zshrc .oh-my-zsh/oh-my-zsh.sh; do
      before="$HOME/.test-before/$(basename "$file")"
      cmp "$HOME/$file" "$before"
      test ! "$HOME/$file" -nt "$before"
      test ! "$HOME/$file" -ot "$before"
    done
    test "$(cat "$HOME/.oh-my-zsh/custom/personal-note")" = keep
  '
  [ -z "$output" ]
}
