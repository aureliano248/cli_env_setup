# Conda Module

## Scope

`conda/` owns Miniforge installation and conda configuration. It does not write shell startup files directly; `zsh/profile.sh` consumes selected conda paths when generating `.zshrc`.

## Files

- `miniforge.sh`: finds or installs conda/Miniforge and writes bootstrap-owned `.condarc`.

## Entry Functions

- `install_miniforge`: selects an existing conda or installs Miniforge under the prefix.
- `write_condarc`: writes conda-forge-only config for bootstrap-owned Miniforge.

## Inputs

Important inputs are `MINIFORGE_VERSION`, `MINIFORGE_URL`, `MINIFORGE_DIR`, `SOURCE_DIR`, `STATE_DIR`, `PREFIX`, `DRY_RUN`, and `FORCE_REBUILD`.

## Outputs

This module sets `SELECTED_CONDA_BIN`, `SELECTED_CONDA_SH`, and `MANAGE_MINIFORGE_CONFIG`.

## Writes

Possible writes include the Miniforge installer archive in `SOURCE_DIR`, `MINIFORGE_DIR`, `MINIFORGE_DIR/.condarc`, and the `miniforge` install stamp under `STATE_DIR`.

## Reuse And Skip Behavior

The module reuses `$MINIFORGE_DIR/bin/conda` or a host `conda`. It manages `.condarc` only when the selected conda is the bootstrap-owned Miniforge with a matching stamp or a fresh install. Existing Miniforge directories without matching stamps are preserved unless `--force-rebuild` is used.

## Dry Run And Force Rebuild

Dry runs print installer download, install command, stamp write, and `.condarc` write without changing files. `--force-rebuild` allows replacing the prefix Miniforge directory.
