#!/usr/bin/env bats

# The child shell reads the isolated HOME and sources the repository copy.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  [[ "$(uname -s)" = Darwin ]] || skip 'Requires macOS defaults and plutil'
  sandbox_create
}

@test "native preference updates preserve local Profiles and unrelated settings across reapply" {
  local preferences="$SANDBOX_HOME/Library/Preferences/com.googlecode.iterm2"
  local profile="$SANDBOX_REPOSITORY/home/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
  mkdir -p "$(dirname "$preferences")"

  # Every defaults invocation uses an explicit temporary file, never the app domain.
  defaults write "$preferences" 'New Bookmarks' -array '
    <dict><key>Name</key><string>Local connection</string>
    <key>Guid</key><string>local-profile</string></dict>'
  defaults write "$preferences" GlobalKeyMap -dict-add local '
    <dict><key>Action</key><integer>12</integer><key>Text</key><string>keep</string></dict>'
  defaults write "$preferences" PointerActions -dict-add local '
    <dict><key>Action</key><string>keep</string></dict>'
  defaults write "$preferences" DeviceOnly -string keep

  local key
  for key in 'New Bookmarks' GlobalKeyMap.local PointerActions.local; do
    plutil -extract "$key" xml1 -o "$SANDBOX_ROOT/$key.before" "$preferences.plist"
  done

  # Run the real library twice with native macOS tools; no package installation or GUI.
  for _ in 1 2; do
    run -0 env -i HOME="$SANDBOX_HOME" PATH=/usr/bin:/bin /bin/bash -eu -c '
      source "$1/scripts/lib/iterm2.sh"
      configure_iterm2 "$2"
    ' _ "$SANDBOX_REPOSITORY" "$profile"
  done

  run -0 defaults read "$preferences" 'Default Bookmark Guid'
  [ "$output" = "$(plutil -extract Profiles.0.Guid raw -o - "$profile")" ]

  run -0 defaults read "$preferences" CopySelection
  [ "$output" = 1 ]
  run -0 defaults read "$preferences" TabStyleWithAutomaticOption
  [ "$output" = 5 ]
  run -0 plutil -extract GlobalKeyMap.0xd-0x20000-0x24.Text raw -o - "$preferences.plist"
  [ "$output" = '\\n' ]

  for key in 'New Bookmarks' GlobalKeyMap.local PointerActions.local; do
    plutil -extract "$key" xml1 -o "$SANDBOX_ROOT/$key.after" "$preferences.plist"
    cmp "$SANDBOX_ROOT/$key.before" "$SANDBOX_ROOT/$key.after"
  done
  run -0 defaults read "$preferences" DeviceOnly
  [ "$output" = keep ]
}
