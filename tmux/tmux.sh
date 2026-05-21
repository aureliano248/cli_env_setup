tmux_version_matches() {
	[ -x "$1" ] || return 1
	"$1" -V 2>/dev/null | grep -q "tmux $TMUX_VERSION"
}

find_reusable_tmux() {
	local found
	if [ -x "$PREFIX/bin/tmux" ]; then
		printf '%s\n' "$PREFIX/bin/tmux"
		return 0
	fi
	found=$(command -v tmux 2>/dev/null || true)
	if [ -n "$found" ] && tmux_version_matches "$found"; then
		printf '%s\n' "$found"
		return 0
	fi
	return 1
}

build_tmux() {
	local existing src pkg_config_path cppflags ldflags
	if [ "$FORCE_REBUILD" -eq 0 ]; then
		existing=$(find_reusable_tmux || true)
		if [ -n "$existing" ]; then
			SELECTED_TMUX_BIN=$existing
			if [ "$existing" = "$PREFIX/bin/tmux" ] && ! tmux_version_matches "$existing"; then
				warn "Existing tmux found under prefix; leaving it in place: $existing"
				warn "Re-run with --force-rebuild to replace it with tmux $TMUX_VERSION."
			else
				log "tmux already available at $existing; skipping build."
				if [ "$existing" = "$PREFIX/bin/tmux" ] && ! stamp_matches "tmux" "$TMUX_VERSION"; then
					write_stamp "tmux" "$TMUX_VERSION"
				fi
			fi
			return
		fi
	fi
	# Preserve any prefix tmux that is not a verified reusable executable.
	if [ "$FORCE_REBUILD" -eq 0 ] && [ -e "$PREFIX/bin/tmux" ]; then
		warn "Existing non-executable tmux path found under prefix; leaving it in place: $PREFIX/bin/tmux"
		warn "Re-run with --force-rebuild to replace it."
		return
	fi

	ensure_native_build_tools
	src="$SOURCE_DIR/tmux-$TMUX_VERSION"
	cppflags=$(common_cppflags)
	ldflags=$(common_ldflags)
	pkg_config_path=$(common_pkg_config_path)

	fetch_source "tmux" "$TMUX_URL" "tmux-$TMUX_VERSION.tar.gz" "$src"
	run_in_dir "$src" env \
		CC="$CC_BIN" \
		YACC="$YACC_CMD" \
		PATH="$(native_build_path)" \
		CPPFLAGS="$cppflags" \
		LDFLAGS="$ldflags" \
		PKG_CONFIG_PATH="$pkg_config_path" \
		LIBEVENT_CFLAGS="-I$PREFIX/include" \
		LIBEVENT_LIBS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib -levent" \
		NCURSES_CFLAGS="-I$PREFIX/include -I$PREFIX/include/ncursesw" \
		NCURSES_LIBS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib -lncursesw" \
		LIBS="-lncursesw" \
		./configure --prefix="$PREFIX"
	run_in_dir "$src" env PATH="$(native_build_path)" make -j "$JOBS"
	run_in_dir "$src" make install
	write_stamp "tmux" "$TMUX_VERSION"
	SELECTED_TMUX_BIN="$PREFIX/bin/tmux"
}
