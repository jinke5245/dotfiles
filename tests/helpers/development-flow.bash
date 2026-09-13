#!/usr/bin/env bash

# Prepared interpreters are read-only inputs. Projects, shims, and tool state
# belong to the current test; the offline suite never downloads a runtime.
# shellcheck disable=SC2034

development_flow_prepare() {
  if [ -z "${NODE_ALTERNATE_SOURCE:-}" ]; then
    printf 'E2E: set NODE_ALTERNATE_SOURCE to a different prepared Node executable.\n' >&2
    return 1
  fi

  local alternate_source
  alternate_source="$(env -i HOME="$SANDBOX_HOME" "$NODE_ALTERNATE_SOURCE" -p 'process.execPath')" || return
  DEVELOPMENT_NODE_VERSION="$(env -i "$NODE_FLOW_RUNTIME/bin/node" --version)" || return
  DEVELOPMENT_ALTERNATE_VERSION="$(env -i "$alternate_source" --version)" || return
  if [ "$DEVELOPMENT_NODE_VERSION" = "$DEVELOPMENT_ALTERNATE_VERSION" ]; then
    printf 'E2E: project switching requires two different real Node versions.\n' >&2
    return 1
  fi

  local alternate_runtime
  alternate_runtime="${NODE_FLOW_RUNTIME%/node-versions/*}/node-versions/$DEVELOPMENT_ALTERNATE_VERSION/installation"
  mkdir -p "$alternate_runtime/bin"
  ln -s "$alternate_source" "$alternate_runtime/bin/node"

  DEVELOPMENT_PYTHON_SOURCE="$(env -i HOME="$SANDBOX_HOME" PATH="$PATH" \
    "${PYTHON_SOURCE:-python3}" -I -c 'import sys; print(sys.executable)')" || return

  DEVELOPMENT_PROJECTS="$SANDBOX_HOME/projects"
  cp -R "$SANDBOX_REPOSITORY/tests/fixtures/development" "$DEVELOPMENT_PROJECTS"
  cp -R "$DEVELOPMENT_PROJECTS/node" "$DEVELOPMENT_PROJECTS/node-alternate"
  printf '%s\n' "$DEVELOPMENT_NODE_VERSION" > "$DEVELOPMENT_PROJECTS/node/.node-version"
  printf '%s\n' "$DEVELOPMENT_ALTERNATE_VERSION" > "$DEVELOPMENT_PROJECTS/node-alternate/.nvmrc"
}
