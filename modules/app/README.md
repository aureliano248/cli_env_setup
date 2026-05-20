# App Module

This module owns the top-level bootstrap flow.

- `main.sh` calls argument parsing, platform setup, native builds, Miniforge setup, shell profile updates, and optional SSH key setup in order.

Keep orchestration here. Put implementation details in the domain module that owns the behavior.
