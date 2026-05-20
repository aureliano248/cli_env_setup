# App Module

## Scope

`app/` owns the top-level bootstrap order. It does not implement install, parsing, platform, or file-update behavior; it calls the module that owns each step.

## Files

- `main.sh`: defines `main`, the only function called directly by `bootstrap_env.sh`.

## Entry Functions

- `main "$@"`: parses options, detects the platform, prints the summary, runs installers/builders, writes managed shell files, and performs optional SSH setup.

## Inputs

`main` depends on all earlier modules loaded by `bootstrap_env.sh`. It reads and passes process-global state from `core/config.sh`, normalized CLI values from `cli/args.sh`, platform values from `platform/detect.sh`, and selected tool paths produced by tool modules.

## Outputs

`main` does not define persistent globals. It relies on module entry functions to set globals such as `SELECTED_ZSH_BIN`, `SELECTED_CONDA_BIN`, `SELECTED_OMZ_DIR`, and `MANAGE_MINIFORGE_CONFIG`.

## Writes

Writes happen through the modules called by `main`: prefix installs, source cache, install stamps, `.condarc`, `.zshrc`, login profile, and optional `authorized_keys`.

## Reuse And Skip Behavior

Reuse and skip decisions belong to the owning modules. `main` preserves order so dependency builders run before tools that require them and selected paths exist before profile writers use them.

## Dry Run And Force Rebuild

`main` forwards the normalized `DRY_RUN` and `FORCE_REBUILD` globals by calling modules in sequence. It does not special-case those flags.
