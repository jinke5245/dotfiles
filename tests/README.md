# Tests

See the root README for [development requirements](../README.md#requirements) and [testing conventions](../README.md#testing).

## Suites

| File                                                                     | Coverage                                                                                                         |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| [integration/chezmoi-layout.bats](integration/chezmoi-layout.bats)       | Source discovery, target paths, deployment exclusions, repeatable application, and unrelated files.              |
| [integration/chezmoi-install.bats](integration/chezmoi-install.bats)     | Installation before configuration, failure propagation, repeatable application, and changes to external scripts. |
| [integration/install-homebrew.bats](integration/install-homebrew.bats)   | macOS and Debian / Ubuntu installation, existing executables, and prerequisite, download, or installer failures. |
| [integration/install-oh-my-zsh.bats](integration/install-oh-my-zsh.bats) | Official installer invocation, existing installations, configuration preservation, managed paths, and failures.  |
| [integration/zsh-startup.bats](integration/zsh-startup.bats)             | Zsh syntax, startup modes, Homebrew selection, PATH handling, and missing Oh My Zsh.                             |
| [e2e/chezmoi-flow.bats](e2e/chezmoi-flow.bats)                           | Real Oh My Zsh installation, native rendering, shell startup, repeat applies, and changes to external scripts.   |

## Running

Run commands from the repository root:

| Command                                     | Scope and requirements                                                                                                     |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `pnpm test`                                 | Default unit and integration suites; runs offline.                                                                         |
| `pnpm ci:test`                              | Local CI check job via act; requires a running Docker-compatible engine and network access. Skips when act is unavailable. |
| `OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e` | End-to-end suite; requires Homebrew on PATH, Git, and a local Oh My Zsh checkout.                                          |

`ci:test` runs the `check` job in `.github/workflows/ci.yml` with the `workflow_dispatch` event through `scripts/run-if-available.sh`, which skips missing commands and propagates execution failures. `.actrc` selects an Ubuntu image; act uses the host's default architecture.

Keep `ci:test` separate from `pnpm check`: the workflow itself runs `pnpm check`, so including it there would cause recursion. Local act runs supplement GitHub CI; they do not reproduce every runner feature.

The `test-e2e` job runs on macOS and Ubuntu in the same CI workflow. Its preparation steps download dependencies and use `actions/checkout` to place Oh My Zsh in `.cache/ohmyzsh`, which is excluded from test repository copies. The suite itself runs offline. `ci:test` selects only `check`; run the E2E suite separately with `pnpm test:e2e` and its prerequisites.

## Isolation

Installation tests serve local installer fixtures instead of downloading scripts. System prefixes are relocated only in disposable repository copies; tests never install into real system directories.

Zsh platform cases use chezmoi data overrides and temporary installation paths. These cases do not replace native tests on each OS.

The end-to-end suite runs the real Oh My Zsh installer and Git fetch against a local snapshot of the supplied checkout's committed files. It installs only inside a temporary home, disables update checks, and blocks remote Git protocols and unexpected installer downloads.

Homebrew must already be available; the E2E suite uses it for environment initialization and never installs or updates it. Native platform data and rendered files remain unchanged. The checkout and actual shell startup files are not modified or sourced.
