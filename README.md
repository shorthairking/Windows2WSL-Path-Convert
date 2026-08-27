# wpc — WSL Path Auto-Converter

> [English](README.md) | [简体中文](README.zh-CN.md)

Windows Path Converter: transparently converts Windows paths to WSL paths as you type in WSL.

```bash
# what you type
some_command C:\Users\username\Documents\file.txt
# what actually runs
some_command /mnt/c/Users/username/Documents/file.txt
```

No explicit invocation or prompt is shown during normal use (except on errors) — you never convert paths by hand.

## Encoding Note (UTF-8)

All project files are **UTF-8 encoded**. If Chinese text appears garbled (e.g., in Chinese error messages or the Chinese docs), make sure your terminal locale is UTF-8:

```bash
echo "$LANG"                       # should contain UTF-8, e.g. C.UTF-8 / en_US.UTF-8
export LANG=C.UTF-8                # add to ~/.bashrc if needed
```

## Features

- **Transparent conversion**: in interactive bash, commands containing Windows drive paths are silently rewritten to WSL paths **before** execution.
- **Zero-overhead fast path**: ordinary commands (without path-like patterns) never fork an external process.
- **Explicit CLI**: scripts/pipelines can convert paths explicitly with the `wpc` command.
- **User-level install**: deployed under `~/.local`, no sudo required, reversible uninstall.
- **Zero-dependency single binary**: Rust implementation, `target/release/wpc` ≈ 325 KB.

## Requirements

wpc is a WSL-only tool. `install.sh` auto-checks these before deploying:

| Dependency | Version | Purpose | Install command |
|------------|---------|---------|-----------------|
| WSL (Ubuntu) | any distro name | runtime platform | already enabled with Windows |
| bash | ≥ 5.x | hook runtime | bundled with Ubuntu |
| Rust toolchain (`cargo`/`rustc`) | ≥ 1.96 (only needed to build from source) | build the release binary | see below |
| `wslpath` | bundled with WSL | reference/fallback for conversion | usually already present |
| standard tools `install`/`grep`/`sed`/`mkdir`/`rm` | bundled with Ubuntu | install script | no extra install |

### One-shot dependency install (bash)

```bash
# 1) Rust toolchain (only required when building from source)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
#   ...or on Ubuntu/Debian:
sudo apt update && sudo apt install -y cargo

# 2) Verify required tools are present (WSL usually has them)
command -v wslpath install grep sed mkdir rm cat

# 3) Build and install
cargo build --release
./install.sh
source ~/.bashrc
```

> If you already have a prebuilt `target/release/wpc`, the Rust toolchain is **not** required.

## Install

```bash
./install.sh
source ~/.bashrc   # or open a new terminal
```

What gets installed:

| File | Description |
|------|-------------|
| `~/.local/bin/wpc` | core conversion binary |
| `~/.local/share/wpc/wpc.bash` | bash DEBUG trap hook |
| `~/.config/wpc/config.toml` | config file skeleton |
| `~/.bashrc` marker block | auto-loads the hook on interactive shell startup |
| `~/.config/systemd/user/wpc-daemon.service` | optional placeholder service (when systemd is available) |

> "Service state": in bash, the hook activates automatically at every interactive shell startup; the systemd user placeholder service represents the serviced status and is an extension point.

## Uninstall

```bash
./uninstall.sh
```

Removes the binary, hook, bashrc marker block and systemd unit; your `~/.config/wpc/config.toml` is kept (delete manually if desired).

## Usage

### Transparent conversion (interactive bash)

```bash
cat C:\Users\x\a.txt            # runs cat /mnt/c/Users/x/a.txt
ls "C:\Program Files\Foo"       # quoted paths with spaces convert correctly
diff C:\a.txt /home/u/b.txt     # mixed arguments: only the Windows part converts
cat C:/Users/x/a.txt            # forward-slash style is supported too
```

Environment switches:

| Variable | Effect |
|----------|--------|
| `WPC_DISABLE=1` | temporarily disable conversion entirely (prefix or `export`) |
| `WPC_FALLBACK=raw` | run the command as-is instead of blocking on unconvertible UNC paths |

### Explicit CLI

```bash
wpc 'C:\Users\x\a.txt'          # per-argument conversion → /mnt/c/Users/x/a.txt
wpc 'C:\a.txt' /home/u/b.txt    # non-path arguments pass through unchanged
printf 'C:\\a.txt\n' | wpc --stdin   # line-by-line whole-line rewriting
wpc --version
```

Exit codes: `0` success (including no match); `1` an unconvertible UNC path exists; `2` usage error.

## Configuration

`~/.config/wpc/config.toml`:

```toml
# mount root: where Windows drive letters map into WSL (default /mnt/)
# mount_root = "/mnt/"
```

Mount root resolution order:

1. `/etc/wsl.conf` → `[automount] root`
2. `~/.config/wpc/config.toml` → `mount_root`
3. default `/mnt/`

## Known limitations

- **Interactive bash only**: Windows paths written directly inside scripts are not auto-converted (use the `wpc` CLI explicitly there).
- **UNC paths unsupported**: `\\server\share\...` cannot be mapped into WSL; wpc prints an error and blocks execution (`WPC_FALLBACK=raw` escapes).
- **Relative drive paths not converted**: e.g. `C:foo` (no separator).
- **zsh/fish unsupported**: left for a later phase.

## Documentation

| Document | English (primary) | 简体中文 |
|----------|-------------------|----------|
| Development plan | [`docs/development-plan.md`](docs/development-plan.md) | [`docs/development-plan.zh-CN.md`](docs/development-plan.zh-CN.md) |
| Architecture | [`docs/architecture.md`](docs/architecture.md) | [`docs/architecture.zh-CN.md`](docs/architecture.zh-CN.md) |
| Smoke & acceptance record | [`docs/smoke-checklist.md`](docs/smoke-checklist.md) | [`docs/smoke-checklist.zh-CN.md`](docs/smoke-checklist.zh-CN.md) |
| Test plan | [`docs/test-plan.md`](docs/test-plan.md) | [`docs/test-plan.zh-CN.md`](docs/test-plan.zh-CN.md) |
| Project conventions (AGENTS) | [`AGENTS.md`](AGENTS.md) | [`AGENTS.zh-CN.md`](AGENTS.zh-CN.md) |
