# wpc Test Plan (Phase 2 · Test Preparation)

> [English](test-plan.md) | [简体中文](test-plan.zh-CN.md)
>
> Version: v1.0 · Date: 2026-08-27
> This plan defines the infrastructure and constraints of wpc's test phase. Core requirements —
> **test against real paths**, **keep impact confined to the current repository folder**,
> **never affect global variables or the terminal environment** (if unavoidable, undo it after the test).

## 1. Test Goals

1. Correctness of engine/CLI conversion logic (real path formats + real filesystem existence).
2. End-to-end behavior of the bash hook transparent conversion (verified in a real interactive shell).
3. Install/uninstall script placement, idempotency and reversibility.
4. **Isolation**: no test pollutes the filesystem outside the repo, global variables, or the parent terminal.

## 2. Three Isolation Principles (mandatory)

| # | Principle | Implementation |
|---|-----------|----------------|
| P1 | subprocess isolation | all tests run via `bash tests/run_all.sh` in **subprocesses**; any `export`/`cd`/`source` inside scripts affects only the subprocess tree, zero impact on the parent terminal |
| P2 | temp content confined to the repo | temp HOME and in/out files all live under `target/test-tmp/<case>/`, cleaned by `trap EXIT` |
| P3 | zero environment pollution | `HOME`/`PATH`/`WPC_*` changes happen only inside subprocesses; `WPC_DISABLE`, `WPC_FALLBACK` etc. are used only as command prefixes or subprocess-locally, never written to the parent shell |

## 3. Forbidden Actions (inside test scripts)

- ❌ modifying the real `~/.bashrc`, `~/.profile`, `~/.local/`, `~/.config/wpc/`.
- ❌ running `source shell/wpc.bash` in the parent terminal (it installs a DEBUG trap).
- ❌ writing to `/etc/` (including `/etc/wsl.conf`).
- ❌ leaving temp files outside the repo (`/tmp`, home dir, etc.); always use `target/test-tmp/`.
- ❌ using `sudo`.

## 4. Real-Path Materials (test inputs, probed dynamically)

Tests assert against **real paths** (conversion results must exist on the filesystem);
if a material is missing, report SKIP explicitly rather than fabricating a pass.

| Material | Type | Assertion |
|----------|------|-----------|
| `/mnt/c/AMFTrace.log` | file | `wpc 'C:\AMFTrace.log'` → `test -f` |
| `/mnt/c/Windows/System32` | dir | `wpc 'C:\Windows\System32'` → `test -d` |
| `/mnt/c/Program Files` | dir with space | `wpc 'C:\Program Files'` → `test -d` (quotes preserved) |
| `/mnt/c/Windows` | dir | matches `wslpath -u` output |

Authenticity check: conversion result `$(wslpath -u 'C:\...')` matches and `test -e` passes.

## 5. Test Layer Structure

| Layer | File | Content |
|-------|------|---------|
| engine unit | `#[cfg(test)]` in `src/engine/{detect,convert}.rs` | pure functions, real path **format** assertions (no I/O) |
| engine/CLI | `tests/engine_cli_test.sh` | release binary + real filesystem existence assertions |
| hook integration | `tests/hook_integration_test.sh` | `script`+pty real interaction, temp HOME/PATH |
| installer | `tests/installer_test.sh` | temp HOME (inside repo) install/uninstall/idempotency |
| entry | `tests/run_all.sh` | unified entry + environment snapshot check |

## 6. Environment Snapshot Check (proves zero pollution)

`run_all.sh` records key environment values at entry and compares at exit:

- `$WPC_DISABLE`, `$WPC_FALLBACK`, `$DEBUG` (should be unset)
- `trap -p DEBUG` (should have nothing wpc-related)
- current working directory
- new files outside the repo (`find "$HOME" -maxdepth 2 -newer marker` sampling)

## 7. Impact-Removal Mechanism

- Every script uses `trap 'cleanup' EXIT`: deletes `target/test-tmp/`.
- Any environment change inside a subprocess disappears when the process exits.
- If a future case must touch external state, back it up explicitly inside the case, restore on `EXIT`, and register it in this plan.

## 8. How to Run

```bash
bash tests/run_all.sh        # everything (build release + engine unit + integration)
cargo test                   # Rust unit tests only (inside target/, naturally isolated)
```

## 9. Phase-2 Scope (continuing development-plan §10)

1. engine unit tests ✅ (this plan)
2. hook integration tests ✅ (this plan)
3. installer script tests ✅ (this plan)
4. CI pipeline, fuzzing, performance benchmarks, zsh/fish — later phases
5. gray-scale install on the real `~/.bashrc` — explicitly **not** in this plan (touches the real environment; requires explicit user authorization)
