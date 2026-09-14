#!/usr/bin/env bats

# Shell snippets expand in the isolated child processes.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'
load '../helpers/zsh.bash'
load '../helpers/flow.bash'
load '../helpers/development-flow.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
  flow_suite_setup
}

setup() {
  flow_sandbox_create
}

@test "apply starts the configured shell and preserves local state on reapplication" {
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh" ]
  [ ! -e "$SANDBOX_HOME/.ssh" ]
  [ ! -e "$SANDBOX_HOME/.config/git/config.local" ]

  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"
  development_flow_prepare "$SANDBOX_HOME" "$SANDBOX_ROOT/development.before"

  run -0 sandbox_chezmoi apply

  [ -f "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh" ]
  [ -f "$SANDBOX_HOME/.ssh/id_ed25519" ]
  [ -f "$SANDBOX_HOME/.ssh/id_ed25519.pub" ]
  cmp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"

  # Start the deployed configuration with real dependencies and local overrides.
  run -0 sandbox_zsh -lic '
    [[ $HOMEBREW_PREFIX = "$1" ]] &&
    [[ $ZSH_THEME = robbyrussell ]] &&
    [[ ${aliases[gst]} = "git status --short" ]] &&
    [[ $EDITOR = nvim ]] &&
    [[ $(project) = "$HOME/projects" ]] &&
    [[ $(bindkey "^[[A") = *beginning-of-line ]] &&
    (( $+functions[compdef] )) &&
    [[ $(git config --get user.name) = "Dotfiles test" ]] &&
    [[ $(git config --get user.email) = test@example.invalid ]]
  ' _ "$FLOW_BREW_PREFIX"
  [ -z "$output" ]

  # Keep manual identity edits, framework customization, and development state.
  run -0 sandbox_zsh -lc '
    git config --file "$HOME/.config/git/config.local" user.name "Manual Name" &&
    git config --file "$HOME/.config/git/config.local" user.email manual@example.invalid
  '
  printf 'keep\n' > "$SANDBOX_HOME/.oh-my-zsh/custom/personal-note"

  local file before
  local files=(
    .zprofile
    .zshrc
    .zshrc.local
    .oh-my-zsh/oh-my-zsh.sh
    .oh-my-zsh/custom/personal-note
    .config/git/config
    .config/git/config.local
    .gitconfig
    .ssh/id_ed25519
    .ssh/id_ed25519.pub
  )
  for file in "${files[@]}"; do
    before="$SANDBOX_ROOT/before/$file"
    mkdir -p "$(dirname "$before")"
    cp -p "$SANDBOX_HOME/$file" "$before"
  done

  run -0 sandbox_zsh -lic 'fnm default && fnm list'
  local versions_before="$output"

  # Any attempt to download an installer again must now fail.
  touch "$SANDBOX_HOME/.test-upstream/no-download"

  run -0 sandbox_chezmoi apply

  for file in "${files[@]}"; do
    before="$SANDBOX_ROOT/before/$file"
    cmp "$SANDBOX_HOME/$file" "$before"
    [ ! "$SANDBOX_HOME/$file" -nt "$before" ]
    [ ! "$SANDBOX_HOME/$file" -ot "$before" ]
  done
  development_flow_check "$SANDBOX_HOME" "$SANDBOX_ROOT/development.before"

  run -0 sandbox_zsh -lic '
    [[ $(git config --get user.name) = "Manual Name" ]] &&
    [[ $(git config --get user.email) = manual@example.invalid ]] &&
    [[ $EDITOR = nvim ]] &&
    fnm default && fnm list
  '
  [ "$output" = "$versions_before" ]

  run -0 sandbox_chezmoi diff --exclude scripts
  [ -z "$output" ]
}

@test "offline apply enables pnpm only inside the isolated Node installation" {
  cp -p "$NODE_FLOW_RUNTIME/bin/node" "$SANDBOX_ROOT/node.before"
  cp -p "$NODE_FLOW_RUNTIME/lib/node_modules/corepack/dist/corepack.js" "$SANDBOX_ROOT/corepack.before"

  run -0 sandbox_chezmoi apply

  [ -x "$NODE_FLOW_RUNTIME/bin/pnpm" ]
  [ "$(readlink "$NODE_FLOW_RUNTIME/bin/pnpm")" = ../lib/node_modules/corepack/dist/pnpm.js ]
  [ ! -L "$NODE_FLOW_RUNTIME/lib/node_modules/corepack" ]
  run -0 sandbox_zsh -lic 'node --version && corepack --version'
  cmp "$NODE_FLOW_RUNTIME/bin/node" "$SANDBOX_ROOT/node.before"
  cmp "$NODE_FLOW_RUNTIME/lib/node_modules/corepack/dist/corepack.js" "$SANDBOX_ROOT/corepack.before"
  [ ! "$NODE_FLOW_RUNTIME/bin/node" -nt "$SANDBOX_ROOT/node.before" ]
}

@test "offline apply refuses a runtime download when the prepared default is missing" {
  local fnm_directory="${NODE_FLOW_RUNTIME%/node-versions/*}"
  rm "$fnm_directory/aliases/default"

  run ! sandbox_chezmoi apply

  [[ "$output" == *'file:///dev/null'* ]] || return 1
  [ ! -e "$fnm_directory/aliases/default" ]
  [ ! -e "$SANDBOX_HOME/.zprofile" ]
}

@test "interactive startup leaves a missing project Node version uninstalled" {
  sandbox_chezmoi apply
  printf '999.0.0\n' > "$SANDBOX_ROOT/.node-version"
  local expected_version fnm_directory
  expected_version="$("$NODE_FLOW_RUNTIME/bin/node" --version)"
  fnm_directory="${NODE_FLOW_RUNTIME%/node-versions/*}"

  run -0 --separate-stderr sandbox_zsh -lic '
    [[ -n $FNM_MULTISHELL_PATH && ${_comps[fnm]} = _fnm ]] && node --version
  '

  [ "$output" = "$expected_version" ]
  [ -z "$stderr" ]
  [ ! -e "$fnm_directory/node-versions/v999.0.0" ]
}
