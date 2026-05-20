# Platform Module

This module detects the host platform and validates prerequisites.

- `detect.sh` maps OS and architecture names, chooses job count, finds a compiler, and checks required tools.

Keep platform-specific branching here so installers and builders can use normalized globals.
