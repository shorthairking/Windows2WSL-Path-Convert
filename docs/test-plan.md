# wpc 测试计划（阶段二 · 测试准备）

> 版本：v1.0　日期：2026-08-27
> 说明：本计划为 wpc 测试阶段的基础设施与执行约束。核心要求——
> **对实际的路径测试**、**影响范围限制在当前仓库文件夹内**、**禁止影响全局变量或终端环境**（如必须影响则测试后消除）。

## 1. 测试目标

1. 引擎/CLI 转换逻辑的正确性（真实路径格式 + 真实文件系统存在性）。
2. bash hook 无感转换的端到端行为（真实交互 shell 中验证）。
3. 安装/卸载脚本的落位、幂等与可逆性。
4. **隔离性**：任何测试都不污染仓库外的文件系统、全局变量或父终端环境。

## 2. 隔离三原则（强制）

| # | 原则 | 实现 |
|---|------|------|
| P1 | 子进程隔离 | 所有测试通过 `bash tests/run_all.sh` 在**子进程**中运行；脚本内任何 `export`/`cd`/`source` 只影响子进程树，父终端零影响 |
| P2 | 临时内容限制在仓库内 | 临时 HOME、输入/输出文件一律放 `target/test-tmp/<用例名>/`，测试结束由 `trap EXIT` 清理 |
| P3 | 环境变量零污染 | 测试内的 `HOME`/`PATH`/`WPC_*` 改动均在子进程内；`WPC_DISABLE`、`WPC_FALLBACK` 等只以命令前缀或子进程局部方式使用，绝不写入父 shell |

## 3. 禁止事项（测试脚本内）

- ❌ 不得修改真实 `~/.bashrc`、`~/.profile`、`~/.local/`、`~/.config/wpc/`。
- ❌ 不得在父终端执行 `source shell/wpc.bash`（会注入 DEBUG trap）。
- ❌ 不得对 `/etc/` 写入（含 `/etc/wsl.conf`）。
- ❌ 不得遗留临时文件在仓库外（`/tmp`、家目录等）；全部用 `target/test-tmp/`。
- ❌ 不得使用 `sudo`。

## 4. 真实路径素材（测试输入，动态探测）

测试对**实际路径**进行断言（转换结果须真实存在于文件系统），素材探测失败则明确报告 SKIP，不伪造通过。

| 素材 | 类型 | 断言方式 |
|------|------|----------|
| `/mnt/c/AMFTrace.log` | 文件 | `wpc 'C:\AMFTrace.log'` → `test -f` |
| `/mnt/c/Windows/System32` | 目录 | `wpc 'C:\Windows\System32'` → `test -d` |
| `/mnt/c/Program Files` | 含空格目录 | `wpc 'C:\Program Files'` → `test -d`（引号保留） |
| `/mnt/c/Windows` | 目录 | 与 `wslpath -u` 输出对照一致 |

真实性校验：转换结果 `$(wslpath -u 'C:\...')` 一致，且 `test -e` 通过。

## 5. 测试层结构

| 层 | 文件 | 内容 |
|----|------|------|
| 引擎单元 | `src/engine/{detect,convert}.rs` 内 `#[cfg(test)]` | 纯函数，真实路径**格式**断言（无 I/O） |
| 引擎/CLI | `tests/engine_cli_test.sh` | release 二进制 + 真实文件系统存在性断言 |
| hook 集成 | `tests/hook_integration_test.sh` | `script`+pty 真实交互，临时 HOME/PATH |
| 安装器 | `tests/installer_test.sh` | 临时 HOME（仓库内）安装/卸载/幂等 |
| 入口 | `tests/run_all.sh` | 统一入口 + 环境快照校验 |

## 6. 环境快照校验（证明零污染）

`run_all.sh` 在入口记录关键环境值，出口比对并输出结论：

- `$WPC_DISABLE`、`$WPC_FALLBACK`、`$DEBUG`（应为未设置）
- `trap -p DEBUG`（应无 wpc 相关）
- 当前工作目录
- 仓库外是否新增文件（`find "$HOME" -maxdepth 2 -newer marker` 抽样）

## 7. 影响消除机制

- 每个脚本 `trap 'cleanup' EXIT`：删除 `target/test-tmp/`。
- 子进程内对环境的任何改动随进程结束自动消除。
- 如未来某用例确需触碰外部状态，须在用例内显式备份并在 `EXIT` 恢复，并在本计划中登记。

## 8. 如何运行

```bash
bash tests/run_all.sh        # 全部（构建 release + 引擎单测 + 集成测试）
cargo test                   # 仅 Rust 单元测试（target/ 内，天然隔离）
```

## 9. 阶段二范围（承接 development-plan §10）

1. 引擎单元测试 ✅（本计划）
2. hook 集成测试 ✅（本计划）
3. 安装脚本测试 ✅（本计划）
4. CI 流水线、模糊测试、性能基准、zsh/fish —— 后续阶段
5. 真实 `~/.bashrc` 灰度安装 —— 明确**不在**本计划（涉及真实环境，留待用户显式授权）
