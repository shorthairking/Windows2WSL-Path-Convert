# Measured Development Environment

> [English](environment.md) | [简体中文](environment.zh-CN.md)
>
> Collected: 2026-08-27. All data measured on the dev machine, for reference by development agents.

## System Environment

| Item | Measured value | Notes |
|------|----------------|-------|
| Kernel | `Linux 6.6.87.2-microsoft-standard-WSL2` (x86_64) | WSL2 |
| Distro | Ubuntu 24.04.4 LTS (Noble) | ⚠️ differs from 22.04 stated in require.md |
| Distro identifier | `WSL_DISTRO_NAME=Ubuntu-22.04` | name still 22.04; userland upgraded to 24.04 |
| Default shell | `/bin/bash` (GNU bash 5.2.21) | bash-only assumption holds |
| User | `shorthair` (home `/home/shorthair`) | |
| WSL interop | enabled (`/run/WSL/1677_interop` exists) | |

## Development Toolchain

| Tool | Version | Path |
|------|---------|------|
| git | 2.43.0 | system |
| Rust (rustc/cargo) | rustc 1.96.0 | system |
| Python 3 | 3.13.9 | `/home/shorthair/miniconda3/bin/python3` (conda base) |
| gcc | 13.3.0 | system |
| GNU Make | 4.3 | system |
| Node.js | not installed | — |
| Go | not installed | — |

## WSL Path-Conversion Capabilities

| Item | Measured value | Notes |
|------|----------------|-------|
| `wslpath` | `/usr/bin/wslpath` available | reference implementation & fallback |
| `wslpath -w ~` output | `\\wsl.localhost\Ubuntu-22.04\home\shorthair` | reverse conversion works |
| `/mnt/c` | exists | default mount point OK; Windows C: mounted |
| `/etc/wsl.conf` | to be read during development | engine must support custom automount root |

## Existing Files

- `~/.bashrc`, `~/.profile` both exist (standard bash startup chain complete, hook can be injected).
- Current repo: `require.md` plus newly created `AGENTS.md` and `.github/` workspace.

## Environment Conclusions (basis for the plan)

1. Distro name differs from the actual userland version; the plan refers to "WSL Ubuntu, bash 5.2"
   to avoid depending on 22.04/24.04-specific behavior.
2. Rust toolchain is complete and no external crates are needed → core engine in Rust, zero-dependency single binary.
3. `wslpath` and `/mnt/c` both available → authoritative reference for conversion rules.
4. Node/Go not installed → implementation does not use JS/Go.
