# 开发环境实测信息

> 采集日期：2026-08-27。所有数据来自开发机实测，供各开发代理参考。

## 系统环境

| 项目 | 实测值 | 备注 |
|------|--------|------|
| 内核 | `Linux 6.6.87.2-microsoft-standard-WSL2`（x86_64） | WSL2 |
| 发行版 | Ubuntu 24.04.4 LTS（Noble） | ⚠️ 与 require.md 所写 22.04 不一致 |
| 发行版标识 | `WSL_DISTRO_NAME=Ubuntu-22.04` | 发行版名仍为 Ubuntu-22.04，用户态已升级为 24.04 |
| 默认 Shell | `/bin/bash`（GNU bash 5.2.21） | 仅支持 bash 的场景假设成立 |
| 用户 | `shorthair`（家目录 `/home/shorthair`） | |
| 是否 WSL 互操作 | 已启用（`/run/WSL/1677_interop` 存在） | |

## 开发工具链

| 工具 | 版本 | 路径 |
|------|------|------|
| git | 2.43.0 | 系统 |
| Rust（rustc/cargo） | rustc 1.96.0 | 系统 |
| Python 3 | 3.13.9 | `/home/shorthair/miniconda3/bin/python3`（conda base 环境） |
| gcc | 13.3.0 | 系统 |
| GNU Make | 4.3 | 系统 |
| Node.js | 未安装 | — |
| Go | 未安装 | — |

## WSL 路径转换相关能力

| 项目 | 实测值 | 说明 |
|------|--------|------|
| `wslpath` | `/usr/bin/wslpath` 可用 | 可作转换参考实现与回退 |
| `wslpath -w ~` 实测输出 | `\\wsl.localhost\Ubuntu-22.04\home\shorthair` | 反向转换正常 |
| `/mnt/c` | 存在 | 默认挂载点正常，Windows C 盘已挂载 |
| `/etc/wsl.conf` | 待开发阶段读取 | 引擎需支持自定义 automount root |

## 已有文件

- `~/.bashrc`、`~/.profile` 均存在（bash 标准启动链完整，可注入 hook）。
- 当前仓库：仅 `require.md` 与刚创建的 `AGENTS.md`、`.github/` 工作区。

## 环境结论（写入方案的依据）

1. 发行版名与实际用户态版本不一致，方案按「WSL Ubuntu，bash 5.2」表述，避免依赖 22.04/24.04 特有行为。
2. Rust 工具链完备且无外部 crate 需求 → 核心引擎选 Rust，零依赖单二进制。
3. `wslpath` 与 `/mnt/c` 均可用 → 转换规则有权威参考。
4. 未安装 Node/Go → 方案不采用 JS/Go 实现。
