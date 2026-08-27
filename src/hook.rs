//! 供 shell hook 调用的快速入口（`wpc --eval-line <原始命令行>`）
//!
//! 职责：对整条原始命令行做整体替换（方案 §6），输出转换后的命令行。
//!
//! 本文件为占位骨架，由 `bash-preexec-integration` skill 填充实现。

/// 整体替换原始命令行，返回转换后的命令行文本。
///
/// 占位实现：原样返回，由后续 skill 填充。
pub fn eval_line(raw_line: &str) -> String {
    raw_line.to_string()
}
