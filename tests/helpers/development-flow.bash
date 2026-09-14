#!/usr/bin/env bash

# Prepared interpreters are read-only inputs. Projects, shims, and tool state
# belong to the current test; the offline suite never downloads a runtime.
# shellcheck disable=SC2034

development_flow_prepare() {
  DEVELOPMENT_NODE_VERSION="$(env -i "$NODE_FLOW_RUNTIME/bin/node" --version)" || return

  DEVELOPMENT_PYTHON_SOURCE="$(env -i HOME="$SANDBOX_HOME" PATH="$PATH" \
    "${PYTHON_SOURCE:-python3}" -I -c 'import sys; print(sys.executable)')" || return

  DEVELOPMENT_PROJECTS="$SANDBOX_HOME/projects"
  cp -R "$SANDBOX_REPOSITORY/tests/fixtures/development" "$DEVELOPMENT_PROJECTS"
  printf '%s\n' "$DEVELOPMENT_NODE_VERSION" > "$DEVELOPMENT_PROJECTS/node/.node-version"
}
