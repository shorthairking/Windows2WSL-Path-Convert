# AGENTS.md — WSL 路径转换工具（wpc）项目约定

## 项目背景

在 WSL（Ubuntu）中开发一个路径自动转换工具 `wpc`（Windows Path Converter）：
用户输入 Windows 路径时，在命令执行前静默转换为 WSL 路径（如 `C:\Users\x\a.txt` → `/mnt/c/Users/x/a.txt`）。

需求原文见 `require.md`，开发方案见 `docs/development-plan.md`。

## 对智能体的强制要求

1. **按 skill 执行**：开发任务已按 TODO 拆分为 `.github/skills/<name>/SKILL.md`，每个 skill 是一个完整 TODO。
   执行开发任务前，必须先读取对应 `SKILL.md` 并严格按其步骤执行。
2. **逐步提交**：每完成一个 skill（或方案中约定的一个里程碑步骤）后，立即执行一次
   `git commit`，commit message 使用中文并注明完成的内容，格式如 `feat(engine): 完成核心路径转换引擎`。
3. **测试（阶段二，已获授权）**：阶段一已完结。编写/运行测试必须遵守
   `docs/test-plan.md` 的隔离三原则：
   - 子进程隔离：统一入口 `bash tests/run_all.sh`，脚本内任何 `export`/`cd`/`source` 只影响子进程；
   - 临时内容限制在仓库内 `target/test-tmp/`，测试结束自动清理；
   - 禁止影响全局变量或终端环境（含不修改真实 `~/.bashrc`/`~/.local/`，不在父终端 `source shell/wpc.bash`）。
   单测入口：`cargo test`（`src/**/*.rs` 内 `#[cfg(test)]`）。
   测试须对**实际路径**断言（真实 `/mnt/c` 路径 + `wslpath` 对照），素材缺失时明确 SKIP 而非伪造通过。
4. **外部依赖登记**：开发中如需引入外部依赖（crate、系统包、工具），必须：
   - 先在本文件「外部依赖清单」中登记（名称、用途、版本、来源）；
   - 并在对应 commit message 中注明。
   禁止引入未登记的依赖。
5. **语言规范**：代码注释、commit message、文档一律使用中文（除代码标识符外）。

## 外部依赖清单

| 依赖 | 用途 | 版本/来源 | 状态 |
|------|------|-----------|------|
| Rust 工具链（rustc/cargo） | 编译核心引擎 | rustc 1.96.0（已安装） | 已确认 |
| wslpath | 路径转换参考实现与回退 | /usr/bin/wslpath（WSL 内置） | 已确认 |
| （待补充） | | | |

## 目录结构约定

```
path_convert/
├── require.md                    # 需求文档
├── AGENTS.md                     # 本文件：项目约定
├── docs/
│   ├── environment.md            # 开发环境实测信息
│   ├── development-plan.md       # 软件开发方案（除测试）
│   ├── architecture.md          # 架构说明
│   ├── test-plan.md              # 测试计划与隔离三原则
│   └── smoke-checklist.md        # 阶段一冒烟与验收记录
├── tests/                        # 测试脚本（隔离运行）
│   ├── run_all.sh                # 统一入口 + 环境快照校验
│   ├── engine_cli_test.sh        # 引擎/CLI 真实路径测试
│   ├── hook_integration_test.sh  # hook 端到端（script+pty）
│   └── installer_test.sh         # 安装/卸载/幂等
├── .github/
│   ├── agents/                   # 代理工作区
│   │   └── path-convert-developer.agent.md
│   └── skills/                   # 每个 TODO 一个完整 skill
│       ├── scaffold-rust-project/SKILL.md
│       ├── path-conversion-engine/SKILL.md
│       ├── bash-preexec-integration/SKILL.md
│       ├── installer-and-autostart/SKILL.md
│       └── project-documentation/SKILL.md
└── src/                          # 源码（由 scaffold skill 创建）
```

## 关键约束

- 目标环境：WSL Ubuntu（发行版名 `Ubuntu-22.04`，实测用户态 24.04），bash 5.2.21。
- 默认 Shell 只支持 bash（zsh/fish 留待后续阶段）。
- 转换引擎必须零依赖或最小依赖，hook 热路径不允许 fork 外部进程。
