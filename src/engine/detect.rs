//! 检测引擎：识别 Windows 路径并施加上下文约束
//!
//! 检测规则（方案 §5.1）：
//! - 盘符绝对路径：`[A-Za-z]:[\\/]` 开头，其后有至少一个非空白字符
//! - UNC 路径：`\\` 开头且后跟非 `\` 字符，标记为错误类别 [`PathKind::Unc`]
//! - 上下文约束：候选串须位于行首、空白之后或引号之后
//! - 误伤防护：`C:` 无分隔符、URL scheme、`${VAR}` 内、转义形态 `\\` 不转换
//!
//! [`PathKind::Unc`]: PathKind::Unc

/// 识别出的路径类别
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PathKind {
    /// 盘符绝对路径，如 `C:\Users\x`
    DriveAbsolute,
    /// UNC 路径，如 `\\server\share`（无法转换，按错误处理）
    Unc,
    /// 非路径
    None,
}

/// 路径在一行文本中的匹配结果（字节区间）
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Match {
    /// 路径类别
    pub kind: PathKind,
    /// 起始字节下标（含）
    pub start: usize,
    /// 结束字节下标（不含）
    pub end: usize,
}

/// 检测单个候选串（已去除引号，如 `wpc <路径...>` 的逐参数模式）。
///
/// 盘符路径返回 [`PathKind::DriveAbsolute`]；UNC 返回 [`PathKind::Unc`]；其余返回 [`PathKind::None`]。
pub fn detect_path_kind(candidate: &str) -> PathKind {
    let b = candidate.as_bytes();
    let n = b.len();

    // UNC：`\\` 开头且后跟合法的服务器名起始字符
    // （排除 `\\`/空白/引号/通配符，避免 `\\*`、`\\ `、行尾 `\\` 等转义/glob 形态误判）
    if n >= 3 && b[0] == b'\\' && b[1] == b'\\' && is_unc_host_start(b[2]) {
        return PathKind::Unc;
    }

    // 盘符绝对路径：`[A-Za-z]:[\\/]` 开头且其后有至少一个非空白字符
    if n >= 3 && is_alpha(b[0]) && b[1] == b':' && (b[2] == b'\\' || b[2] == b'/') {
        if candidate[2..].chars().any(|c| !c.is_whitespace()) {
            return PathKind::DriveAbsolute;
        }
    }

    PathKind::None
}

/// 扫描整行，找出所有位于「候选位置」的 Windows 路径。
///
/// 候选位置：行首、空白之后、或引号（`'`/`"`）之后紧跟的起始处。
/// 引号内（单引号或双引号）的路径同样被识别；裸文本中路径结束于空白或引号。
pub fn scan_line(line: &str) -> Vec<Match> {
    let b = line.as_bytes();
    let n = b.len();
    let mut matches: Vec<Match> = Vec::new();
    let mut i = 0usize;
    let mut in_single = false;
    let mut in_double = false;

    while i < n {
        let c = b[i];

        // 引号开关
        if c == b'\'' && !in_double {
            in_single = !in_single;
            i += 1;
            continue;
        }
        if c == b'"' && !in_single {
            in_double = !in_double;
            i += 1;
            continue;
        }
        // 双引号内反斜杠转义：跳过 `\` 及其后一个字符
        if in_double && c == b'\\' && i + 1 < n {
            i += 2;
            continue;
        }

        // 候选位置判定
        let is_candidate = i == 0
            || is_blank(b[i - 1])
            || (in_single && b[i - 1] == b'\'')
            || (in_double && b[i - 1] == b'"');
        if !is_candidate {
            i += 1;
            continue;
        }

        // 盘符绝对路径
        if is_alpha(c) && i + 1 < n && b[i + 1] == b':' && i + 2 < n
            && (b[i + 2] == b'\\' || b[i + 2] == b'/')
        {
            // 转义/正则形态（`X:\\`，双反斜杠）不转换
            let is_double_bs = b[i + 2] == b'\\' && i + 3 < n && b[i + 3] == b'\\';
            if is_double_bs {
                i += 3;
                continue;
            }
            let end = path_end(b, n, i + 2, in_single, in_double);
            if end > i + 2 {
                matches.push(Match { kind: PathKind::DriveAbsolute, start: i, end });
                i = end;
                continue;
            }
            i += 1;
            continue;
        }

        // UNC 路径：`\\` 后须跟合法的服务器名起始字符
        // （行尾 `\\`、空白/引号/通配符开头的 `\\*` 等转义与 glob 形态不视为 UNC）
        if c == b'\\' && i + 1 < n && b[i + 1] == b'\\' && i + 2 < n && is_unc_host_start(b[i + 2]) {
            let end = path_end(b, n, i + 2, in_single, in_double);
            matches.push(Match { kind: PathKind::Unc, start: i, end });
            i = end;
            continue;
        }

        i += 1;
    }
    matches
}

/// 计算路径子串的结束下标：引号内延伸到对应引号，裸文本延伸到空白或引号
fn path_end(b: &[u8], n: usize, start: usize, in_single: bool, in_double: bool) -> usize {
    let mut end = start;
    while end < n {
        let e = b[end];
        if in_single && e == b'\'' {
            break;
        }
        if in_double && e == b'"' {
            break;
        }
        if !in_single && !in_double && (is_blank(e) || e == b'\'' || e == b'"') {
            break;
        }
        end += 1;
    }
    end
}

/// 是否为空白字符（空格或制表符）
fn is_blank(c: u8) -> bool {
    c == b' ' || c == b'\t'
}

/// 是否为 ASCII 字母
fn is_alpha(c: u8) -> bool {
    c.is_ascii_alphabetic()
}

/// 是否为合法的 UNC 服务器名起始字符：
/// 排除 `\\`（`\\\\` 不构成路径）、空白、引号与通配符（`*?[`），
/// 避免把 shell 转义/glob 形态（如 `\\*`、`[[ $cmd == \\* ]]`）误判为 UNC 路径。
fn is_unc_host_start(c: u8) -> bool {
    c != b'\\' && !is_blank(c) && c != b'\'' && c != b'"' && c != b'*' && c != b'?' && c != b'['
}

#[cfg(test)]
mod tests {
    use super::*;

    fn slice<'a>(line: &'a str, m: &Match) -> &'a str {
        &line[m.start..m.end]
    }

    #[test]
    fn detect_drive_absolute() {
        assert_eq!(detect_path_kind(r"C:\Users\x"), PathKind::DriveAbsolute);
        assert_eq!(detect_path_kind(r"c:/foo/bar"), PathKind::DriveAbsolute);
        assert_eq!(detect_path_kind("C:/Users/x/a.txt"), PathKind::DriveAbsolute);
    }

    #[test]
    fn detect_unc() {
        assert_eq!(detect_path_kind(r"\\server\share\x"), PathKind::Unc);
    }

    #[test]
    fn detect_non_path() {
        assert_eq!(detect_path_kind("foo"), PathKind::None);
        assert_eq!(detect_path_kind("C:"), PathKind::None);
        assert_eq!(detect_path_kind("C:foo"), PathKind::None);
        assert_eq!(detect_path_kind("/home/u/b.txt"), PathKind::None);
        assert_eq!(detect_path_kind("http://x"), PathKind::None);
    }

    #[test]
    fn scan_line_basic() {
        let line = r"cat C:\Users\x\a.txt";
        let ms = scan_line(line);
        assert_eq!(ms.len(), 1);
        assert_eq!(ms[0].kind, PathKind::DriveAbsolute);
        assert_eq!(slice(line, &ms[0]), r"C:\Users\x\a.txt");
    }

    #[test]
    fn scan_line_quoted_spaces() {
        let line = r#"ls "C:\Program Files\Foo""#;
        let ms = scan_line(line);
        assert_eq!(ms.len(), 1);
        assert_eq!(slice(line, &ms[0]), r"C:\Program Files\Foo");
    }

    #[test]
    fn scan_line_mixed() {
        let line = r"diff C:\a.txt /home/u/b.txt";
        let ms = scan_line(line);
        assert_eq!(ms.len(), 1);
        assert_eq!(slice(line, &ms[0]), r"C:\a.txt");
    }

    #[test]
    fn scan_line_unc() {
        let line = r"ls \\server\share\x";
        let ms = scan_line(line);
        assert_eq!(ms.len(), 1);
        assert_eq!(ms[0].kind, PathKind::Unc);
    }

    #[test]
    fn scan_line_no_false_positive() {
        assert!(scan_line("echo C:").is_empty());
        assert!(scan_line("curl http://example.com/x").is_empty());
        assert!(scan_line("echo ${VAR}").is_empty());
        assert!(scan_line(r#"grep -E 'C:\\foo'"#).is_empty());
    }

    #[test]
    fn detect_unc_requires_real_host() {
        // 转义/glob 形态不视为 UNC
        assert_eq!(detect_path_kind(r"\\*"), PathKind::None);
        assert_eq!(detect_path_kind(r"\\"), PathKind::None);
        assert_eq!(detect_path_kind(r"\\ "), PathKind::None);
        assert_eq!(detect_path_kind(r"\\\x"), PathKind::None); // 三反斜杠
        // 真实 UNC 仍识别
        assert_eq!(detect_path_kind(r"\\server\\share\\x"), PathKind::Unc);
        assert_eq!(detect_path_kind(r"\\wsl.localhost\\Ubuntu-22.04"), PathKind::Unc);
    }

    #[test]
    fn scan_line_escaped_double_backslash_not_unc() {
        // 补全/测试脚本中的转义反斜杠形态：不判为 UNC（tab 补全误判 bug 回归）
        assert!(scan_line(r"[[ $cmd == \\* ]]").is_empty());
        assert!(scan_line(r"\\*").is_empty());
        assert!(scan_line(r"ls \\*").is_empty());
        assert!(scan_line(r"ls \\\\server").is_empty()); // 四个反斜杠紧跟反斜杠
        // 真实 UNC 行仍识别
        let ms = scan_line(r"ls \\server\\share\\x");
        assert_eq!(ms.len(), 1);
        assert_eq!(ms[0].kind, PathKind::Unc);
    }
}
