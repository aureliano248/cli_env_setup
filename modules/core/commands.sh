ensure_dir() {
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: mkdir -p $1"
	else
		mkdir -p "$1"
	fi
}

run_cmd() {
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: $(format_args "$@")"
	else
		"$@"
	fi
}

run_in_dir() {
	local dir
	dir=$1
	shift
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: (cd $(shell_quote "$dir") && $(format_args "$@"))"
	else
		(cd "$dir" && "$@")
	fi
}
