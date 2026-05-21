has_prefix_yacc() {
	[ -x "$PREFIX/bin/yacc" ]
}

is_byacc_installed() {
	stamp_matches "byacc" "$BYACC_VERSION" || return 1
	has_prefix_yacc
}

build_byacc() {
	local src
	if [ "$FORCE_REBUILD" -eq 0 ] && is_byacc_installed; then
		log "byacc $BYACC_VERSION already installed; using $PREFIX/bin/yacc."
		YACC_CMD="yacc"
		return
	fi
	if [ "$FORCE_REBUILD" -eq 0 ] && [ -e "$PREFIX/bin/yacc" ]; then
		warn "Existing non-executable yacc path found under prefix; leaving it in place: $PREFIX/bin/yacc"
		warn "Re-run with --force-rebuild to replace it with byacc $BYACC_VERSION."
		die "Missing usable parser generator for native source builds."
	fi

	ensure_c_build_tools
	src="$SOURCE_DIR/byacc-$BYACC_VERSION"
	fetch_source "byacc" "$BYACC_URL" "byacc-$BYACC_VERSION.tgz" "$src"
	run_in_dir "$src" env CC="$CC_BIN" ./configure --prefix="$PREFIX"
	run_in_dir "$src" make -j "$JOBS"
	run_in_dir "$src" make install
	write_stamp "byacc" "$BYACC_VERSION"
	YACC_CMD="yacc"
}
