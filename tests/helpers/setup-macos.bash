#!/usr/bin/env bash

# Snippets expand only in the guarded runner's temporary home.
# shellcheck disable=SC2016
# Scenario variables are consumed by the Bats entry point and shared assertions.
# shellcheck disable=SC2034

setup_macos_require_runner() {
  if [[ "${GITHUB_ACTIONS:-}" != true || "${RUNNER_ENVIRONMENT:-}" != github-hosted ||
    "${RUNNER_OS:-}" != macOS || -n "${ACT:-}" ||
    -z "${RUNNER_TEMP:-}" || "$(uname -s)" != Darwin ]]; then
    printf 'Setup requires a GitHub-hosted macOS runner; local and act runs are refused.\n' >&2
    return 1
  fi
}

setup_macos_create() {
  setup_macos_require_runner || return

  SETUP_MACOS_ROOT="$(mktemp -d "$RUNNER_TEMP/dotfiles-setup.XXXXXX")"
  mkdir -p "$SETUP_MACOS_ROOT/home" "$SETUP_MACOS_ROOT/tmp"
  SETUP_SOURCE="$SETUP_MACOS_ROOT/source"
  sandbox_copy_repository "$SETUP_SOURCE"

  case "$(uname -m)" in
    arm64) SETUP_BREW_PREFIX=/opt/homebrew ;;
    *) SETUP_BREW_PREFIX=/usr/local ;;
  esac

  # GitHub's disposable VM ships Homebrew. Remove it with the official
  # uninstaller so the test must exercise installation, not the existing guard.
  setup_macos_shell '
    test "$(id -u)" -ne 0
    xcode-select -p
    for prefix in /opt/homebrew /usr/local; do
      if test -x "$prefix/bin/brew"; then
        uninstaller="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
        /bin/bash -c "$uninstaller" -- --force --skip-cache-and-logs --path "$prefix"
      fi
    done
    test ! -x /opt/homebrew/bin/brew
    test ! -x /usr/local/bin/brew
  '
}

setup_macos_remove() {
  if [ -n "${SETUP_MACOS_ROOT:-}" ]; then
    setup_macos_require_runner || return
    rm -rf -- "$SETUP_MACOS_ROOT"
  fi
}

setup_macos_shell() (
  setup_macos_require_runner || return
  cd "$SETUP_MACOS_ROOT/home" || return

  env -i HOME="$SETUP_MACOS_ROOT/home" USER="$(id -un)" LOGNAME="$(id -un)" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TMPDIR="$SETUP_MACOS_ROOT/tmp" \
    XDG_DATA_HOME="$SETUP_MACOS_ROOT/home/.local/share" \
    XDG_STATE_HOME="$SETUP_MACOS_ROOT/home/.local/state" \
    XDG_CACHE_HOME="$SETUP_MACOS_ROOT/home/.cache" \
    COREPACK_HOME="$SETUP_MACOS_ROOT/home/.cache/corepack" \
    UV_PYTHON_INSTALL_DIR="$SETUP_MACOS_ROOT/home/.local/share/uv/python" \
    PYTHONDONTWRITEBYTECODE=1 \
    LC_ALL=C TERM=dumb NONINTERACTIVE=1 \
    /bin/bash --noprofile --norc -euo pipefail -c "$@"
)
