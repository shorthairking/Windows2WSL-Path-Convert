---
name: project-documentation
description: "Use when: 编写 wpc 的 README、使用说明、安装指南、配置说明、架构文档、常见问题、外部依赖清单核对"
---

# Skill：项目文档

## 目标

补齐 wpc 的用户文档与开发者文档，并做阶段一收尾核对。本 skill 是阶段一最后一个 TODO。

## 步骤

1. 编写完整 `README.md`，包含：
   - 项目简介与效果示例（`some_command C:\Users\...` → 实际执行 `/mnt/c/...`）
   - 安装方法（`./install.sh`）与卸载方法
   - 使用说明：显式 CLI 用法（`wpc`、`wpc --stdin`）、无感转换用法、环境变量开关（`WPC_DISABLE`、`WPC_FALLBACK`）
   - 配置说明：`~/.config/wpc/config.toml` 各选项
   - 已知限制：UNC 不支持、仅 bash、脚本场景不生效等
2. 编写 `docs/architecture.md`：
   - 组件图（文字版）：`wpc` 二进制 / `wpc.bash` hook / install.sh / systemd 单元
   - 数据流：用户输入 → DEBUG trap → 快速路径 → `wpc --eval-line` → 执行
   - 错误处理策略表（退出码 0/1/2 语义）
3. 核对 `AGENTS.md`「外部依赖清单」与实际引入依赖一致；不一致则补记。
4. 检查 `cargo build --release` 全绿、无 warning；所有 skill 的冒烟清单均有记录（在 `docs/smoke-checklist.md` 中汇总记录每条冒烟结果）。
5. 对照 `docs/development-plan.md` 的「阶段一验收清单」逐项核对并记录结果。
6. git commit，message 形如：`docs: 完成 README 与架构文档及阶段一验收核对`。

## 验收（手动冒烟检查，非测试）

- [ ] README 中的每个示例命令均能按文档所述复现
- [ ] `cargo build --release` 成功且无 warning
- [ ] 阶段一验收清单逐项通过

## 输出

- 文档文件清单、验收核对结果表、commit 哈希。
