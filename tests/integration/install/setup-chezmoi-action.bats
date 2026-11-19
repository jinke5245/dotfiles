#!/usr/bin/env bats

# Download and installer fixtures run only inside the isolated HOME.
# shellcheck disable=SC2016

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
  local step
  for step in 0 1; do
    sandbox_chezmoi execute-template \
      "{{ (index (fromYaml (include \"$SANDBOX_REPOSITORY/.github/actions/setup-chezmoi/action.yml\")).runs.steps $step).run }}" \
      > "$SANDBOX_ROOT/action-$step.sh"
  done
  cat > "$SANDBOX_ROOT/bin/curl" << 'EOF'
#!/bin/sh
[ "$#" -eq 2 ] && [ "$1" = -fsLS ] && [ "$2" = https://get.chezmoi.io ] || exit 90
if [ -e "$HOME/fail-download" ]; then
  printf 'touch "$HOME/partial-installer-ran"\n'
  exit 22
fi
cat << 'INSTALLER'
[ "$#" -eq 2 ] && [ "$1" = -b ] || exit 91
mkdir -p "$2"
printf '#!/bin/sh\nexit 0\n' > "$2/chezmoi"
chmod +x "$2/chezmoi"
INSTALLER
EOF
}

@test "the chezmoi action stops before executing a failed download" {
  touch "$SANDBOX_HOME/fail-download"

  run -22 install_sandbox_run /bin/bash -e -o pipefail "$SANDBOX_ROOT/action-0.sh"

  [ ! -e "$SANDBOX_HOME/partial-installer-ran" ]
  [ ! -e "$SANDBOX_HOME/.local/bin/chezmoi" ]
}

@test "the chezmoi action installs into HOME and publishes its binary directory" {
  run -0 install_sandbox_run /bin/bash -e -o pipefail "$SANDBOX_ROOT/action-0.sh"
  run -0 install_sandbox_run env GITHUB_PATH="$SANDBOX_ROOT/github-path" \
    /bin/bash -e -o pipefail "$SANDBOX_ROOT/action-1.sh"

  [ -x "$SANDBOX_HOME/.local/bin/chezmoi" ]
  [ "$(cat "$SANDBOX_ROOT/github-path")" = "$SANDBOX_HOME/.local/bin" ]
}
