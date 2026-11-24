#!/usr/bin/env bats

# Snippets expand in the isolated Zsh process. Each case owns its search paths.
# shellcheck disable=SC2016,SC2030,SC2031

load '../../support/helpers/sandbox.bash'
load '../../support/helpers/zsh.bash'
load '../../support/helpers/zsh-development.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  zsh_sandbox_create
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  zsh_fixture_plugins "$SANDBOX_ROOT/brew"
  zsh_fixture_development "$SANDBOX_ROOT/brew"
  zsh_fixture_oh_my_zsh
  cat "$SANDBOX_REPOSITORY/tests/support/fixtures/zsh/completion.zsh" >> "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:$SANDBOX_ZSH_PATH"
}

@test "interactive login shells initialize fnm after plugins and before local overrides" {
  cat > "$SANDBOX_HOME/.zshrc.local" << 'EOF'
[[ -n $FNM_MULTISHELL_PATH && ${_comps[fnm]} = _fnm ]] || return 1
print -r -- local >> "$ZSH_TEST_TRACE"
EOF

  run -0 sandbox_zsh -lic 'command -v node'

  [ "$output" = "$SANDBOX_HOME/.fnm-test/multishell/bin/node" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    brew "omz:robbyrussell:git:$SANDBOX_ROOT/brew" completion:_dotfiles-test \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
    fnm-env fnm-completions local)" ]
}

@test "standalone interactive shells initialize fnm without repeating Homebrew shellenv" {
  run -0 sandbox_zsh -ic '[[ ${_comps[fnm]} = _fnm ]] && command -v node'

  [ "$output" = "$SANDBOX_HOME/.fnm-test/multishell/bin/node" ]
  local events
  events="$(cat "$SANDBOX_ROOT/startup.log")"
  [[ "$events" == brew-prefix$'\n'* && "$events" == *$'\nfnm-env\nfnm-completions' ]] || return 1
}

@test "interactive shells expose rustup shims without invoking them or duplicating PATH" {
  local mode
  for mode in -lic -ic; do
    run -0 --separate-stderr sandbox_zsh "$mode" '
      source "$HOME/.zshrc"
      for tool in rustup rustc cargo; do
        [[ $(command -v "$tool") = "$HOMEBREW_PREFIX/opt/rustup/bin/$tool" ]] || exit 1
      done
      print -l -- $path | grep -Fxc "$HOMEBREW_PREFIX/opt/rustup/bin"
    '

    [ "$output" = 1 ]
    [ -z "$stderr" ]
  done
  [[ "$(cat "$SANDBOX_ROOT/startup.log")" != *unexpected-runtime* ]]
}

@test "rustup shims follow the inherited Homebrew prefix" {
  local inherited="$SANDBOX_ROOT/inherited brew"
  zsh_fixture_plugins "$inherited"
  zsh_fixture_development "$inherited"
  printf 'export HOMEBREW_PREFIX=%q\n' "$inherited" >> "$SANDBOX_HOME/.zshenv"

  run -0 --separate-stderr sandbox_zsh -ic 'command -v rustup'

  [ "$output" = "$inherited/opt/rustup/bin/rustup" ]
  [ -z "$stderr" ]
}

@test "missing rustup keeps shell startup quiet without adding a nonexistent PATH" {
  rm -r "$SANDBOX_ROOT/brew/opt/rustup"

  run -0 --separate-stderr sandbox_zsh -lic '
    [[ ":$PATH:" != *":$HOMEBREW_PREFIX/opt/rustup/bin:"* ]] && print -r -- ready
  '

  [ "$output" = ready ]
  [ -z "$stderr" ]
}

@test "interactive shells prefer Homebrew OpenJDK without duplicating PATH" {
  local jdk_bin="$SANDBOX_ROOT/brew/opt/openjdk/bin" tool mode
  mkdir -p "$jdk_bin"
  for tool in java javac; do
    cp "$SANDBOX_ROOT/brew/bin/go" "$jdk_bin/$tool"
    cp "$SANDBOX_ROOT/brew/bin/go" "$SANDBOX_ROOT/brew/bin/$tool"
  done

  for mode in -lic -ic; do
    run -0 --separate-stderr sandbox_zsh "$mode" '
      source "$HOME/.zshrc"
      command -v java javac
      print -l -- $path | grep -Fxc "$1"
    ' _ "$jdk_bin"

    [ "$output" = "$jdk_bin/java"$'\n'"$jdk_bin/javac"$'\n'1 ]
    [ -z "$stderr" ]
  done
}

@test "uv and uvx completions are discovered without executing either tool" {
  local mode
  for mode in -lic -ic; do
    run -0 sandbox_zsh "$mode" 'print -r -- "${_comps[uv]:-missing}:${_comps[uvx]:-missing}"'

    [ "$output" = _uv:_uvx ]
  done
  [[ "$(cat "$SANDBOX_ROOT/startup.log")" != *unexpected-runtime* ]]
}

@test "uv completion paths pass auditing with a group-writable shared prefix" {
  mkdir -p "$SANDBOX_ROOT/brew/share/zsh/site-functions"
  ln -s "$SANDBOX_ROOT/brew/opt/uv/share/zsh/site-functions/_uv" "$SANDBOX_ROOT/brew/share/zsh/site-functions/_uv"
  chmod g+w "$SANDBOX_ROOT/brew/share"

  run -0 sandbox_zsh -lic 'compaudit && print -r -- "${_comps[uv]:-missing}:${_comps[uvx]:-missing}"'

  [ "$output" = _uv:_uvx ]
}

@test "uv completions follow the inherited Homebrew prefix" {
  local inherited="$SANDBOX_ROOT/inherited brew"
  zsh_fixture_plugins "$inherited"
  zsh_fixture_uv_completions "$inherited"
  rm -r "$SANDBOX_ROOT/brew/opt/uv"
  printf 'export HOMEBREW_PREFIX=%q\n' "$inherited" >> "$SANDBOX_HOME/.zshenv"

  run -0 sandbox_zsh -ic 'print -r -- "${_comps[uv]:-missing}:${_comps[uvx]:-missing}"'

  [ "$output" = _uv:_uvx ]
}

@test "missing fnm keeps shell startup quiet and uv completions available" {
  rm "$SANDBOX_ROOT/brew/bin/fnm"

  run -0 --separate-stderr sandbox_zsh -lic '[[ -z ${FNM_MULTISHELL_PATH:-} ]] && print -r -- "${_comps[uv]:-missing}"'

  [ "$output" = _uv ]
  [ -z "$stderr" ]
  [[ "$(cat "$SANDBOX_ROOT/startup.log")" != *fnm-* ]]
}

@test "missing Oh My Zsh still initializes fnm without calling an unavailable compdef" {
  rm "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"

  run -0 --separate-stderr sandbox_zsh -lic 'command -v node'

  [ "$output" = "$SANDBOX_HOME/.fnm-test/multishell/bin/node" ]
  [ -z "$stderr" ]
  local events
  events="$(cat "$SANDBOX_ROOT/startup.log")"
  [[ "$events" == *fnm-env* && "$events" != *fnm-completions* ]]
}

@test "missing uv completion files do not prevent fnm initialization" {
  rm -r "$SANDBOX_ROOT/brew/opt/uv"

  run -0 --separate-stderr sandbox_zsh -lic '
    [[ ${_comps[fnm]} = _fnm ]] &&
    [[ $fpath != *"$HOMEBREW_PREFIX/opt/uv/share/zsh/site-functions"* ]] &&
    print -r -- ready
  '

  [ "$output" = ready ]
  [ -z "$stderr" ]
}

@test "noninteractive shells do not initialize fnm or invoke language tools" {
  local mode
  for mode in -lc -c; do
    run -0 sandbox_zsh "$mode" '[[ -z ${FNM_MULTISHELL_PATH:-} ]]'
    [ -z "$output" ]
  done

  [ "$(cat "$SANDBOX_ROOT/startup.log")" = brew ]
}

@test "machine-local overrides can replace the shared Node executable path" {
  mkdir -p "$SANDBOX_HOME/local-node/bin"
  cp "$SANDBOX_ROOT/brew/bin/node" "$SANDBOX_HOME/local-node/bin/node"
  printf 'path=("$HOME/local-node/bin" $path)\n' > "$SANDBOX_HOME/.zshrc.local"

  run -0 sandbox_zsh -lic 'command -v node'

  [ "$output" = "$SANDBOX_HOME/local-node/bin/node" ]
  [[ "$(cat "$SANDBOX_ROOT/startup.log")" == *fnm-env* ]]
}

@test "login shells expose Go tool executables without setting Go or Python defaults" {
  mkdir -p "$SANDBOX_HOME/go/bin"
  cp "$SANDBOX_ROOT/brew/bin/go" "$SANDBOX_HOME/go/bin/go-test-tool"

  run -0 sandbox_zsh -lc '
    [[ -z ${GOROOT:-} && -z ${GOPATH:-} && -z ${VIRTUAL_ENV:-} ]] &&
    command -v go-test-tool
  '

  [ "$output" = "$SANDBOX_HOME/go/bin/go-test-tool" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = brew ]
}
