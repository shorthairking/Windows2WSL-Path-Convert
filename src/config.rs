//! 配置读取：挂载根目录
//!
//! 读取顺序（方案 §5.2）：
//! 1. `/etc/wsl.conf` 的 `[automount] root`（若存在且合法）
//! 2. `~/.config/wpc/config.toml` 的 `mount_root`（若存在）
//! 3. 默认 `/mnt/`
//!
//! 本文件为占位骨架，由 `path-conversion-engine` skill 填充实现。

/// 默认挂载根目录
pub const DEFAULT_MOUNT_ROOT: &str = "/mnt/";

/// 获取当前生效的挂载根目录。
///
/// 占位实现：返回默认值，由后续 skill 填充。
#[allow(dead_code)]
pub fn mount_root() -> String {
    DEFAULT_MOUNT_ROOT.to_string()
}
