# Contributing

For installation, see the [README](README.md).

## Layout

```text
.
├── .github/workflows/      # CI checks
├── .chezmoiroot            # Selects home/ as the source directory
├── Brewfile                # Shared Homebrew dependencies
├── home/                   # Chezmoi source state
│   ├── .chezmoi.toml.tmpl  # Local identity setup
│   ├── .chezmoiignore      # Deployment exclusions
│   ├── .chezmoiscripts/    # Chezmoi lifecycle hooks
│   ├── Library/            # macOS application settings
│   ├── dot_config/git/     # Shared Git configuration
│   ├── dot_zprofile.tmpl   # Login environment
│   └── dot_zshrc           # Interactive shell
├── scripts/                # Installation and development scripts
│   ├── dev/                # Repository development helpers
│   └── install/            # Local installation
│       ├── install.sh      # Installer entry point
│       └── lib/            # Installation and initialization functions
└── tests/                  # Test suites and shared support
    ├── integration/       # Offline integration tests
    ├── e2e/               # Offline workflows with prepared dependencies
    ├── setup/             # First-time installation tests
    └── support/           # Shared test support
        ├── fixtures/      # Test inputs and substitutes
        └── helpers/       # Shared Bats helpers
```

Chezmoi filename attributes determine deployment paths. For example, `home/dot_zshrc` maps to `~/.zshrc`. Repository docs, development tools, and `scripts/` are outside the deployment source.

## Development

### Requirements

| Tool                                  | Requirement                                                       |
| ------------------------------------- | ----------------------------------------------------------------- |
| Node.js                               | `>=22.22.1` (CI uses Node.js 22)                                  |
| pnpm                                  | Use the `packageManager` version in [package.json](package.json). |
| `chezmoi`, `git`, `zsh`, `ssh-keygen` | On PATH for integration tests.                                    |
| Docker                                | A running engine for `pnpm test:setup` and `pnpm ci:test`.        |

Install the development dependencies from the repository root.

```sh
pnpm install --frozen-lockfile
```

### Checks

Run `pnpm check` before requesting review.

| Command           | What it does                                                                                                            |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `pnpm check`      | Runs lint, formatting checks, and offline integration tests.                                                            |
| `pnpm ci:test`    | Runs the Ubuntu CI jobs in order via act. Requires Docker and network access. Skips if act is missing.                  |
| `pnpm test`       | Runs the [offline integration tests](tests/integration/README.md).                                                      |
| `pnpm format`     | Formats repository files.                                                                                               |
| `pnpm test:e2e`   | Runs [offline end-to-end tests](tests/e2e/README.md) with prepared dependencies.                                        |
| `pnpm test:setup` | Tests [first-time installation](tests/setup/README.md) in a fresh Ubuntu container. Requires Docker and network access. |

GitHub Actions runs `check` on Ubuntu and runs `test-e2e` and `test-setup` on Ubuntu and macOS. The macOS setup suite runs only on disposable GitHub-hosted runners.

### Local CI

Run one Ubuntu CI job with the corresponding command. The full `pnpm ci:test` runs them in this order and stops on failure.

```sh
pnpm ci:test:check
pnpm ci:test:test-e2e
pnpm ci:test:test-setup
```

[.actrc](.actrc) selects the workflow and image. The architecture follows the Docker engine.
If the Docker socket group differs from `0`, pass `--container-options="--group-add=<socket-gid>"` to the individual job.
Keep `pnpm ci:test` separate from `pnpm check` because the check job calls `pnpm check`.

## Conventions

### Configuration

- Use chezmoi to manage configuration and package managers to install software.
- Prefer shared configuration. Use templates and built-in chezmoi data where settings need to differ between machines.

### Shell

- Call functions explicitly from entry points. Sourcing a library should have no installation side effects.
- Keep installation safe to rerun and separate from shell startup.
- Run external installers through `run_onchange_before_` hooks. Include checksums of external inputs so changes to the Brewfile, installation scripts, and iTerm2 Profile trigger another run. Installers must not invoke `chezmoi apply`.
- Render templates before checking them. Use `zsh -n` for Zsh files and exclude them from Bash formatters.
- Keep the Oh My Zsh template examples. Set completion paths before Oh My Zsh initializes and load shell plugins afterward. Keep development tools after the examples and machine-specific overrides in `.zshrc.local`.

### Testing

- Separate setup, execution, and assertions with blank lines. Explain any fixture behavior or isolation choices that are not obvious.
- Check exit status, output, and resulting files. Avoid relying on implementation details. Limit third-party tool tests to installation, configuration, basic use, and preservation across repeated applies.
- Test against copies of the repository. Isolate `HOME`, configuration, cache, and state to protect the real checkout and user environment.
- Keep the default tests offline and independent of execution order. Use controlled substitutes for external dependencies where needed.
- Use CI matrices for platform coverage and Bats tags for different execution requirements. Keep end-to-end tests out of `pnpm test`. Tests must return a nonzero status on failure.
