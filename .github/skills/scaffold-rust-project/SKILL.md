---
name: scaffold-rust-project
description: "Use when: 初始化 wpc 的 Rust 项目脚手架、创建 Cargo 工程、搭建 src/ 目录结构与构建配置、cargo build 验证"
---

# Skill：初始化 Rust 项目脚手架

## 目标

创建 wpc 的 Rust 项目骨架：Cargo 工程、模块划分、构建配置，并验证可编译。

## 前置条件

- 已阅读 `AGENTS.md`、`docs/development-plan.md`、`docs/environment.md`
- Rust 工具链可用（rustc 1.96.0）

## 步骤

1. 在仓库根目录执行 `cargo init --name wpc --vcs none`（不得覆盖已存在的 git 仓库）。
2. 在 `Cargo.toml` 中设置：
   - `[package]` edition = "2021"（与已装工具链兼容）
   - `[profile.release]` 启用 `opt-level = 3`、`lto = true`、`strip = true`（单二进制、零开销要求）
   - 本阶段不引入任何外部 crate（核心引擎零依赖，见方案）。
3. 创建模块骨架（均为空实现或最小实现，留待后续 skill 填充）：
   - `src/main.rs`：CLI 入口，子命令框架（`wpc <路径...>`、`wpc --stdin`、`wpc --version`）
   - `src/engine/mod.rs`、`src/engine/detect.rs`、`src/engine/convert.rs`：检测与转换引擎模块
   - `src/config.rs`：配置读取（默认值内置，配置文件可选）
   - `src/hook.rs`：供 shell hook 调用的快速入口（`wpc --eval-line <原始命令行>`）
4. 创建 `README.md` 占位（标题、一句话简介、链接到方案文档）。
5. 执行 `cargo build` 与 `cargo build --release`，确保编译通过、无 warning（如出现 warning 需修复）。
6. 在 `AGENTS.md`「外部依赖清单」中登记本 skill 引入的依赖（预期：无）。
7. 执行 git commit，message 形如：`feat(scaffold): 初始化 Rust 项目脚手架与模块骨架`。

## 验收（手动冒烟检查，非测试）

- [ ] `cargo run -- --version` 输出 `wpc <版本号>` 且退出码为 0
- [ ] `cargo build --release` 成功，生成 `target/release/wpc`，体积 < 1 MB（零依赖单二进制）

## 输出

- 新增文件列表、`cargo build` 结果、commit 哈希。
