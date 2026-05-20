backup_file() {
	local file backup
	file=$1
	[ -f "$file" ] || return 0
	backup="$file.bootstrap_env.bak.$BACKUP_SUFFIX"
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: backup $file -> $backup"
		return
	fi
	if [ ! -e "$backup" ]; then
		cp -p "$file" "$backup"
	fi
}

write_managed_block() {
	local file start end block_file tmpdir body new
	file=$1
	start=$2
	end=$3
	block_file=$4

	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: update managed block in $file"
		return
	fi

	tmpdir=$(make_temp_dir)
	body="$tmpdir/body"
	new="$tmpdir/new"

	if [ -f "$file" ]; then
		if ! awk -v start="$start" -v end="$end" '
			$0 == start {
				if (skip) {
					bad = 1
				}
				skip = 1
				next
			}
			$0 == end {
				if (!skip) {
					bad = 1
				}
				skip = 0
				next
			}
			bad { next }
			skip { next }
			{ lines[++n] = $0 }
			END {
				if (bad || skip) {
					exit 2
				}
				while (n > 0 && lines[n] == "") {
					n--
				}
				for (i = 1; i <= n; i++) {
					print lines[i]
				}
			}
		' "$file" > "$body"; then
			rm -rf "$tmpdir"
			die "Malformed managed block markers in $file"
		fi
	else
		: > "$body"
	fi

	{
		if [ -s "$body" ]; then
			cat "$body"
			printf '\n\n'
		fi
		printf '%s\n' "$start"
		cat "$block_file"
		printf '%s\n' "$end"
	} > "$new"

	if [ -f "$file" ] && cmp -s "$new" "$file"; then
		rm -rf "$tmpdir"
		log "Managed block already current: $file"
		return
	fi

	backup_file "$file"
	if [ -f "$file" ]; then
		cp "$new" "$file"
		rm -f "$new"
	else
		mv "$new" "$file"
	fi
	rm -rf "$tmpdir"
	log "Updated managed block: $file"
}
