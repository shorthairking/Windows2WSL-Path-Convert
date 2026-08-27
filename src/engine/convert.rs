//! 转换引擎：盘符/分隔符/挂载点映射
//!
//! 转换规则（方案 §5.2）：
//! - 盘符字母转小写；`\` → `/`；连续分隔符归一
//! - `X:` → `<root>/x`，其中 `<root>` 默认 `/mnt/`（可配置）
//! - 引号风格保持原文
//!
//! 本文件为占位骨架，由 `path-conversion-engine` skill 填充实现。

/// 将盘符绝对路径转换为 WSL 路径。
///
/// 占位实现：返回空字符串，由后续 skill 填充。
#[allow(dead_code)]
pub fn convert_path(_windows_path: &str, _mount_root: &str) -> String {
    String::new()
}
