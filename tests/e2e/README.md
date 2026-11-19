# Offline end-to-end tests

Prepare Homebrew on PATH, the Brewfile packages for your platform, Homebrew's Ruby/Bundler runtime and API cache, Node.js, and Corepack.

Set `OMZ_SOURCE` to a local Oh My Zsh Git checkout. The suite uses its committed files. Run from the repository root.

```sh
OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e
```

- `NODE_SOURCE` can override `node` on PATH with an absolute executable path.
- Set `COREPACK_SOURCE` to the package directory containing `dist/corepack.js` if the selected Node installation does not bundle Corepack.

The suite uses an [isolated repository copy and home](../integration/README.md#isolation).
It checks the Brewfile against installed packages and fails if a prerequisite is missing. Downloads are disabled.
