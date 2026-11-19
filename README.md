# Dotfiles

[简体中文](README.zh.md)

This is my personal dotfiles repo. Feel free to use it as a template for your own setup.

## Setup

1. **Create your repository.** Select **Use this template** on GitHub.
2. **Prepare your machine.** Use a regular account with network access and permission to install dependencies. On macOS, install the Command Line Tools if needed.

   ```sh
   xcode-select --install
   ```

   On Debian/Ubuntu, install the prerequisites with APT.

   ```sh
   sudo apt-get update
   sudo apt-get install --yes ca-certificates curl git openssh-client zsh
   ```

3. **Install [chezmoi](https://www.chezmoi.io/) and clone your repository.** Replace `<repository-url>` with your repository's clone URL. The example uses `~/.dotfiles` as the checkout directory.

   ```sh
   sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
   export PATH="$HOME/.local/bin:$PATH"
   git clone "<repository-url>" "$HOME/.dotfiles"
   cd "$HOME/.dotfiles"
   ```

4. **Customize, preview, and apply.** Edit the [Brewfile](Brewfile) and the files in [`home/`](home/) to suit your setup. Then initialize chezmoi and review the proposed changes.

   ```sh
   chezmoi --source "$PWD" init
   chezmoi --source "$PWD" diff
   ```

   Back up any settings you want to keep. Applying installs dependencies, writes local configuration, and can create SSH keys. On macOS, quit iTerm2 and apply from another terminal.

   ```sh
   chezmoi --source "$PWD" apply
   exec zsh -l
   ```

For development and testing, see [CONTRIBUTING.md](CONTRIBUTING.md).
