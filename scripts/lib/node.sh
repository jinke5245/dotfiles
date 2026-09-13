#!/usr/bin/env bash

initialize_node() (
  local brew prefix fnm_environment node_bin
  brew="$(find_homebrew)" || return
  prefix="$("$brew" --prefix)" || return
  export PATH="$prefix/bin:$PATH"

  # Initialize only this subprocess, independently of project version files.
  fnm_environment="$(fnm env --shell bash)" || return
  eval "$fnm_environment" || return

  if ! fnm default > /dev/null 2>&1; then
    if [[ -e "$FNM_DIR/aliases/default" || -L "$FNM_DIR/aliases/default" ]]; then
      printf 'fnm: cannot resolve the existing default; repair it before applying.\n' >&2
      return 1
    fi

    # fnm assigns a default on first installation. Prepare Corepack below,
    # including on Node releases that no longer bundle it.
    FNM_COREPACK_ENABLED=false fnm install --lts || return
  fi
  fnm use default < /dev/null || return

  # Target this Node installation even if PATH or npmrc names another prefix.
  node_bin="$FNM_MULTISHELL_PATH/bin"
  if [[ ! -x "$node_bin/corepack" ]]; then
    "$node_bin/npm" install --global --prefix "$FNM_MULTISHELL_PATH" corepack || return
  fi
  "$node_bin/corepack" enable pnpm --install-directory "$node_bin"
)
