#!/usr/bin/env bash

# These functions run only inside the setup suites' disposable homes.
# Sourcing the library does not install or initialize anything.

setup_development_versions() {
  fnm default
  fnm list
  node --version
  corepack --version
  go version
  uv --version
  uvx --version
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
  test -z "${GOROOT:-}${GOPATH:-}${VIRTUAL_ENV:-}"
  case ":$PATH:" in
    *":$HOME/go/bin:"*) ;;
    *) return 1 ;;
  esac

  # Apply prepares shims, but must not download pnpm or managed Python.
  test ! -e "$COREPACK_HOME"
  test ! -e "$UV_PYTHON_INSTALL_DIR"
  local snapshot="$HOME/.test-development"
  development_flow_prepare "$HOME" "$snapshot/files"

  cd "$HOME/projects/node"
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

  cp -p package.json "$snapshot/package.json"
  setup_development_versions > "$snapshot/versions"
)

setup_development_check() (
  set -eu

  local snapshot="$HOME/.test-development"
  cd "$HOME/projects/node"
  setup_development_versions > "$snapshot/versions.after"
  cmp "$snapshot/versions" "$snapshot/versions.after"
  test "$(node --version)" = "$(fnm default)"
  test "$(command -v pnpm)" = "$FNM_MULTISHELL_PATH/bin/pnpm"
  test ! -e "$UV_PYTHON_INSTALL_DIR"
  test -z "${VIRTUAL_ENV:-}"

  cmp package.json "$snapshot/package.json"
  development_flow_check "$HOME" "$snapshot/files"
)
