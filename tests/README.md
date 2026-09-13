# Tests

See the root README for [development requirements](../README.md#requirements) and [testing conventions](../README.md#testing).

## Suites

Group integration suites by responsibility: `chezmoi`, `install`, `git`, `ssh`, `zsh`, and `harness` (test isolation and safety). Keep descriptive filenames, and organize scenarios within each file. Tests run independently of directory order.

| File                                                                                               | Coverage                                                                                                                            |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| [integration/chezmoi/chezmoi-layout.bats](integration/chezmoi/chezmoi-layout.bats)                 | Source discovery, target paths, deployment exclusions, repeatable application, and unrelated files.                                 |
| [integration/chezmoi/chezmoi-install.bats](integration/chezmoi/chezmoi-install.bats)               | Installation before configuration, failure propagation, repeatable application, and changes to external scripts.                    |
| [integration/chezmoi/chezmoi-usage.bats](integration/chezmoi/chezmoi-usage.bats)                   | Configuration application from a clone, previewing changes, and applying pulled updates using a local Git remote.                   |
| [integration/install/install-homebrew.bats](integration/install/install-homebrew.bats)             | macOS and Debian / Ubuntu installation, existing executables, and prerequisite, download, or installer failures.                    |
| [integration/install/setup-homebrew-action.bats](integration/install/setup-homebrew-action.bats)   | Linux prerequisites, installation, existing executables, repeated setup, GitHub PATH updates, and failure propagation.              |
| [integration/install/install-brewfile.bats](integration/install/install-brewfile.bats)             | Brewfile installation, executable selection after setup, explicit repository paths, repeated apply, and failures.                   |
| [integration/install/install-oh-my-zsh.bats](integration/install/install-oh-my-zsh.bats)           | Official installer invocation, existing installations, configuration preservation, managed paths, and failures.                     |
| [integration/git/git-defaults.bats](integration/git/git-defaults.bats)                             | Configuration discovery, main branch, Chinese filenames, fast-forward-only pulls, pruning, and LFS filter settings.                 |
| [integration/git/git-local.bats](integration/git/git-local.bats)                                   | Required identity, local and repository overrides, legacy configuration precedence, preservation, and Git / chezmoi exclusions.     |
| [integration/git/git-credentials.bats](integration/git/git-credentials.bats)                       | GitHub / Gist helper routing, inherited-helper resets, unrelated URLs, local overrides, and unavailable credentials.                |
| [integration/ssh/ssh-keys.bats](integration/ssh/ssh-keys.bats)                                     | Ed25519 generation, default comments, permissions, existing keys and directories, repeat execution, and path conflicts.             |
| [integration/ssh/ssh-key-recovery.bats](integration/ssh/ssh-key-recovery.bats)                     | Public-key recovery, encrypted private keys, preservation, and failures without creating empty public-key files.                    |
| [integration/ssh/ssh-install.bats](integration/ssh/ssh-install.bats)                               | Preview without generation, unmanaged keys, initialization and recovery on apply, preservation, and failure propagation.            |
| [integration/zsh/zsh-startup.bats](integration/zsh/zsh-startup.bats)                               | Zsh syntax, startup modes, Homebrew selection, PATH handling, and missing Oh My Zsh.                                                |
| [integration/zsh/zsh-plugins.bats](integration/zsh/zsh-plugins.bats)                               | Completion auditing, plugin loading order, prefix discovery and absence, missing dependencies, and arrow bindings.                  |
| [integration/zsh/zsh-local.bats](integration/zsh/zsh-local.bats)                                   | Local overrides, missing and unreadable files, startup modes, repeat-apply preservation, and Git / chezmoi exclusions.              |
| [integration/harness/sandbox-isolation.bats](integration/harness/sandbox-isolation.bats)           | Current edits and new files are copied; ignored private data, Git metadata, and deleted files are excluded.                         |
| [integration/harness/flow-homebrew-safety.bats](integration/harness/flow-homebrew-safety.bats)     | Offline E2E substitutes read-only dependency checks and rejects other Homebrew operations.                                          |
| [integration/harness/setup-container-safety.bats](integration/harness/setup-container-safety.bats) | Container setup reports missing Docker and stops before attempting installation.                                                    |
| [integration/harness/setup-macos-safety.bats](integration/harness/setup-macos-safety.bats)         | macOS setup refuses local, act, and self-hosted execution before installation or removal.                                           |
| [e2e/chezmoi-flow.bats](e2e/chezmoi-flow.bats)                                                     | Real Oh My Zsh installation, native rendering, shell startup, local file preservation, repeat applies, and external script changes. |
| [e2e/git-flow.bats](e2e/git-flow.bats)                                                             | Login-shell Git discovery, local identity preservation, real LFS filtering, and project setup without changing global files.        |
| [e2e/zsh-plugins.bats](e2e/zsh-plugins.bats)                                                       | Completion initialization, real interactive plugin behavior, and local key-binding overrides.                                       |
| [e2e/setup.bats](e2e/setup.bats)                                                                   | Documented Ubuntu setup with real downloads, Git tooling paths and versions, login startup, and repeat application.                 |
| [e2e/setup-macos.bats](e2e/setup-macos.bats)                                                       | The same setup and Git tooling checks on a guarded GitHub-hosted macOS runner, including missing Homebrew.                          |

## Running

Run commands from the repository root:

| Command                                     | Scope and requirements                                                                                                      |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `pnpm test`                                 | Default unit and integration suites; runs offline.                                                                          |
| `pnpm ci:test`                              | Local Linux CI jobs via act; requires a running Docker-compatible engine and network access. Skips when act is unavailable. |
| `OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e` | End-to-end suite; requires Homebrew on PATH, installed Brewfile packages, Git, and a local Oh My Zsh checkout.              |
| `pnpm test:setup`                           | First-time setup suite; requires Docker and network access. Creates and removes a fresh `ubuntu:24.04` container.           |

`ci:test` runs these subcommands sequentially, stopping on failure. Each uses `ci:run` and the existing optional-command wrapper; missing act is skipped. `.actrc` selects the CI workflow and Ubuntu image, and removes failed act containers. Architecture follows the local Docker engine.

| Command                   | Job selection                                  |
| ------------------------- | ---------------------------------------------- |
| `pnpm ci:test:check`      | `check`                                        |
| `pnpm ci:test:test-e2e`   | `test-e2e`, restricted to `os:ubuntu-latest`   |
| `pnpm ci:test:test-setup` | `test-setup`, restricted to `os:ubuntu-latest` |

Keep `ci:test` separate from `pnpm check`: the workflow itself runs `pnpm check`, so including it there would cause recursion. Local act runs supplement GitHub CI; the `runner-24.04` image uses an ordinary user with passwordless sudo.

`.actrc` also grants supplementary group `0` access for a root-group-owned Docker socket. If your Docker engine uses a different socket group, pass `--container-options="--group-add=<socket-gid>"` to the `ci:test:*` command. This lets `test-setup` create its disposable container while the runner remains a non-root user.

Local setup actions handle runner preparation independently of their callers. `setup-zsh` installs on Ubuntu and checks availability on macOS. `setup-homebrew` installs Linux prerequisites, reuses or installs Homebrew as the current user, and adds it to the job PATH. Brewfile installation remains a separate workflow step.

Both `test-e2e` and `test-setup` use macOS / Ubuntu matrices. E2E preparation installs Brewfile packages in the disposable runner and checks out Oh My Zsh under `.cache/ohmyzsh`; the flow suite runs offline after preparation. Setup uses real downloads and has a 20-minute job timeout.

Bats tags keep the suites separate: `test:e2e` excludes `network`, `test:setup` selects `network,container`, and the CI-only `test:setup:macos` selects `network,macos`. Neither setup suite runs through `pnpm test` or `pnpm check`.

## Isolation

Installation tests serve local installer fixtures instead of downloading scripts. System prefixes are relocated only in disposable repository copies; tests never install into real system directories.

Git integration tests use real Git with a temporary HOME, a test-owned system configuration, and an empty inherited environment. Git discovers the deployed `~/.config/git/config` through its normal XDG lookup. Repositories and remotes are local; network Git protocols and credential prompts are disabled. A substitute `gh` exercises the credential protocol with synthetic values. LFS filter execution with real dependencies belongs to E2E coverage.

SSH integration tests require `ssh-keygen` and generate real keys only in temporary homes, with explicit key paths and an empty inherited environment. No SSH connections are made. Tests substitute only passphrase input through a test-owned askpass program; unavailable input fails immediately without opening a terminal prompt. Private-key contents are never printed or stored in fixtures.

Zsh platform cases use chezmoi data overrides and temporary installation paths. These cases do not replace native tests on each OS.

`chezmoi-flow.bats` runs the real Oh My Zsh installer and Git fetch against a local snapshot of the supplied checkout's committed files. It installs only inside a temporary home, disables update checks, and blocks remote Git protocols and unexpected installer downloads.

This flow suite requires existing Homebrew and installed Brewfile packages. A command adapter forwards prefix and environment queries to the real Homebrew, replaces Bundle installation with `brew bundle check --no-upgrade`, and rejects other operations. It checks Homebrew's prepared Ruby and Bundler files before invoking Bundle, preventing automatic runtime installation or upgrades. Missing prerequisites fail the test without installation. Native platform data and rendered files remain unchanged. The checkout and actual shell startup files are not modified or sourced.

`zsh-plugins.bats` reuses that isolation and dependency adapter. The shared `helpers/zsh-pty.zsh` driver uses Zsh's built-in `zpty` module to send real keystrokes and read terminal output. A test-only redraw hook records the editing buffer and highlights without invoking plugin internals. Waits are bounded, the terminal is closed after each scenario, and all history, completion caches, and autojump data stay inside the temporary home and state directories.

`setup.bats` starts with no chezmoi, Homebrew, or Oh My Zsh in a fresh Ubuntu container. Root only provisions a test account with sudo access; that ordinary user follows the README prerequisites and installation steps. It checks that Brewfile dependencies are satisfied and installed package versions remain unchanged after a second apply. A pre-existing `.zshrc.local` must take effect and survive both applies unchanged. `NONINTERACTIVE=1` answers Homebrew's unattended-installation prompts.

After both applies, shared assertions check that `git`, `git-lfs`, `gh`, `glab`, and `tig` resolve from the expected Homebrew prefix in a fresh login shell and report their versions. Pre-existing Git identity and overrides must load from `config.local`; shared, local, and legacy Git files must survive reapplication unchanged.

`git-flow.bats` uses the same isolated dependency adapter as the shell E2E suites. Both E2E and first-time setup source `helpers/git-flow.bash` inside a login shell to verify real LFS staging, pointer format, commit identity, and binary checkout. The round-trip uses shared filters before `git lfs install --local` verifies project setup and hook creation. All LFS objects stay in temporary repositories without remotes; no authentication is required.

Repository copies use tracked files and nonignored untracked files from the current Git checkout, preserving uncommitted contents. Ignored local files, Git metadata, dependencies, and caches are excluded. A temporary local Git remote serves this snapshot under the documented clone URL; dependency downloads remain real. The Ubuntu setup container has no host directories, credentials, or Docker socket mounted, and teardown removes it on success or failure.

`setup-macos.bats` requires native macOS and GitHub-hosted runner markers, and explicitly refuses act and self-hosted runners. In that disposable VM only, it removes preinstalled Homebrew with the official uninstaller before following setup in a temporary HOME. It shares the installation, startup, and repeat-apply assertions with Ubuntu; teardown removes its temporary files. Local commands never run this installation path.
