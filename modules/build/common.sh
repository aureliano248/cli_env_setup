common_cppflags() {
	printf '%s\n' "-I$PREFIX/include -I$PREFIX/include/ncursesw"
}

common_ldflags() {
	printf '%s\n' "-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
}

common_pkg_config_path() {
	if [ -n "${PKG_CONFIG_PATH:-}" ]; then
		printf '%s:%s\n' "$PREFIX/lib/pkgconfig" "$PKG_CONFIG_PATH"
	else
		printf '%s\n' "$PREFIX/lib/pkgconfig"
	fi
}
