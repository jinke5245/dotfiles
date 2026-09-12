#!/usr/bin/env bats

# Shell snippets expand in the isolated Zsh process.
# shellcheck disable=SC2016

load '../../helpers/sandbox.bash'
load '../../helpers/zsh.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  zsh_sandbox_create
  zsh_fixture_oh_my_zsh
  zsh_fixture_brew "$SANDBOX_ROOT/brew"
  zsh_fixture_plugins "$SANDBOX_ROOT/brew"
  SANDBOX_ZSH_PATH="$SANDBOX_ROOT/brew/bin:$SANDBOX_ZSH_PATH"
}

@test "discovers extra completions before Oh My Zsh initializes completion" {
  cat "$SANDBOX_REPOSITORY/tests/fixtures/zsh/completion.zsh" \
    >> "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"

  run -0 sandbox_zsh -lic 'print -r -- "${_comps[dotfiles-test]:-missing}"'

  [ "$output" = _dotfiles-test ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    brew "omz:robbyrussell:git:$SANDBOX_ROOT/brew" completion:_dotfiles-test \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)" ]
}

@test "completion paths pass auditing when Homebrew's shared directory is group-writable" {
  # Mirror the CI runner: a writable shared prefix, with secure formula files.
  ln -s ../opt/zsh-completions/share/zsh-completions "$SANDBOX_ROOT/brew/share/zsh-completions"
  chmod g+w "$SANDBOX_ROOT/brew/share"
  cat "$SANDBOX_REPOSITORY/tests/fixtures/zsh/completion.zsh" \
    >> "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"

  run -0 sandbox_zsh -lic 'compaudit && print -r -- "${_comps[dotfiles-test]:-missing}"'

  [ "$output" = _dotfiles-test ]
}

@test "nonlogin interactive shells discover Homebrew without initializing its environment" {
  run -0 sandbox_zsh -ic 'print -r -- "$HOMEBREW_PREFIX"'

  [ "$output" = "$SANDBOX_ROOT/brew" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    brew-prefix "omz:robbyrussell:git:$SANDBOX_ROOT/brew" \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)" ]
}

@test "uses the inherited Homebrew prefix even when a different brew is on PATH" {
  zsh_fixture_plugins "$SANDBOX_ROOT/inherited brew"
  printf 'export HOMEBREW_PREFIX=%q\n' "$SANDBOX_ROOT/inherited brew" >> "$SANDBOX_HOME/.zshenv"

  run -0 sandbox_zsh -ic 'print -r -- "$HOMEBREW_PREFIX"'

  [ "$output" = "$SANDBOX_ROOT/inherited brew" ]
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    "omz:robbyrussell:git:$SANDBOX_ROOT/inherited brew" \
    autojump zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)" ]
}

@test "reports a missing plugin and continues loading later integrations" {
  rm "$SANDBOX_ROOT/brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

  run -0 --separate-stderr sandbox_zsh -lic 'print -r -- ready'

  [ "$output" = ready ]
  [[ "$stderr" == *"$SANDBOX_ROOT/brew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"* ]] || return 1
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf '%s\n' \
    brew "omz:robbyrussell:git:$SANDBOX_ROOT/brew" \
    autojump zsh-syntax-highlighting zsh-history-substring-search)" ]
}

@test "reports missing plugin files while keeping the shell usable" {
  rm -r "$SANDBOX_ROOT/brew/share" "$SANDBOX_ROOT/brew/etc" "$SANDBOX_ROOT/brew/opt"

  run -0 --separate-stderr sandbox_zsh -lic '[[ $fpath != *"$HOMEBREW_PREFIX/opt/zsh-completions/share/zsh-completions"* ]] && print -r -- ready'

  [ "$output" = ready ]
  [[ "$stderr" == *"$SANDBOX_ROOT/brew/etc/profile.d/autojump.sh"* ]] || return 1
  local plugin
  for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
    [[ "$stderr" == *"$SANDBOX_ROOT/brew/share/$plugin/$plugin.zsh"* ]] || return 1
  done
  [ "$(cat "$SANDBOX_ROOT/startup.log")" = "$(printf 'brew\nomz:robbyrussell:git:%s' "$SANDBOX_ROOT/brew")" ]
}

@test "binds terminal and common arrow sequences while preserving other keys" {
  run -0 sandbox_zsh -lic '
    zmodload zsh/terminfo
    for key in "$terminfo[kcuu1]" "^[[A" "^[OA"; do
      [[ $(bindkey "$key") = *history-substring-search-up ]] || exit 1
    done
    for key in "$terminfo[kcud1]" "^[[B" "^[OB"; do
      [[ $(bindkey "$key") = *history-substring-search-down ]] || exit 1
    done
    [[ $(bindkey "^A") = *beginning-of-line ]]
  '

  [ -z "$output" ]
}

@test "keeps existing arrow bindings when history substring search is unavailable" {
  rm "$SANDBOX_ROOT/brew/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
  printf 'bindkey "^[[A" up-line-or-history\nbindkey "^[[B" down-line-or-history\n' \
    >> "$SANDBOX_HOME/.oh-my-zsh/oh-my-zsh.sh"

  run -0 --separate-stderr sandbox_zsh -lic '
    [[ $(bindkey "^[[A") = *up-line-or-history ]] &&
    [[ $(bindkey "^[[B") = *down-line-or-history ]]
  '

  [ -z "$output" ]
  [[ "$stderr" == *"$SANDBOX_ROOT/brew/share/zsh-history-substring-search/zsh-history-substring-search.zsh"* ]] || return 1
}

@test "common arrows work when the terminal does not define arrow capabilities" {
  printf 'export TERM=dumb\n' >> "$SANDBOX_HOME/.zshenv"

  run -0 sandbox_zsh -lic '
    [[ -z $terminfo[kcuu1] && -z $terminfo[kcud1] ]] &&
    [[ $(bindkey "^[[A") = *history-substring-search-up ]] &&
    [[ $(bindkey "^[[B") = *history-substring-search-down ]]
  '

  [ -z "$output" ]
}
