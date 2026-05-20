# SSH Module

## Scope

`ssh/` owns optional SSH public key setup. It validates accepted public key prefixes and appends a user-pasted public key to `authorized_keys`.

## Files

- `authorized-keys.sh`: validates key format and performs optional interactive setup.

## Entry Functions

- `configure_ssh_key`: handles skip logic, prompt flow, validation, backups, append, and permissions.
- `is_valid_ssh_public_key`: validates supported public key prefixes.

## Inputs

Important inputs are `HOME`, `NO_SSH_KEY`, `DRY_RUN`, `ASSUME_YES`, stdin interactivity, and the pasted public key line.

## Outputs

This module sets no globals for later modules.

## Writes

Possible writes include `$HOME/.ssh`, `$HOME/.ssh/authorized_keys`, permissions on those paths, and timestamped backups through `core/managed-files.sh`.

## Reuse And Skip Behavior

The module skips when `--no-ssh-key` is set, during dry runs, when stdin is not interactive, when the prompt is declined, or when the pasted key is empty. Existing matching keys are not duplicated.

## Dry Run And Force Rebuild

Dry runs only report the optional write. `--force-rebuild` does not affect SSH key behavior.
