# First-time setup tests

The tests follow the [setup guide](../../README.md#setup) through init, preview, and apply. A second apply checks that local config, keys, and development state survive.

## Ubuntu

`pnpm test:setup` installs dependencies in a fresh `ubuntu:24.04` container. The container receives a repository copy and has no host mounts, credentials, or Docker socket. The test removes it when finished.

## macOS

**`pnpm test:setup:macos` removes preinstalled Homebrew.** Run it only on a disposable GitHub-hosted macOS runner.
