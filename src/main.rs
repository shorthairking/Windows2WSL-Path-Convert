//! wpc（Windows Path Converter）—— WSL 路径自动转换工具
//!
//! 本文件为 CLI 入口，负责子命令分发与退出码管理。
//! 核心转换逻辑位于 `engine/` 模块，由后续 skill 填充。

mod config;
mod engine;
mod hook;

use std::io::{self, BufRead};
use std::process::ExitCode;

/// 程序版本号（取自 Cargo.toml）
const VERSION: &str = env!("CARGO_PKG_VERSION");

/// 用法说明
const USAGE: &str = "用法：wpc <路径...> | wpc --stdin | wpc --eval-line <原始命令行> | wpc --version";

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
            // stdin 逐行转换；核心转换逻辑后续填充，当前原样输出
            let stdin = io::stdin();
            for line in stdin.lock().lines() {
                match line {
                    Ok(line) => println!("{}", line),
                    Err(_) => break,
                }
            }
            ExitCode::SUCCESS
        }
        "--eval-line" => {
            // 供 shell hook 调用：整体替换原始命令行；当前原样返回
            let cmd = args.get(1).cloned().unwrap_or_default();
            println!("{}", hook::eval_line(&cmd));
            ExitCode::SUCCESS
        }
        flag if flag.starts_with('-') => {
            eprintln!("wpc: 未知选项：{}", flag);
            eprintln!("{}", USAGE);
            ExitCode::from(2)
        }
        _ => {
            // wpc <路径...>：逐参数转换；非路径参数原样输出
            // 核心检测/转换逻辑后续填充，当前原样输出
            for arg in &args {
                println!("{}", arg);
            }
            ExitCode::SUCCESS
        }
    }
}
