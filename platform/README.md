# Platform Module

## Scope

`platform/` owns host detection and prerequisite checks. It normalizes OS, architecture, build job count, compiler selection, and required command availability.

## Files

- `detect.sh`: defines platform detection, job detection, compiler/parser-generator checks, and prerequisite checks.

## Entry Functions

- `detect_platform`: sets normalized OS, architecture, shared-library extension, and Miniforge platform values.
- `detect_jobs`: validates or detects the build job count.
- `check_prerequisites`: verifies baseline commands required by the bootstrap.
- `ensure_native_build_tools`: finds a compiler and parser generator, verifies the compiler can build a trivial program, and checks native build tools.

## Inputs

Inputs are `JOBS`, optional `CC`, optional `YACC`, `DRY_RUN`, and host commands such as `uname`, `getconf`, `sysctl`, `cc`, `gcc`, `clang`, `yacc`, `bison`, and `byacc`.

## Outputs

This module sets `OS_NAME`, `ARCH_NAME`, `MINIFORGE_OS`, `MINIFORGE_ARCH`, `SHLIB_EXT`, `JOBS`, `CC_BIN`, `YACC_CMD`, and `NATIVE_BUILD_TOOLS_CHECKED`.

## Writes

Normal runs create a temporary compiler probe under `${TMPDIR:-/tmp}` and remove it. Dry runs skip the compiler probe.

## Reuse And Skip Behavior

`ensure_native_build_tools` runs only once per process by checking `NATIVE_BUILD_TOOLS_CHECKED`.

## Dry Run And Force Rebuild

Dry runs skip the compiler build probe. `--force-rebuild` does not affect platform detection.
