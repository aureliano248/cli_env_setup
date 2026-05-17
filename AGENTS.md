# Repository Guidelines

## Project Structure & Module Organization

This repository is centered on a single Bash bootstrap script:

- `bootstrap_env.sh`: installs a no-sudo CLI environment under a user prefix such as `$HOME/.local`.
- `AGENTS.md`: contributor and agent workflow guidance.

There is currently no separate `src/`, `tests/`, or assets directory. Keep the project flat unless a new file has a clear maintenance purpose, such as `README.md`, `CHANGELOG.md`, or focused test fixtures.

## Build, Test, and Development Commands

Use these commands from the repository root:

- `bash -n bootstrap_env.sh`: validates Bash syntax without running the script.
- `bash bootstrap_env.sh --help`: checks CLI option output.
- `env HOME=/private/tmp/bootstrap_env_dry_home bash bootstrap_env.sh --dry-run --jobs 2 --no-ssh-key`: verifies platform detection, URLs, planned writes, and dry-run flow without modifying a real home directory.
- `shellcheck bootstrap_env.sh`: run when available for static linting.

Avoid full install runs during routine edits unless you intend to download and build dependencies.

## Coding Style & Naming Conventions

Target Bash 3.2 compatibility for macOS system Bash. Use portable shell patterns and avoid arrays or newer Bash features unless already supported by Bash 3.2. Keep indentation with tabs in function bodies, matching the existing script. Use uppercase names for global configuration constants, lowercase function names with underscores, and descriptive local variable names.

Prefer explicit checks and clear error messages over implicit failures. Keep comments short and only where they clarify non-obvious behavior.

## Testing Guidelines

There is no automated test framework yet. At minimum, run syntax and dry-run checks before committing. For behavior changes, test with a temporary `HOME` and a temporary `--prefix` under `/private/tmp` or `/tmp`. Do not run tests that modify a real user shell profile unless explicitly intended.

## Commit & Pull Request Guidelines

The current history uses structured commit subjects such as:

```text
[Feature] 添加无 sudo CLI 环境初始化脚本
```

Use an English type in brackets (`Feature`, `Bug`, `Docs`, `Refactor`, `Test`, `Patch`) and a concise Chinese summary when appropriate. Pull requests should describe the user-visible behavior change, list validation commands run, and call out any platform-specific assumptions or untested OS/architecture combinations.

## Security & Configuration Tips

Do not add secrets, SSH private keys, tokens, or machine-specific dotfiles. Preserve the no-sudo design: changes should not require `sudo`, `apt`, `brew`, or `chsh`.
