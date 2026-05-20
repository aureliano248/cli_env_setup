# Build Module

This module builds source-based native dependencies under the configured prefix.

- `common.sh` defines shared compiler and linker flags.
- `native_tools.sh` builds ncurses, libevent, zsh, and tmux.

Build functions should remain idempotent by checking stamps, prefix files, and reusable host tools before doing work.
