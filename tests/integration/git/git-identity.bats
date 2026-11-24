#!/usr/bin/env bats

load '../../support/helpers/sandbox.bash'
load '../../support/helpers/git.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  git_sandbox_create
}

@test "initialization creates the local Git file and any missing parent directories" {
  rm "$SANDBOX_HOME/.config/git/config"
  rmdir "$SANDBOX_HOME/.config/git" "$SANDBOX_HOME/.config"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  git_assert_local_identity 'Saved Name' saved@example.invalid
  [ ! -e "$SANDBOX_HOME/.gitconfig" ]
}

@test "initialization fills either missing field without replacing the other" {
  local missing
  for missing in user.name user.email; do
    git_fixture_identity
    sandbox_git config --file "$SANDBOX_GIT_LOCAL" --unset "$missing"

    run -0 git_identity_initialize 'Saved Name' saved@example.invalid

    if [ "$missing" = user.name ]; then
      git_assert_local_identity 'Saved Name' test@example.invalid
    else
      git_assert_local_identity 'Dotfiles test' saved@example.invalid
    fi
  done
}

@test "initialization preserves unrelated local settings and comments" {
  cat > "$SANDBOX_GIT_LOCAL" << 'CONFIG'
# Keep this machine-specific setting.
[core]
    editor = "editor --wait" # Keep this comment too.
CONFIG
  cp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/settings.before"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  git_assert_local_identity 'Saved Name' saved@example.invalid
  # New defaults precede the original configuration without rewriting it.
  tail -n 3 "$SANDBOX_GIT_LOCAL" > "$SANDBOX_ROOT/settings.after"
  cmp "$SANDBOX_ROOT/settings.before" "$SANDBOX_ROOT/settings.after"
  run -0 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --get core.editor
  [ "$output" = 'editor --wait' ]
}

@test "initialization preserves UTF-8 BOM configuration" {
  printf '\357\273\277# Keep this comment.\n[core]\n editor = vim\n' > "$SANDBOX_GIT_LOCAL"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  [ "$(head -c 3 "$SANDBOX_GIT_LOCAL")" = "$(printf '\357\273\277')" ]
  git_assert_local_identity 'Saved Name' saved@example.invalid
  run -0 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --get core.editor
  [ "$output" = vim ]
}

@test "initialization preserves identity supplied by an included local file" {
  git_fixture_included_identity
  local included="$SANDBOX_HOME/.config/git/identity.config"
  touch -t 200001010000 "$SANDBOX_GIT_LOCAL" "$included"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  cp -p "$included" "$SANDBOX_ROOT/included.before"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  git_assert_local_identity 'Included Name' included@example.invalid
  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  cmp "$included" "$SANDBOX_ROOT/included.before"
  [ ! "$SANDBOX_GIT_LOCAL" -nt "$SANDBOX_ROOT/local.before" ]
  [ ! "$included" -nt "$SANDBOX_ROOT/included.before" ]
}

@test "initialized defaults preserve conditional identity in matching repositories" {
  local included="$SANDBOX_HOME/.config/git/work.config"
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" \
    "includeIf.gitdir:$SANDBOX_GIT_WORKTREE/.path" work.config
  sandbox_git config --file "$included" user.name 'Work Name'
  sandbox_git config --file "$included" user.email work@example.invalid
  cp -p "$included" "$SANDBOX_ROOT/included.before"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  git_assert_local_identity 'Saved Name' saved@example.invalid
  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" config --get user.name
  [ "$output" = 'Work Name' ]
  run -0 sandbox_git -C "$SANDBOX_GIT_WORKTREE" config --get user.email
  [ "$output" = work@example.invalid ]
  cmp "$included" "$SANDBOX_ROOT/included.before"
}

@test "initialization fills only the field absent from included local identity" {
  git_fixture_included_identity
  local included="$SANDBOX_HOME/.config/git/identity.config"
  sandbox_git config --file "$included" --unset user.email
  cp -p "$included" "$SANDBOX_ROOT/included.before"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  git_assert_local_identity 'Included Name' saved@example.invalid
  run -1 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --get user.name
  run -0 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --get user.email
  [ "$output" = saved@example.invalid ]
  cmp "$included" "$SANDBOX_ROOT/included.before"
}

@test "included empty and valueless identity keys remain unchanged" {
  git_fixture_included_identity
  printf '[user]\n name = ""\n email\n' > "$SANDBOX_HOME/.config/git/identity.config"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
}

@test "a malformed included file stops initialization without writing local identity" {
  git_fixture_included_identity
  printf '[broken\n' > "$SANDBOX_HOME/.config/git/identity.config"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"

  run ! git_identity_initialize 'Saved Name' saved@example.invalid

  [[ "$output" == *'identity.config'* ]]
  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
}

@test "defined empty and valueless identity keys remain unchanged" {
  printf '[user]\n    name = ""\n    email\n' > "$SANDBOX_GIT_LOCAL"
  touch -t 200001010000 "$SANDBOX_GIT_LOCAL"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  [ ! "$SANDBOX_GIT_LOCAL" -nt "$SANDBOX_ROOT/local.before" ]
  [ ! "$SANDBOX_GIT_LOCAL" -ot "$SANDBOX_ROOT/local.before" ]
}

@test "initialization skips writes when no saved identity is available" {
  run -0 git_identity_initialize

  [ ! -e "$SANDBOX_GIT_LOCAL" ]
}

@test "partial saved identity only initializes the available field" {
  run -0 git_identity_initialize '' saved@example.invalid

  run -1 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --get user.name
  run -0 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --get user.email
  [ "$output" = saved@example.invalid ]
}

@test "a malformed local file fails before any identity is written" {
  printf '[core]\n    editor = keep\n[broken\n' > "$SANDBOX_GIT_LOCAL"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"

  run ! git_identity_initialize 'Saved Name' saved@example.invalid

  [[ "$output" == *'config.local'* ]]
  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  [ ! "$SANDBOX_GIT_LOCAL" -nt "$SANDBOX_ROOT/local.before" ]
}

@test "an unreadable local file fails without replacing it" {
  [ "$(id -u)" -ne 0 ] || skip 'Requires an ordinary user to enforce file permissions.'
  printf '# keep\n' > "$SANDBOX_GIT_LOCAL"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  chmod 000 "$SANDBOX_GIT_LOCAL"

  run ! git_identity_initialize 'Saved Name' saved@example.invalid

  chmod 600 "$SANDBOX_GIT_LOCAL"
  [[ "$output" == *'config.local'* ]]
  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
}

@test "conflicting local paths are preserved instead of creating configuration" {
  mkdir "$SANDBOX_GIT_LOCAL"

  run ! git_identity_initialize 'Saved Name' saved@example.invalid
  [ -d "$SANDBOX_GIT_LOCAL" ]

  rmdir "$SANDBOX_GIT_LOCAL"
  ln -s "$SANDBOX_ROOT/missing.config" "$SANDBOX_GIT_LOCAL"

  run ! git_identity_initialize 'Saved Name' saved@example.invalid
  [ -L "$SANDBOX_GIT_LOCAL" ]
  [ ! -e "$SANDBOX_ROOT/missing.config" ]
}

@test "a Git lock failure preserves the existing file and lock" {
  sandbox_git config --file "$SANDBOX_GIT_LOCAL" user.name 'Existing Name'
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  printf 'existing lock\n' > "$SANDBOX_GIT_LOCAL.lock"

  run ! git_identity_initialize 'Saved Name' saved@example.invalid

  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  [ "$(cat "$SANDBOX_GIT_LOCAL.lock")" = 'existing lock' ]
}

@test "termination releases the application lock so Git identity can be retried" {
  printf '[core]\n editor = keep\n' > "$SANDBOX_GIT_LOCAL"
  cp -p "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  mkdir "$SANDBOX_ROOT/real"
  ln -s "$SANDBOX_GIT" "$SANDBOX_ROOT/real/git"
  cat > "$SANDBOX_ROOT/bin/git" << 'WRAPPER'
#!/usr/bin/env bash
# Signal only the isolated parent that is writing to the owned lock.
if [[ "$1" = config && "$2" = --file && "$3" = "$HOME/.config/git/config.local.lock" ]]; then
  kill -TERM "$PPID"
  exit 1
fi
exec "${0%/*}/../real/git" "$@"
WRAPPER
  chmod +x "$SANDBOX_ROOT/bin/git"

  run -143 git_identity_initialize 'Saved Name' saved@example.invalid

  cmp "$SANDBOX_GIT_LOCAL" "$SANDBOX_ROOT/local.before"
  [ ! -e "$SANDBOX_GIT_LOCAL.lock" ]
  rm "$SANDBOX_ROOT/bin/git"
  run -0 git_identity_initialize 'Saved Name' saved@example.invalid
  git_assert_local_identity 'Saved Name' saved@example.invalid
}

@test "initialization keeps temporary configuration private" {
  umask 022
  # Observe permissions after copying local content, before restoring its mode.
  cat > "$SANDBOX_ROOT/bin/chmod" << 'WRAPPER'
#!/usr/bin/env bash
lock="$HOME/.config/git/config.local.lock"
{ stat -c '%a' "$lock" 2> /dev/null || stat -f '%Lp' "$lock"; } > "$HOME/lock.mode"
exec /bin/chmod "$@"
WRAPPER
  chmod +x "$SANDBOX_ROOT/bin/chmod"

  local mode actual
  for mode in 600 640; do
    printf '[core]\n editor = private-fixture\n' > "$SANDBOX_GIT_LOCAL"
    chmod "$mode" "$SANDBOX_GIT_LOCAL"

    run -0 git_identity_initialize 'Saved Name' saved@example.invalid

    [ "$(cat "$SANDBOX_HOME/lock.mode")" = 600 ]
    actual="$(stat -c '%a' "$SANDBOX_GIT_LOCAL" 2> /dev/null)" || actual="$(stat -f '%Lp' "$SANDBOX_GIT_LOCAL")"
    [ "$actual" = "$mode" ]
    git_assert_local_identity 'Saved Name' saved@example.invalid
    run -0 sandbox_git config --file "$SANDBOX_GIT_LOCAL" --get core.editor
    [ "$output" = private-fixture ]
  done
}

@test "initialization follows a valid local file symlink without replacing it" {
  printf '# keep\n' > "$SANDBOX_ROOT/linked.config"
  chmod 600 "$SANDBOX_ROOT/linked.config"
  ln -s "$SANDBOX_ROOT/linked.config" "$SANDBOX_GIT_LOCAL"

  run -0 git_identity_initialize 'Saved Name' saved@example.invalid

  [ -L "$SANDBOX_GIT_LOCAL" ]
  git_assert_local_identity 'Saved Name' saved@example.invalid
  run -0 sandbox_git config --file "$SANDBOX_ROOT/linked.config" --get user.name
  [ "$output" = 'Saved Name' ]
  local mode
  mode="$(stat -c '%a' "$SANDBOX_ROOT/linked.config" 2> /dev/null)" || mode="$(stat -f '%Lp' "$SANDBOX_ROOT/linked.config")"
  [ "$mode" = 600 ]
}
