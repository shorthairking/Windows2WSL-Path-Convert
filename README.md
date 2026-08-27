# wpc —— WSL 路径自动转换工具

Windows Path Converter：在 WSL 中无感知地将 Windows 路径自动转换为 WSL 路径。

```bash
# 用户输入
some_command C:\Users\x\a.txt
# 实际执行
some_command /mnt/c/Users/x/a.txt
```

- 开发方案：见 [`docs/development-plan.md`](docs/development-plan.md)
- 项目约定：见 [`AGENTS.md`](AGENTS.md)
- 开发环境：见 [`docs/environment.md`](docs/environment.md)
