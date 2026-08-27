# wpc 冒烟与验收记录

> 阶段一手动冒烟记录（按方案要求不做自动化测试）。
> 采集日期：2026-08-27

## 一、各 skill 冒烟结果

### 1. scaffold-rust-project

| 检查项 | 结果 |
|--------|------|
| `cargo run -- --version` 输出 `wpc 0.1.0` 且退出码 0 | ✅ |
| `cargo build --release` 成功，`target/release/wpc` 体积 < 1 MB | ✅（325 KB） |
| debug 与 release 均无 warning | ✅ |

### 2. path-conversion-engine

| 场景 | 输入 | 预期 | 实际 | 结果 |
|------|------|------|------|------|
| A1 逐参数盘符 | `wpc 'C:\Users\x\a.txt'` | `/mnt/c/Users/x/a.txt` | 同预期 | ✅ |
| A2 正斜杠小写 | `wpc 'c:/foo/bar'` | `/mnt/c/foo/bar` | 同预期 | ✅ |
| S7 显式调用 | `wpc 'C:\a.txt'` | `/mnt/c/a.txt` | 同预期 | ✅ |
| 非路径 | `wpc foo /home/u/b.txt` | 原样输出 | 同预期 | ✅ |
| 混合参数 | `wpc 'C:\a.txt' /home/u/b.txt` | 仅转换 Windows 部分 | 同预期 | ✅ |
| UNC | `wpc '\\server\share\f'` | 原样 + 退出码 1 | 同预期 | ✅ |
| S1 eval-line | `wpc --eval-line 'cat C:\Users\x\a.txt'` | `cat /mnt/c/Users/x/a.txt` | 同预期 | ✅ |
| S2/A4 引号空格 | `wpc --eval-line 'ls "C:\Program Files\Foo"'` | `ls "/mnt/c/Program Files/Foo"` | 同预期 | ✅ |
| S3/A5 混合 | `wpc --eval-line 'diff C:\a.txt /home/u/b.txt'` | 仅转换 Windows 部分 | 同预期 | ✅ |
| S4 正斜杠 | `wpc --eval-line 'cat C:/Users/x/a.txt'` | 转换 | 同预期 | ✅ |
| A6 UNC | `wpc --eval-line 'ls \\server\share\x'` | 原样 + 退出码 1 | 同预期 | ✅ |
| A7 误伤防护 | `echo C:` / URL / `${VAR}` | 均不转换 | 同预期 | ✅ |
| 边界 转义反斜杠 | `grep -E 'C:\\foo'`（单引号双反斜杠） | 不转换 | 同预期 | ✅ |
| 连续分隔符归一 | `wpc 'C:\Users\\x\a.txt'` | `/mnt/c/Users/x/a.txt` | 同预期 | ✅ |
| stdin | 多行管道 | 逐行整体替换 | 同预期 | ✅ |
| wslpath 对照 | `wslpath -u 'C:\Users\x\a.txt'` | `/mnt/c/Users/x/a.txt` 与 wpc 一致 | 一致 | ✅ |
| 挂载根配置 | 用户 config.toml `mount_root="/opt/mnt/"` | `/opt/mnt/c/a.txt` | 同预期 | ✅ |
| 用法错误 | `wpc --eval-line`（缺参） | 退出码 2 + 提示 | 同预期 | ✅ |

### 3. bash-preexec-integration

| 检查项 | 结果 |
|--------|------|
| 盘符路径无感转换（`echo C:\Users\x\a.txt` → `/mnt/c/Users/x/a.txt`） | ✅ |
| 普通命令无影响、无多余输出（`echo hello`） | ✅ |
| `WPC_DISABLE=1` 前缀禁用 | ✅ |
| UNC 中文提示 + 命令未执行 | ✅ |
| 带引号空格路径正确转换 | ✅ |
| hook 内部命令（history 写入）不触发递归 | ✅ |
| `WPC_FALLBACK=raw` 逃生（前缀与环境变量两种方式） | ✅ |
| 转换后 hook 状态无泄漏（连续多条命令均正常） | ✅ |
| 幂等重载（重复 source） | ✅ |
| 性能观察：`set -x` 确认快速路径纯 bash 内建模式匹配，零 fork | ✅ |

### 4. installer-and-autostart

| 检查项 | 结果 |
|--------|------|
| 临时 HOME 中 install：二进制/hook/bashrc 标记块/配置骨架落位 | ✅ |
| 临时 HOME 新 `bash -i` hook 自动激活（`type wpc_preexec` + 转换生效） | ✅ |
| 连续两次 install 幂等（bashrc 标记块仅 1 组） | ✅ |
| uninstall 后全部移除（二进制/hook/标记块/systemd 单元） | ✅ |
| `WPC_DISABLE=1` 环境 install/uninstall 不受干扰（退出码 0） | ✅ |
| systemd 不可用时提示而非失败 | ✅ |

## 二、阶段一验收清单核对（development-plan §9）

| # | 验收项 | 结果 |
|---|--------|------|
| A1 | `wpc 'C:\Users\x\a.txt'` → `/mnt/c/Users/x/a.txt` | ✅ |
| A2 | `wpc 'c:/foo/bar'` → `/mnt/c/foo/bar` | ✅ |
| A3 | 交互 shell `cat C:\AMFTrace.log`（真实 /mnt/c 文件）无感执行成功、无多余输出 | ✅ |
| A4 | `ls "C:\Program Files\..."` 引号内空格路径正确 | ✅ |
| A5 | 混合参数仅转换 Windows 部分 | ✅ |
| A6 | UNC → 中文提示 + 不执行 + 退出码 1 | ✅ |
| A7 | `echo C:`、URL、`${VAR}` 不误伤 | ✅ |
| A8 | 普通命令零输出、零额外进程（`set -x` 观察快速路径零 fork） | ✅ |
| A9 | `WPC_DISABLE=1` 完全禁用 | ✅ |
| A10 | 临时 HOME install → 新 `bash -i` 自动激活 → uninstall → 完全移除 | ✅ |
| A11 | 连续两次 install 幂等 | ✅ |
| A12 | `cargo build --release` 全绿无 warning，二进制 < 1 MB | ✅（325 KB） |
| A13 | systemd 可用时 `systemctl --user status wpc-daemon` 正常 | ⚠️ 见下 |

> **A13 说明**：本开发环境（VS Code 非用户会话）`systemctl --user` 实例不可用，
> install.sh 已优雅跳过并提示（不失败）；服务单元与 enable 逻辑已实现，
> 需在真实登录用户会话（systemd user 实例运行）中验证。

## 三、结论

阶段一全部功能开发与手动冒烟完成；A1–A12 全部通过，A13 受环境限制
（脚本已实现优雅降级）。遗留项：

- A13 在真实登录会话中验证 `systemctl --user status wpc-daemon`。
- 真实用户 `~/.bashrc` 灰度安装验证（方案 §10.6 明确留待后续阶段）。
