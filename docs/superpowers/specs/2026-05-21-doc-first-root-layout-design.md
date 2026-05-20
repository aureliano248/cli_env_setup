# Doc-First Root Layout Design

## Purpose

The project should be understandable from Markdown first. Source code remains the source of truth for behavior, but a maintainer should be able to learn the project structure, execution flow, module contracts, and install decisions without reading every shell file.

The current `modules/` wrapper hides the useful structure one level down, and `modules/build/native_tools.sh` mixes several final tools and dependencies in one file. The current per-directory `README.md` files also describe scope too briefly for doc-first maintenance.

## Target Structure

The `modules/` wrapper will be removed. Capability and utility directories move to the repository root:

```text
bootstrap_env.sh
README.md
AGENTS.md

app/
cli/
platform/
core/
zsh/
tmux/
conda/
ssh/
```

Directory responsibilities:

- `app/`: top-level bootstrap orchestration only.
- `cli/`: help text, argument parsing, option validation, and run summary.
- `platform/`: OS, architecture, job count, compiler, and prerequisite detection.
- `core/`: shared configuration and helper functions that are not owned by a final installed tool.
- `zsh/`: zsh build, Oh My Zsh, zsh plugins, `.zshrc`, and login profile zsh integration.
- `tmux/`: tmux build plus the ncurses/libevent native dependency builders used by the terminal toolchain.
- `conda/`: Miniforge install and `.condarc`.
- `ssh/`: optional `authorized_keys` setup.

## File Movement

Planned movement from the current layout:

- `modules/app/main.sh` -> `app/main.sh`
- `modules/cli/args.sh` -> `cli/args.sh`
- `modules/platform/detect.sh` -> `platform/detect.sh`
- `modules/core/config.sh` -> `core/config.sh`
- `modules/core/logging.sh` -> `core/logging.sh`
- `modules/core/paths.sh` -> `core/paths.sh`
- `modules/core/commands.sh` -> `core/commands.sh`
- `modules/files/managed.sh` -> `core/managed-files.sh`
- `modules/sources/urls.sh` -> `core/urls.sh`
- `modules/sources/archive.sh` -> `core/sources.sh`
- `modules/build/common.sh` -> `core/build-flags.sh`
- `modules/build/native_tools.sh` will be split:
  - ncurses/libevent helpers and builders -> `tmux/deps.sh`
  - tmux helpers and builder -> `tmux/tmux.sh`
  - zsh helpers and builder -> `zsh/zsh.sh`
- `modules/shell/oh_my_zsh.sh` -> `zsh/oh-my-zsh.sh`
- `modules/shell/profile.sh` -> `zsh/profile.sh`
- `modules/conda/miniforge.sh` -> `conda/miniforge.sh`
- `modules/ssh/authorized_keys.sh` -> `ssh/authorized-keys.sh`

Each destination directory will keep a `README.md`.

`ncurses` is a shared native dependency: zsh links against it when zsh is built from source, and tmux also needs it. It will live in `tmux/deps.sh` because the tmux stack owns both ncurses and libevent in this project, but `zsh/README.md` must explicitly document that source-built zsh depends on the ncurses builder being loaded and run earlier.

## Entry Point Contract

`bootstrap_env.sh` stays thin. Its responsibilities are:

1. Enable strict Bash behavior.
2. Resolve the repository root.
3. Define `load_bootstrap_module`.
4. Source modules in dependency order.
5. Call `main "$@"`.

The source order is part of the public maintenance contract because all shell files share one process-global namespace. The entrypoint will include a short comment explaining this.

Expected load groups:

1. Core defaults and generic helpers.
2. CLI parsing.
3. Platform detection.
4. Tool capability modules.
5. App orchestration.

## Documentation Contract

The root `README.md` will be the main reader entry point and should cover:

- What the bootstrap installs or reuses.
- The high-level execution flow.
- The root directory map.
- Common development and verification commands.
- The meaning of `--dry-run`, `--force-rebuild`, `--prefix`, and `--no-ssh-key`.
- Files and directories the script may write.

Each directory `README.md` should cover:

- Scope: what this directory owns and what it does not own.
- Files: each shell file and its role.
- Entry functions: functions called by `app/main.sh` or another module.
- Inputs: important globals read from `core/config.sh` or earlier modules.
- Outputs: important globals selected for later modules.
- Writes: filesystem paths managed by this module.
- Reuse and skip behavior: when host or prefix installs are reused.
- `--dry-run` and `--force-rebuild` behavior where relevant.

The goal is not to duplicate all source code in Markdown. The goal is to make module contracts and operational decisions clear enough that source reading becomes optional for normal maintenance.

`AGENTS.md` must also be updated so future contributors use the root-level directories in examples and verification commands instead of `modules/*`.

## Commenting Contract

Shell comments should act as source-code signposts:

- Add comments before major execution phases in `app/main.sh`.
- Add comments in `bootstrap_env.sh` explaining why load order matters.
- Add comments around non-obvious install decisions, especially reuse, prefix protection, stamps, and `--force-rebuild`.
- Add comments where a function sets a global consumed by later modules.
- Avoid comments that merely repeat simple assignments or command names.

Comments must remain short and compatible with the current Bash style.

## Behavioral Compatibility

This refactor should not change install behavior. Existing commands should keep working:

```sh
bash bootstrap_env.sh --help
env HOME=/private/tmp/bootstrap_env_dry_home bash bootstrap_env.sh --dry-run --jobs 2 --no-ssh-key
```

The script should still support Bash 3.2.

## Verification

Minimum verification after implementation:

```sh
bash -n bootstrap_env.sh
find app cli platform core zsh tmux conda ssh -name '*.sh' -exec bash -n {} \;
bash bootstrap_env.sh --help
env HOME=/private/tmp/bootstrap_env_dry_home bash bootstrap_env.sh --dry-run --jobs 2 --no-ssh-key
```

Run ShellCheck when available:

```sh
shellcheck bootstrap_env.sh app/*.sh cli/*.sh platform/*.sh core/*.sh zsh/*.sh tmux/*.sh conda/*.sh ssh/*.sh
```

## Out Of Scope

- Changing pinned tool versions.
- Changing actual install destinations under `--prefix`.
- Adding a test framework.
- Running a full install that downloads and builds dependencies.
- Requiring `sudo`, package managers, or `chsh`.
