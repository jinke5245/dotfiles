#!/bin/bash

# Generated shell expressions expand only when the caller evaluates them.
# shellcheck disable=SC2016

set -eu

state="$HOME/.install-test"
export FNM_DIR="${FNM_DIR:-$state/fnm}"
mkdir -p "$FNM_DIR/aliases"
printf '%s\n' "$*" >> "$state/fnm.log"
printf 'fnm %s\n' "$*" >> "$state/events.log"
printf '%s\n' "$0" > "$state/selected-fnm"

case "$*" in
  'env --shell bash')
    if [ -e "$state/fail-fnm-env" ]; then
      # Partial output from a failed command must not be evaluated.
      printf 'touch "$HOME/partial-fnm-env"\n'
      exit 95
    fi
    printf 'export FNM_DIR=%q\n' "$FNM_DIR"
    printf 'export FNM_MULTISHELL_PATH=%q\n' "$state/fnm-shell"
    printf 'export PATH=%q:"$PATH"\n' "$state/fnm-shell/bin"
    ;;
  default)
    target="$(readlink "$FNM_DIR/aliases/default")" || exit 1
    [ -d "$target" ] || exit 1
    version="${target%/installation}"
    printf '%s\n' "${version##*/}"
    ;;
  'install --lts' | 'install v22.22.2' | 'install v24.0.0')
    [ ! -e "$state/fail-fnm-install" ] || exit 96
    if [ "${FNM_COREPACK_ENABLED:-false}" = true ] && [ -e "$state/without-bundled-corepack" ]; then
      printf 'fnm cannot enable Corepack when Node does not bundle it.\n' >&2
      exit 96
    fi
    version="$2"
    [ "$version" != --lts ] || version=v24.0.0
    prefix="$FNM_DIR/node-versions/$version/installation"
    mkdir -p "$prefix/bin"
    cp "$state/unexpected-command.bash" "$prefix/bin/node"
    cp "$state/npm.bash" "$prefix/bin/npm"
    if [ ! -e "$state/without-bundled-corepack" ]; then
      cp "$state/corepack.bash" "$prefix/bin/corepack"
    fi
    chmod +x "$prefix/bin/"*
    if [ ! -e "$FNM_DIR/aliases/default" ]; then
      ln -sfn "$prefix" "$FNM_DIR/aliases/default"
    fi
    ;;
  'use default')
    [ ! -e "$state/fail-fnm-use" ] || exit 97
    target="$(readlink "$FNM_DIR/aliases/default")"
    [ -x "$target/bin/node" ] || exit 97
    ln -sfn "$target" "$FNM_MULTISHELL_PATH"
    ;;
  *)
    printf 'Unexpected fnm invocation: %s\n' "$*" >&2
    exit 90
    ;;
esac
