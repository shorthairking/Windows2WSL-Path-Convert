# wpc Architecture

> [English](architecture.md) | [简体中文](architecture.zh-CN.md)
>
> Phase-1 implementation. A Windows path auto-converter inside WSL (bash 5.2).

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                       User Layer (bash)                          │
│                                                                  │
│  user command line ──► DEBUG trap (wpc.bash)                     │
│                        │                                         │
│                        ├─ fast path (bash builtin match, no fork)│
│                        │   no candidate ──► run as-is (zero cost)│
│                        │   candidate ──► invoke wpc --eval-line  │
│                        │                                         │
│                        ├─ exit 0 ──► eval converted command      │
│                        ├─ exit 1 ──► stderr message, block       │
│                        └─ exit 2 ──► pass through (defensive)    │
└────────────────────────────┬────────────────────────────────────┘
                             │ fork (only for candidate commands)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Core Engine (Rust binary wpc)                 │
│                                                                  │
│  CLI entry main.rs ──► hook.rs (--eval-line whole-line rewrite)  │
│                        │                                         │
│                        ├─► engine/detect.rs  detection           │
│                        ├─► engine/convert.rs conversion          │
│                        └─► config.rs         mount root          │
└─────────────────────────────────────────────────────────────────┘
        ▲                                    ▲
        │ install.sh deploys                 │ config reads
        │                                    │
┌───────┴────────────┐          ┌────────────┴──────────────────┐
│  Deployment layer  │          │  Config layer                 │
│  ~/.local/bin/wpc  │          │  /etc/wsl.conf [automount]    │
│  ~/.local/share/   │          │  ~/.config/wpc/config.toml    │
│    wpc/wpc.bash    │          └───────────────────────────────┘
│  ~/.bashrc marker  │
│  systemd user unit │
└────────────────────┘
```

## Data Flow (transparent conversion)

```
user input:  some_command C:\Users\x\a.txt
     │
     ▼
DEBUG trap captures $BASH_COMMAND (raw text in interactive shell)
     │
     ▼
fast path: matches [A-Za-z]:[\\/] or \\ ?
     ├─ no ──► run original command (zero fork, zero output)
     └─ yes ──► wpc --eval-line "some_command C:\Users\x\a.txt"
                 │
                 ▼
      detect: C:\Users\x\a.txt → DriveAbsolute
      convert: C: → /mnt/c, \ → /, collapse repeated separators
                 │
                 ▼
      output: some_command /mnt/c/Users/x/a.txt (exit 0)
                 │
                 ▼
      hook: history -s keeps the original → eval converted → skip original
                 │
                 ▼
actually runs: some_command /mnt/c/Users/x/a.txt (user unaware)
```

## Execution Replacement Strategy (inside the hook)

1. **Capture**: read `$BASH_COMMAND` in the DEBUG trap.
2. **Fast path**: bash builtin pattern pre-filter; no candidate → pass through (no fork).
3. **Replace**: `wpc --eval-line` rewrites the whole line; exit 0 → `history -s` keeps the
   original + `eval` runs the converted command; exit 1 → Chinese message and block
   (`WPC_FALLBACK=raw` escapes).
4. **Execution safety**: only substrings recognized as paths are replaced; the rest of the
   text is kept verbatim, no new escaping is introduced.
5. **Re-entry protection**: `__wpc_in_hook` local flag + `WPC_DISABLE=1` command prefix.
6. **No state leak**: the handler uses only local variables; it never pollutes the outer shell.

## Error Handling Strategy

| Exit code | Scenario | Hook behavior | CLI behavior |
|-----------|----------|---------------|--------------|
| 0 | conversion success (incl. no match) | eval the converted command | normal output |
| 1 | unconvertible UNC path present | stderr message, block (`WPC_FALLBACK=raw` escapes) | prints original text, returns 1 |
| 2 | argument/usage error | not applicable (hook never produces it) | stderr usage, returns 2 |

## Config Resolution

| Source | Key | Notes |
|--------|-----|-------|
| `/etc/wsl.conf` | `[automount] root` | system-level mount root (highest) |
| `~/.config/wpc/config.toml` | `mount_root` | user-level override (middle) |
| built-in default | — | `/mnt/` |

## Security Design

| Risk | Mitigation |
|------|------------|
| hook recursion / infinite loop | `__wpc_in_hook` + `WPC_DISABLE` double protection |
| false conversion | context constraints (start-of-line / after whitespace / after quote) + engine entered only for clear candidates |
| `wpc` unavailable | hook passes the original command through when the call fails (127), never blocks the user |
| install pollution | all user-level paths; bashrc only appends a marker block; uninstall is reversible |
| Chinese / Unicode paths | Rust `String` handles UTF-8 end-to-end, no byte-level truncation |
| VS Code terminal compatibility | saves and chains the caller's original DEBUG trap |
