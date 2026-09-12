#!/usr/bin/env zsh

# Run through sandbox_zsh: the driver and its child share only test-owned state.
# Scenarios arrive on stdin; zpty supplies a separate terminal to the child shell.
setopt ERR_EXIT
zmodload zsh/zpty
zmodload zsh/zselect
zmodload zsh/datetime

pty_send() {
  zpty -w -n shell "$1"
}

pty_expect() {
  local expected="$1" received= chunk
  local -F deadline=$(( EPOCHREALTIME + 10 ))

  while (( EPOCHREALTIME < deadline )); do
    if zpty -r shell chunk; then
      received+="$chunk"
      [[ "$received" = *"$expected"* ]] && return 0
    elif ! zpty -t shell; then
      break
    else
      zselect -t 10 -r "$pty_fd" || true
    fi
  done

  print -u2 -r -- "Expected terminal output: ${(qqq)expected}"
  print -u2 -r -- "Received: ${(qqq)received}"
  return 1
}

pty_command() {
  pty_send "$1"$'\n'
  pty_expect $'\x1eREADY\x1f'
}

pty_expect_state() {
  local field="$1" expected="$2" actual chunk
  local -F deadline=$(( EPOCHREALTIME + 10 ))

  # Observe real redraws without calling plugin internals or injecting probe keys.
  while (( EPOCHREALTIME < deadline )); do
    if [[ -f "$TMPDIR/zle-$field" ]]; then
      actual=$(<"$TMPDIR/zle-$field")
      [[ "$actual" = ${~expected} ]] && return 0
    fi
    # Drain output so the terminal cannot block while the child redraws.
    zpty -r shell chunk || true
    zselect -t 10 -r "$pty_fd" || true
  done

  print -u2 -r -- "Expected $field: ${(qqq)expected}"
  print -u2 -r -- "Received: ${(qqq)actual}"
  return 1
}

{
  zpty -b shell "${(q)ZSH_TEST_BIN}" -dli
  pty_fd=$REPLY
  pty_expect $'\x1eREADY\x1f'
  source /dev/stdin
} always {
  zpty -d shell
}
