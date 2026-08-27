//! wpc（Windows Path Converter）—— WSL 路径自动转换工具
//!
//! CLI 接口与退出码（方案 §5.3）：
//! - `wpc <路径...>`：逐参数转换，每个参数一行；非路径参数原样输出
//! - `wpc --stdin`：stdin 多行 → stdout 逐行整体替换
//! - `wpc --eval-line <原始命令行>`：整体替换，供 shell hook 使用
//! - `wpc --version`
//! 退出码：0 成功（含无匹配）；1 存在无法转换的 UNC；2 用法错误。

mod config;
mod engine;
mod hook;

use std::io::{self, BufRead};
use std::process::ExitCode;

use engine::detect::{self, PathKind};

/// 程序版本号（取自 Cargo.toml）
const VERSION: &str = env!("CARGO_PKG_VERSION");

/// 用法说明
const USAGE: &str =
    "用法：wpc <路径...> | wpc --stdin | wpc --eval-line <原始命令行> | wpc --version";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();

    if args.is_empty() {
        eprintln!("{}", USAGE);
        return ExitCode::from(2);
    }

    match args[0].as_str() {
        "--version" | "-V" => {
            println!("wpc {}", VERSION);
            ExitCode::SUCCESS
        }
        "--stdin" => {
            // stdin 多行 → stdout 逐行整体替换
            let mount_root = config::mount_root();
            let mut has_unc = false;
            let stdin = io::stdin();
            for line in stdin.lock().lines() {
                let Ok(line) = line else { break };
                let res = hook::eval_line(&line, &mount_root);
                println!("{}", res.text);
                has_unc |= res.has_unc;
            }
            if has_unc {
                ExitCode::from(1)
            } else {
                ExitCode::SUCCESS
            }
        }
        "--eval-line" => {
            // 需要至少一个参数：原始命令行
            let Some(cmd) = args.get(1) else {
                eprintln!("wpc: --eval-line 需要一个参数：原始命令行");
                eprintln!("{}", USAGE);
                return ExitCode::from(2);
            };
            let mount_root = config::mount_root();
            let res = hook::eval_line(cmd, &mount_root);
            println!("{}", res.text);
            if res.has_unc {
                ExitCode::from(1)
            } else {
                ExitCode::SUCCESS
            }
        }
        flag if flag.starts_with('-') => {
            eprintln!("wpc: 未知选项：{}", flag);
            eprintln!("{}", USAGE);
            ExitCode::from(2)
        }
        _ => {
            // wpc <路径...>：逐参数转换，每个参数一行；非路径参数原样输出
            let mount_root = config::mount_root();
            let mut has_unc = false;
            for arg in &args {
                match detect::detect_path_kind(arg) {
                    PathKind::DriveAbsolute => {
                        println!("{}", engine::convert::convert_path(arg, &mount_root));
                    }
                    PathKind::Unc => {
                        has_unc = true;
                        println!("{}", arg);
                    }
                    PathKind::None => println!("{}", arg),
                }
            }
            if has_unc {
                ExitCode::from(1)
            } else {
                ExitCode::SUCCESS
            }
        }
    }
}
