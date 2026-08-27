//! 转换引擎：盘符/分隔符/挂载点映射
//!
//! 转换规则（方案 §5.2）：
//! - 盘符字母转小写；`\` → `/`；连续分隔符归一为一个 `/`
//! - 盘符 `X:` → `<root>/x`，`<root>` 默认 `/mnt/`（可配置）
//! - 引号风格由调用方保持（本函数输入/输出均不含引号）

/// 将盘符绝对路径转换为 WSL 路径。
///
/// `windows_path` 不含引号，形如 `C:\Users\x\a.txt` 或 `c:/foo/bar`；
/// `mount_root` 形如 `/mnt/`。输出形如 `/mnt/c/Users/x/a.txt`。
pub fn convert_path(windows_path: &str, mount_root: &str) -> String {
    let b = windows_path.as_bytes();
    let drive = (b[0] as char).to_ascii_lowercase();
    let rest = &windows_path[2..];

    let mut out = String::with_capacity(windows_path.len() + 8);
    // 挂载根：去除尾部 `/` 后拼接
    out.push_str(mount_root.trim_end_matches('/'));
    out.push('/');
    out.push(drive);

    let mut prev_was_sep = false;
    for ch in rest.chars() {
        if ch == '\\' || ch == '/' {
            if !prev_was_sep {
                out.push('/');
                prev_was_sep = true;
            }
        } else {
            out.push(ch);
            prev_was_sep = false;
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn convert_basic() {
        assert_eq!(convert_path(r"C:\Users\x\a.txt", "/mnt/"), "/mnt/c/Users/x/a.txt");
    }

    #[test]
    fn convert_lowercase_forward() {
        assert_eq!(convert_path("c:/foo/bar", "/mnt/"), "/mnt/c/foo/bar");
    }

    #[test]
    fn convert_spaces_kept() {
        assert_eq!(convert_path(r"C:\Program Files\Foo", "/mnt/"), "/mnt/c/Program Files/Foo");
    }

    #[test]
    fn convert_normalize_separators() {
        assert_eq!(convert_path(r"C:\Users\\x\a.txt", "/mnt/"), "/mnt/c/Users/x/a.txt");
    }

    #[test]
    fn convert_custom_root() {
        assert_eq!(convert_path(r"C:\a.txt", "/opt/mnt/"), "/opt/mnt/c/a.txt");
    }
}
