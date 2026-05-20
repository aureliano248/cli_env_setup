# Repository Guidelines

## Project Structure & Module Organization

This repository is organized around a thin Bash entrypoint plus root-level capability modules:

- `bootstrap_env.sh`: executable entrypoint that sets strict shell options, resolves the repository root, loads modules in dependency order, and calls `main`.
- `app/`: top-level orchestration only.
- `core/`: shared config, logging, paths, command wrappers, URL/source helpers, build flags, install stamps, and safe managed-file updates.
- `cli/`: help text, argument parsing, option validation, and run summaries.
- `platform/`: OS/architecture detection, job count selection, compiler detection, and prerequisite checks.
- `zsh/`: zsh build, Oh My Zsh, zsh plugins, `.zshrc`, and login profile integration.
- `tmux/`: tmux build plus ncurses/libevent native dependency builders used by the terminal toolchain.
- `conda/`: Miniforge and conda configuration.
- `ssh/`: optional `authorized_keys` setup.
- `docs/`: development plans and design notes.

Each root-level capability directory must include a `README.md` that describes its scope and module contract. Keep `bootstrap_env.sh` small. Add behavior to the module that owns it, and update that module's `README.md` when the responsibility or contract changes. Preserve the flat top level unless a new root file has a clear maintenance purpose, such as `README.md`, `CHANGELOG.md`, or focused test fixtures.

## Build, Test, and Development Commands

Use these commands from the repository root:

- `bash -n bootstrap_env.sh`: validates Bash syntax without running the script.
- `find app cli platform core zsh tmux conda ssh -name '*.sh' -exec bash -n {} \;`: validates module syntax.
- `bash bootstrap_env.sh --help`: checks CLI option output.
- `env HOME=/private/tmp/bootstrap_env_dry_home bash bootstrap_env.sh --dry-run --jobs 2 --no-ssh-key`: verifies platform detection, URLs, planned writes, and dry-run flow without modifying a real home directory.
- `shellcheck bootstrap_env.sh app/*.sh cli/*.sh platform/*.sh core/*.sh zsh/*.sh tmux/*.sh conda/*.sh ssh/*.sh`: run when available for static linting.

Avoid full install runs during routine edits unless you intend to download and build dependencies.

## Coding Style & Naming Conventions

Target Bash 3.2 compatibility for macOS system Bash. Use portable shell patterns and avoid arrays or newer Bash features unless already supported by Bash 3.2. Keep indentation with tabs in function bodies, matching the existing script. Use uppercase names for global configuration constants, lowercase function names with underscores, and descriptive local variable names.

Prefer explicit checks and clear error messages over implicit failures. Keep comments short and only where they clarify non-obvious behavior.

Modules share process-global shell state. Define global defaults in `core/config.sh`, keep generic helpers in `core/`, and avoid hidden dependencies between distant modules. If a module needs state selected by another module, use a clearly named global such as `SELECTED_ZSH_BIN`.

The load order in `bootstrap_env.sh` is part of the contract. When adding a module, place it after the modules that define the functions and globals it consumes. Document any new entry function or cross-module global in the owning directory's `README.md`.

## Testing Guidelines

There is no automated test framework yet. At minimum, run syntax and dry-run checks before committing. For behavior changes, test with a temporary `HOME` and a temporary `--prefix` under `/private/tmp` or `/tmp`. Do not run tests that modify a real user shell profile unless explicitly intended.

Dry-run output should show whether the script plans to reuse host-installed components or install under the prefix. When changing install decisions, test cases where a matching tool exists on `PATH`, where a conflicting file already exists under `--prefix`, and where `--force-rebuild` is used.

## Security & Configuration Tips

Do not add secrets, SSH private keys, tokens, or machine-specific dotfiles. Preserve the no-sudo design: changes should not require `sudo`, `apt`, `brew`, or `chsh`.

Before installing a component, check whether it is already available on the host or under the prefix. Do not overwrite user-owned installs by default. Leave existing files in place and require `--force-rebuild` for replacement when the path is under the managed prefix.
