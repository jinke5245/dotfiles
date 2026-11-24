# Missing-prefix tests must never source real /etc or /share files.
source() {
  if [[ "$1" != "$HOME/"* ]]; then
    print -u2 -r -- "Unexpected source outside test HOME: $1"
    return 1
  fi
  builtin source "$@"
}
