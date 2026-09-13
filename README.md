# @jinke5245/dotfiles

Personal dotfiles for macOS and Linux, managed with [chezmoi](https://www.chezmoi.io/).

## Usage

### Prerequisites

Use a regular user account on macOS or Debian / Ubuntu, with network access and administrator permissions for dependency installation. Bash, Git, curl, Zsh, and `ssh-keygen` must be available before applying configuration.

On macOS, install the Xcode Command Line Tools if needed, and wait for installation to finish:

```sh
xcode-select --install
```

On Debian / Ubuntu, use an account with `sudo` access:

```sh
sudo apt-get update
sudo apt-get install --yes ca-certificates curl git openssh-client zsh
```

### Setup

Before the first apply, review the [Git migration steps](#git) if you already have Git configuration.

Install chezmoi using its [official installer](https://www.chezmoi.io/install/#one-line-binary-install), clone the repository, and initialize your identity before previewing and applying configuration:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

git clone https://github.com/jinke5245/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"

chezmoi --source "$PWD" init
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" apply
```

For each identity field, `init` reads both global Git files and their includes in Git's normal order, then reuses saved values, and prompts only if still missing. System and repository settings are excluded. It saves the name and email under `[data.user]` in `~/.config/chezmoi/chezmoi.toml`, outside the repository. `diff` and `apply` do not prompt for identity.

For unattended setup, replace the `init` command with supplied answers; existing global or saved values still take precedence:

```sh
chezmoi --source "$PWD" init \
  --promptString 'User name=Your Name,User email=you@example.com' < /dev/null
```

Both fields are required during initialization; missing input stops unattended setup. Initialization does not install software, change Git configuration, or generate SSH keys.

Applying prepares Homebrew, installs the packages declared in `Brewfile`, installs Oh My Zsh, and initializes local Git identity and SSH keys before writing managed configuration. Homebrew and Oh My Zsh use their official installers; installation or initialization failures stop the apply. On Debian / Ubuntu, the script also installs [Homebrew's build prerequisites](https://docs.brew.sh/Homebrew-on-Linux).

Start a login Zsh to load the environment and interactive configuration:

```sh
exec zsh -l
```

Login shells initialize Homebrew and PATH; interactive shells load Oh My Zsh with the `robbyrussell` theme and `git` plugin. Installation does not change the account's default shell. To select Zsh as the default, use `chsh -s "$(command -v zsh)"` separately.

The Brewfile includes Git, Git LFS, GitHub CLI (`gh`), GitLab CLI (`glab`), and Tig. System Git is used for initial setup; login shells make the Homebrew tools available. Authenticate `gh` and `glab` separately on each device.

Shared integrations add extra completions, autojump (`j <directory-pattern>`), history-based suggestions (Right accepts), syntax highlighting, and substring history search (Up / Down). Extra completion definitions load before Oh My Zsh initializes completion; the other integrations load afterward. Brewfile supplies the required plugins; shell startup loads them directly when a Homebrew prefix is available and reports missing files without installing packages.

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

#### Zsh

Create `~/.zshrc.local` on each machine for local aliases, functions, environment variables, and key bindings. It loads last in interactive shells, so local settings take precedence:

```zsh
export EDITOR=nvim
alias gst='git status --short'
```

The file is optional and ignored by Git and chezmoi. Setup and apply neither create nor overwrite it.

#### Git

Shared defaults live in `~/.config/git/config`: new repositories use `main`, fetch prunes stale remote branches, pull requires a fast-forward, and Chinese filenames remain readable. Git LFS filters and GitHub / Gist HTTPS credential helpers are configured; `gh` resolves through PATH and requires device authentication.

**Migration and identity**

These paths use Git's default XDG location: `XDG_CONFIG_HOME` must be unset or point to `~/.config`.

1. Review and back up existing `~/.gitconfig` and `~/.config/git/config`. Use `git -C / config --list --show-origin` to locate settings outside any repository.
2. Move device-specific settings into `~/.config/git/config.local`, preserving any settings already there.
3. Preview `chezmoi diff` before applying. Resolve conflicting entries in `~/.gitconfig` manually; dotfiles do not move or delete that file.

No shared identity is provided. On apply, saved inputs initialize missing `user.name` and `user.email` entries in `config.local`, creating the file if needed. Existing entries (including empty values), unrelated settings, and comments are preserved. `user.useConfigOnly = true` requires an explicitly configured identity for commits.

To change this device's Git identity afterward:

```sh
mkdir -p ~/.config/git
git config --file ~/.config/git/config.local user.name "Your Name"
git config --file ~/.config/git/config.local user.email "you@example.com"
```

`config.local` loads after shared defaults and can override them. Git and chezmoi exclude it from source management; later applies preserve manual changes. An existing `~/.gitconfig` is read afterward, and repository settings take precedence over these global files.

**Authentication**

Authenticate separately on each device with [GitHub CLI](https://cli.github.com/manual/gh_auth_login) and [GitLab CLI](https://docs.gitlab.com/cli/auth/login/), selecting the appropriate host and Git transport:

```sh
gh auth login
glab auth login
```

Authentication state stays outside the repository. The shared GitHub helpers apply to HTTPS; SSH authentication remains device-managed.

**Git LFS projects**

Inside each repository that uses LFS, [initialize its hooks and local configuration](https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-install.adoc), then select the file patterns to track:

```sh
git lfs install --local
git lfs track "*.bin"
git add .gitattributes
```

Commit `.gitattributes` with the matching files. `--local` keeps project setup from writing global configuration; tracking does not convert existing history.

### SSH keys

Each apply checks `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`:

| Existing files   | Behavior                                                  |
| ---------------- | --------------------------------------------------------- |
| Neither          | Generate a new Ed25519 key pair.                          |
| Both             | Preserve the files and their permissions.                 |
| Private key only | Recover the public key without changing the private key.  |
| Public key only  | Stop with an error; resolve the incomplete pair manually. |

New keys have no passphrase. Their comment uses the email saved under `[data.user]`; if absent or empty, generation omits `-C` and keeps the default `user@hostname` comment. SSH initialization does not query Git, and existing or recovered keys keep their original comments.

Newly created permissions are `700` for `.ssh`, `600` for the private key, and `644` for the public key. Existing directories, keys at other paths, and their permissions remain unchanged.

Key paths must be regular files or symlinks to regular files. Conflicting directories and dangling symlinks stop apply without being replaced.

Public-key recovery requires an Ed25519 private key and may prompt for its existing passphrase. If recovery fails, apply stops without creating a public-key file.

Keys stay on the device; keep them outside Git and the chezmoi source state. Inspect the public-key fingerprint with:

```sh
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

Register the public key with your Git host or servers separately.

## Layout

```text
.
├── .chezmoiroot           # Selects home/ as the source root
├── Brewfile               # Shared Homebrew packages
├── home/                  # Chezmoi source state
│   ├── .chezmoi.toml.tmpl  # Local identity initialization
│   ├── .chezmoiignore     # Deployment exclusions
│   ├── .chezmoiscripts/   # Chezmoi lifecycle adapters
│   ├── dot_config/git/    # Shared Git configuration
│   ├── dot_zprofile.tmpl  # Login environment
│   └── dot_zshrc          # Interactive shell
├── scripts/               # Installation scripts
│   ├── install.sh         # Entry point
│   └── lib/               # Installation and initialization functions
├── tests/                 # Behavior tests and helpers
└── .github/workflows/     # CI checks
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
