zsh_version_matches() {
	[ -x "$1" ] || return 1
	"$1" --version 2>/dev/null | grep -q "zsh $ZSH_VERSION"
}

find_reusable_zsh() {
	local found
	if [ -x "$PREFIX/bin/zsh" ]; then
		printf '%s\n' "$PREFIX/bin/zsh"
		return 0
	fi
	found=$(command -v zsh 2>/dev/null || true)
	if [ -n "$found" ] && zsh_version_matches "$found"; then
		printf '%s\n' "$found"
		return 0
	fi
	return 1
}

build_zsh() {
	local existing src
	if [ "$FORCE_REBUILD" -eq 0 ]; then
		existing=$(find_reusable_zsh || true)
		if [ -n "$existing" ]; then
			SELECTED_ZSH_BIN=$existing
			if [ "$existing" = "$PREFIX/bin/zsh" ] && ! zsh_version_matches "$existing"; then
				warn "Existing zsh found under prefix; leaving it in place: $existing"
				warn "Re-run with --force-rebuild to replace it with zsh $ZSH_VERSION."
			else
				log "zsh already available at $existing; skipping build."
				if [ "$existing" = "$PREFIX/bin/zsh" ] && ! stamp_matches "zsh" "$ZSH_VERSION"; then
					write_stamp "zsh" "$ZSH_VERSION"
				fi
			fi
			return
		fi
	fi
	# Preserve any prefix zsh that is not a verified reusable executable.
	if [ "$FORCE_REBUILD" -eq 0 ] && [ -e "$PREFIX/bin/zsh" ]; then
		warn "Existing non-executable zsh path found under prefix; leaving it in place: $PREFIX/bin/zsh"
		warn "Re-run with --force-rebuild to replace it."
		return
	fi

	ensure_native_build_tools
	if [ "$OS_NAME" = "linux" ] && ! command_exists xz; then
		die "Missing required tool for zsh .tar.xz extraction: xz"
	fi
	src="$SOURCE_DIR/zsh-$ZSH_VERSION"
	fetch_source "zsh" "$ZSH_URL" "zsh-$ZSH_VERSION.tar.xz" "$src"
	run_in_dir "$src" env CC="$CC_BIN" CPPFLAGS="$(common_cppflags)" LDFLAGS="$(common_ldflags)" PKG_CONFIG_PATH="$(common_pkg_config_path)" LIBS="-lncursesw" ./configure \
		--prefix="$PREFIX" \
		--enable-multibyte \
		--enable-function-subdirs \
		--enable-fndir="$PREFIX/share/zsh/functions" \
		--enable-site-fndir="$PREFIX/share/zsh/site-functions" \
		--enable-scriptdir="$PREFIX/share/zsh/scripts"
	run_in_dir "$src" make -j "$JOBS"
	run_in_dir "$src" make install
	write_stamp "zsh" "$ZSH_VERSION"
	# Later profile configuration uses this path for login-shell handoff.
	SELECTED_ZSH_BIN="$PREFIX/bin/zsh"
}
