#!/usr/bin/env bash

node_flow_prepare() {
  local node_source
  node_source="$(env -i HOME="$SANDBOX_HOME" PATH="$PATH" node -p 'process.execPath')" || return

  # Copy the test runner's Node and Corepack; never link writable runtime state
  # back to the host installation or download dependencies in the offline suite.
  # shellcheck disable=SC2016,SC2034
  NODE_FLOW_RUNTIME="$(env -i \
    HOME="$SANDBOX_HOME" PATH="$SANDBOX_PATH" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" TMPDIR="$SANDBOX_ROOT/tmp" \
    FNM_NODE_DIST_MIRROR=file:///dev/null \
    bash -euo pipefail -c '
      corepack_source="${1%/bin/node}/lib/node_modules/corepack"
      if [ ! -f "$corepack_source/dist/corepack.js" ]; then
        printf "E2E: the test runner needs Node with Corepack installed alongside it.\n" >&2
        exit 1
      fi

      fnm_environment="$(fnm env --shell bash)"
      eval "$fnm_environment"
      version="$("$1" --version)"
      runtime="$FNM_DIR/node-versions/$version/installation"
      mkdir -p "$runtime/bin" "$runtime/lib/node_modules"
      cp "$1" "$runtime/bin/node"
      cp -RL "$corepack_source" "$runtime/lib/node_modules/corepack"
      ln -s ../lib/node_modules/corepack/dist/corepack.js "$runtime/bin/corepack"
      fnm default "$version"
      printf "%s\n" "$runtime"
    ' _ "$node_source")"
}
