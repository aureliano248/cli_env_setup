# Core Module

## Scope

`core/` owns shared state and generic helpers that are not specific to one final installed tool. It includes config defaults, logging, path helpers, command wrappers, source downloads, install stamps, build flags, URL construction, and safe managed-file updates.

## Files

- `config.sh`: version pins, default flags, selected-path globals, and mutable state.
- `logging.sh`: `log`, `warn`, and `die`.
- `paths.sh`: command lookup, absolute paths, trailing slash stripping, shell quoting, argument formatting, and temporary directory creation.
- `commands.sh`: normal/dry-run command execution helpers.
- `managed-files.sh`: timestamped backups and marker-bounded managed block updates.
- `urls.sh`: download URL construction from pinned versions and platform values.
- `sources.sh`: install stamp helpers, prefix-safe removal, downloads, archive unpacking, source preparation, and archive-component installs.
- `build-flags.sh`: shared compiler, linker, pkg-config, and PATH values for prefix builds.

## Entry Functions

Other modules call `command_exists`, `ensure_dir`, `run_cmd`, `run_in_dir`, `write_managed_block`, `set_urls`, `fetch_source`, `install_archive_component`, `stamp_matches`, `write_stamp`, `common_cppflags`, `common_ldflags`, `common_pkg_config_path`, and `native_build_path`.

## Inputs

Core helpers read globals from `config.sh`, especially `PREFIX`, `SOURCE_DIR`, `STATE_DIR`, `DRY_RUN`, `FORCE_REBUILD`, platform URL components, version pins, and `PKG_CONFIG_PATH`.

## Outputs

`config.sh` initializes all process-global defaults. `set_urls` fills URL globals such as `ZSH_URL`, `BYACC_URL`, `NCURSES_URL`, `TMUX_URL`, `MINIFORGE_URL`, and plugin URLs.

## Writes

This module may write source archives under `SOURCE_DIR`, extracted source directories, stamp files under `STATE_DIR`, temporary files under `${TMPDIR:-/tmp}`, backups next to managed files, and marker-bounded managed file replacements. `remove_path_under_prefix` refuses to remove paths outside `PREFIX`.

## Reuse And Skip Behavior

`stamp_matches` and `write_stamp` provide the common install-stamp contract. `install_archive_component` skips when a matching stamp and destination directory exist. Existing destination directories without matching stamps are preserved unless `--force-rebuild` is used.

## Dry Run And Force Rebuild

Dry runs print downloads, extracts, command execution, stamps, directory creation, and managed block updates without changing files. `--force-rebuild` allows source re-extraction and managed archive-component replacement under the prefix.
