#!/usr/bin/env bash

node_flow_prepare() {
  local node_source corepack_source
  node_source="$(env -i HOME="$SANDBOX_HOME" PATH="$PATH" "${NODE_SOURCE:-node}" -p 'process.execPath')" || return
  corepack_source="${COREPACK_SOURCE:-${node_source%/bin/node}/lib/node_modules/corepack}"

  # Reuse Node in place so native library paths still resolve. Copy Corepack and
  # keep generated shims and all writable runtime state inside the sandbox.
  # shellcheck disable=SC2016,SC2034
  NODE_FLOW_RUNTIME="$(env -i \
    HOME="$SANDBOX_HOME" PATH="$SANDBOX_PATH" \
    XDG_DATA_HOME="$SANDBOX_ROOT/data" XDG_STATE_HOME="$SANDBOX_ROOT/state" \
    XDG_CACHE_HOME="$SANDBOX_ROOT/cache" TMPDIR="$SANDBOX_ROOT/tmp" \
    FNM_NODE_DIST_MIRROR=file:///dev/null \
    bash -euo pipefail -c '
      if [ ! -f "$2/dist/corepack.js" ]; then
        printf "E2E: set COREPACK_SOURCE to a prepared Corepack package directory.\n" >&2
        exit 1
      fi

      fnm_environment="$(fnm env --shell bash)"
      eval "$fnm_environment"
      version="$("$1" --version)"
      runtime="$FNM_DIR/node-versions/$version/installation"
      mkdir -p "$runtime/bin" "$runtime/lib/node_modules"
      ln -s "$1" "$runtime/bin/node"
      cp -RL "$2" "$runtime/lib/node_modules/corepack"
      ln -s ../lib/node_modules/corepack/dist/corepack.js "$runtime/bin/corepack"
      fnm default "$version"
      printf "%s\n" "$runtime"
    ' _ "$node_source" "$corepack_source")"
}
