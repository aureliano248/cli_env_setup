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
	if [ "$FORCE_REBUILD" -eq 0 ] && is_ncurses_installed; then
		log "ncurses $NCURSES_VERSION already installed; skipping."
		return
	fi
	if [ "$FORCE_REBUILD" -eq 0 ] && has_prefix_ncurses; then
		warn "Existing ncurses files found under prefix; leaving them in place."
		warn "Re-run with --force-rebuild to replace them: $PREFIX/lib"
		return
	fi
	if [ "$FORCE_REBUILD" -eq 0 ] && find_reusable_zsh >/dev/null 2>&1 && find_reusable_tmux >/dev/null 2>&1; then
		log "zsh and tmux are already available; skipping ncurses build."
		return
	fi

	ensure_native_build_tools
	src="$SOURCE_DIR/ncurses-$NCURSES_VERSION"
	fetch_source "ncurses" "$NCURSES_URL" "ncurses-$NCURSES_VERSION.tar.gz" "$src"
	run_in_dir "$src" env CC="$CC_BIN" ./configure \
		--prefix="$PREFIX" \
		--enable-widec \
		--with-shared \
		--without-debug \
		--without-ada \
		--enable-overwrite \
		--enable-pc-files \
		--with-pkg-config-libdir="$PREFIX/lib/pkgconfig"
	run_in_dir "$src" make -j "$JOBS"
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
	if [ "$FORCE_REBUILD" -eq 0 ] && is_libevent_installed; then
		log "libevent $LIBEVENT_VERSION already installed; skipping."
		return
	fi
	if [ "$FORCE_REBUILD" -eq 0 ] && has_prefix_libevent; then
		warn "Existing libevent files found under prefix; leaving them in place."
		warn "Re-run with --force-rebuild to replace them: $PREFIX/lib"
		return
	fi
	if [ "$FORCE_REBUILD" -eq 0 ] && find_reusable_tmux >/dev/null 2>&1; then
		log "tmux is already available; skipping libevent build."
		return
	fi

	ensure_native_build_tools
	src="$SOURCE_DIR/libevent-$LIBEVENT_VERSION"
	fetch_source "libevent" "$LIBEVENT_URL" "libevent-$LIBEVENT_VERSION.tar.gz" "$src"
	run_in_dir "$src" env CC="$CC_BIN" CPPFLAGS="$(common_cppflags)" LDFLAGS="$(common_ldflags)" PKG_CONFIG_PATH="$(common_pkg_config_path)" ./configure \
		--prefix="$PREFIX" \
		--disable-openssl \
		--disable-samples
	run_in_dir "$src" make -j "$JOBS"
	run_in_dir "$src" make install
	write_stamp "libevent" "$LIBEVENT_VERSION"
}

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
	SELECTED_ZSH_BIN="$PREFIX/bin/zsh"
}

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
		CPPFLAGS="$cppflags" \
		LDFLAGS="$ldflags" \
		PKG_CONFIG_PATH="$pkg_config_path" \
		LIBEVENT_CFLAGS="-I$PREFIX/include" \
		LIBEVENT_LIBS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib -levent" \
		NCURSES_CFLAGS="-I$PREFIX/include -I$PREFIX/include/ncursesw" \
		NCURSES_LIBS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib -lncursesw" \
		LIBS="-lncursesw" \
		./configure --prefix="$PREFIX"
	run_in_dir "$src" make -j "$JOBS"
	run_in_dir "$src" make install
	write_stamp "tmux" "$TMUX_VERSION"
	SELECTED_TMUX_BIN="$PREFIX/bin/tmux"
}
