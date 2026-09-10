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
| [e2e/zsh-startup.bats](e2e/zsh-startup.bats)                             | Real Oh My Zsh theme, git plugin, history, and completion loading.                                               |

## Running

Run commands from the repository root:

| Command                                     | Scope and requirements                                                                                                    |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `pnpm test`                                 | Default unit and integration suites; runs offline.                                                                        |
| `pnpm ci:test`                              | Local CI workflow via act; requires a running Docker-compatible engine and network access. Skips when act is unavailable. |
| `OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e` | End-to-end suite; requires Git and a local Oh My Zsh checkout.                                                            |

`ci:test` runs `.github/workflows/ci.yml` with the `workflow_dispatch` event through `scripts/run-if-available.sh`, which skips missing commands and propagates execution failures. `.actrc` selects an Ubuntu image; act uses the host's default architecture.

Keep `ci:test` separate from `pnpm check`: the workflow itself runs `pnpm check`, so including it there would cause recursion. Local act runs supplement GitHub CI; they do not reproduce every runner feature.

## Isolation

Installation tests serve local installer fixtures instead of downloading scripts. System prefixes are relocated only in disposable repository copies; tests never install into real system directories.

Zsh platform cases use chezmoi data overrides and temporary installation paths. These cases do not replace native tests on each OS.

The end-to-end suite copies committed framework files into a temporary home and disables update checks. It does not install dependencies or use the network.
