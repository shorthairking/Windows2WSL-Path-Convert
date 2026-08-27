---
name: installer-and-autostart
description: "Use when: 实现 wpc 安装脚本、卸载脚本、将 hook 注入 bashrc、发行版启动时自动启用服务状态、~/.local/bin 部署、systemd user 服务"
---

# Skill：安装器与开机自启

## 目标

实现 `install.sh` / `uninstall.sh`：把 wpc 部署到用户环境，使发行版启动后每个交互式 shell 自动进入「服务状态」（即 hook 自动生效）。

## 技术要点（遵循方案文档「安装与自启动」章节）

1. **部署位置**：`~/.local/bin/wpc`（用户级，无需 sudo）；hook 文件部署到 `~/.local/share/wpc/wpc.bash`。
2. **注入方式**：向 `~/.bashrc` 追加带标记的加载块：
   ```bash
   # >>> WPC-HOOK-BEGIN >>>
   [ -n "$WPC_DISABLE" ] || . "$HOME/.local/share/wpc/wpc.bash"
   # <<< WPC-HOOK-END <<<
   ```
   仅在标记块不存在时追加；重复安装必须幂等。
3. **服务状态解读**（方案已确认）：bash 场景下「自动启动进入服务状态」= 每次交互式 shell 启动时 hook 自动激活，无需守护进程。
4. **可选 systemd user 服务**：`wpc-daemon.service`（`systemctl --user`）作为「工具服务化」的体现与后续扩展点（本阶段实现服务单元文件与 enable 逻辑，服务体暂为占位 no-op 或版本报告，不承载转换逻辑）。仅当 systemd 可用时启用，不可用时静默跳过并提示。
5. **卸载**：`uninstall.sh` 删除二进制、hook 文件、bashrc 标记块、systemd 单元，全部可逆。
6. **配置骨架**：生成 `~/.config/wpc/config.toml`（默认注释全量），引擎读取挂载点前缀等（与引擎 skill 的 config 模块对应）。

## 步骤

1. 阅读方案文档「安装与自启动」章节。
2. 编写 `install.sh`、`uninstall.sh`（set -eu、幂等、中文输出）。
3. 编写 `deploy/wpc-daemon.service` 模板与安装逻辑。
4. 手动冒烟检查（见清单；不动用户真实 `~/.bashrc`，检查时用 `BASH_ENV`/临时 HOME 验证）。
5. git commit，message 形如：`feat(install): 完成安装/卸载脚本与开机自启`。

## 手动冒烟检查清单

- [ ] 在临时 HOME（如 `HOME=$(mktemp -d)`）中执行 `install.sh`，二进制、hook、bashrc 标记块、配置文件骨架均正确落位
- [ ] 临时 HOME 中新开 `bash -i`，hook 自动激活（`type wpc_hook` 或标志变量可查）
- [ ] 连续执行两次 `install.sh` 无重复注入、无报错
- [ ] `uninstall.sh` 后所有落位文件与 bashrc 标记块被移除，新 shell 无 hook
- [ ] `WPC_DISABLE=1` 环境下 install/uninstall 本身不受 hook 干扰
- [ ] systemd 可用时 `systemctl --user status wpc-daemon` 正常；不可用时脚本给出提示而非失败

## 输出

- 脚本清单、逐条冒烟结果、commit 哈希。
