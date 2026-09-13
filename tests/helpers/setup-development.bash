#!/usr/bin/env bash

# These functions run only inside the setup suites' disposable homes.
# Sourcing the library does not install or initialize anything.

setup_development_versions() {
  fnm default
  fnm list
  node --version
  corepack --version
  pnpm --version
  go version
  uv --version
  "$HOME/projects/python/.venv/bin/python" --version
}

setup_development_prepare() (
  set -eu

  local tool
  for tool in go fnm uv uvx; do
    test "$(command -v "$tool")" = "$HOMEBREW_PREFIX/bin/$tool"
  done
  for tool in node corepack pnpm; do
    test "$(command -v "$tool")" = "$FNM_MULTISHELL_PATH/bin/$tool"
  done
  test "$(fnm default)" = "$(node --version)"
  node -e 'if (!process.release.lts) process.exit(1)'

  # Apply prepares shims, but must not download pnpm or managed Python.
  test ! -e "$COREPACK_HOME"
  test ! -e "$UV_PYTHON_INSTALL_DIR"
  cp -R "$HOME/dotfiles/tests/fixtures/development" "$HOME/projects"

  cd "$HOME/projects/go"
  go run .
  go install .
  dotfiles-smoke

  cd "$HOME/projects/node"
  node --version > .node-version
  # Use the repository's exact package-manager declaration without installing
  # its development dependencies or inheriting its separate Node version file.
  node -e '
    const fs = require("node:fs");
    const { packageManager } = require(process.argv[1]);
    fs.writeFileSync("package.json", JSON.stringify({ private: true, packageManager }, null, 2) + "\n");
  ' "$HOME/dotfiles/package.json"

  local expected_pnpm actual_pnpm
  expected_pnpm="$(node -p 'require("./package.json").packageManager.split("@")[1].split("+")[0]')"
  actual_pnpm="$(pnpm --version)"
  test "$actual_pnpm" = "$expected_pnpm"
  test -d "$COREPACK_HOME"
  pnpm exec node main.cjs

  # Explicit project use downloads Python; it is not a setup default.
  cd "$HOME/projects/python"
  uv venv --managed-python --python 3.13
  uv run --no-project --python .venv/bin/python main.py
  test -d "$UV_PYTHON_INSTALL_DIR"
  test -z "${VIRTUAL_ENV:-}"

  # Preserve a project-local dependency without adding a registry dependency.
  mkdir -p "$HOME/projects/node/node_modules/local-fixture"
  printf 'module.exports = "local:ok";\n' > "$HOME/projects/node/node_modules/local-fixture/index.cjs"

  local snapshot="$HOME/.test-development"
  mkdir "$snapshot"
  cp -Rp "$HOME/projects" "$snapshot/projects"
  cp -p "$HOME/go/bin/dotfiles-smoke" "$snapshot/go-tool"
  readlink "$HOME/projects/python/.venv/bin/python" > "$snapshot/python-link"
  cd "$HOME/projects/node"
  setup_development_versions > "$snapshot/versions"
)

setup_development_check() (
  set -eu

  local snapshot="$HOME/.test-development"
  cd "$HOME/projects/node"
  setup_development_versions > "$snapshot/versions.after"
  cmp "$snapshot/versions" "$snapshot/versions.after"
  pnpm exec node main.cjs
  test "$(node -p 'require("./node_modules/local-fixture/index.cjs")')" = local:ok
  test "$(fnm current)" = "$(fnm default)"

  dotfiles-smoke
  cmp "$HOME/go/bin/dotfiles-smoke" "$snapshot/go-tool"
  test ! "$HOME/go/bin/dotfiles-smoke" -nt "$snapshot/go-tool"
  test ! "$HOME/go/bin/dotfiles-smoke" -ot "$snapshot/go-tool"

  cd "$HOME/projects/python"
  uv run --no-project --python .venv/bin/python main.py
  test -z "${VIRTUAL_ENV:-}"
  test "$(readlink .venv/bin/python)" = "$(cat "$snapshot/python-link")"
  test ! .venv/pyvenv.cfg -nt "$snapshot/projects/python/.venv/pyvenv.cfg"
  test ! .venv/pyvenv.cfg -ot "$snapshot/projects/python/.venv/pyvenv.cfg"
  diff -r "$snapshot/projects" "$HOME/projects"
)
