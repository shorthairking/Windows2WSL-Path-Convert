# wpc 架构说明

> [English](architecture.md) | [简体中文](architecture.zh-CN.md)
>
> 阶段一实现。WSL（bash 5.2）中的 Windows 路径自动转换工具。

## 组件图

```
┌─────────────────────────────────────────────────────────────────┐
│                        用户交互层（bash）                         │
│                                                                 │
│  用户输入命令行 ──► DEBUG trap（wpc.bash）                        │
│                     │                                            │
│                     ├─ 快速路径（bash 内建模式，零 fork）          │
│                     │   无候选特征 ──► 直接执行（零开销）          │
│                     │   有候选特征 ──► 调用 wpc --eval-line       │
│                     │                                            │
│                     ├─ 退出码 0 ──► eval 执行转换后命令            │
│                     ├─ 退出码 1 ──► stderr 中文提示，阻止执行      │
│                     └─ 退出码 2 ──► 放行（不应发生，防御性）       │
└────────────────────────────┬────────────────────────────────────┘
                             │ fork（仅候选路径命令）
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   核心引擎（Rust 单二进制 wpc）                    │
│                                                                 │
│  CLI 入口 main.rs ──► hook.rs（--eval-line 整体替换）             │
│                    │                                             │
│                    ├─► engine/detect.rs  检测（盘符/UNC/上下文）   │
│                    ├─► engine/convert.rs 转换（盘符→挂载点映射）   │
│                    └─► config.rs         挂载根（wsl.conf/配置）  │
└─────────────────────────────────────────────────────────────────┘
        ▲                                    ▲
        │ install.sh 部署                     │ 配置读取
        │                                    │
┌───────┴────────────┐          ┌────────────┴──────────────────┐
│  部署层             │          │  配置层                       │
│  ~/.local/bin/wpc  │          │  /etc/wsl.conf [automount]    │
│  ~/.local/share/   │          │  ~/.config/wpc/config.toml    │
│    wpc/wpc.bash    │          └───────────────────────────────┘
│  ~/.bashrc 标记块   │
│  systemd user 单元 │
└────────────────────┘
```

## 数据流（无感转换）

```
用户输入：  some_command C:\Users\x\a.txt
     │
     ▼
DEBUG trap 捕获 $BASH_COMMAND（交互 shell 原始文本）
     │
     ▼
快速路径：匹配 [A-Za-z]:[\\/] 或 \\ 特征？
     ├─ 否 ──► 直接执行原命令（零 fork，零输出）
     └─ 是 ──► wpc --eval-line "some_command C:\Users\x\a.txt"
                 │
                 ▼
      检测：C:\Users\x\a.txt → DriveAbsolute（盘符绝对路径）
      转换：C: → /mnt/c，\ → /，连续分隔符归一
                 │
                 ▼
      输出：some_command /mnt/c/Users/x/a.txt（退出码 0）
                 │
                 ▼
      hook：history -s 保留用户原文 → eval 执行转换后命令 → 跳过原命令
                 │
                 ▼
实际执行：some_command /mnt/c/Users/x/a.txt（用户无感知）
```

## 执行替换策略（hook 内部）

1. **捕获**：DEBUG trap 中读 `$BASH_COMMAND`。
   - **补全上下文防护**：TAB 补全期间 bash 会设置 `COMP_LINE`/`COMP_POINT`；hook 对补全函数内部命令（如 `[[ $cmd == \\* ]]`）不做转换，这些不是用户真实命令行。
2. **快速路径**：bash 内建模式预筛，无候选特征直接放行（不 fork）。
3. **替换**：`wpc --eval-line` 整体替换；退出码 0 → `history -s` 保留原文 + `eval` 执行转换后命令；退出码 1 → 中文提示并阻止执行（`WPC_FALLBACK=raw` 逃生）。
4. **执行安全**：替换仅作用于被识别为路径的子串，其余文本逐字保留，不引入新转义。
5. **防递归**：`__wpc_in_hook` 局部标志 + `WPC_DISABLE=1` 命令前缀，双保险。
6. **状态无泄漏**：handler 内全部使用局部变量，不污染外层 shell。

## 错误处理策略表

| 退出码 | 场景 | hook 行为 | CLI 行为 |
|--------|------|-----------|----------|
| 0 | 转换成功（含无匹配） | eval 执行转换后命令 | 正常输出 |
| 1 | 存在无法转换的 UNC 路径 | stderr 中文提示，阻止执行（`WPC_FALLBACK=raw` 可逃生） | 输出原文本，返回 1 |
| 2 | 参数/用法错误 | 不适用（hook 不产生） | stderr 用法提示，返回 2 |

## 配置解析

| 来源 | 键 | 说明 |
|------|-----|------|
| `/etc/wsl.conf` | `[automount] root` | 系统级挂载根（优先） |
| `~/.config/wpc/config.toml` | `mount_root` | 用户级覆盖（次优先） |
| 内置默认 | — | `/mnt/` |

## 安全设计

| 风险 | 对策 |
|------|------|
| hook 递归/死循环 | `__wpc_in_hook` + `WPC_DISABLE` 双保险 |
| 误转换 | 上下文约束（行首/空白后/引号后）+ 补全上下文防护（COMP_LINE/COMP_POINT）+ UNC 须后跟合法服务器名起始字符（非 `\`/空白/引号/通配符 `*?[`） |
| `wpc` 不可用 | hook 检测调用失败（127）时原样放行，不阻断用户 |
| 安装污染 | 全部用户级路径；bashrc 仅追加标记块；卸载可逆 |
| 中文/Unicode 路径 | Rust `String` 全程 UTF-8 处理 |
| VS Code 终端兼容 | 保存并链式调用调用方原有 DEBUG trap |
