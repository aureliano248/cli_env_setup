# Core Module

This module contains shared state and small utilities used across the bootstrap.

- `config.sh` defines version pins and mutable global settings.
- `logging.sh` provides message and error helpers.
- `paths.sh` contains path, quoting, command lookup, and temp directory helpers.
- `commands.sh` wraps command execution for normal and dry-run modes.

Keep these helpers generic. Domain-specific behavior belongs in the owning module.
