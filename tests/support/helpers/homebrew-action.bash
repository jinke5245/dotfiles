#!/usr/bin/env bash

homebrew_action_sandbox_create() {
  install_sandbox_create
  ACTION_PATH_FILE="$SANDBOX_ROOT/github-path"
  ACTION_SCRIPT_DIR="$SANDBOX_ROOT/action-steps"
  : > "$ACTION_PATH_FILE"
  mkdir -p "$ACTION_SCRIPT_DIR"

  local step
  # Extract prerequisites and Homebrew setup from the actual action.
  for step in 0 1; do
    sandbox_chezmoi execute-template \
      "{{ (index (fromYaml (include \"$SANDBOX_REPOSITORY/.github/actions/setup-homebrew/action.yml\")).runs.steps $step).run }}" \
      > "$SANDBOX_ROOT/action-source.sh"
    [ -s "$SANDBOX_ROOT/action-source.sh" ] || {
      printf 'Missing Homebrew action step: %s\n' "$step" >&2
      return 1
    }

    # Only disposable script copies may see these relocated system paths.
    sed \
      -e "s|/opt/homebrew|$SANDBOX_ROOT/prefixes/apple|g" \
      -e "s|/usr/local|$SANDBOX_ROOT/prefixes/intel|g" \
      -e "s|/home/linuxbrew/.linuxbrew|$SANDBOX_ROOT/prefixes/linux|g" \
      "$SANDBOX_ROOT/action-source.sh" > "$ACTION_SCRIPT_DIR/$step.sh"
  done
}

homebrew_action_step() {
  install_sandbox_run env \
    GITHUB_PATH="$ACTION_PATH_FILE" \
    /bin/bash --noprofile --norc -e -o pipefail "$ACTION_SCRIPT_DIR/$1.sh"
}

setup_homebrew_action() {
  local runner_os="$1"

  # Separate child processes mirror action steps; act verifies GitHub's routing.
  if [[ "$runner_os" = Linux ]]; then
    homebrew_action_step 0 || return
  fi
  homebrew_action_step 1
}
