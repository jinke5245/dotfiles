#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/install.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  install_sandbox_create
}

@test "macOS apply configures iTerm2 and selects the shared Profile GUID" {
  install_sandbox_platform Darwin

  run -0 sandbox_chezmoi --override-data '{"chezmoi":{"os":"darwin"}}' apply

  local profile="$SANDBOX_HOME/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
  local guid
  guid="$(node -p 'JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")).Profiles[0].Guid' "$profile")"

  [ "$(cat "$SANDBOX_HOME/.install-test/defaults/Default Bookmark Guid")" = "$(printf '%s\n' -string "$guid")" ]
  [ -s "$SANDBOX_HOME/.install-test/defaults/GlobalKeyMap" ]
  [ -s "$SANDBOX_HOME/.install-test/defaults/CopySelection" ]
  [ -s "$SANDBOX_HOME/.install-test/defaults/TabStyleWithAutomaticOption" ]
}

@test "Linux apply does not configure iTerm2 preferences" {
  run -0 sandbox_chezmoi --override-data '{"chezmoi":{"os":"linux"}}' apply

  [ ! -e "$SANDBOX_HOME/.install-test/defaults" ]
  [ ! -e "$SANDBOX_HOME/Library" ]
}

@test "a preference write failure stops apply before managed files change" {
  install_sandbox_platform Darwin
  touch "$SANDBOX_HOME/.install-test/fail-iterm2"
  printf 'keep existing configuration\n' > "$SANDBOX_HOME/.zshrc"

  run ! sandbox_chezmoi --override-data '{"chezmoi":{"os":"darwin"}}' apply --force

  [[ "$output" == *'iTerm2: preference write failed'* ]] || return 1
  [ "$(cat "$SANDBOX_HOME/.zshrc")" = 'keep existing configuration' ]
  [ ! -e "$SANDBOX_HOME/.install-test/defaults/Default Bookmark Guid" ]
}
