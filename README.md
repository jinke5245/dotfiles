# Dotfiles

适用于 macOS 和 Debian / Ubuntu 的 dotfiles，使用 [chezmoi](https://www.chezmoi.io/) 管理。

## Usage

### Prerequisites

使用普通用户账户，并准备网络和安装依赖所需的管理员权限。应用配置前，需要有 Bash、Git、curl、Zsh 和 `ssh-keygen`。

macOS 如未安装 Xcode Command Line Tools，先运行以下命令，等待安装完成：

```sh
xcode-select --install
```

Debian / Ubuntu 使用有 `sudo` 权限的账户安装基础依赖：

```sh
sudo apt-get update
sudo apt-get install --yes ca-certificates curl git openssh-client zsh
```

### Setup

已有 Git 配置时，先阅读 [Git 迁移说明](#git)。macOS 请关闭 iTerm2，在其他终端中执行安装。

可以直接使用本仓库，或在 GitHub 上通过 [Use this template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template) 创建新仓库。将下方 `<repository-url>` 替换为实际使用仓库的克隆地址。

通过[官方安装脚本](https://www.chezmoi.io/install/#one-line-binary-install)安装 chezmoi，克隆仓库，再初始化身份、预览并应用配置：

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

git clone "<repository-url>" "$HOME/dotfiles"
cd "$HOME/dotfiles"

chezmoi --source "$PWD" init
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" apply
```

`init` 分别查找姓名和邮箱：先按 Git 原生顺序读取默认的全局配置及其 include，再使用已保存的值，仍缺失时才询问。不读取系统、仓库、环境变量指定的配置或命令级覆盖值。结果保存到仓库外的 `~/.config/chezmoi/chezmoi.toml` 中的 `[data.user]`。

重复 `init` 会保留其他 chezmoi 配置，但会重新生成 TOML，原有注释和格式不会保留。`init` 不安装软件、不修改 Git 配置、不生成 SSH 密钥；`diff` 和 `apply` 不再询问身份。

无人值守安装时，用下面的命令替换 `init`；已有全局配置或已保存的值仍优先使用：

```sh
chezmoi --source "$PWD" init \
  --promptString 'User name=Your Name,User email=you@example.com' < /dev/null
```

姓名和邮箱都不能为空，缺少输入会停止初始化。

`apply` 会在写入托管配置前准备 Homebrew、安装 [Brewfile](Brewfile) 中的依赖、准备 Node.js 和 Corepack、安装 Oh My Zsh，并初始化本机 Git 身份和 SSH 密钥。Homebrew 和 Oh My Zsh 使用官方安装脚本；任何安装或初始化失败都会停止应用。Debian / Ubuntu 还会安装 [Homebrew 的构建依赖](https://docs.brew.sh/Homebrew-on-Linux)。

完成后启动登录 Zsh：

```sh
exec zsh -l
```

登录 shell 初始化 Homebrew 和 PATH，交互式 shell 加载共享 Zsh 配置及插件。启动 shell 不安装软件，安装也不会修改账户的默认 shell。

### Daily use

在仓库根目录操作，共享配置源位于 [home/](home/)；例如 `home/dot_zshrc` 部署到 `~/.zshrc`。直接编辑源文件，仅修改部署文件可能被下一次应用覆盖。

| 操作         | 命令                                 |
| ------------ | ------------------------------------ |
| 预览配置变更 | `chezmoi --source "$PWD" diff`       |
| 应用本地变更 | `chezmoi --source "$PWD" apply`      |
| 获取仓库更新 | `git pull --ff-only`，然后预览并应用 |
| 重载登录环境 | `exec zsh -l`                        |

每次 `apply` 都会执行安装脚本，读取最新 Brewfile。依赖通过 `brew bundle install --no-upgrade` 补齐，不主动升级或删除其他包；已有 Node 默认版本和项目环境会保留。Homebrew 和 Oh My Zsh 的升级由各自机制管理。

### iTerm2

macOS 安装会通过 Homebrew 安装 iTerm2，并将共享的 `Dotfiles` Profile 设为默认。

| 内容                           | 共享源文件                                                                              |
| ------------------------------ | --------------------------------------------------------------------------------------- |
| Profile 外观和终端行为         | [Profile JSON](<home/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json>) |
| 全局标签页、复制粘贴和键盘设置 | [iTerm2 安装库](scripts/install/lib/iterm2.sh)                                          |

Profile 部署到 `~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json`。修改共享源后，按[日常操作](#daily-use)预览并应用；全局偏好设置由脚本在应用时写入，需审阅脚本中的全局偏好变更。

应用前退出 iTerm2，在 Terminal 等其他终端中执行，再重新打开 iTerm2，避免退出时覆盖偏好设置。连接命令和本机工作目录放在本地 Profile 中；应用会保留这些 Profile 和无关偏好。Linux 不安装或配置 iTerm2。

### Local customization

#### Zsh

登录 shell 的本机环境变量和 PATH 放在 `~/.zprofile.local`；交互式 shell 的别名、函数、环境变量和按键绑定放在 `~/.zshrc.local`。两个文件分别在 `.zprofile` 和 `.zshrc` 最后加载，可覆盖对应的共享设置。例如，在 `.zshrc.local` 中添加：

```zsh
export EDITOR=nvim
alias gst='git status --short'
```

两个文件均可选，在所有支持的平台上生效，Git 和 chezmoi 都会忽略；安装和应用不会创建或覆盖它们。

#### Git

共享配置位于 `~/.config/git/config`：新仓库默认使用 `main`，fetch 清理失效远程分支，pull 仅允许快进，中文文件名直接显示。此外配置了 Git LFS 过滤器和 GitHub / Gist HTTPS 凭据助手；`gh` 从 PATH 查找，需要在本机登录。

**Migration and identity**

当前配置使用默认 XDG 路径，`XDG_CONFIG_HOME` 必须未设置或指向 `~/.config`。

1. 检查并备份已有 `~/.gitconfig` 和 `~/.config/git/config`，查看全局配置及来源：

   ```sh
   env -u GIT_CONFIG -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_PARAMETERS \
     GIT_CONFIG_COUNT=0 GIT_CONFIG_NOSYSTEM=1 \
     git --git-dir=/dev/null config --includes --list --show-origin
   ```

2. 将本机设置迁移到 `~/.config/git/config.local`，保留其中已有配置。
3. 先预览 `chezmoi --source "$PWD" diff` 再应用。自行解决 `~/.gitconfig` 中的冲突项，安装脚本不会迁移或删除该文件。

仓库不提供共享身份。应用时，只用已保存的输入补齐 `config.local` 中缺失的 `user.name` 和 `user.email`，必要时创建文件。已有字段（包括空值和 include 中的字段）、无关配置及注释都会保留。`user.useConfigOnly = true` 要求提交时有显式身份。

之后可手动修改本机身份：

```sh
mkdir -p ~/.config/git
git config --file ~/.config/git/config.local user.name "Your Name"
git config --file ~/.config/git/config.local user.email "you@example.com"
```

`config.local` 在共享配置后加载，可以覆盖共享值；Git 和 chezmoi 不管理该文件，重复应用保留手动修改。已有 `~/.gitconfig` 加载得更晚，仓库级配置的优先级又高于这些全局配置。

认证状态保留在各设备上，不随仓库同步。共享 GitHub 凭据助手用于 HTTPS，需要在本机单独登录；SSH 认证由本机密钥决定。

### SSH keys

每次应用都会检查 `~/.ssh/id_ed25519` 和 `~/.ssh/id_ed25519.pub`：

| 已有文件 | 行为                                   |
| -------- | -------------------------------------- |
| 都不存在 | 生成新的 Ed25519 密钥对                |
| 两者都有 | 保留文件及其权限                       |
| 仅有私钥 | 恢复公钥，保留私钥                     |
| 仅有公钥 | 停止并报错，需要手动处理不完整的密钥对 |

新密钥不设口令，注释使用 `[data.user]` 保存的邮箱；邮箱缺失或为空时使用默认 `user@hostname`，不查询 Git。恢复公钥沿用私钥中的注释，仅支持 Ed25519，可能询问已有口令；失败时停止应用，不留下公钥文件。

新建 `.ssh`、私钥、公钥的权限分别为 `700`、`600`、`644`。已有目录、其他路径的密钥及权限不变。密钥路径必须是普通文件或指向普通文件的符号链接；目录冲突和悬空链接会导致应用停止，不会被替换。

密钥仅保存在设备上，不应加入 Git 或 chezmoi 源状态；公钥需自行注册到对应的 Git 托管平台或服务器。

Linux 登录时，若未继承 `SSH_AUTH_SOCK`，会检查并启动或复用 ssh-agent，将环境缓存到 `~/.ssh/ssh-agent`，并尝试加载 `id_ed25519`。已有 agent 环境保持不变。

## Maintenance

仓库结构、开发环境、检查命令和维护约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。
