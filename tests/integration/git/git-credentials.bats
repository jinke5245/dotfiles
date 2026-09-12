#!/usr/bin/env bats

# Credential helpers expand only inside the isolated Git process.
# shellcheck disable=SC2016

load '../../helpers/sandbox.bash'
load '../../helpers/git.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  git_sandbox_create
  cp "$SANDBOX_REPOSITORY/tests/fixtures/git/gh.bash" "$SANDBOX_ROOT/bin/gh"
  chmod +x "$SANDBOX_ROOT/bin/gh"
}

git_credential_fill() {
  printf 'url=%s\n\n' "$1" | sandbox_git credential fill
}

@test "GitHub and Gist HTTPS credentials use gh from PATH" {
  local host
  for host in github.com gist.github.com; do
    run -0 git_credential_fill "https://$host/example/project.git"

    [[ "$output" == *'username=fixture-user'* ]]
    [[ "$output" == *'password=fixture-password'* ]]
    [ "$(cat "$SANDBOX_HOME/gh-arguments")" = 'auth git-credential get' ]
    [ "$(cat "$SANDBOX_HOME/gh-input")" = "$(printf 'protocol=https\nhost=%s' "$host")" ]
  done
}

@test "GitHub and Gist reset inherited credential helpers" {
  # A system-level helper would supply credentials before gh unless reset.
  sandbox_git config --file "$SANDBOX_GIT_SYSTEM" credential.helper \
    '!f() { touch "$HOME/inherited-helper"; printf "username=unexpected\npassword=unexpected\n"; }; f'

  local host
  for host in github.com gist.github.com; do
    run -0 git_credential_fill "https://$host"

    [[ "$output" == *'password=fixture-password'* ]]
    [ ! -e "$SANDBOX_HOME/inherited-helper" ]
  done
}

@test "other hosts and non-HTTPS requests do not invoke gh" {
  local url
  for url in https://gitlab.com https://github.com.example.invalid http://github.com ssh://git@github.com; do
    run -128 git_credential_fill "$url"

    [[ "$output" == *'terminal prompts disabled'* ]]
    [ ! -e "$SANDBOX_HOME/gh-arguments" ]
  done
}

@test "local configuration can replace the GitHub credential helper" {
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" --add credential.https://github.com.helper ''
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" --add credential.https://github.com.helper \
    '!f() { printf "username=local-user\npassword=local-password\n"; }; f'

  run -0 git_credential_fill https://github.com

  [[ "$output" == *'username=local-user'* ]]
  [[ "$output" == *'password=local-password'* ]]
  [ ! -e "$SANDBOX_HOME/gh-arguments" ]
}

@test "unavailable GitHub credentials fail without using inherited credentials" {
  sandbox_git config --file "$SANDBOX_GIT_SYSTEM" credential.helper \
    '!f() { touch "$HOME/inherited-helper"; printf "username=unexpected\npassword=unexpected\n"; }; f'
  touch "$SANDBOX_HOME/gh-unavailable"

  run -128 git_credential_fill https://github.com

  [[ "$output" == *'terminal prompts disabled'* ]]
  [ -f "$SANDBOX_HOME/gh-arguments" ]
  [ ! -e "$SANDBOX_HOME/inherited-helper" ]
  [[ "$output" != *'password='* ]]
}
