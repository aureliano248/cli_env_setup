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

load_bootstrap_module modules/core/config.sh
load_bootstrap_module modules/core/logging.sh
load_bootstrap_module modules/core/paths.sh
load_bootstrap_module modules/core/commands.sh
load_bootstrap_module modules/cli/args.sh
load_bootstrap_module modules/platform/detect.sh
load_bootstrap_module modules/sources/urls.sh
load_bootstrap_module modules/sources/archive.sh
load_bootstrap_module modules/build/common.sh
load_bootstrap_module modules/build/native_tools.sh
load_bootstrap_module modules/files/managed.sh
load_bootstrap_module modules/conda/miniforge.sh
load_bootstrap_module modules/shell/oh_my_zsh.sh
load_bootstrap_module modules/shell/profile.sh
load_bootstrap_module modules/ssh/authorized_keys.sh
load_bootstrap_module modules/app/main.sh

main "$@"
