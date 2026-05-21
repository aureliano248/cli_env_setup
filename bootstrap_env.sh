#!/usr/bin/env bash
#
# Bootstrap a no-sudo CLI environment under a user-owned prefix.
# Supports macOS and Ubuntu-style Linux with Bash 3.2 compatible syntax.

set -euo pipefail
IFS='
	'

BOOTSTRAP_ENV_SCRIPT=${BASH_SOURCE[0]}
case "$BOOTSTRAP_ENV_SCRIPT" in
	*/*) BOOTSTRAP_ENV_DIR=${BOOTSTRAP_ENV_SCRIPT%/*} ;;
	*) BOOTSTRAP_ENV_DIR=. ;;
esac
[ -n "$BOOTSTRAP_ENV_DIR" ] || BOOTSTRAP_ENV_DIR=/

BOOTSTRAP_ENV_ROOT=$(CDPATH= cd "$BOOTSTRAP_ENV_DIR" && pwd) || {
	printf 'ERROR: unable to resolve bootstrap_env.sh directory\n' >&2
	exit 1
}

load_bootstrap_module() {
	local module
	module=$1
	if [ ! -r "$BOOTSTRAP_ENV_ROOT/$module" ]; then
		printf 'ERROR: missing bootstrap module: %s\n' "$BOOTSTRAP_ENV_ROOT/$module" >&2
		exit 1
	fi
	# shellcheck source=/dev/null
	. "$BOOTSTRAP_ENV_ROOT/$module"
}

# Load order is a maintenance contract: modules share one shell namespace.
# Keep providers before modules that call their functions or read their globals.
load_bootstrap_module core/config.sh
load_bootstrap_module core/logging.sh
load_bootstrap_module core/paths.sh
load_bootstrap_module core/commands.sh
load_bootstrap_module core/managed-files.sh
load_bootstrap_module core/urls.sh
load_bootstrap_module core/sources.sh
load_bootstrap_module core/build-flags.sh

load_bootstrap_module cli/args.sh
load_bootstrap_module platform/detect.sh
load_bootstrap_module platform/byacc.sh

load_bootstrap_module tmux/deps.sh
load_bootstrap_module zsh/zsh.sh
load_bootstrap_module tmux/tmux.sh
load_bootstrap_module conda/miniforge.sh
load_bootstrap_module zsh/oh-my-zsh.sh
load_bootstrap_module zsh/profile.sh
load_bootstrap_module ssh/authorized-keys.sh

load_bootstrap_module app/main.sh

main "$@"
