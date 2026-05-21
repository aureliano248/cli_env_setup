# Platform Module

## Scope

`platform/` owns host detection and prerequisite checks. It normalizes OS, architecture, build job count, compiler selection, and required command availability.

## Files

- `detect.sh`: defines platform detection, job detection, compiler/parser-generator checks, and prerequisite checks.
- `byacc.sh`: builds a prefix-owned yacc-compatible parser generator when the host does not provide one.

## Entry Functions

- `detect_platform`: sets normalized OS, architecture, shared-library extension, and Miniforge platform values.
- `detect_jobs`: validates or detects the build job count.
- `check_prerequisites`: verifies baseline commands required by the bootstrap.
- `ensure_c_build_tools`: finds a compiler, verifies it can build a trivial program, and checks base native build tools.
- `ensure_native_build_tools`: finds or builds a parser generator after base native build tools are available.
- `build_byacc`: installs byacc under the prefix and selects `$PREFIX/bin/yacc`.

## Inputs

Inputs are `JOBS`, optional `CC`, optional `YACC`, `DRY_RUN`, `FORCE_REBUILD`, `PREFIX`, `SOURCE_DIR`, `STATE_DIR`, and host commands such as `uname`, `getconf`, `sysctl`, `cc`, `gcc`, `clang`, `yacc`, `bison`, and `byacc`.

## Outputs

This module sets `OS_NAME`, `ARCH_NAME`, `MINIFORGE_OS`, `MINIFORGE_ARCH`, `SHLIB_EXT`, `JOBS`, `CC_BIN`, `YACC_CMD`, `C_BUILD_TOOLS_CHECKED`, and `NATIVE_BUILD_TOOLS_CHECKED`.

## Writes

Normal runs create a temporary compiler probe under `${TMPDIR:-/tmp}` and remove it. When no parser generator is available, normal runs may write byacc source/build files under `SOURCE_DIR`, `$PREFIX/bin/yacc`, and a byacc install stamp under `STATE_DIR`. Dry runs skip the compiler probe and print the byacc build commands.

## Reuse And Skip Behavior

`ensure_c_build_tools` and `ensure_native_build_tools` run only once per process by checking `C_BUILD_TOOLS_CHECKED` and `NATIVE_BUILD_TOOLS_CHECKED`. Host `yacc`, host `bison -y`, host `byacc`, and `$PREFIX/bin/yacc` are reused before source-building byacc, but host parser generators must resolve to real executable paths rather than shell aliases or functions.

## Dry Run And Force Rebuild

Dry runs skip the compiler build probe. `--force-rebuild` does not affect platform detection.
