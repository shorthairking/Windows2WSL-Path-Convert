# wpc —— WSL 路径自动转换工具

Windows Path Converter：在 WSL 中无感知地将 Windows 路径自动转换为 WSL 路径。

```bash
# 用户输入
some_command C:\Users\username\Documents\file.txt
# 实际执行
some_command /mnt/c/Users/username/Documents/file.txt
```

整个过程中没有工具显式调用或提示（除非遇到错误），用户无需手动转换路径。

## 特性

- **无感转换**：交互式 bash 中，含 Windows 盘符路径的命令在**执行前**被静默替换为 WSL 路径。
- **零开销快速路径**：普通命令（无路径特征）不 fork 任何外部进程，完全无感。
- **显式 CLI**：脚本/管道场景可用 `wpc` 命令显式转换。
- **用户级安装**：部署到 `~/.local`，无需 sudo，卸载可逆。
- **零依赖单二进制**：Rust 实现，`target/release/wpc` 约 325 KB。

## 环境要求

wpc 是 WSL 专用工具，安装/运行前请确认以下依赖（`install.sh` 会在部署前自动检查并提示）：

| 依赖 | 版本 | 用途 | 安装方式 |
|------|------|------|----------|
| WSL（Ubuntu） | 发行版名不限 | 运行平台 | 已随 Windows 启用 |
| bash | ≥ 5.x | hook 运行环境 | Ubuntu 自带 |
| Rust 工具链（`cargo`/`rustc`） | ≥ 1.96（仅从源码构建时需要） | 构建 release 二进制 | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` 或 `sudo apt install cargo` |
| `wslpath` | WSL 自带 | 路径转换参考/回退 | 通常无需安装 |
| 标准工具 `install`/`grep`/`sed`/`mkdir`/`rm` | Ubuntu 自带 | 安装脚本 | 无需额外安装 |

> 说明：若直接使用已构建好的 `target/release/wpc` 发布二进制，则无需 Rust 工具链。

## 安装

```bash
./install.sh
source ~/.bashrc   # 或重新打开终端
```

安装内容：

| 文件 | 说明 |
|------|------|
| `~/.local/bin/wpc` | 核心转换二进制 |
| `~/.local/share/wpc/wpc.bash` | bash DEBUG trap hook |
| `~/.config/wpc/config.toml` | 配置文件骨架 |
| `~/.bashrc` 标记块 | 交互 shell 启动时自动加载 hook |
| `~/.config/systemd/user/wpc-daemon.service` | 可选占位服务（systemd 可用时） |

> 「服务状态」：bash 场景下每次交互式 shell 启动时 hook 自动激活；systemd user 占位服务作为服务化体现与扩展点。

## 卸载

```bash
./uninstall.sh
```

将删除二进制、hook、bashrc 标记块与 systemd 单元；用户配置 `~/.config/wpc/config.toml` 会保留（可手动删除）。

## 使用说明

### 无感转换（交互式 bash）

```bash
cat C:\Users\x\a.txt            # 执行 cat /mnt/c/Users/x/a.txt
ls "C:\Program Files\Foo"       # 引号内空格路径正确转换
diff C:\a.txt /home/u/b.txt     # 混合参数仅转换 Windows 部分
cat C:/Users/x/a.txt            # 正斜杠风格同样支持
```

环境变量开关：

| 变量 | 作用 |
|------|------|
| `WPC_DISABLE=1` | 临时完全禁用转换（前缀形式或 export 均可） |
| `WPC_FALLBACK=raw` | 遇到无法转换的 UNC 路径时原样执行而非阻止 |

### 显式 CLI

```bash
wpc 'C:\Users\x\a.txt'          # 逐参数转换，输出 /mnt/c/Users/x/a.txt
wpc 'C:\a.txt' /home/u/b.txt    # 非路径参数原样输出
printf 'C:\\a.txt\n' | wpc --stdin   # 逐行整体替换
wpc --version
```

退出码：`0` 成功（含无匹配）；`1` 存在无法转换的 UNC 路径；`2` 用法错误。

## 配置

`~/.config/wpc/config.toml`：

```toml
# 挂载根目录：Windows 盘符映射到 WSL 的根（默认 /mnt/）
# mount_root = "/mnt/"
```

挂载根解析优先级：

1. `/etc/wsl.conf` 的 `[automount] root`
2. `~/.config/wpc/config.toml` 的 `mount_root`
3. 默认 `/mnt/`

## 已知限制

- **仅交互式 bash**：脚本内部直接写 Windows 路径不会自动转换（可用 `wpc` CLI 显式转换）。
- **UNC 路径不支持**：`\\server\share\...` 无法映射到 WSL 路径，将提示错误并阻止执行（`WPC_FALLBACK=raw` 可逃生）。
- **相对盘符路径不转换**：如 `C:foo`（无分隔符）。
- **zsh/fish 不支持**：留待后续阶段。

## 文档

- 开发方案：[`docs/development-plan.md`](docs/development-plan.md)
- 架构说明：[`docs/architecture.md`](docs/architecture.md)
- 冒烟与验收记录：[`docs/smoke-checklist.md`](docs/smoke-checklist.md)
- 项目约定：[`AGENTS.md`](AGENTS.md)

