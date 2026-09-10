# Tests

See the root README for [development requirements](../README.md#requirements) and [testing conventions](../README.md#testing).

## Suites

| File                                                                       | Coverage                                                                                                                |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| [integration/chezmoi-layout.bats](integration/chezmoi-layout.bats)         | Source discovery, target paths, deployment exclusions, repeatable application, and unrelated files.                     |
| [integration/chezmoi-install.bats](integration/chezmoi-install.bats)       | Installation before configuration, failure propagation, repeatable application, and changes to external scripts.        |
| [integration/chezmoi-usage.bats](integration/chezmoi-usage.bats)           | Configuration application from a clone, previewing changes, and applying pulled updates using a local Git remote.       |
| [integration/install-homebrew.bats](integration/install-homebrew.bats)     | macOS and Debian / Ubuntu installation, existing executables, and prerequisite, download, or installer failures.        |
| [integration/install-oh-my-zsh.bats](integration/install-oh-my-zsh.bats)   | Official installer invocation, existing installations, configuration preservation, managed paths, and failures.         |
| [integration/sandbox-isolation.bats](integration/sandbox-isolation.bats)   | Current edits and new files are copied; ignored private data, Git metadata, and deleted files are excluded.             |
| [integration/setup-macos-safety.bats](integration/setup-macos-safety.bats) | macOS setup refuses local, act, and self-hosted execution before installation or removal.                               |
| [integration/zsh-startup.bats](integration/zsh-startup.bats)               | Zsh syntax, startup modes, Homebrew selection, PATH handling, and missing Oh My Zsh.                                    |
| [e2e/chezmoi-flow.bats](e2e/chezmoi-flow.bats)                             | Real Oh My Zsh installation, native rendering, shell startup, repeat applies, and changes to external scripts.          |
| [e2e/setup.bats](e2e/setup.bats)                                           | Documented first-time setup with real downloads, missing dependencies, login startup, and repeat application in Ubuntu. |
| [e2e/setup-macos.bats](e2e/setup-macos.bats)                               | The same first-time setup checks on a guarded GitHub-hosted macOS runner, including missing Homebrew.                   |

## Running

Run commands from the repository root:

| Command                                     | Scope and requirements                                                                                                      |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `pnpm test`                                 | Default unit and integration suites; runs offline.                                                                          |
| `pnpm ci:test`                              | Local Linux CI jobs via act; requires a running Docker-compatible engine and network access. Skips when act is unavailable. |
| `OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e` | End-to-end suite; requires Homebrew on PATH, Git, and a local Oh My Zsh checkout.                                           |
| `pnpm test:setup`                           | First-time setup suite; requires Docker and network access. Creates and removes a fresh `ubuntu:24.04` container.           |

`ci:test` runs these subcommands sequentially, stopping on failure. Each uses `ci:run` and the existing optional-command wrapper; missing act is skipped. `.actrc` selects the CI workflow and Ubuntu image, and removes failed act containers. Architecture follows the local Docker engine.

| Command                   | Job selection                                  |
| ------------------------- | ---------------------------------------------- |
| `pnpm ci:test:check`      | `check`                                        |
| `pnpm ci:test:test-e2e`   | `test-e2e`, restricted to `os:ubuntu-latest`   |
| `pnpm ci:test:test-setup` | `test-setup`, restricted to `os:ubuntu-latest` |

Keep `ci:test` separate from `pnpm check`: the workflow itself runs `pnpm check`, so including it there would cause recursion. Local act runs supplement GitHub CI. The act image needs additional Homebrew preparation inside its container for the E2E job.

Both `test-e2e` and `test-setup` use macOS / Ubuntu matrices. E2E preparation checks out Oh My Zsh under `.cache/ohmyzsh`; the flow suite runs offline after preparation. Setup uses real downloads and has a 20-minute job timeout.

Bats tags keep the suites separate: `test:e2e` excludes `network`, `test:setup` selects `network,container`, and the CI-only `test:setup:macos` selects `network,macos`. Neither setup suite runs through `pnpm test` or `pnpm check`.

## Isolation

Installation tests serve local installer fixtures instead of downloading scripts. System prefixes are relocated only in disposable repository copies; tests never install into real system directories.

Zsh platform cases use chezmoi data overrides and temporary installation paths. These cases do not replace native tests on each OS.

`chezmoi-flow.bats` runs the real Oh My Zsh installer and Git fetch against a local snapshot of the supplied checkout's committed files. It installs only inside a temporary home, disables update checks, and blocks remote Git protocols and unexpected installer downloads.

This flow suite requires existing Homebrew and uses it for environment initialization without installing or updating it. Native platform data and rendered files remain unchanged. The checkout and actual shell startup files are not modified or sourced.

`setup.bats` starts with no chezmoi, Homebrew, or Oh My Zsh in a fresh Ubuntu container. Root only provisions a test account with sudo access; that ordinary user follows the README prerequisites and installation steps. `NONINTERACTIVE=1` answers Homebrew's unattended-installation prompts.

Repository copies use tracked files and nonignored untracked files from the current Git checkout, preserving uncommitted contents. Ignored local files, Git metadata, dependencies, and caches are excluded. A temporary local Git remote serves this snapshot under the documented clone URL; dependency downloads remain real. The Ubuntu setup container has no host directories, credentials, or Docker socket mounted, and teardown removes it on success or failure.

`setup-macos.bats` requires native macOS and GitHub-hosted runner markers, and explicitly refuses act and self-hosted runners. In that disposable VM only, it removes preinstalled Homebrew with the official uninstaller before following setup in a temporary HOME. It shares the installation, startup, and repeat-apply assertions with Ubuntu; teardown removes its temporary files. Local commands never run this installation path.
