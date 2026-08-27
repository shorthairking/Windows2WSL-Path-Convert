//! 路径检测与转换引擎
//!
//! - `detect`：识别 Windows 路径（盘符绝对路径、UNC 路径）并施加上下文约束
//! - `convert`：盘符/分隔符/挂载点映射，产出 WSL 路径
//!
//! 本模块由 `path-conversion-engine` skill 填充实现。

pub mod convert;
pub mod detect;
