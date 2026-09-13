#!/usr/bin/env bats

# Snippets expand in the isolated Zsh process, with real prepared tools.
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
  development_flow_prepare
  sandbox_chezmoi apply
}

@test "Go runs a local module and preserves an installed command across apply" {
  run -0 sandbox_zsh -lic '
    cd "$HOME/projects/go" &&
    [[ $(go env GOPATH) = "$HOME/go" ]] &&
    go run . && go install . && dotfiles-smoke
  '

  [ "$output" = "$(printf 'go:ok\ngo:ok')" ]
  cp -p "$SANDBOX_HOME/go/bin/dotfiles-smoke" "$SANDBOX_ROOT/go-tool.before"

  run -0 sandbox_chezmoi apply
  cmp "$SANDBOX_HOME/go/bin/dotfiles-smoke" "$SANDBOX_ROOT/go-tool.before"
  [ ! "$SANDBOX_HOME/go/bin/dotfiles-smoke" -nt "$SANDBOX_ROOT/go-tool.before" ]

  run -0 sandbox_zsh -lic 'dotfiles-smoke'
  [ "$output" = go:ok ]
}

@test "Node executes JavaScript from the prepared fnm default" {
  run -0 sandbox_zsh -lic '
    [[ $(node --version) = "$1" && $(fnm current) = "$1" ]] &&
    node "$HOME/projects/node/main.cjs"
  ' _ "$DEVELOPMENT_NODE_VERSION"

  [ "$output" = node:ok ]
}

@test "directory changes select real Node versions from node-version and nvmrc files" {
  run -0 sandbox_zsh -lic '
    cd "$HOME/projects/node-alternate" > /dev/null &&
    [[ $(node --version) = "$2" && $(fnm current) = "$2" ]] &&
    node main.cjs &&
    cd "$HOME/projects/node" > /dev/null &&
    [[ $(node --version) = "$1" && $(fnm current) = "$1" ]] &&
    node main.cjs &&
    [[ $(fnm default) = "$1" ]]
  ' _ "$DEVELOPMENT_NODE_VERSION" "$DEVELOPMENT_ALTERNATE_VERSION"

  [ "$output" = "$(printf 'node:ok\nnode:ok')" ]
}

@test "uv creates and runs a Python environment without activating it in the shell" {
  run -0 sandbox_zsh -lic '
    cd "$HOME/projects/python" &&
    uv venv --quiet --python "$1" &&
    uv run --no-project --python .venv/bin/python main.py &&
    [[ -z ${VIRTUAL_ENV:-} ]]
  ' _ "$DEVELOPMENT_PYTHON_SOURCE"

  [ "$output" = python:ok ]
  [ -f "$DEVELOPMENT_PROJECTS/python/.venv/pyvenv.cfg" ]
}

@test "offline development tools refuse unprepared Go modules and Python versions" {
  run ! sandbox_zsh -lic 'go list -m example.invalid/unavailable@v1.0.0'

  [[ "$output" == *'GOPROXY=off'* ]]

  run ! sandbox_zsh -lic 'uv venv --python 99.0 "$HOME/unavailable-python"'

  # uv versions describe a missing interpreter differently across platforms.
  [[ "$output" == *'99.0'* ]]
  [ ! -e "$SANDBOX_HOME/unavailable-python" ]
}

@test "repeated apply preserves Node versions, project environments, and local overrides" {
  run -0 sandbox_zsh -lic 'uv venv --quiet --python "$1" "$HOME/projects/python/.venv"' \
    _ "$DEVELOPMENT_PYTHON_SOURCE"

  # A project-local dependency exercises file preservation without a registry.
  mkdir -p "$DEVELOPMENT_PROJECTS/node/node_modules/local-fixture"
  printf 'module.exports = "local:ok";\n' > "$DEVELOPMENT_PROJECTS/node/node_modules/local-fixture/index.cjs"
  printf 'export DEVELOPMENT_LOCAL=preserved\n' > "$SANDBOX_HOME/.zshrc.local"

  local file snapshot=0
  local files=(
    .zshrc.local
    projects/node/.node-version
    projects/node-alternate/.nvmrc
    projects/node/node_modules/local-fixture/index.cjs
    projects/python/.venv/pyvenv.cfg
  )
  for file in "${files[@]}"; do
    cp -p "$SANDBOX_HOME/$file" "$SANDBOX_ROOT/preserved-$snapshot"
    snapshot=$((snapshot + 1))
  done

  run -0 sandbox_zsh -lic 'fnm default && fnm list'
  local versions_before="$output"
  local python_before
  python_before="$(readlink "$DEVELOPMENT_PROJECTS/python/.venv/bin/python")"

  run -0 sandbox_chezmoi apply

  snapshot=0
  for file in "${files[@]}"; do
    cmp "$SANDBOX_HOME/$file" "$SANDBOX_ROOT/preserved-$snapshot"
    [ ! "$SANDBOX_HOME/$file" -nt "$SANDBOX_ROOT/preserved-$snapshot" ]
    snapshot=$((snapshot + 1))
  done
  [ "$(readlink "$DEVELOPMENT_PROJECTS/python/.venv/bin/python")" = "$python_before" ]

  run -0 sandbox_zsh -lic 'fnm default && fnm list'
  [ "$output" = "$versions_before" ]

  run -0 sandbox_zsh -lic '
    [[ $DEVELOPMENT_LOCAL = preserved ]] &&
    cd "$HOME/projects/node" > /dev/null &&
    node -p "require(process.argv[1])" "$PWD/node_modules/local-fixture/index.cjs" &&
    cd "$HOME/projects/node-alternate" > /dev/null &&
    [[ $(node --version) = "$1" ]] &&
    cd "$HOME/projects/python" > /dev/null &&
    uv run --no-project --python .venv/bin/python main.py
  ' _ "$DEVELOPMENT_ALTERNATE_VERSION"

  [ "$output" = "$(printf 'local:ok\npython:ok')" ]
}
