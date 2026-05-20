state_file() {
	printf '%s/%s.version\n' "$STATE_DIR" "$1"
}

stamp_matches() {
	local file
	file=$(state_file "$1")
	[ -f "$file" ] || return 1
	[ "$(sed -n '1p' "$file")" = "$2" ]
}

write_stamp() {
	local file
	file=$(state_file "$1")
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: write stamp $file = $2"
		return
	fi
	mkdir -p "$STATE_DIR"
	printf '%s\n' "$2" > "$file"
}

remove_path_under_prefix() {
	case "$1" in
		"$PREFIX"/*)
			run_cmd rm -rf "$1"
			;;
		*)
			die "Refusing to remove path outside prefix: $1"
			;;
	esac
}

file_exists_any() {
	local path
	for path in "$@"; do
		if [ -e "$path" ]; then
			return 0
		fi
	done
	return 1
}

download_file() {
	local url output
	url=$1
	output=$2

	if [ -f "$output" ]; then
		log "Using cached archive: $output"
		return
	fi

	ensure_dir "${output%/*}"
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: download $url -> $output"
		return
	fi

	log "Downloading $url"
	if command_exists curl; then
		curl -fL --retry 3 --connect-timeout 30 -o "$output" "$url"
	elif command_exists wget; then
		wget --tries=3 -O "$output" "$url"
	else
		die "Missing required download tool: curl or wget"
	fi
}

unpack_archive() {
	local archive dest tmp first
	archive=$1
	dest=$2

	if [ -d "$dest" ] && [ "$FORCE_REBUILD" -eq 0 ]; then
		log "Using existing source directory: $dest"
		return
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: extract $archive -> $dest"
		return
	fi

	remove_path_under_prefix "$dest"
	mkdir -p "${dest%/*}"
	tmp=$(make_temp_dir)
	tar -xf "$archive" -C "$tmp"
	set -- "$tmp"/*
	if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
		rm -rf "$tmp"
		die "Archive did not contain exactly one top-level directory: $archive"
	fi
	first=$1
	mv "$first" "$dest"
	rm -rf "$tmp"
}

fetch_source() {
	local name url archive dest
	name=$1
	url=$2
	archive=$3
	dest=$4
	download_file "$url" "$SOURCE_DIR/$archive"
	unpack_archive "$SOURCE_DIR/$archive" "$dest"
	log "Prepared $name source: $dest"
}

install_archive_component() {
	local component version url archive dest
	component=$1
	version=$2
	url=$3
	archive=$4
	dest=$5

	if [ "$FORCE_REBUILD" -eq 0 ] && stamp_matches "$component" "$version" && [ -d "$dest" ]; then
		log "$component $version already installed; skipping."
		return
	fi
	if [ "$FORCE_REBUILD" -eq 0 ] && [ -d "$dest" ]; then
		warn "Existing $component directory found; leaving it in place: $dest"
		warn "Re-run with --force-rebuild to replace it with $version."
		return
	fi

	download_file "$url" "$SOURCE_DIR/$archive"
	unpack_archive "$SOURCE_DIR/$archive" "$dest"
	write_stamp "$component" "$version"
}
