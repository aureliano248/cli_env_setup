# Zsh Module

## Scope

`zsh/` owns zsh itself, Oh My Zsh, configured zsh plugins, `.zshrc`, and login profile zsh integration. It does not own ncurses; source-built zsh links against ncurses from `tmux/deps.sh`, which must be loaded and run before `build_zsh`.

## Files

- `zsh.sh`: finds a reusable zsh or builds zsh from source.
- `oh-my-zsh.sh`: finds or installs Oh My Zsh and installs configured plugins.
- `profile.sh`: chooses the login profile and writes managed `.zshrc` and login-shell blocks.

## Entry Functions

- `build_zsh`: selects or builds zsh and sets `SELECTED_ZSH_BIN`.
- `install_oh_my_zsh_and_plugins`: selects or installs Oh My Zsh and plugin directories.
- `choose_login_profile_file`: selects `$HOME/.bash_profile` or `$HOME/.profile`.
- `configure_zshrc`: writes the managed `.zshrc` block.
- `configure_login_profile`: writes the login-shell handoff block.

## Inputs

Important inputs are `PREFIX`, `SOURCE_DIR`, `STATE_DIR`, `ZSH_VERSION`, `ZSH_URL`, plugin version/URL globals, `HOME`, `LOGIN_PROFILE_FILE`, `SELECTED_CONDA_BIN`, `SELECTED_CONDA_SH`, `MANAGE_MINIFORGE_CONFIG`, `MINIFORGE_DIR`, `DRY_RUN`, and `FORCE_REBUILD`.

## Outputs

This module sets `SELECTED_ZSH_BIN`, `SELECTED_OMZ_DIR`, `SELECTED_ZSH_CUSTOM_DIR`, and `LOGIN_PROFILE_FILE`.

## Writes

Possible writes include `$PREFIX/bin/zsh`, `$PREFIX/share/zsh`, `$PREFIX/share/oh-my-zsh`, `$PREFIX/share/oh-my-zsh-custom/plugins/*`, install stamps under `STATE_DIR`, `$HOME/.zshrc`, and the selected login profile.

## Reuse And Skip Behavior

`build_zsh` reuses `$PREFIX/bin/zsh` when executable or a host `zsh` matching the pinned version. Existing prefix zsh paths that are not reusable are preserved unless `--force-rebuild` is used. `configure_zshrc` always writes the prefix `PATH` block, even when Oh My Zsh is not selected. Oh My Zsh is reused from the prefix, `$ZSH`, or `$HOME/.oh-my-zsh`; plugins are managed under the selected custom directory.

## Dry Run And Force Rebuild

Dry runs print downloads, extracts, builds, plugin installs, and managed file updates. `--force-rebuild` allows replacing bootstrap-managed prefix zsh and archive-installed shell assets.
