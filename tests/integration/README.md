# Integration tests

To run one test file, pass its path to Bats from the repository root.

```sh
pnpm exec bats --print-output-on-failure tests/integration/zsh/zsh-development.bats
```

## Isolation

Integration and offline E2E tests copy tracked and unignored files, including uncommitted changes. They use temporary homes, configuration, caches, and state. The copy excludes Git metadata, local caches, and dependencies. Integration tests substitute fixtures for external installers.

## iTerm2

The native preferences test uses a temporary plist without launching iTerm2. It runs only on macOS, and the macOS E2E job runs it separately.

For a manual check, follow the [setup instructions](../../README.md#setup) on macOS, then reopen iTerm2.

- Open a new window and check that it uses the `Dotfiles` profile and starts a login shell.
- Check the font, colors, tabs, Shift-Return, and copy/paste against the shared settings.
- Confirm that existing local connection profiles still work.

Record the result in the pull request.
