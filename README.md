# CLI Environment Bootstrap

This project bootstraps a no-sudo command-line environment under a user-owned prefix. Source code remains the behavior source of truth, but the Markdown files describe the execution flow, module contracts, and install decisions so normal maintenance does not require reading every shell file first.

## What It Installs Or Reuses

The script prefers existing compatible tools before building or installing under the prefix.

- zsh `5.9`
- ncurses `6.5`
- libevent `2.1.12-stable`
- tmux `3.6a`
- Miniforge `26.1.1-3`
- Oh My Zsh at commit `3604dc23e0d95b5ce9a3932838a7b103ef5ff0c1`
- zsh plugins: autosuggestions `v0.7.1`, completions `0.36.0`, syntax highlighting `0.8.0`

It supports macOS and Ubuntu-style Linux without requiring `sudo`, package managers, or `chsh`.

## Execution Flow

`bootstrap_env.sh` loads modules in dependency order, then calls `main` from `app/main.sh`.

1. Parse CLI options and normalize paths.
2. Detect OS, architecture, build jobs, profile file, and download URLs.
3. Print the run summary and check prerequisites.
4. Build or reuse ncurses, libevent, zsh, and tmux.
5. Install or reuse Miniforge, then write `.condarc` only for bootstrap-owned Miniforge.
6. Install or reuse Oh My Zsh and plugins.
7. Update managed blocks in `.zshrc` and the login profile.
8. Optionally append a pasted SSH public key to `authorized_keys`.

## Directory Map

- `app/`: orchestration only.
- `cli/`: CLI help, parsing, validation, and run summaries.
- `platform/`: OS, architecture, job count, compiler, and prerequisite detection.
- `core/`: shared globals, logging, paths, command wrappers, URLs, source cache, stamps, build flags, and managed-file helpers.
- `zsh/`: zsh source build, Oh My Zsh, plugins, `.zshrc`, and login profile integration.
- `tmux/`: ncurses/libevent dependency builds and tmux source build.
- `conda/`: Miniforge install and `.condarc`.
- `ssh/`: optional `authorized_keys` setup.
- `docs/`: implementation plans and design notes.

Each capability directory has its own `README.md` with scope, files, entry functions, inputs, outputs, writes, and skip behavior.

## Common Commands

```sh
bash -n bootstrap_env.sh
find app cli platform core zsh tmux conda ssh -name '*.sh' -exec bash -n {} \;
bash bootstrap_env.sh --help
env HOME=/private/tmp/bootstrap_env_dry_home bash bootstrap_env.sh --dry-run --jobs 2 --no-ssh-key
shellcheck bootstrap_env.sh app/*.sh cli/*.sh platform/*.sh core/*.sh zsh/*.sh tmux/*.sh conda/*.sh ssh/*.sh
```

Run ShellCheck when it is installed. Avoid full install runs during routine edits unless you intend to download and build dependencies.

## Important Options

- `--dry-run`: prints detected platform, source URLs, managed files, downloads, extracts, builds, and writes without changing files.
- `--force-rebuild`: allows replacement of managed prefix installs and re-extraction of source directories. Without it, existing prefix files without matching bootstrap stamps are preserved.
- `--prefix DIR`: sets the install root. Defaults to `BOOTSTRAP_PREFIX` or `$HOME/.local`.
- `--no-ssh-key`: skips interactive SSH public key setup.

## Files And Directories Written

The default prefix is `$HOME/.local`. Under the selected prefix the script may write:

- `bin/`, `lib/`, `include/`, and `share/` for source-built tools and shell assets.
- `source/` for downloaded archives and extracted source trees.
- `.bootstrap_env/state/*.version` install stamps.
- `miniforge3/` and `miniforge3/.condarc` when Miniforge is bootstrap-owned.

In the user's home directory the script may update:

- `$HOME/.zshrc`
- `$HOME/.bash_profile` or `$HOME/.profile`
- `$HOME/.ssh/authorized_keys` unless `--no-ssh-key` is used

Managed shell/profile edits are marker-bounded blocks with timestamped backups. Existing user-owned prefix files are left in place unless `--force-rebuild` is provided.
