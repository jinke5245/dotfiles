# @jinke5245/dotfiles

Personal dotfiles for macOS and Linux, managed with [chezmoi](https://www.chezmoi.io/).

## Usage

### Prerequisites

Use a regular user account on macOS or Debian / Ubuntu, with network access and administrator permissions for dependency installation. Bash, Git, curl, and Zsh must be available before applying configuration.

On macOS, install the Xcode Command Line Tools if needed, and wait for installation to finish:

```sh
xcode-select --install
```

On Debian / Ubuntu, use an account with `sudo` access:

```sh
sudo apt-get update
sudo apt-get install --yes ca-certificates curl git zsh
```

### Setup

Install chezmoi using its [official installer](https://www.chezmoi.io/install/#one-line-binary-install), then clone the repository and preview the configuration before applying it:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

git clone https://github.com/jinke5245/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"

chezmoi --source "$PWD" diff
chezmoi --source "$PWD" apply
```

Applying prepares Homebrew, installs the packages declared in `Brewfile`, and installs Oh My Zsh before writing the managed `.zprofile` and `.zshrc`. Homebrew and Oh My Zsh use their official installers; installation failures stop the apply. On Debian / Ubuntu, the script also installs [Homebrew's build prerequisites](https://docs.brew.sh/Homebrew-on-Linux).

Start a login Zsh to load the environment and interactive configuration:

```sh
exec zsh -l
```

Login shells initialize Homebrew and PATH; interactive shells load Oh My Zsh with the `robbyrussell` theme and `git` plugin. Installation does not change the account's default shell. To select Zsh as the default, use `chsh -s "$(command -v zsh)"` separately.

Shared integrations add extra completions, autojump (`j <directory-pattern>`), history-based suggestions (Right accepts), syntax highlighting, and substring history search (Up / Down). Extra completion definitions load before Oh My Zsh initializes completion; the other integrations load afterward. Brewfile supplies the required plugins; shell startup loads them directly and reports missing files without installing packages.

### Daily use

Run these commands from the repository root. Edit files under `home/`; changes made only to deployed files such as `~/.zshrc` can be overwritten by the next apply.

| Task                          | Command                                      |
| ----------------------------- | -------------------------------------------- |
| Preview configuration changes | `chezmoi --source "$PWD" diff`               |
| Apply local changes           | `chezmoi --source "$PWD" apply`              |
| Pull repository updates       | `git pull --ff-only`, then preview and apply |
| Reload the login environment  | `exec zsh -l`                                |

Each apply picks up changes to the Brewfile and installation scripts. Brewfile packages use `brew bundle install --no-upgrade`: missing packages are installed without requesting routine upgrades or removing other packages. Homebrew and Oh My Zsh upgrades remain managed by their own update mechanisms.

### Local customization

Create `~/.zshrc.local` on each machine for local aliases, functions, environment variables, and key bindings. It loads last in interactive shells, so local settings take precedence:

```zsh
export EDITOR=nvim
alias gst='git status --short'
```

The file is optional and ignored by Git and chezmoi. Setup and apply neither create nor overwrite it.

## Layout

```text
.
├── .chezmoiroot          # Selects home/ as the source root
├── Brewfile              # Shared Homebrew packages
├── home/                 # Chezmoi source state
│   ├── .chezmoiignore    # Deployment exclusions
│   ├── .chezmoiscripts/  # Chezmoi lifecycle adapters
│   ├── dot_zprofile.tmpl # Login environment
│   └── dot_zshrc         # Interactive shell
├── scripts/              # Installation scripts
│   ├── install.sh        # Entry point
│   └── lib/              # Homebrew and Oh My Zsh functions
├── tests/                # Behavior tests and helpers
└── .github/workflows/    # CI checks
```

Chezmoi filename attributes define target paths: for example, `home/dot_zshrc` maps to `~/.zshrc`. Repository documentation, tooling, and `scripts/` stay outside the deployment source.

## Development

### Requirements

| Tool    | Version                  |
| ------- | ------------------------ |
| Node.js | `>=22.22.1` (CI uses 22) |
| pnpm    | `12.3.4`                 |
| chezmoi | Tested with `2.72.1`     |
| Zsh     | Tested with `5.9`        |

Install development dependencies from the repository root:

```sh
pnpm install --frozen-lockfile
```

### Checks

| Command           | Purpose                                                     |
| ----------------- | ----------------------------------------------------------- |
| `pnpm check`      | Run linting, formatting checks, and tests.                  |
| `pnpm ci:test`    | Run the Linux CI jobs sequentially through act.             |
| `pnpm test`       | Run the unit and integration suites.                        |
| `pnpm format`     | Format repository files.                                    |
| `pnpm test:e2e`   | Run end-to-end tests separately.                            |
| `pnpm test:setup` | Verify first-time installation in a fresh Ubuntu container. |

CI runs `check` on Ubuntu, plus `test-e2e` and `test-setup` on macOS and Ubuntu. First-time setup uses a fresh Ubuntu container or a disposable GitHub macOS runner.

### Tests

Use [Bats](https://bats-core.readthedocs.io/), installed through pnpm. Prioritize integration tests; add unit tests for meaningful logic and a small number of end-to-end workflows using real dependencies.

| Directory            | Purpose                                             |
| -------------------- | --------------------------------------------------- |
| `tests/unit/`        | Isolated function or module behavior.               |
| `tests/integration/` | Configuration and scripts working with real tools.  |
| `tests/e2e/`         | Complete setup and shell workflows, run separately. |
| `tests/helpers/`     | Shared setup and execution functions.               |
| `tests/fixtures/`    | Fixed inputs; generated files belong in temp dirs.  |

Create directories as needed and name test files after the behavior they cover.

See [tests/README.md](tests/README.md) for suite coverage, execution requirements, and isolation details.

## Conventions

### Configuration

- Chezmoi manages configuration; package managers manage software.
- Prefer shared configuration. Use templates and built-in chezmoi data for necessary machine differences.

### Shell

- Entry points call functions explicitly; sourcing libraries has no installation side effects.
- Keep installation idempotent and separate from shell startup.
- Use `run_before_` adapters to invoke external scripts on every apply. Keep calls one-way; installers must not invoke `chezmoi apply`.
- Render templates before checking scripts, and test Zsh behavior with Zsh.
- Zsh files use `zsh -n` syntax checks; exclude them from the Bash-oriented formatter.
- Base `.zshrc` on the upstream Oh My Zsh template, preserve its structure and examples, and append personal configuration after the examples.

### Testing

- Separate setup, execution, and assertions with blank lines. Comment non-obvious fixture behavior and isolation choices; use readable multiline snippets.
- Assert exit status, output, and resulting files. Avoid coupling tests to implementation details.
- Test real repository copies with isolated home, configuration, cache, and state paths. Leave the checkout and real home untouched.
- Keep default tests offline and independent of execution order. Use controlled substitutes at external boundaries when needed.
- Share suites across platforms. Use CI matrices for OS coverage and Bats tags for execution requirements.
- Keep end-to-end tests outside `pnpm test`. Failures must return a nonzero exit status.

### Changes

- Branches: `<issue>-<type>-<summary>`.
- Do not commit or push directly to the default branch. Merge changes through pull requests.
- Commits: English Conventional Commits, `<type>: <summary>`.
- Keep pull requests focused and run `pnpm check` before requesting review.

### Documentation

- Keep shared project context, usage, and conventions in this README; keep agent-specific instructions in [AGENTS.md](AGENTS.md).
- Update relevant documentation when behavior, setup, or workflows change.

### Sensitive information

- Keep credentials, private keys, and tokens out of version control.
- Use placeholders in examples.
