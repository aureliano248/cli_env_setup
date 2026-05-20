# Tmux Module

## Scope

`tmux/` owns tmux and the native dependency builders for the terminal toolchain. It builds ncurses and libevent under the prefix when needed. zsh uses ncurses from this module when zsh must be built from source.

## Files

- `deps.sh`: detects/builds ncurses and libevent.
- `tmux.sh`: finds a reusable tmux or builds tmux from source.

## Entry Functions

- `build_ncurses`: installs ncurses when needed by source-built zsh or tmux.
- `build_libevent`: installs libevent when needed by source-built tmux.
- `build_tmux`: selects or builds tmux and sets `SELECTED_TMUX_BIN`.

## Inputs

Important inputs are `PREFIX`, `SOURCE_DIR`, `STATE_DIR`, `NCURSES_VERSION`, `LIBEVENT_VERSION`, `TMUX_VERSION`, `NCURSES_URL`, `LIBEVENT_URL`, `TMUX_URL`, `SHLIB_EXT`, `JOBS`, `CC_BIN`, `DRY_RUN`, and `FORCE_REBUILD`.

## Outputs

`build_tmux` sets `SELECTED_TMUX_BIN`. Dependency builders write install stamps for `ncurses` and `libevent`.

## Writes

Possible writes include `$PREFIX/include`, `$PREFIX/lib`, `$PREFIX/lib/pkgconfig`, `$PREFIX/bin/tmux`, source trees under `SOURCE_DIR`, and install stamps under `STATE_DIR`.

## Reuse And Skip Behavior

ncurses is skipped when a matching stamp and library files exist, when prefix ncurses files are preserved without `--force-rebuild`, or when both zsh and tmux are already reusable. libevent is skipped when a matching stamp and library files exist, when prefix libevent files are preserved, or when tmux is already reusable. tmux is reused from `$PREFIX/bin/tmux` or a host `tmux` matching the pinned version.

## Dry Run And Force Rebuild

Dry runs print downloads, extracts, configure commands, builds, installs, and stamps. `--force-rebuild` allows replacement of managed prefix dependency files and tmux.
