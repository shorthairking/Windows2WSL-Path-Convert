//! 检测引擎：识别 Windows 路径并施加上下文约束
//!
//! 检测规则（方案 §5.1）：
//! - 盘符绝对路径：`[A-Za-z]:[\\/]` 开头，其后有至少一个非空白字符
//! - UNC 路径：`\\` 开头且后跟非 `\` 字符，标记为错误类别 `Unc`
//! - 上下文约束：候选串须位于行首、空白之后或引号之后
//! - 误伤防护：`C:` 无分隔符、URL scheme、`${VAR}` 内等不转换
//!
//! 本文件为占位骨架，由 `path-conversion-engine` skill 填充实现。

/// 识别出的路径类别
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(dead_code)] // 骨架阶段占位：变体由 path-conversion-engine skill 构造
pub enum PathKind {
    /// 盘符绝对路径，如 `C:\Users\x`
    DriveAbsolute,
    /// UNC 路径，如 `\\server\share`（无法转换，按错误处理）
    Unc,
    /// 非路径
    None,
}

/// 检测单个候选串是否为 Windows 路径。
///
/// 占位实现：一律返回 [`PathKind::None`]，由后续 skill 填充。
#[allow(dead_code)]
pub fn detect_path_kind(_candidate: &str) -> PathKind {
    PathKind::None
}
