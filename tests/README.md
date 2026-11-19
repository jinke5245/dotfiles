# Tests

版本要求和开发约定见[开发维护说明](../CONTRIBUTING.md)。测试使用 pnpm 提供的 Bats；默认 integration 需要系统中已有 chezmoi、Git、Zsh 和 `ssh-keygen`。

## Suites

- `integration/`：离线验证配置、安装脚本、失败处理和隔离边界，按 chezmoi、install、git、ssh、zsh、iterm2、harness 分组。
- `e2e/`：使用真实依赖验证 apply、shell 启动和重复 apply；首次安装测试也放在这里，通过 Bats 的 `network`、`container`、`macos` 标签单独运行。
- `helpers/` 保存共享执行与断言函数，`fixtures/` 保存固定输入；生成文件写入临时目录。

## Running

安装仓库开发依赖后，在仓库根目录执行：

| 命令                                   | 范围与前置条件                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------ |
| `pnpm test` 或 `pnpm test:integration` | 默认离线 integration。                                                               |
| `pnpm test:e2e`                        | 排除 `network`，需要下文列出的已准备依赖。                                           |
| `pnpm test:setup`                      | 选择 `network,container`；需要可用的 Docker 和网络，创建并清理 `ubuntu:24.04` 容器。 |
| `pnpm test:setup:macos`                | 选择 `network,macos`；需要网络，仅允许下文限定的 GitHub-hosted macOS runner。        |
| `pnpm ci:test`                         | 通过 act 顺序运行本地 Linux CI，需要 Docker 和网络；缺少 act 时跳过。                |

E2E 和 setup 不随 `pnpm test` 或 `pnpm check` 运行。GitHub CI 的 `check` 在 Ubuntu 运行，`test-e2e` 和 `test-setup` 使用 Ubuntu / macOS 矩阵；setup job 超时为 20 分钟。

### Offline E2E

运行前需准备 PATH 中的 Homebrew、Brewfile 中的依赖、可用的 Node.js 和 Corepack，以及本地 Oh My Zsh Git checkout。Homebrew 的 Ruby / Bundler 运行时和 API 缓存也必须准备完成；缺少依赖时测试失败，不会补装。无需单独准备 Python 解释器。

| 环境变量          | 用法                                                                                                                               |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `OMZ_SOURCE`      | 必填，指向本地 Oh My Zsh Git checkout；测试使用其已提交文件的快照。                                                                |
| `NODE_SOURCE`     | 可选，指定 Node 可执行文件的绝对路径；默认使用 PATH 中的 `node`。                                                                  |
| `COREPACK_SOURCE` | 可选，指定包含 `dist/corepack.js` 的 Corepack 包目录；默认查找所选 Node 安装下的 `lib/node_modules/corepack`，找不到时需显式提供。 |

```sh
OMZ_SOURCE=/path/to/ohmyzsh pnpm test:e2e
```

需要覆盖 Node 或 Corepack 来源时：

```sh
OMZ_SOURCE=/path/to/ohmyzsh \
  NODE_SOURCE=/absolute/path/to/node \
  COREPACK_SOURCE=/path/to/corepack \
  pnpm test:e2e
```

测试会在临时 HOME 中执行本地 Oh My Zsh 安装脚本，并为 Node / Corepack 准备隔离的运行环境。Homebrew 适配器只允许查询，将 Bundle 安装替换为 `brew bundle check --no-upgrade`，API 缓存使用临时副本，并禁止 HTTP(S) 下载；远程 Git、npm、Corepack 和运行时下载均被禁用。CI 在准备阶段安装依赖，测试阶段保持离线。

### Local CI

`pnpm ci:test` 按下列顺序执行，任一失败即停止：

| 命令                      | job                                 |
| ------------------------- | ----------------------------------- |
| `pnpm ci:test:check`      | `check`                             |
| `pnpm ci:test:test-e2e`   | `test-e2e`，仅 `os:ubuntu-latest`   |
| `pnpm ci:test:test-setup` | `test-setup`，仅 `os:ubuntu-latest` |

`.actrc` 指定 workflow、`runner-24.04` 镜像和容器清理选项，架构随本地 Docker 引擎。act 是 GitHub CI 的补充，不提供原生 macOS 覆盖。不要把 `ci:test` 加入 `pnpm check`，以免 workflow 中再次执行 `pnpm check` 形成递归。

为使 runner 能通过 Docker socket 创建 setup 容器，`ci:run` 在命令行添加补充组 `0`，避免新版 act 忽略项目 `.actrc` 中的容器权限选项。若本地 socket 属于其他组，向相应的 `ci:test:*` 命令传入 `--container-options="--group-add=<socket-gid>"`。

## Isolation

- 仓库副本使用当前 checkout 中已跟踪和未被忽略的新文件，保留未提交内容；排除已删除文件、忽略的本机数据、Git 元数据、依赖和缓存。
- integration 和离线 E2E 使用临时 HOME、XDG 配置、缓存和状态目录。integration 在安装边界使用受控替身；真实 Git 和 `ssh-keygen` 只在测试目录写入，不连接远程或读取真实凭据。实际 shell 启动文件不被修改或加载。
- 原生 macOS iTerm2 E2E 使用明确的临时偏好文件路径，不启动 iTerm2，也不读写用户偏好；仅更换 HOME 不足以隔离应用偏好域。平台数据覆盖用例不能替代原生平台验证。
- Ubuntu setup 允许真实下载与安装，但只在独立容器内执行。容器不挂载宿主目录、凭据或 Docker socket，并在成功或失败后清理。
- macOS setup 会卸载 runner 预装的 Homebrew，并清理其遗留的悬空补全链接，仅能在可销毁的 GitHub-hosted 原生 macOS runner 上执行；脚本拒绝本机、act 和自托管 runner。安装与复验使用临时 HOME。

首次安装测试按 README 执行 init、预览、apply 和再次 apply，验证本机配置、SSH 密钥和开发环境状态得到保留。默认测试与离线 E2E 不承担首次安装的网络验证。

## Manual iTerm2 Check

按[macOS iTerm2 说明](../README.md#iterm2)应用配置并重新打开 iTerm2 后，做一次简短检查：

- 新窗口使用 `Dotfiles` Profile，并启动 login shell。
- 字体、颜色、标签页、Shift-Return 和复制粘贴符合共享设置。
- 现有本机连接 Profile 仍然可用。

在 PR 中记录实际检查结果。
