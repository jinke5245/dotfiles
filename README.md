# @jinke5245/dotfiles

Personal dotfiles for macOS and Linux, managed with [chezmoi](https://www.chezmoi.io/).

## Usage

The minimal Zsh configuration and repository checks are available. Oh My Zsh must already exist at `~/.oh-my-zsh`; installation scripts and complete setup instructions will follow.

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
│   └── lib/              # Reusable script libraries
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

| Command         | Purpose                                          |
| --------------- | ------------------------------------------------ |
| `pnpm check`    | Run linting, formatting checks, and tests.       |
| `pnpm test`     | Run the unit and integration suites.             |
| `pnpm format`   | Format repository files.                         |
| `pnpm test:e2e` | Run shell checks with a real Oh My Zsh checkout. |

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

- `integration/chezmoi-layout.bats`: source discovery, mapping, deployment exclusions, repeatable application, and preservation of unrelated files.
- `integration/zsh-startup.bats`: Zsh syntax, startup modes, Homebrew selection, PATH handling, and missing Oh My Zsh. Platform cases render templates with chezmoi data overrides and relocate installation paths into the sandbox; these do not replace tests on each OS.
- `e2e/zsh-startup.bats`: real Oh My Zsh theme, plugin, history, and completion loading. Requires Git and a local Oh My Zsh checkout:

  ```sh
  OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e
  ```

The e2e suite copies committed framework files into a temporary home and disables update checks. It does not install dependencies or use the network.

## Conventions

### Configuration

- Chezmoi manages configuration; package managers manage software.
- Prefer shared configuration. Use templates and built-in chezmoi data for necessary machine differences.

### Shell

- Entry points call functions explicitly; sourcing libraries has no installation side effects.
- Keep installation idempotent and separate from shell startup.
- Render templates before checking scripts, and test Zsh behavior with Zsh.
- Zsh files use `zsh -n` syntax checks; exclude them from the Bash-oriented formatter.
- Base `.zshrc` on the upstream Oh My Zsh template, preserve its structure and examples, and append personal configuration after the examples.

### Testing

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
