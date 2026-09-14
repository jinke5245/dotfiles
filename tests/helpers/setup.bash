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
    XDG_DATA_HOME=/home/dotfiles/.local/share XDG_STATE_HOME=/home/dotfiles/.local/state \
    XDG_CACHE_HOME=/home/dotfiles/.cache COREPACK_HOME=/home/dotfiles/.cache/corepack \
    UV_PYTHON_INSTALL_DIR=/home/dotfiles/.local/share/uv/python PYTHONDONTWRITEBYTECODE=1 \
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

setup_check_ssh_keys() {
  run -0 setup_shell '
    source "$1/tests/helpers/ssh-flow.bash"
    ssh_flow_check initial@example.invalid
  ' _ "$SETUP_SOURCE"
}

setup_prepare_development() {
  run -0 setup_shell 'exec zsh -lic "$1" _ "$2"' _ '
    source "$1/tests/helpers/development-flow.bash"
    source "$1/tests/helpers/setup-development.bash"
    setup_development_prepare
  ' "$SETUP_SOURCE"
}

setup_check_development() {
  # Disable downloads before startup and repeated checks.
  run -0 setup_shell '
    export COREPACK_ENABLE_NETWORK=0 UV_OFFLINE=true UV_PYTHON_DOWNLOADS=never
    export FNM_NODE_DIST_MIRROR=file:///dev/null GOPROXY=off GOTOOLCHAIN=local
    exec zsh -lic "$1" _ "$2"
  ' _ '
    source "$1/tests/helpers/development-flow.bash"
    source "$1/tests/helpers/setup-development.bash"
    setup_development_check
  ' "$SETUP_SOURCE"
}

setup_check_flow() {
  # Follow the README sequence, including PATH before the first login shell.
  run -0 setup_shell '
    # Keep existing shell customization, but start without a Git identity.
    cp "$1/tests/fixtures/zsh/local.zsh" "$HOME/.zshrc.local"
    test ! -e "$HOME/.config/git/config.local"
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    git clone https://github.com/jinke5245/dotfiles.git "$HOME/dotfiles"
    cd "$HOME/dotfiles"
    chezmoi --source "$PWD" init \
      --promptString "User name=Initial User,User email=initial@example.invalid" </dev/null
    test -f "$HOME/.config/chezmoi/chezmoi.toml"
    test "$(chezmoi --source "$PWD" execute-template "{{ .user.name }}")" = "Initial User"
    test "$(chezmoi --source "$PWD" execute-template "{{ .user.email }}")" = initial@example.invalid

    # Initialization and preview must leave Git, SSH, and dependencies untouched.
    chezmoi --source "$PWD" diff </dev/null
    test ! -e "$HOME/.config/git/config.local"
    test ! -e "$HOME/.oh-my-zsh"
    test ! -e "$HOME/.ssh/id_ed25519"
    test ! -e "$HOME/.ssh/id_ed25519.pub"
    chezmoi --source "$PWD" apply </dev/null
    test -f "$HOME/.oh-my-zsh/oh-my-zsh.sh"
    cmp home/dot_zshrc "$HOME/.zshrc"
    cmp tests/fixtures/zsh/local.zsh "$HOME/.zshrc.local"
    test "$(git -C / config --get user.name)" = "Initial User"
    test "$(git -C / config --get user.email)" = initial@example.invalid

    # With saved inputs available, initialization also works without prompts.
    chezmoi --source "$PWD" init </dev/null
    test "$(chezmoi --source "$PWD" execute-template "{{ .user.name }}")" = "Initial User"
    test "$(chezmoi --source "$PWD" execute-template "{{ .user.email }}")" = initial@example.invalid
  ' _ "$SETUP_SOURCE"

  run -0 setup_shell 'exec zsh -lic "$1" _ "$2"' _ '
    [[ $HOMEBREW_PREFIX = "$1" ]] &&
    [[ $path[1] = "$FNM_MULTISHELL_PATH/bin" ]] &&
    [[ $(command -v node) = "$FNM_MULTISHELL_PATH/bin/node" ]] &&
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
    [[ $path[1] = "$HOME/bin" && $path[2] = "$HOME/.local/bin" ]] &&
    brew bundle check --file="$HOME/dotfiles/Brewfile" --no-upgrade &&
    brew list --versions > "$HOME/.test-package-versions"
  '

  setup_check_git_tools
  setup_check_ssh_keys
  setup_prepare_development

  # Follow the documented identity-edit commands before reapplying. The saved
  # inputs and SSH comment must remain independent of these later Git changes.
  run -0 setup_shell '
    git config --file "$HOME/.config/git/config.local" user.name "Dotfiles test"
    git config --file "$HOME/.config/git/config.local" user.email test@example.invalid
    git config --file "$HOME/.config/git/config.local" core.quotePath true
    printf "\n# Keep this local comment.\n" >> "$HOME/.config/git/config.local"
  '

  # Snapshot managed and local configuration plus the installed framework.
  setup_shell '
    mkdir "$HOME/.test-before"
    for file in .zprofile .zshrc .zshrc.local .oh-my-zsh/oh-my-zsh.sh \
      .config/chezmoi/chezmoi.toml .config/git/config .config/git/config.local .gitconfig \
      .ssh/id_ed25519 .ssh/id_ed25519.pub; do
      cp -p "$HOME/$file" "$HOME/.test-before/$(basename "$file")"
    done
    printf "keep\n" > "$HOME/.oh-my-zsh/custom/personal-note"
  '

  run -0 setup_shell '
    export PATH="$HOME/.local/bin:$PATH"
    export COREPACK_ENABLE_NETWORK=0 UV_OFFLINE=true UV_PYTHON_DOWNLOADS=never
    export FNM_NODE_DIST_MIRROR=file:///dev/null
    cd "$HOME/dotfiles"
    chezmoi --source "$PWD" apply </dev/null
    configuration_diff="$(chezmoi --source "$PWD" diff --exclude scripts </dev/null)"
    test -z "$configuration_diff"

    # Repeated apply must not request upgrades of already installed packages.
    zsh -lc "brew list --versions" > "$HOME/.test-package-versions-after"
    cmp "$HOME/.test-package-versions" "$HOME/.test-package-versions-after"

    for file in .zprofile .zshrc .zshrc.local .oh-my-zsh/oh-my-zsh.sh \
      .config/chezmoi/chezmoi.toml .config/git/config .config/git/config.local .gitconfig \
      .ssh/id_ed25519 .ssh/id_ed25519.pub; do
      before="$HOME/.test-before/$(basename "$file")"
      cmp "$HOME/$file" "$before"
      test ! "$HOME/$file" -nt "$before"
      test ! "$HOME/$file" -ot "$before"
    done
    test "$(cat "$HOME/.oh-my-zsh/custom/personal-note")" = keep
  '

  setup_check_git_configuration
  setup_check_development
}
