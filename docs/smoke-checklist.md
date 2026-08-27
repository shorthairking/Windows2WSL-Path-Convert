# wpc Smoke & Acceptance Record

> [English](smoke-checklist.md) | [简体中文](smoke-checklist.zh-CN.md)
>
> Phase-1 manual smoke record (no automated tests, per the plan).
> Collected: 2026-08-27

## 1. Smoke Results per Skill

### 1.1 scaffold-rust-project

| Check | Result |
|-------|--------|
| `cargo run -- --version` prints `wpc 0.1.0`, exit 0 | ✅ |
| `cargo build --release` succeeds, `target/release/wpc` < 1 MB | ✅ (325 KB) |
| no warnings in debug and release | ✅ |

### 1.2 path-conversion-engine

| Scenario | Input | Expected | Actual | Result |
|----------|-------|----------|--------|--------|
| A1 per-arg drive | `wpc 'C:\Users\x\a.txt'` | `/mnt/c/Users/x/a.txt` | same | ✅ |
| A2 forward slash lowercase | `wpc 'c:/foo/bar'` | `/mnt/c/foo/bar` | same | ✅ |
| S7 explicit | `wpc 'C:\a.txt'` | `/mnt/c/a.txt` | same | ✅ |
| non-path | `wpc foo /home/u/b.txt` | unchanged | same | ✅ |
| mixed args | `wpc 'C:\a.txt' /home/u/b.txt` | only Windows part converts | same | ✅ |
| UNC | `wpc '\\server\share\f'` | unchanged + exit 1 | same | ✅ |
| S1 eval-line | `wpc --eval-line 'cat C:\Users\x\a.txt'` | `cat /mnt/c/Users/x/a.txt` | same | ✅ |
| S2/A4 quoted spaces | `wpc --eval-line 'ls "C:\Program Files\Foo"'` | `ls "/mnt/c/Program Files/Foo"` | same | ✅ |
| S3/A5 mixed | `wpc --eval-line 'diff C:\a.txt /home/u/b.txt'` | only Windows part converts | same | ✅ |
| S4 forward slash | `wpc --eval-line 'cat C:/Users/x/a.txt'` | converts | same | ✅ |
| A6 UNC | `wpc --eval-line 'ls \\server\share\x'` | unchanged + exit 1 | same | ✅ |
| A7 false-positive guard | `echo C:` / URL / `${VAR}` | none converted | same | ✅ |
| edge escaped backslash | `grep -E 'C:\\foo'` (single-quoted double backslash) | not converted | same | ✅ |
| collapse separators | `wpc 'C:\Users\\x\a.txt'` | `/mnt/c/Users/x/a.txt` | same | ✅ |
| stdin | piped multi-line | line-by-line whole rewrite | same | ✅ |
| wslpath comparison | `wslpath -u 'C:\Users\x\a.txt'` | identical to wpc | identical | ✅ |
| mount root config | user config `mount_root="/opt/mnt/"` | `/opt/mnt/c/a.txt` | same | ✅ |
| usage error | `wpc --eval-line` (missing arg) | exit 2 + message | same | ✅ |

### 1.3 bash-preexec-integration

| Check | Result |
|-------|--------|
| drive path transparent conversion (`echo C:\Users\x\a.txt` → `/mnt/c/Users/x/a.txt`) | ✅ |
| ordinary command unaffected, no extra output (`echo hello`) | ✅ |
| `WPC_DISABLE=1` prefix disables | ✅ |
| UNC Chinese message + command not executed | ✅ |
| quoted path with spaces converts correctly | ✅ |
| hook internal commands (history writes) do not recurse | ✅ |
| `WPC_FALLBACK=raw` escape (prefix and env-var forms) | ✅ |
| no state leak after conversion (consecutive commands fine) | ✅ |
| idempotent reload (repeated `source`) | ✅ |
| perf observation: `set -x` confirms fast path is pure builtin matching, zero fork | ✅ |

### 1.4 installer-and-autostart

| Check | Result |
|-------|--------|
| install in temp HOME: binary/hook/bashrc marker/config skeleton in place | ✅ |
| new `bash -i` in temp HOME auto-activates hook (`type wpc_preexec` + conversion works) | ✅ |
| two consecutive installs idempotent (only 1 marker block) | ✅ |
| uninstall removes everything (binary/hook/marker/systemd unit) | ✅ |
| `WPC_DISABLE=1` environment: install/uninstall unaffected (exit 0) | ✅ |
| when systemd unavailable: prompt, not failure | ✅ |

## 2. Phase-1 Acceptance Checklist (development-plan §9)

| # | Acceptance item | Result |
|---|-----------------|--------|
| A1 | `wpc 'C:\Users\x\a.txt'` → `/mnt/c/Users/x/a.txt` | ✅ |
| A2 | `wpc 'c:/foo/bar'` → `/mnt/c/foo/bar` | ✅ |
| A3 | interactive shell `cat C:\AMFTrace.log` (real /mnt/c file) executes transparently, no extra output | ✅ |
| A4 | `ls "C:\Program Files\..."` quoted space path correct | ✅ |
| A5 | mixed args: only Windows part converts | ✅ |
| A6 | UNC → Chinese message + not executed + exit 1 | ✅ |
| A7 | `echo C:` / URL / `${VAR}` not false-converted | ✅ |
| A8 | ordinary command zero output, zero extra processes (`set -x` shows zero-fork fast path) | ✅ |
| A9 | `WPC_DISABLE=1` fully disables | ✅ |
| A10 | temp HOME install → new `bash -i` auto-activates → uninstall → fully removed | ✅ |
| A11 | two consecutive installs idempotent | ✅ |
| A12 | `cargo build --release` green, no warnings, binary < 1 MB | ✅ (325 KB) |
| A13 | `systemctl --user status wpc-daemon` OK when systemd available | ⚠️ see below |

> **A13 note**: in this dev environment (VS Code non-user session) the `systemctl --user`
> instance is unavailable; install.sh skips gracefully (not a failure). The service unit and
> enable logic are implemented; verify in a real login user session.

## 3. Conclusion

Phase-1 functional development and manual smoke are complete; A1–A12 all pass, A13 is
environment-limited (the script degrades gracefully). Open items:

- Verify A13 `systemctl --user status wpc-daemon` in a real login session.
- Gray-scale install verification on a real user `~/.bashrc` (explicitly deferred to a later phase, plan §10.6).
