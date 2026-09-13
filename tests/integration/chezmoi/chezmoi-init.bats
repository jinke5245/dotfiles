#!/usr/bin/env bats

load '../../helpers/sandbox.bash'
load '../../helpers/git.bash'
load '../../helpers/identity.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  identity_sandbox_create
}

@test "init saves supplied identity for unattended setup" {
  rm "$SANDBOX_CONFIG"

  run -0 identity_init --promptString 'User name=Supplied Name,User email=supplied@example.invalid' < /dev/null

  identity_assert_data 'Supplied Name' supplied@example.invalid
}

@test "init prefers global Git identity over saved inputs" {
  identity_saved_data
  sandbox_git config --global user.name 'Global Name'
  sandbox_git config --global user.email global@example.invalid
  cp -p "$SANDBOX_HOME/.gitconfig" "$SANDBOX_ROOT/global.before"

  run -0 identity_init < /dev/null

  identity_assert_data 'Global Name' global@example.invalid
  cmp "$SANDBOX_HOME/.gitconfig" "$SANDBOX_ROOT/global.before"
}

@test "init resolves name and email independently" {
  identity_saved_data
  sandbox_git config --global user.name 'Global Name'

  run -0 identity_init < /dev/null

  identity_assert_data 'Global Name' saved@example.invalid
}

@test "repeated init reuses saved identity without input" {
  identity_saved_data

  run -0 identity_init < /dev/null
  run -0 identity_init < /dev/null

  identity_assert_data 'Saved Name' saved@example.invalid
}

@test "init reads identity from included XDG Git configuration" {
  identity_xdg_configuration

  run -0 identity_init < /dev/null

  identity_assert_data 'Included Name' included@example.invalid
}

@test "init prefers XDG identity over saved inputs when legacy Git settings exist" {
  identity_saved_data
  identity_xdg_configuration
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" core.editor vim

  run -0 identity_init < /dev/null

  identity_assert_data 'Included Name' included@example.invalid
}

@test "init resolves identity fields split between both global Git files" {
  identity_saved_data
  mkdir -p "$SANDBOX_HOME/.config/git"
  sandbox_git config --file "$SANDBOX_HOME/.config/git/config" user.email xdg@example.invalid
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" user.name 'Legacy Name'

  run -0 identity_init < /dev/null

  identity_assert_data 'Legacy Name' xdg@example.invalid
}

@test "init gives legacy Git identity precedence over included XDG values" {
  identity_saved_data
  identity_xdg_configuration
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" user.name 'Legacy Name'
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" user.email legacy@example.invalid

  run -0 identity_init < /dev/null

  identity_assert_data 'Legacy Name' legacy@example.invalid
}

@test "init falls back to saved email when the higher-priority Git email is empty" {
  identity_saved_data
  identity_xdg_configuration
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" user.email ''

  run -0 identity_init < /dev/null

  identity_assert_data 'Included Name' saved@example.invalid
}

@test "init excludes system Git identity from initialization inputs" {
  identity_saved_data
  sandbox_git config --file "$SANDBOX_GIT_SYSTEM" user.name 'System Name'
  sandbox_git config --file "$SANDBOX_GIT_SYSTEM" user.email system@example.invalid

  run -0 identity_init < /dev/null

  identity_assert_data 'Saved Name' saved@example.invalid
}

@test "init fails without replacing saved configuration when required input is unavailable" {
  printf '[data.user]\nname = "Saved Name"\n' > "$SANDBOX_CONFIG"
  cp -p "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"

  run ! identity_init < /dev/null

  [[ "$output" == *email* ]]
  cmp "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"
}

@test "init only asks for the field missing from Git and saved data" {
  sandbox_git config --global user.name 'Global Name'

  run -0 identity_init --promptString 'User email=supplied@example.invalid' < /dev/null

  identity_assert_data 'Global Name' supplied@example.invalid
}

@test "init preserves unrelated chezmoi settings and template data" {
  cat > "$SANDBOX_CONFIG" << 'TOML'
progress = false
[edit]
command = "test-editor"
[data]
keep = "local data"
[data.user]
name = "Saved Name"
email = "saved@example.invalid"
location = "local location"
TOML

  run -0 identity_init < /dev/null

  identity_assert_data 'Saved Name' saved@example.invalid
  run -0 sandbox_chezmoi execute-template '{{ .keep }}|{{ .user.location }}'
  [ "$output" = 'local data|local location' ]
  run -0 sandbox_chezmoi execute-template '{{ $config := include .chezmoi.configFile | fromToml }}{{ $config.edit.command }}|{{ $config.progress }}'
  [ "$output" = 'test-editor|false' ]
}

@test "init accepts answers through its real input prompts" {
  run -0 identity_init << 'ANSWERS'
Prompted Name
prompted@example.invalid
ANSWERS

  [[ "$output" == *'User name'* ]]
  [[ "$output" == *'User email'* ]]
  identity_assert_data 'Prompted Name' prompted@example.invalid
}

@test "init rejects an empty required answer without replacing saved configuration" {
  printf '[data.user]\nname = "Saved Name"\n' > "$SANDBOX_CONFIG"
  cp -p "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"

  run ! identity_init --promptString 'User email=   ' < /dev/null

  [[ "$output" == *'email is required'* ]]
  cmp "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"
}

@test "init round-trips Unicode, spaces, quotes, and backslashes" {
  local name='李 "Test" O\Brien'
  sandbox_git config --global user.name "$name"
  sandbox_git config --global user.email quoted@example.invalid

  run -0 identity_init < /dev/null

  identity_assert_data "$name" quoted@example.invalid
}

@test "init fails on malformed Git configuration instead of silently using saved inputs" {
  identity_saved_data
  printf '[broken\n' > "$SANDBOX_HOME/.gitconfig"
  cp -p "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"

  run ! identity_init < /dev/null

  [[ "$output" == *'gitconfig'* ]]
  cmp "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"
}

@test "init rejects malformed XDG configuration even when legacy identity is valid" {
  identity_saved_data
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" user.name 'Legacy Name'
  sandbox_git config --file "$SANDBOX_HOME/.gitconfig" user.email legacy@example.invalid
  mkdir -p "$SANDBOX_HOME/.config/git"
  printf '[broken\n' > "$SANDBOX_HOME/.config/git/config"
  cp -p "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"

  run ! identity_init < /dev/null

  [[ "$output" == *'.config/git/config'* ]]
  cmp "$SANDBOX_CONFIG" "$SANDBOX_ROOT/config.before"
}

@test "init ignores repository identity and repository-dependent global includes" {
  identity_saved_data
  sandbox_git config --global user.name 'Global Name'
  sandbox_git config --global user.email global@example.invalid
  sandbox_git config --file "$SANDBOX_ROOT/project.config" user.name 'Project Name'
  sandbox_git config --file "$SANDBOX_ROOT/project.config" user.email project@example.invalid
  sandbox_git config --global 'includeIf.gitdir:**.path' "$SANDBOX_ROOT/project.config"

  # Even HOME is inside the caller's repository. Changing to HOME alone would
  # still select the project-specific include during repository discovery.
  sandbox_git init --quiet "$SANDBOX_ROOT"
  sandbox_git -C "$SANDBOX_ROOT" config user.name 'Repository Name'

  run -0 identity_init < /dev/null

  identity_assert_data 'Global Name' global@example.invalid
}

@test "init keeps identity out of the source and does not run installation" {
  run -0 identity_init --promptString 'User name=Private Test Name,User email=private-test@example.invalid' < /dev/null

  identity_assert_data 'Private Test Name' private-test@example.invalid
  [ ! -e "$SANDBOX_HOME/.gitconfig" ]
  [ ! -e "$SANDBOX_HOME/.config/git/config.local" ]
  [ ! -e "$SANDBOX_HOME/.ssh" ]
  [ ! -e "$SANDBOX_HOME/.oh-my-zsh" ]
  [ ! -e "$SANDBOX_HOME/.zshrc" ]

  # Search for the synthetic private value to detect accidental persistence in
  # source files; all test input was supplied outside the repository snapshot.
  run -1 grep -R -F 'private-test@example.invalid' "$SANDBOX_REPOSITORY/home"
}

@test "preview and configuration-only apply do not repeat identity prompts" {
  identity_saved_data
  identity_init < /dev/null

  run -0 sandbox_chezmoi diff < /dev/null
  run -0 sandbox_chezmoi apply --exclude scripts < /dev/null
  run -0 sandbox_chezmoi diff --exclude scripts < /dev/null

  [ -z "$output" ]
  identity_assert_data 'Saved Name' saved@example.invalid
}
