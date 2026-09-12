#!/usr/bin/env bash

# Shell snippets expand only inside the isolated test environment.
# shellcheck disable=SC2016

setup_container_create() {
  if ! command -v docker > /dev/null; then
    printf 'Docker is required to run the Ubuntu setup tests.\n' >&2
    return 1
  fi

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

setup_check_git_tools() {
  # Check the expected installation, not a system copy elsewhere on PATH.
  run -0 setup_shell 'exec zsh -lc "$1" _ "$2"' _ '
    for tool in git git-lfs gh glab tig; do
      expected="$1/bin/$tool"
      actual="$(command -v "$tool")"
      if [[ "$actual" != "$expected" ]]; then
        print -u2 -r -- "$tool: expected $expected, got ${actual:-not found}"
        exit 1
      fi
    done

    git --version &&
    git lfs version &&
    gh --version &&
    glab --version &&
    tig --version
  ' "$SETUP_BREW_PREFIX"
}

setup_check_git_configuration() {
  run -0 setup_shell 'exec zsh -lc "$1" _ "$2"' _ '
    source "$1/tests/helpers/git-flow.bash"
    git_flow_check
  ' "$SETUP_SOURCE"
}

setup_check_flow() {
  # Follow the README sequence, including PATH before the first login shell.
  run -0 setup_shell '
    # A machine may already have local configuration before its first setup.
    cp "$1/tests/fixtures/zsh/local.zsh" "$HOME/.zshrc.local"
    mkdir -p "$HOME/.config/git"
    cp "$1/tests/fixtures/git/local.config" "$HOME/.config/git/config.local"
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    git clone https://github.com/jinke5245/dotfiles.git "$HOME/dotfiles"
    cd "$HOME/dotfiles"
    chezmoi --source "$PWD" diff
    test ! -e "$HOME/.oh-my-zsh"
    chezmoi --source "$PWD" apply
    test -f "$HOME/.oh-my-zsh/oh-my-zsh.sh"
    cmp home/dot_zshrc "$HOME/.zshrc"
    cmp tests/fixtures/zsh/local.zsh "$HOME/.zshrc.local"
    cmp tests/fixtures/git/local.config "$HOME/.config/git/config.local"
  ' _ "$SETUP_SOURCE"

  run -0 setup_shell 'exec zsh -lic "$1" _ "$2"' _ '
    [[ $HOMEBREW_PREFIX = "$1" ]] &&
    [[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" ]] &&
    [[ $ZSH_THEME = robbyrussell ]] &&
    [[ ${aliases[gst]} = "git status --short" ]] &&
    [[ $EDITOR = nvim ]] &&
    [[ $(project) = "$HOME/projects" ]] &&
    [[ $(bindkey "^[[A") = *beginning-of-line ]] &&
    (( $+functions[compdef] )) &&
    brew --version >/dev/null && chezmoi --version >/dev/null
  ' "$SETUP_BREW_PREFIX"
  [ -z "$output" ]

  # Package-manager diagnostics are separate from a quiet shell startup.
  run -0 setup_shell 'exec zsh -lc "$1"' _ '
    brew bundle check --file="$HOME/dotfiles/Brewfile" --no-upgrade &&
    brew list --versions > "$HOME/.test-package-versions"
  '

  setup_check_git_tools
  setup_check_git_configuration

  # Snapshot managed and local configuration plus the installed framework.
  setup_shell '
    mkdir "$HOME/.test-before"
    for file in .zprofile .zshrc .zshrc.local .oh-my-zsh/oh-my-zsh.sh \
      .config/git/config .config/git/config.local .gitconfig; do
      cp -p "$HOME/$file" "$HOME/.test-before/$(basename "$file")"
    done
    printf "keep\n" > "$HOME/.oh-my-zsh/custom/personal-note"
  '

  run -0 setup_shell '
    export PATH="$HOME/.local/bin:$PATH"
    cd "$HOME/dotfiles"
    chezmoi --source "$PWD" apply
    configuration_diff="$(chezmoi --source "$PWD" diff --exclude scripts)"
    test -z "$configuration_diff"

    # Repeated apply must not request upgrades of already installed packages.
    zsh -lc "brew list --versions" > "$HOME/.test-package-versions-after"
    cmp "$HOME/.test-package-versions" "$HOME/.test-package-versions-after"

    for file in .zprofile .zshrc .zshrc.local .oh-my-zsh/oh-my-zsh.sh \
      .config/git/config .config/git/config.local .gitconfig; do
      before="$HOME/.test-before/$(basename "$file")"
      cmp "$HOME/$file" "$before"
      test ! "$HOME/$file" -nt "$before"
      test ! "$HOME/$file" -ot "$before"
    done
    test "$(cat "$HOME/.oh-my-zsh/custom/personal-note")" = keep
  '

  setup_check_git_tools
  setup_check_git_configuration
}
