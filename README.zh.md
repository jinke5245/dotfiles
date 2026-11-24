# Dotfiles

[English](README.md)

这是我的 dotfiles 仓库，欢迎拿它当模板，搭一套自己的配置。

## 安装

1. **用模板创建仓库。** 在 GitHub 上选择 **Use this template**。
2. **准备环境。** 使用普通用户账户，确保能联网并有权限安装依赖。macOS 上如果缺少命令行工具，先安装。

   ```sh
   xcode-select --install
   ```

   Debian/Ubuntu 使用 APT 安装基础依赖。

   ```sh
   sudo apt-get update
   sudo apt-get install --yes ca-certificates curl git openssh-client zsh
   ```

3. **安装 [chezmoi](https://www.chezmoi.io/) 并克隆仓库。** 将 `<repository-url>` 替换为你新建仓库的克隆地址。下面以 `~/.dotfiles` 为例。

   ```sh
   sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
   export PATH="$HOME/.local/bin:$PATH"
   git clone "<repository-url>" "$HOME/.dotfiles"
   cd "$HOME/.dotfiles"
   ```

4. **定制、预览并应用。** 按需修改 [Brewfile](Brewfile) 和 [`home/`](home/) 中的文件，再初始化 chezmoi 并预览变更。

   本配置使用 `~/.config/git`；运行 `init` 或 `apply` 前，请确保 `XDG_CONFIG_HOME` 未设置或指向 `~/.config`。如果使用自定义目录，请先迁移想保留的 Git 配置。

   ```sh
   chezmoi --source "$PWD" init
   chezmoi --source "$PWD" diff --exclude=dirs
   ```

先备份想保留的设置。安装器在首次应用或安装输入变化时运行，会安装依赖、写入本机配置，也可能生成 SSH 密钥。仅修改 shell 配置不会重新运行安装器。macOS 上请先退出 iTerm2，再从其他终端应用配置。

> [!WARNING]
> 应用时必须保留 `--exclude=dirs`，否则 chezmoi 可能将已有父目录的权限从 `0700` 改成 `0755`。该参数也会跳过目录创建，因此需要先按下面的命令补齐缺失的父目录。避免使用 `init --apply` 或通过 `update` 自动应用，它们会绕过这里的命令。

```sh
mkdir -p "$HOME/.config/git"
if [ "$(uname -s)" = Darwin ]; then
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
fi
chezmoi --source "$PWD" apply --exclude=dirs
exec zsh -l
```

开发和测试说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。
