//! 供 shell hook 调用的快速入口（`wpc --eval-line <原始命令行>`）
//!
//! 职责：对整条原始命令行做整体替换（方案 §6），输出转换后的命令行。

use crate::engine::convert;
use crate::engine::detect::{self, PathKind};

/// `--eval-line` 的处理结果
pub struct EvalResult {
    /// 替换后的命令行文本（UNC 未转换，原样保留）
    pub text: String,
    /// 是否包含无法转换的 UNC 路径（对应退出码 1）
    pub has_unc: bool,
}

/// 整体替换原始命令行中的 Windows 路径。
///
/// 仅替换被检测规则（§5.1）识别为路径的子串，其余文本逐字保留（方案 §6 执行安全）。
pub fn eval_line(raw_line: &str, mount_root: &str) -> EvalResult {
    let matches = detect::scan_line(raw_line);
    if matches.is_empty() {
        return EvalResult {
            text: raw_line.to_string(),
            has_unc: false,
        };
    }

    let mut text = String::with_capacity(raw_line.len() + 16);
    let mut last = 0usize;
    let mut has_unc = false;

    for m in matches {
        text.push_str(&raw_line[last..m.start]);
        match m.kind {
            PathKind::DriveAbsolute => {
                text.push_str(&convert::convert_path(&raw_line[m.start..m.end], mount_root));
            }
            PathKind::Unc => {
                has_unc = true;
                text.push_str(&raw_line[m.start..m.end]);
            }
            PathKind::None => {
                text.push_str(&raw_line[m.start..m.end]);
            }
        }
        last = m.end;
    }
    text.push_str(&raw_line[last..]);
    EvalResult { text, has_unc }
}
