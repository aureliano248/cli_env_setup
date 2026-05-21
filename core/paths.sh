command_exists() {
	command -v "$1" >/dev/null 2>&1
}

command_path() {
	local found
	found=$(command -v "$1" 2>/dev/null || true)
	case "$found" in
		*/*)
			[ -x "$found" ] || return 1
			printf '%s\n' "$found"
			;;
		*)
			return 1
			;;
	esac
}

absolute_path() {
	case "$1" in
		/*) printf '%s\n' "$1" ;;
		*) printf '%s/%s\n' "$(pwd)" "$1" ;;
	esac
}

strip_trailing_slash() {
	case "$1" in
		/) printf '/\n' ;;
		*/) printf '%s\n' "${1%/}" ;;
		*) printf '%s\n' "$1" ;;
	esac
}

shell_quote() {
	case "$1" in
		'') printf "''\n" ;;
		*) printf "'%s'\n" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;;
	esac
}

format_args() {
	local arg out quoted
	out=""
	for arg in "$@"; do
		quoted=$(shell_quote "$arg")
		if [ -z "$out" ]; then
			out=$quoted
		else
			out="$out $quoted"
		fi
	done
	printf '%s\n' "$out"
}

make_temp_dir() {
	mktemp -d "${TMPDIR:-/tmp}/bootstrap_env.XXXXXX"
}
