# Contributing

本文件面向仓库维护者和 AI，说明开发环境、检查流程和维护约定。安装、日常使用和本机定制见 [README.md](README.md)，AI 专用操作约束见 [AGENTS.md](AGENTS.md)。

## Layout

```text
.
├── .chezmoiroot            # 指定 home/ 为源目录
├── Brewfile                # 共享 Homebrew 依赖
├── home/                   # chezmoi 源状态
│   ├── .chezmoi.toml.tmpl  # 本机身份初始化
│   ├── .chezmoiignore      # 部署排除项
│   ├── .chezmoiscripts/    # chezmoi 生命周期适配脚本
│   ├── Library/            # macOS 应用配置
│   ├── dot_config/git/     # 共享 Git 配置
│   ├── dot_zprofile.tmpl   # 登录环境
│   └── dot_zshrc           # 交互式 shell
├── scripts/                # 安装和仓库开发脚本
│   ├── dev/                # 仓库开发辅助脚本
│   └── install/            # 本机安装
│       ├── install.sh      # 安装入口
│       └── lib/            # 安装及初始化函数
├── tests/                  # 行为测试及辅助文件
└── .github/workflows/      # CI 检查
```

chezmoi 文件名属性决定部署路径，例如 `home/dot_zshrc` 对应 `~/.zshrc`。仓库文档、开发工具和 `scripts/` 位于部署源目录之外。

## Development

### Requirements

| 工具    | 版本                                       |
| ------- | ------------------------------------------ |
| Node.js | `>=22.22.1`（CI 使用 22）                  |
| pnpm    | 以 `package.json` 的 `packageManager` 为准 |
| chezmoi | 已使用 `2.72.1` 验证                       |
| Zsh     | 已使用 `5.9` 验证                          |

在仓库根目录安装开发依赖：

```sh
pnpm install --frozen-lockfile
```

### Checks

| 命令              | 用途                             |
| ----------------- | -------------------------------- |
| `pnpm check`      | 运行 lint、格式检查和集成测试    |
| `pnpm ci:test`    | 通过 act 顺序运行 Linux CI 任务  |
| `pnpm test`       | 运行离线集成测试                 |
| `pnpm format`     | 格式化仓库文件                   |
| `pnpm test:e2e`   | 使用已安装的真实依赖运行离线 E2E |
| `pnpm test:setup` | 在全新 Ubuntu 容器中验证首次安装 |

CI 的 `check` 在 Ubuntu 上运行，`test-e2e` 和 `test-setup` 覆盖 macOS 与 Ubuntu。首次安装测试使用全新 Ubuntu 容器或可销毁的 GitHub macOS runner。

### Tests

测试使用通过 pnpm 安装的 [Bats](https://bats-core.readthedocs.io/)。目录组织和运行前置条件见 [tests/README.md](tests/README.md)。默认运行集成测试，E2E 和联网安装测试单独执行。

## Conventions

### Configuration

- chezmoi 管理配置，包管理器管理软件。
- 优先使用共享配置；必要的机器差异使用模板和 chezmoi 内置数据处理。

### Shell

- 入口显式调用函数，加载库文件不触发安装。
- 安装逻辑保持幂等，与 shell 启动分离。
- 通过 `run_before_` 适配脚本在每次应用时调用外部脚本；安装脚本不反向调用 `chezmoi apply`。
- 模板先渲染再检查；Zsh 文件使用 `zsh -n` 检查，并排除在面向 Bash 的格式化工具之外。
- `.zshrc` 基于上游 Oh My Zsh 模板，保留结构和示例，共享配置追加在示例之后；本机专用配置放在 `.zshrc.local`。

### Testing

- 准备、执行、断言之间空行分隔；对不直观的 fixture 行为和隔离方式添加说明。
- 检查退出状态、输出和结果文件，避免依赖实现细节。第三方工具仅验证安装、配置集成、基本执行和重复应用后的保留行为。
- 使用仓库副本，隔离 HOME、配置、缓存和状态路径，不修改真实工作区和用户环境。
- 默认测试离线运行且不依赖顺序，必要时在外部边界使用受控替身。
- 用 CI 矩阵覆盖平台，用 Bats 标签区分执行条件；E2E 不纳入 `pnpm test`，失败必须返回非零状态。

### Changes

- 分支使用 `<issue>-<type>-<summary>`。
- 不向默认分支直接提交或推送，通过 pull request 合并。
- 提交信息使用英文 Conventional Commits：`<type>: <summary>`。
- pull request 保持聚焦，请求 review 前运行 `pnpm check`。

### Documentation

- [README.md](README.md)：本仓库的安装、更新、应用配置、本机定制及其对本机环境的影响。
- [CONTRIBUTING.md](CONTRIBUTING.md)：维护者与 AI 共用的仓库结构、开发环境、检查命令和维护约定。
- [tests/README.md](tests/README.md)：测试套件、运行条件和隔离细节。
- [AGENTS.md](AGENTS.md)：AI 专用的工作区、权限和交付约束；共用的维护规则放在本文件。
- 使用英文标题、中文正文；行为、安装或工作流变化时，同步相关文档。

### Sensitive information

- 凭据、私钥和令牌不进入版本控制。
- 示例中使用占位值。
