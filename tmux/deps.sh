has_prefix_ncurses() {
	file_exists_any \
		"$PREFIX/lib/libncursesw.a" \
		"$PREFIX/lib/libncursesw.$SHLIB_EXT" \
		"$PREFIX/lib/libncursesw.so" \
		"$PREFIX/lib/libncursesw.dylib"
}

is_ncurses_installed() {
	stamp_matches "ncurses" "$NCURSES_VERSION" || return 1
	has_prefix_ncurses
}

build_ncurses() {
	local src
	# A matching stamp plus library files means this prefix owns ncurses.
	if [ "$FORCE_REBUILD" -eq 0 ] && is_ncurses_installed; then
		log "ncurses $NCURSES_VERSION already installed; skipping."
		return
	fi
	# Prefix files without a matching stamp are preserved unless forced.
	if [ "$FORCE_REBUILD" -eq 0 ] && has_prefix_ncurses; then
		warn "Existing ncurses files found under prefix; leaving them in place."
		warn "Re-run with --force-rebuild to replace them: $PREFIX/lib"
		return
	fi
	# ncurses is only needed when zsh or tmux must be built from source.
	if [ "$FORCE_REBUILD" -eq 0 ] && find_reusable_zsh >/dev/null 2>&1 && find_reusable_tmux >/dev/null 2>&1; then
		log "zsh and tmux are already available; skipping ncurses build."
		return
	fi

	ensure_native_build_tools
	src="$SOURCE_DIR/ncurses-$NCURSES_VERSION"
	fetch_source "ncurses" "$NCURSES_URL" "ncurses-$NCURSES_VERSION.tar.gz" "$src"
	run_in_dir "$src" env CC="$CC_BIN" YACC="$YACC_CMD" PATH="$(native_build_path)" ./configure \
		--prefix="$PREFIX" \
		--enable-widec \
		--with-shared \
		--without-debug \
		--without-ada \
		--enable-overwrite \
		--enable-pc-files \
		--with-pkg-config-libdir="$PREFIX/lib/pkgconfig"
	run_in_dir "$src" env PATH="$(native_build_path)" make -j "$JOBS"
	run_in_dir "$src" make install
	write_stamp "ncurses" "$NCURSES_VERSION"
}

has_prefix_libevent() {
	file_exists_any \
		"$PREFIX/lib/libevent.a" \
		"$PREFIX/lib/libevent.$SHLIB_EXT" \
		"$PREFIX/lib/libevent.so" \
		"$PREFIX/lib/libevent.dylib"
}

is_libevent_installed() {
	stamp_matches "libevent" "$LIBEVENT_VERSION" || return 1
	has_prefix_libevent
}

build_libevent() {
	local src
	# A matching stamp plus library files means this prefix owns libevent.
	if [ "$FORCE_REBUILD" -eq 0 ] && is_libevent_installed; then
		log "libevent $LIBEVENT_VERSION already installed; skipping."
		return
	fi
	# Prefix files without a matching stamp are preserved unless forced.
	if [ "$FORCE_REBUILD" -eq 0 ] && has_prefix_libevent; then
		warn "Existing libevent files found under prefix; leaving them in place."
		warn "Re-run with --force-rebuild to replace them: $PREFIX/lib"
		return
	fi
	# libevent is only needed when tmux must be built from source.
	if [ "$FORCE_REBUILD" -eq 0 ] && find_reusable_tmux >/dev/null 2>&1; then
		log "tmux is already available; skipping libevent build."
		return
	fi

	ensure_native_build_tools
	src="$SOURCE_DIR/libevent-$LIBEVENT_VERSION"
	fetch_source "libevent" "$LIBEVENT_URL" "libevent-$LIBEVENT_VERSION.tar.gz" "$src"
	run_in_dir "$src" env CC="$CC_BIN" YACC="$YACC_CMD" PATH="$(native_build_path)" CPPFLAGS="$(common_cppflags)" LDFLAGS="$(common_ldflags)" PKG_CONFIG_PATH="$(common_pkg_config_path)" ./configure \
		--prefix="$PREFIX" \
		--disable-openssl \
		--disable-samples
	run_in_dir "$src" env PATH="$(native_build_path)" make -j "$JOBS"
	run_in_dir "$src" make install
	write_stamp "libevent" "$LIBEVENT_VERSION"
}
