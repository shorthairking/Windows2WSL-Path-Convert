---
name: bash-preexec-integration
description: "Use when: 实现 wpc 的 bash 集成、preexec hook、DEBUG trap 命令拦截、无感路径替换、bashrc 注入片段、命令执行前静默转换"
---

# Skill：bash preexec 无感集成

## 目标

实现「用户输入 Windows 路径 → 命令执行前静默替换为 WSL 路径 → 执行」的核心体验。纯 bash 实现，不依赖第三方库。

## 技术要点（必须遵循方案文档「Shell 集成层」章节）

1. bash 无原生 preexec，用 **DEBUG trap** 实现：
   - 每次提示符前 trap 触发时，取 `$BASH_COMMAND`（即即将执行的命令行原文）。
   - 该值只在交互式 shell 可用；非交互（脚本）场景跳过。
2. **零开销快速路径**（关键性能要求）：
   - 先用 bash 内建模式匹配快速判断文本是否含候选特征（如 `[A-Za-z]:[\\/]` 或行内 `\\\\`）；
   - 无候选特征时直接放行，**不 fork 任何外部进程**。
3. 有候选特征时调用 `wpc --eval-line "$BASH_COMMAND"` 获得替换后的命令行：
   - 退出码 0：将返回值替换为 `READLINE_LINE` 或经 `eval` 执行？→ **禁止 eval 拼接**；本方案采用：将转换后的命令行写入内部变量并在 trap 中 `history -s` + 以该文本通过内建机制执行（见方案「执行替换策略」：使用 `eval` 的替代做法是仅在 DEBUG trap 里改写当前命令——若实现上有歧义，先实现「拦截 + 执行转换后文本」并确保 `set -x` 下可见）。
   - 退出码 1（UNC 等错误）：打印一行中文提示到 stderr，并**阻止执行**（除非环境变量 `WPC_FALLBACK=raw` 设为 1，则原样执行）。
4. **状态控制**：
   - 环境变量 `WPC_DISABLE=1` 临时关闭拦截（防递归：hook 内部命令必须设置该变量）。
   - hook 调用的 `wpc` 自身不得再次进入转换流程。
5. **历史与显示**：用户可见的历史记录与命令行回显保持用户输入原文（转换发生在执行层）。
6. 防递归与防重入：trap 内执行命令前必须保证不会再次触发 DEBUG trap（用全局标志位）。

## 步骤

1. 阅读方案文档「Shell 集成层」与「执行替换策略」章节，确认实现细节。
2. 在仓库中新建 `shell/wpc.bash`（hook 主体，带 `# WPC-HOOK-BEGIN / # WPC-HOOK-END` 标记，可被安装器注入 bashrc）。
3. 实现 DEBUG trap、快速路径、`wpc --eval-line` 调用、错误提示、`WPC_DISABLE`/`WPC_FALLBACK` 开关。
4. 手动冒烟检查（不做自动化测试），见下方清单。
5. git commit，message 形如：`feat(shell): 实现 bash preexec 无感路径转换 hook`。

## 手动冒烟检查清单

- [ ] `source shell/wpc.bash` 后输入 `cat C:\Users\x\a.txt`（构造一个真实存在的 /mnt/c 路径），命令被无感替换执行且终端无多余输出
- [ ] 输入不含 Windows 路径的普通命令（如 `ls`、`echo hello`），行为与未启用时完全一致，且无额外进程开销（可用 `set -x` 观察）
- [ ] `WPC_DISABLE=1 cat C:\a.txt` 时 hook 不介入
- [ ] 输入 UNC 路径命令时收到中文错误提示且命令未执行
- [ ] 带引号的含空格路径可正确转换
- [ ] hook 内部命令（如历史记录写入）不触发递归转换

## 输出

- 文件清单、逐条冒烟结果、性能观察结论、commit 哈希。
