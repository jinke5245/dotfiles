# @jinke5245/dotfiles

Personal dotfiles for macOS and Linux, managed with [chezmoi](https://www.chezmoi.io/).

## Usage

With Bash, Git, curl, Zsh, and chezmoi available, apply from the repository root:

```sh
chezmoi --source "$PWD" apply
```

Before applying configuration, chezmoi invokes `scripts/install.sh` to ensure Homebrew and Oh My Zsh at `~/.oh-my-zsh`, using their official installers. Supported systems are macOS and Debian / Ubuntu.

On Debian / Ubuntu, a missing Homebrew installation first triggers `sudo apt-get update` and installation of `build-essential`, `procps`, `curl`, `file`, and `git`, following the [official Linux requirements](https://docs.brew.sh/Homebrew-on-Linux). Homebrew may require administrator permissions.

Existing installations are skipped; download or installer failures stop the apply. Oh My Zsh uses `--unattended --keep-zshrc` to preserve existing configuration and avoid changing or launching the shell. On a fresh home, its generated `.zshrc` is then replaced by the managed configuration. Shell startup never installs dependencies.

Login shells initialize Homebrew when available, then prepend `~/bin`, `~/.local/bin`, and `/usr/local/bin` to PATH with duplicates removed. Interactive shells inherit PATH and load Oh My Zsh with the `robbyrussell` theme and `git` plugin.

Chezmoi selects the default Homebrew path using `.chezmoi.os` and `.chezmoi.arch` when rendering `.zprofile`. Nonlogin shells inherit the Homebrew environment.

## Layout

```text
.
├── .chezmoiroot          # Selects home/ as the source root
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

| Command         | Purpose                                            |
| --------------- | -------------------------------------------------- |
| `pnpm check`    | Run linting, formatting checks, and tests.         |
| `pnpm ci:test`  | Run the CI workflow locally when act is installed. |
| `pnpm test`     | Run the unit and integration suites.               |
| `pnpm format`   | Format repository files.                           |
| `pnpm test:e2e` | Run end-to-end tests separately.                   |

CI runs `pnpm check` on Ubuntu for pull requests and pushes to `main`.

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
