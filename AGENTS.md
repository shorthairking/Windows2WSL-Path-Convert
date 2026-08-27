# AGENTS.md — Project Conventions for wpc (WSL Path Converter)

> [English](AGENTS.md) | [简体中文](AGENTS.zh-CN.md)

## Project Background

Building `wpc` (Windows Path Converter) inside WSL (Ubuntu): when a user types a Windows
path, it is silently converted to a WSL path before the command runs (e.g.
`C:\Users\x\a.txt` → `/mnt/c/Users/x/a.txt`).

Original requirements: `require.md`; development plan: `docs/development-plan.md`.

## Mandatory Rules for Agents

1. **Follow skills**: development tasks are decomposed into `.github/skills/<name>/SKILL.md`,
   each skill being one complete TODO. Read the relevant `SKILL.md` first and follow its steps strictly.
2. **Commit per step**: after each skill (or agreed milestone) completes, commit immediately.
   Commit messages are in Chinese and state what was done, e.g. `feat(engine): 完成核心路径转换引擎`.
3. **Testing (phase 2, authorized)**: phase 1 is complete. Any test written/run must follow
   the three isolation principles in `docs/test-plan.md`:
   - Subprocess isolation: unified entry `bash tests/run_all.sh`; any `export`/`cd`/`source`
     inside scripts affects only the subprocess tree;
   - Temporary content stays inside the repo under `target/test-tmp/`, auto-cleaned on exit;
   - Never affect global variables or the terminal environment (do not modify the real
     `~/.bashrc`/`~/.local/`, and never `source shell/wpc.bash` in the parent terminal).
   Unit-test entry: `cargo test` (`#[cfg(test)]` inside `src/**/*.rs`).
   Tests must assert against **real paths** (real `/mnt/c` paths + `wslpath` comparison);
   when material is missing, report SKIP explicitly rather than fabricating a pass.
4. **Register external dependencies**: before introducing any external dependency
   (crate, system package, tool), register it in the "External Dependencies" table below
   (name, purpose, version, source) and mention it in the commit message.
   Unregistered dependencies are forbidden.
5. **Language rule**: code comments, commit messages and docs use Chinese (except code identifiers).

## External Dependencies

| Dependency | Purpose | Version / Source | Status |
|------------|---------|------------------|--------|
| Rust toolchain (rustc/cargo) | compiles the core engine | rustc 1.96.0 (installed) | confirmed |
| wslpath | reference implementation & fallback for path conversion | /usr/bin/wslpath (bundled with WSL) | confirmed |
| (to be added) | | | |

## Directory Structure Convention

```
path_convert/
├── require.md                    # requirements document
├── AGENTS.md                     # this file: project conventions (EN primary)
├── AGENTS.zh-CN.md               # 项目约定（中文版）
├── docs/
│   ├── environment.md            # measured dev environment (EN)
│   ├── development-plan.md       # software development plan, tests excluded (EN)
│   ├── architecture.md           # architecture (EN)
│   ├── test-plan.md              # test plan & isolation principles (EN)
│   └── smoke-checklist.md        # phase-1 smoke & acceptance record (EN)
│   └── *.zh-CN.md                # 对应中文版
├── tests/                        # test scripts (isolated)
│   ├── run_all.sh                # unified entry + env snapshot check
│   ├── engine_cli_test.sh        # engine/CLI real-path tests
│   ├── hook_integration_test.sh  # hook e2e (script+pty)
│   └── installer_test.sh         # install/uninstall/idempotency
├── .github/                      # dev workspace (not tracked in release)
│   ├── agents/
│   │   └── path-convert-developer.agent.md
│   └── skills/
│       ├── scaffold-rust-project/SKILL.md
│       ├── path-conversion-engine/SKILL.md
│       ├── bash-preexec-integration/SKILL.md
│       ├── installer-and-autostart/SKILL.md
│       └── project-documentation/SKILL.md
└── src/                          # source (created by scaffold skill)
```

## Key Constraints

- Target environment: WSL Ubuntu (distro name `Ubuntu-22.04`, measured userland 24.04), bash 5.2.21.
- Default shell is bash only (zsh/fish left for a later phase).
- The conversion engine must be zero-dependency (or minimal); the hook hot path must not fork external processes.
