---
name: path-conversion-engine
description: "Use when: 实现 wpc 核心路径转换引擎、Windows 路径检测、盘符路径与 UNC 路径识别、/mnt 挂载点解析、转义处理、wpc CLI 转换命令"
---

# Skill：核心路径转换引擎

## 目标

实现 wpc 的核心能力：从文本中识别 Windows 路径并转换为 WSL 路径。本 skill 是项目的核心，实现于 `src/engine/`。

## 规范（必须严格按方案 `docs/development-plan.md` 的「路径转换规则」实现）

### 检测规则（detect.rs）

1. **盘符绝对路径**：`[A-Za-z]:[\\/]` 开头（如 `C:\Users\x\a.txt`、`c:/foo/bar`）。
2. **UNC 路径**：`\\server\share\...` 开头，识别后标记为「无法转换」，返回错误类别 `UnsupportedUnc`。
3. **上下文感知**：仅在「看起来是路径」的位置转换，避免误伤 `git diff` 输出、正则等场景中形似路径的文本。至少实现：
   - 行首或空白后（命令/参数起始位置）；
   - 引号内（`"..."` 或 `'...'`）紧跟空白或行尾。
4. 已含 `:` 的合法 WSL 文本（如 `C:` 后无路径分隔符、URL `http://`、环境变量引用 `${VAR}`）不得误转换。

### 转换规则（convert.rs）

1. 盘符字母转小写；`\` 全部替换为 `/`；连续重复分隔符归一为一个。
2. 盘符 `X:` 映射为 `/mnt/x`（挂载点前缀从 `/etc/wsl.conf` 的 `[automount] root` 读取，默认 `/mnt/`；配置文件不存在时用默认值）。
3. 保留路径中的合法 WSL 字符；Windows 路径中的非法字符（如 `<>:"|?*` 中的未在引号规则下处理的）按原样透传（交由 shell 报错），引擎不自行报错。
4. 输出保持原文本中的引号风格：原文用双引号则结果用双引号包裹，无引号则输出未引号形式。
5. UNC 路径转换失败时，返回错误类别 `UnsupportedUnc`，供上层决定提示或阻止。

### CLI 接口（main.rs / hook.rs）

- `wpc <路径...>`：逐参数转换并输出（每个参数一行）；无 Windows 路径的参数原样输出。
- `wpc --stdin`：从 stdin 读入多行文本，逐行输出转换结果。
- `wpc --eval-line <原始命令行>`：接收一条完整的原始命令行文本，整体检测并替换其中的 Windows 路径，输出替换后的命令行（供 preexec hook 使用）；无匹配时原样输出该行。
- 退出码约定：`0` = 成功（含无匹配）；`1` = 存在无法转换的 UNC 路径；`2` = 参数/用法错误。

## 步骤

1. 阅读方案文档中的「路径转换规则」与「架构设计」章节。
2. 实现 `src/engine/detect.rs`（检测）与 `src/engine/convert.rs`（转换），单元逻辑独立于 I/O。
3. 实现 CLI 各子命令，接线到 `src/main.rs`。
4. 用 `docs/development-plan.md`「验收清单」中的全部示例命令逐一手动执行验证（不做自动化测试）。
5. 处理 `wslpath` 对照：以 `wslpath -u 'C:\...'` 的输出作为参考（注意 wslpath 不支持 UNC，行为应一致）。
6. git commit，message 形如：`feat(engine): 完成核心路径检测与转换引擎`。

## 边界情况检查表（手动逐一验证）

- 带空格的路径参数（以引号包裹传入）
- 大小写盘符（`C:\` 与 `c:\`）
- 正斜杠风格（`C:/Users/x`）
- 混合 Windows 与 WSL 参数（`cat C:\a.txt /home/u/b.txt`）
- 非路径场景不误伤：`echo C:`, `grep -E 'C:\\foo' ...`（转义后的反斜杠）
- UNC：`\\server\share\f` → 输出错误类别，退出码 1

## 输出

- 实现文件清单、逐条冒烟检查结果、commit 哈希。
