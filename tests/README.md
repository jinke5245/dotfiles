# Tests

See the root README for [development requirements](../README.md#requirements) and [testing conventions](../README.md#testing).

## Suites

Group integration suites by responsibility: `chezmoi`, `install`, `git`, `ssh`, `zsh`, and `harness` (test isolation and safety). Keep descriptive filenames, and organize scenarios within each file. Tests run independently of directory order.

- Integration tests own detailed configuration rules, failure cases, and external-script updates.
- Offline E2E keeps one apply / startup / reapply flow, basic checks with real dependencies, and isolation checks.
- Setup tests cover the documented first-time installation and one reapply on each platform.

| File                                                                                               | Coverage                                                                                                                              |
| -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| [integration/chezmoi/chezmoi-init.bats](integration/chezmoi/chezmoi-init.bats)                     | Identity precedence, interactive and unattended inputs, local persistence, configuration preservation, and failures.                  |
| [integration/chezmoi/chezmoi-layout.bats](integration/chezmoi/chezmoi-layout.bats)                 | Source discovery, actual Zsh / Git target paths, and repository deployment exclusions.                                                |
| [integration/chezmoi/chezmoi-install.bats](integration/chezmoi/chezmoi-install.bats)               | Installation before configuration, failure propagation, repeatable application, and changes to external scripts.                      |
| [integration/chezmoi/chezmoi-usage.bats](integration/chezmoi/chezmoi-usage.bats)                   | Documented unattended init / diff / apply, default config discovery, and saved identity.                                              |
| [integration/install/install-homebrew.bats](integration/install/install-homebrew.bats)             | macOS and Debian / Ubuntu installation, existing executables, and prerequisite, download, or installer failures.                      |
| [integration/install/setup-homebrew-action.bats](integration/install/setup-homebrew-action.bats)   | Linux prerequisites, installation, existing executables, repeated setup, GitHub PATH updates, and failure propagation.                |
| [integration/install/install-brewfile.bats](integration/install/install-brewfile.bats)             | Brewfile installation, executable selection after setup, explicit repository paths, repeated apply, and failures.                     |
| [integration/install/install-node.bats](integration/install/install-node.bats)                     | Default LTS preparation, existing installations, Corepack location and fallback, environment isolation, repeated apply, and failures. |
| [integration/install/install-oh-my-zsh.bats](integration/install/install-oh-my-zsh.bats)           | Official installer invocation, existing installations, configuration preservation, managed paths, and failures.                       |
| [integration/git/git-defaults.bats](integration/git/git-defaults.bats)                             | Shared configuration discovery, effective default values and their origins, and LFS filter settings.                                  |
| [integration/git/git-local.bats](integration/git/git-local.bats)                                   | Required identity, local and repository overrides, legacy configuration precedence, preservation, and Git / chezmoi exclusions.       |
| [integration/git/git-identity.bats](integration/git/git-identity.bats)                             | Missing fields, direct / included identity, comments, absent inputs, symlinks, and read, parse, or lock failures.                     |
| [integration/git/git-install.bats](integration/git/git-install.bats)                               | Saved identity on apply, read-only preview, manual changes, argument quoting, and failure before SSH or managed files.                |
| [integration/git/git-credentials.bats](integration/git/git-credentials.bats)                       | GitHub / Gist helper routing, inherited-helper resets, unrelated URLs, local overrides, and unavailable credentials.                  |
| [integration/ssh/ssh-keys.bats](integration/ssh/ssh-keys.bats)                                     | Ed25519 keys, supplied/default comments, Git independence, permissions, preservation, and path conflicts.                             |
| [integration/ssh/ssh-key-recovery.bats](integration/ssh/ssh-key-recovery.bats)                     | Public-key recovery, original comments, encrypted keys, Ed25519 validation, preservation, and failure handling.                       |
| [integration/ssh/ssh-install.bats](integration/ssh/ssh-install.bats)                               | Saved email on apply, default comments, Git independence, preview, preservation, recovery, and failure propagation.                   |
| [integration/zsh/zsh-startup.bats](integration/zsh/zsh-startup.bats)                               | Zsh syntax, startup modes, Homebrew selection, PATH handling, and missing Oh My Zsh.                                                  |
| [integration/zsh/zsh-development.bats](integration/zsh/zsh-development.bats)                       | fnm environment and completion order, uv/uvx discovery and auditing, missing dependencies, local overrides, and Go tool paths.        |
| [integration/zsh/zsh-plugins.bats](integration/zsh/zsh-plugins.bats)                               | Completion auditing, plugin loading order, prefix discovery and absence, missing dependencies, and arrow bindings.                    |
| [integration/zsh/zsh-local.bats](integration/zsh/zsh-local.bats)                                   | Local overrides, missing and unreadable files, startup modes, repeat-apply preservation, and Git / chezmoi exclusions.                |
| [integration/harness/sandbox-isolation.bats](integration/harness/sandbox-isolation.bats)           | Current edits and new files are copied; ignored private data, Git metadata, and deleted files are excluded.                           |
| [integration/harness/flow-homebrew-safety.bats](integration/harness/flow-homebrew-safety.bats)     | Offline E2E substitutes read-only dependency checks and rejects other Homebrew operations.                                            |
| [integration/harness/setup-container-safety.bats](integration/harness/setup-container-safety.bats) | Container setup reports missing Docker and stops before attempting installation.                                                      |
| [integration/harness/setup-macos-safety.bats](integration/harness/setup-macos-safety.bats)         | macOS setup refuses local, act, and self-hosted execution before installation or removal.                                             |
| [e2e/chezmoi-flow.bats](e2e/chezmoi-flow.bats)                                                     | One apply / startup / reapply flow, local-state preservation, and Node / Corepack isolation.                                          |
| [e2e/development-flow.bats](e2e/development-flow.bats)                                             | Language-tool paths and versions, the Node default, and the shell environment.                                                        |
| [e2e/git-flow.bats](e2e/git-flow.bats)                                                             | Effective Git configuration and Git LFS availability.                                                                                 |
| [e2e/zsh-plugins.bats](e2e/zsh-plugins.bats)                                                       | Plugin and completion loading and configured key bindings.                                                                            |
| [e2e/setup.bats](e2e/setup.bats)                                                                   | Ubuntu setup, identity / SSH, language-tool availability, first-use pnpm, and repeat application.                                     |
| [e2e/setup-macos.bats](e2e/setup-macos.bats)                                                       | The same setup and development checks on a guarded GitHub-hosted macOS runner, including missing Homebrew.                            |

## Running

Run commands from the repository root:

| Command           | Scope and requirements                                                                                                                               |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pnpm test`       | Default unit and integration suites; runs offline.                                                                                                   |
| `pnpm ci:test`    | Local Linux CI jobs via act; requires a running Docker-compatible engine and network access. Skips when act is unavailable.                          |
| `pnpm test:e2e`   | End-to-end suite; requires Homebrew on PATH, installed Brewfile packages, Git, and the prepared Node runtime and Oh My Zsh checkout described below. |
| `pnpm test:setup` | First-time setup suite; requires Docker and network access. Creates and removes a fresh `ubuntu:24.04` container.                                    |

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

Development E2E reuses the available `node` executable; an optional `NODE_SOURCE` override accepts an absolute executable path. CI reuses its prepared Node runtime. No separate Python interpreter is required.

```sh
OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e
```

## Isolation

Identity initialization tests run real chezmoi and Git with temporary homes, configuration, and source copies. Synthetic values exercise native prompts and unattended inputs; initialization must leave Git files unchanged and never run installers or generate SSH keys.

Global identity lookup covers legacy and XDG files together, includes, per-field precedence, and empty-value fallback. A test-owned system configuration verifies that system identity is excluded. Explicit Git environment overrides exercise repository selection, conditional includes, command-scope values, and config-file selection; none may replace global identity.

Installation tests serve local installer fixtures instead of downloading scripts. System prefixes are relocated only in disposable repository copies; tests never install into real system directories.

Node installation tests substitute fnm, npm, and Corepack with strict command fixtures. Their state and executable paths stay inside the sandbox; unrelated tools on PATH reject calls. These tests cover installation decisions and failure handling without downloading Node.js, Python, or pnpm. Real runtime execution belongs to E2E and setup coverage.

Offline E2E creates a temporary fnm installation, symlinking the runner's Node executable to preserve native library lookup and copying Corepack into it. All generated shims and writable state stay in the sandbox. Set `COREPACK_SOURCE` to a prepared Corepack package directory when Node does not bundle it; CI prepares this package under the runner's temporary directory. Missing prerequisites fail without installation. The shared apply and shell helpers disable npm and Corepack network access and give fnm a non-network mirror, so missing runtime preparation also fails without downloading software.

Git integration tests use real Git with a temporary HOME, a test-owned system configuration, and an empty inherited environment. Git discovers the deployed `~/.config/git/config` through its normal XDG lookup; default-setting checks read effective values and their origins. Repositories stay inside the sandbox, and network Git protocols and credential prompts are disabled. A substitute `gh` exercises the credential protocol with synthetic values. E2E checks the installed Git LFS executable and effective filter configuration.

SSH integration tests require `ssh-keygen` and generate real keys only in temporary homes, with explicit key paths and an empty inherited environment. No SSH connections are made. Tests substitute only passphrase input through a test-owned askpass program; unavailable input fails immediately without opening a terminal prompt. Private-key contents are never printed or stored in fixtures.

Zsh platform cases use chezmoi data overrides and temporary installation paths. These cases do not replace native tests on each OS.

Development integration cases use a strict fnm fixture for the two shell setup commands and real Zsh completion discovery. Runtime and package-manager fixtures reject startup-time invocations. E2E uses real fnm, uv, and uvx completion definitions and verifies that starting a shell with a missing project Node version does not install it.

`development-flow.bats` checks tool paths and version commands in the configured shell. Shared `helpers/development-flow.bash` supplies marker files under `~/go/bin`, project `node_modules`, and `.venv` directories for the combined apply flow and setup tests. These checks need no compilation, project execution, or Python environment creation; shell helpers keep downloads disabled.

`chezmoi-flow.bats` runs the real Oh My Zsh installer and Git fetch against a local snapshot of the supplied checkout's committed files. It installs only inside a temporary home, disables update checks, and blocks remote Git protocols and unexpected installer downloads.

One scenario covers first apply, shell startup with local overrides, and repeated apply. It checks Git identity initialization, then snapshots manual Git edits, Zsh configuration, Oh My Zsh customization, and SSH keys. Reapplication must preserve their contents and timestamps, development markers, and Node's default and installed-version list. Detailed key validation and script-update rules remain in integration tests.

This flow suite requires existing Homebrew and installed Brewfile packages. A command adapter forwards prefix and environment queries to the real Homebrew, replaces Bundle installation with `brew bundle check --no-upgrade`, and rejects other operations. It checks Homebrew's prepared Ruby and Bundler files before invoking Bundle, preventing automatic runtime installation or upgrades. Missing prerequisites fail the test without installation. Native platform data and rendered files remain unchanged. The checkout and actual shell startup files are not modified or sourced.

`zsh-plugins.bats` starts the configured shell with real plugins in a temporary HOME, checks plugin and completion availability, and reads the configured key bindings. Local overrides are exercised by the combined apply flow.

`setup.bats` starts with no chezmoi, Homebrew, or Oh My Zsh in a fresh Ubuntu container. Root only provisions a test account with sudo access; that ordinary user follows the README prerequisites and installation steps. Supplied answers initialize `[data.user]` at the default config path before preview and apply. Repeat init needs no answers; init and preview must not install dependencies or create Git identity / SSH files. `NONINTERACTIVE=1` answers Homebrew's unattended-installation prompts.

The first apply creates local Git identity and SSH keys from the saved inputs, then checks shell startup and installed tools. Manual Git identity edits, an unrelated setting, and a comment are added before reapplying; local Git changes, saved inputs, SSH keys, and the pre-existing `.zshrc.local` must survive unchanged. Final checks read effective Git configuration and compare development state. Brewfile dependencies must be satisfied, and installed package versions must remain unchanged after reapplication.

Both setup platforms use `helpers/setup-development.bash` to verify tool paths, the initial LTS Node, and Corepack's pnpm shim. Before first use, the isolated Corepack cache and uv-managed Python directory must be absent. A temporary `package.json` copies the repository's `packageManager` declaration; one `pnpm --version` invocation verifies that Corepack can fetch and start the declared version.

Checks in fresh shells keep downloads disabled and compare tool versions, Node's default, and the shared marker files across reapplication. Python remains uninstalled by uv. HOME, XDG state, and Corepack cache stay inside the disposable environment. The full setup suites permit dependency downloads; default and offline E2E suites remain separate.

Both setup platforms use `helpers/ssh-flow.bash` once to verify matching, unencrypted Ed25519 keys, the supplied comment, and directory / key permissions after installation. Preview must not generate keys; repeated apply uses snapshots to verify preservation. Test keys and snapshots stay inside isolated homes or test directories.

`git-flow.bats` uses the same isolated dependency adapter as the shell E2E suites. Both E2E and first-time setup source `helpers/git-flow.bash` inside a login shell to check effective Git settings, the Homebrew Git LFS executable, its version command, and the four shared LFS filter declarations. These checks are read-only and need no project repository or authentication.

Repository copies use tracked files and nonignored untracked files from the current Git checkout, preserving uncommitted contents. Ignored local files, Git metadata, dependencies, and caches are excluded. A temporary local Git remote serves this snapshot under the documented clone URL; dependency downloads remain real. The Ubuntu setup container has no host directories, credentials, or Docker socket mounted, and teardown removes it on success or failure.

`setup-macos.bats` requires native macOS and GitHub-hosted runner markers, and explicitly refuses act and self-hosted runners. In that disposable VM only, it removes preinstalled Homebrew with the official uninstaller before following setup in a temporary HOME. It shares the installation, startup, and repeat-apply assertions with Ubuntu; teardown removes its temporary files. Local commands never run this installation path.
