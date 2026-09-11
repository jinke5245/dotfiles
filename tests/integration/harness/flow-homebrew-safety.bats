#!/usr/bin/env bats

# The stand-in executable expands HOME in its isolated child process.
# shellcheck disable=SC2016

load '../../helpers/sandbox.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  sandbox_create
  mkdir -p "$SANDBOX_HOME/.test-upstream"

  # Stand in for the host brew: record exactly what reaches that boundary.
  cat > "$SANDBOX_ROOT/real-brew" << 'EOF'
#!/bin/bash
if [ "$1" = --repository ]; then
  printf '%s\n' "$HOME/.test-upstream/homebrew"
  exit 0
fi
printf '%s\n' "$@" > "$HOME/brew.calls"
EOF
  chmod +x "$SANDBOX_ROOT/real-brew"
  printf '%s\n' "$SANDBOX_ROOT/real-brew" > "$SANDBOX_HOME/.test-upstream/brew-path"

  # Model a prepared Homebrew runtime without executing Ruby or Bundler.
  local vendor="$SANDBOX_HOME/.test-upstream/homebrew/Library/Homebrew/vendor"
  mkdir -p "$vendor/portable-ruby/1.2.3/bin"
  printf '1.2.3\n' > "$vendor/portable-ruby-version"
  ln -s 1.2.3 "$vendor/portable-ruby/current"
  touch "$vendor/portable-ruby/current/bin/ruby" "$vendor/portable-ruby/current/bin/bundle"
  chmod +x "$vendor/portable-ruby/current/bin/ruby"
}

flow_brew() {
  env -i HOME="$SANDBOX_HOME" PATH=/usr/bin:/bin \
    /bin/bash "$SANDBOX_REPOSITORY/tests/fixtures/flow/brew.bash" "$@"
}

@test "offline E2E replaces package installation with a read-only dependency check" {
  run -0 flow_brew bundle install "--file=$SANDBOX_REPOSITORY/Brewfile" --no-upgrade

  local expected
  printf -v expected 'bundle\ncheck\n--file=%s/Brewfile\n--no-upgrade' "$SANDBOX_REPOSITORY"
  [ "$(cat "$SANDBOX_HOME/brew.calls")" = "$expected" ]
}

@test "offline E2E refuses Homebrew operations outside its read-only contract" {
  run -1 flow_brew upgrade

  [[ "$output" == *'unexpected Homebrew'* ]]
  [ ! -e "$SANDBOX_HOME/brew.calls" ]
}

@test "offline E2E stops before Homebrew could install a missing Ruby runtime" {
  rm "$SANDBOX_HOME/.test-upstream/homebrew/Library/Homebrew/vendor/portable-ruby/current/bin/ruby"

  run -1 flow_brew bundle install "--file=$SANDBOX_REPOSITORY/Brewfile" --no-upgrade

  [[ "$output" == *'Homebrew runtime'* ]]
  [ ! -e "$SANDBOX_HOME/brew.calls" ]
}

@test "offline E2E stops before Homebrew could upgrade its Ruby runtime" {
  printf '1.2.4\n' > "$SANDBOX_HOME/.test-upstream/homebrew/Library/Homebrew/vendor/portable-ruby-version"

  run -1 flow_brew bundle install "--file=$SANDBOX_REPOSITORY/Brewfile" --no-upgrade

  [[ "$output" == *'Homebrew runtime'* ]]
  [ ! -e "$SANDBOX_HOME/brew.calls" ]
}

@test "offline E2E stops before Homebrew could install a missing Bundler" {
  rm "$SANDBOX_HOME/.test-upstream/homebrew/Library/Homebrew/vendor/portable-ruby/current/bin/bundle"

  run -1 flow_brew bundle install "--file=$SANDBOX_REPOSITORY/Brewfile" --no-upgrade

  [[ "$output" == *'Homebrew runtime'* ]]
  [ ! -e "$SANDBOX_HOME/brew.calls" ]
}
