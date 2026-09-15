#!/usr/bin/env bats

load '../../helpers/sandbox.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  sandbox_create
  ITERM2_PROFILES="$SANDBOX_HOME/Library/Application Support/iTerm2/DynamicProfiles"
  ITERM2_SOURCE="$SANDBOX_REPOSITORY/home/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
}

@test "deploys a valid shared Dynamic Profile at the native macOS path" {
  run -0 sandbox_chezmoi --override-data '{"chezmoi":{"os":"darwin"}}' apply --exclude scripts

  cmp "$ITERM2_SOURCE" "$ITERM2_PROFILES/dotfiles.json"

  # Check the native file structure, not iTerm2's rendering or interaction behavior.
  run -0 node - "$ITERM2_PROFILES/dotfiles.json" << 'JS'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { Profiles } = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

assert.equal(Profiles.length, 1);
assert.equal(Profiles[0].Name, 'Dotfiles');
assert.equal(typeof Profiles[0].Guid, 'string');
assert.ok(Profiles[0].Guid.length > 0);
JS
}

@test "does not deploy the macOS Library tree on Linux" {
  run -0 sandbox_chezmoi --override-data '{"chezmoi":{"os":"linux"}}' apply --exclude scripts

  [ ! -e "$SANDBOX_HOME/Library" ]
}

@test "first and repeated macOS apply preserve local Profiles and preferences" {
  local preferences="$SANDBOX_HOME/Library/Preferences/com.googlecode.iterm2.plist"
  mkdir -p "$ITERM2_PROFILES" "$(dirname "$preferences")"

  # Synthetic local settings stay entirely inside the temporary home.
  cat > "$ITERM2_PROFILES/local.json" << 'JSON'
{"Profiles": [{"Name": "Local", "Guid": "local-profile", "Custom Command": "Yes", "Command": "ssh host.example.invalid"}]}
JSON
  cat > "$preferences" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
  <dict>
    <key>Default Bookmark Guid</key>
    <string>local-default</string>
    <key>New Bookmarks</key>
    <array>
      <dict>
        <key>Name</key><string>Local default</string>
        <key>Guid</key><string>local-default</string>
      </dict>
    </array>
  </dict>
</plist>
PLIST
  cp "$ITERM2_PROFILES/local.json" "$SANDBOX_ROOT/profile.before"
  cp "$preferences" "$SANDBOX_ROOT/preferences.before"

  run -0 sandbox_chezmoi --override-data '{"chezmoi":{"os":"darwin"}}' apply --exclude scripts
  run -0 sandbox_chezmoi --override-data '{"chezmoi":{"os":"darwin"}}' apply --exclude scripts

  cmp "$ITERM2_SOURCE" "$ITERM2_PROFILES/dotfiles.json"
  cmp "$SANDBOX_ROOT/profile.before" "$ITERM2_PROFILES/local.json"
  cmp "$SANDBOX_ROOT/preferences.before" "$preferences"
}
