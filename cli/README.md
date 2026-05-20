# CLI Module

## Scope

`cli/` owns user-facing command-line behavior: help text, argument parsing, option validation, and the run summary. It does not perform platform detection or installation.

## Files

- `args.sh`: defines usage text, parses CLI options, validates prefix/job inputs, and prints the run summary.

## Entry Functions

- `usage`: prints supported options and pinned versions.
- `parse_args "$@"`: normalizes CLI and environment inputs into globals.
- `print_summary`: prints platform, prefix, source cache, jobs, and dry-run details.

## Inputs

Important inputs are `HOME`, `BOOTSTRAP_PREFIX`, `BOOTSTRAP_JOBS`, and CLI arguments. `print_summary` also reads platform globals, URL globals, `LOGIN_PROFILE_FILE`, and selected prefix paths.

## Outputs

`parse_args` sets `PREFIX`, `JOBS`, `SOURCE_DIR`, `STATE_DIR`, `MINIFORGE_DIR`, `BACKUP_SUFFIX`, `DRY_RUN`, `FORCE_REBUILD`, `ASSUME_YES`, and `NO_SSH_KEY`.

## Writes

This module writes no files. It only prints help or summary text.

## Reuse And Skip Behavior

This module does not choose reusable tools. It validates options so later modules can make reuse decisions from normalized globals.

## Dry Run And Force Rebuild

`--dry-run` sets `DRY_RUN=1`. `--force-rebuild` sets `FORCE_REBUILD=1`. The effects are implemented by installer and file modules.
