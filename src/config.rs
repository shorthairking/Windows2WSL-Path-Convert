//! 配置读取：挂载根目录
//!
//! 读取顺序（方案 §5.2）：
//! 1. `/etc/wsl.conf` 的 `[automount] root`（若存在且合法）
//! 2. `~/.config/wpc/config.toml` 的 `mount_root`（若存在）
//! 3. 默认 `/mnt/`

use std::path::PathBuf;

/// 默认挂载根目录
pub const DEFAULT_MOUNT_ROOT: &str = "/mnt/";

/// 获取当前生效的挂载根目录（含尾部 `/`）。
pub fn mount_root() -> String {
    if let Some(root) = read_wsl_conf_root() {
        return root;
    }
    if let Some(root) = read_user_config_root() {
        return root;
    }
    DEFAULT_MOUNT_ROOT.to_string()
}

/// 从 `/etc/wsl.conf` 的 `[automount]` 段读取 `root`
fn read_wsl_conf_root() -> Option<String> {
    let content = std::fs::read_to_string("/etc/wsl.conf").ok()?;
    let mut in_automount = false;
    for raw in content.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') {
            let sec = line.trim_matches(|c| c == '[' || c == ']').trim();
            in_automount = sec.eq_ignore_ascii_case("automount");
            continue;
        }
        if in_automount {
            if let Some(eq) = line.find('=') {
                let key = line[..eq].trim();
                let value = line[eq + 1..].trim();
                if key.eq_ignore_ascii_case("root") && !value.is_empty() {
                    return Some(normalize_root(value));
                }
            }
        }
    }
    None
}

/// 从 `~/.config/wpc/config.toml` 读取 `mount_root`
fn read_user_config_root() -> Option<String> {
    let home = std::env::var("HOME").ok()?;
    let path = PathBuf::from(home).join(".config/wpc/config.toml");
    let content = std::fs::read_to_string(path).ok()?;
    for raw in content.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some(eq) = line.find('=') {
            let key = line[..eq].trim();
            let value = line[eq + 1..].trim();
            if key == "mount_root" {
                let value = value.trim_matches('"').trim_matches('\'');
                if !value.is_empty() {
                    return Some(normalize_root(value));
                }
            }
        }
    }
    None
}

/// 规范化挂载根：去除尾部 `/` 后补回一个，保证返回值以 `/` 结尾
fn normalize_root(root: &str) -> String {
    let r = root.trim().trim_end_matches('/');
    if r.is_empty() {
        return DEFAULT_MOUNT_ROOT.to_string();
    }
    format!("{}/", r)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_root_variants() {
        assert_eq!(normalize_root("/mnt/"), "/mnt/");
        assert_eq!(normalize_root("/mnt"), "/mnt/");
        assert_eq!(normalize_root(" /opt/ "), "/opt/");
        assert_eq!(normalize_root(""), "/mnt/");
    }
}
