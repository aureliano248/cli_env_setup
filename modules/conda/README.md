# Conda Module

This module owns Miniforge installation and conda configuration.

- `miniforge.sh` installs Miniforge, checks the bootstrap stamp, and writes `.condarc`.

Keep conda-specific files and installer behavior here. Reuse an existing conda when one is present, and only manage `.condarc` for the bootstrap-owned Miniforge.
