#!/usr/bin/env bats

# Scenarios are read by Zsh inside the sandbox, not expanded by Bats.
# shellcheck disable=SC2016

load '../helpers/sandbox.bash'
load '../helpers/zsh.bash'
load '../helpers/flow.bash'

setup_file() {
  bats_require_minimum_version 1.5.0
  flow_suite_setup
}

setup() {
  flow_sandbox_create
  sandbox_chezmoi apply

  # Instrument only the deployed copy after the complete production startup.
  cat "$SANDBOX_REPOSITORY/tests/fixtures/zsh/interactive.zsh" >> "$SANDBOX_HOME/.zshrc"
}

@test "Oh My Zsh initializes completion exactly once with extra definitions available" {
  printf 'zmodload zsh/zprof\n' >> "$SANDBOX_HOME/.zshenv"

  run -0 sandbox_zsh -lic '[[ ${_comps[http]} = _httpie ]] && zprof'

  local calls
  # zprof repeats each summary row in its call tree; count the first occurrence.
  calls="$(printf '%s\n' "$output" | awk '$1 ~ /^[0-9]+\)$/ && $NF == "compinit" && !seen++ { print $2 }')"
  [ "$calls" = 1 ]
}

@test "Tab completes an option from the installed zsh-completions definitions" {
  run -0 sandbox_zsh -f "$SANDBOX_REPOSITORY/tests/helpers/zsh-pty.zsh" << 'EOF'
pty_send $'http --vers\t'
pty_expect_state buffer 'http --version '
EOF

  [ -z "$output" ]
}

@test "autojump navigates to a learned directory in an interactive shell" {
  mkdir -p "$SANDBOX_HOME/projects/navigation-target"

  run -0 sandbox_zsh -f "$SANDBOX_REPOSITORY/tests/helpers/zsh-pty.zsh" << 'EOF'
pty_command 'autojump --add "$HOME/projects/navigation-target"'
pty_command 'j navigation-target'
pty_command 'print -r -- "$PWD" > "$TMPDIR/jump-result"'
[[ $(<"$TMPDIR/jump-result") = "$HOME/projects/navigation-target" ]]
EOF

  [ -z "$output" ]
}

@test "typing a history prefix suggests the remainder and Right accepts it" {
  run -0 sandbox_zsh -f "$SANDBOX_REPOSITORY/tests/helpers/zsh-pty.zsh" << 'EOF'
pty_command 'print -s -- "echo suggested-command"'
pty_send 'echo sugg'
# Asynchronous suggestions redraw without necessarily running the observation hook.
pty_expect 'ested-command'
pty_send $'\e[C'
pty_expect_state buffer 'echo suggested-command'
EOF

  [ -z "$output" ]
}

@test "syntax highlighting updates as an unknown command is replaced with a builtin" {
  run -0 sandbox_zsh -f "$SANDBOX_REPOSITORY/tests/helpers/zsh-pty.zsh" << 'EOF'
pty_send 'dotfiles-nonexistent-command'
pty_expect_state highlights '*fg=red*'
pty_send $'\x15echo'
pty_expect_state buffer echo
pty_expect_state highlights '*fg=green*'
EOF

  [ -z "$output" ]
}

@test "Up and Down search history by substring using both common arrow sequences" {
  run -0 sandbox_zsh -f "$SANDBOX_REPOSITORY/tests/helpers/zsh-pty.zsh" << 'EOF'
pty_command 'print -s -- "echo older-needle"; print -s -- "echo newer-needle"'
pty_send $'needle\e[A'
pty_expect_state buffer 'echo newer-needle'
pty_send $'\eOA'
pty_expect_state buffer 'echo older-needle'
pty_send $'\e[B'
pty_expect_state buffer 'echo newer-needle'
pty_send $'\eOB'
pty_expect_state buffer needle
EOF

  [ -z "$output" ]
}

@test "machine-local configuration overrides Oh My Zsh and shared history bindings" {
  cp "$SANDBOX_REPOSITORY/tests/fixtures/zsh/local.zsh" "$SANDBOX_HOME/.zshrc.local"

  run -0 sandbox_zsh -lic '
    [[ ${aliases[gst]} = "git status --short" ]] &&
    [[ $EDITOR = nvim ]] &&
    [[ $(project) = "$HOME/projects" ]]
  '
  [ -z "$output" ]

  # The local Up binding moves to the start of the line instead of searching history.
  run -0 sandbox_zsh -f "$SANDBOX_REPOSITORY/tests/helpers/zsh-pty.zsh" << 'EOF'
pty_send 'echo local-override'
pty_expect_state buffer 'echo local-override'
pty_send $'\e[A# '
pty_expect_state buffer '# echo local-override'
EOF

  [ -z "$output" ]
}
