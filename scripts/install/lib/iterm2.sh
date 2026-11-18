#!/usr/bin/env bash

configure_iterm2() {
  [[ "$(uname -s)" = Darwin ]] || return 0

  local profile_guid preferences="$HOME/Library/Preferences/com.googlecode.iterm2"
  profile_guid="$(plutil -extract Profiles.0.Guid raw -o - "$1")" || return
  mkdir -p "$(dirname "$preferences")" || return

  # Close iTerm2 before applying. Update individual keys, preserving local Profiles.
  # Use an explicit file path so preferences follow the destination HOME.
  defaults write "$preferences" TabStyleWithAutomaticOption -int 5 || return
  defaults write "$preferences" TabViewType -int 0 || return
  defaults write "$preferences" HideTab -bool true || return
  defaults write "$preferences" ShowFullScreenTabBar -bool true || return
  defaults write "$preferences" ShowPaneTitles -bool true || return
  defaults write "$preferences" UseBorder -bool false || return
  defaults write "$preferences" HideScrollbar -bool true || return

  defaults write "$preferences" CopySelection -bool true || return
  defaults write "$preferences" CopyLastNewline -bool false || return
  defaults write "$preferences" ThreeFingerEmulates -bool true || return
  defaults write "$preferences" PointerActions -dict-add 'Button,2,1,,' '
    <dict>
      <key>Action</key><string>kPasteFromClipboardPointerAction</string>
    </dict>' || return

  # Preserve unrelated shortcuts; add the existing Shift-Return binding.
  defaults write "$preferences" GlobalKeyMap -dict-add '0xd-0x20000-0x24' '
    <dict>
      <key>Version</key><integer>1</integer>
      <key>Keycode</key><integer>13</integer>
      <key>Action</key><integer>12</integer>
      <key>Text</key><string>\\n</string>
      <key>Modifiers</key><integer>131072</integer>
    </dict>' || return

  defaults write "$preferences" 'Default Bookmark Guid' -string "$profile_guid"
}
