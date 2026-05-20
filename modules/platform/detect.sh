detect_platform() {
	local raw_os raw_arch
	raw_os=$(uname -s 2>/dev/null || true)
	raw_arch=$(uname -m 2>/dev/null || true)

	case "$raw_os" in
		Darwin)
			OS_NAME="darwin"
			MINIFORGE_OS="MacOSX"
			SHLIB_EXT="dylib"
			;;
		Linux)
			OS_NAME="linux"
			MINIFORGE_OS="Linux"
			SHLIB_EXT="so"
			;;
		*)
			die "Unsupported OS: ${raw_os:-unknown}. Supported: macOS and Linux."
			;;
	esac

	case "$raw_arch" in
		x86_64|amd64)
			ARCH_NAME="x86_64"
			MINIFORGE_ARCH="x86_64"
			;;
		arm64)
			ARCH_NAME="arm64"
			MINIFORGE_ARCH="arm64"
			[ "$OS_NAME" = "darwin" ] || MINIFORGE_ARCH="aarch64"
			;;
		aarch64)
			ARCH_NAME="aarch64"
			MINIFORGE_ARCH="aarch64"
			[ "$OS_NAME" = "linux" ] || die "Unsupported macOS architecture: $raw_arch"
			;;
		*)
			die "Unsupported architecture: ${raw_arch:-unknown}. Supported: x86_64 and arm64/aarch64."
			;;
	esac
}

detect_jobs() {
	local detected
	if [ -n "$JOBS" ]; then
		case "$JOBS" in
			''|*[!0-9]*) die "--jobs must be a positive integer: $JOBS" ;;
		esac
		[ "$JOBS" -gt 0 ] || die "--jobs must be greater than zero"
		return
	fi

	detected=""
	if command_exists getconf; then
		detected=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
	fi
	if [ -z "$detected" ] && command_exists sysctl; then
		detected=$(sysctl -n hw.ncpu 2>/dev/null || true)
	fi
	case "$detected" in
		''|*[!0-9]*) JOBS=1 ;;
		*) JOBS=$detected ;;
	esac
	[ "$JOBS" -gt 0 ] || JOBS=1
}

find_compiler() {
	if [ -n "${CC:-}" ]; then
		if command_exists "$CC"; then
			CC_BIN=$CC
			return
		fi
		die "CC is set but not executable: $CC"
	fi

	if command_exists cc; then
		CC_BIN=cc
	elif command_exists gcc; then
		CC_BIN=gcc
	elif command_exists clang; then
		CC_BIN=clang
	else
		die "Missing C compiler. Install or expose cc, gcc, or clang before running this no-sudo bootstrap."
	fi
}

verify_compiler_works() {
	local tmp
	if [ "$DRY_RUN" -eq 1 ]; then
		return
	fi

	tmp=$(make_temp_dir)
	printf 'int main(void) { return 0; }\n' > "$tmp/test.c"
	if ! "$CC_BIN" "$tmp/test.c" -o "$tmp/test" >/dev/null 2>&1; then
		rm -rf "$tmp"
		die "C compiler exists but cannot build a trivial program: $CC_BIN"
	fi
	rm -rf "$tmp"
}

check_prerequisites() {
	local missing tool

	missing=""
	for tool in tar sed awk grep cmp cat cp mv rm mkdir chmod date mktemp uname env; do
		if ! command_exists "$tool"; then
			missing="$missing $tool"
		fi
	done

	if [ -n "$missing" ]; then
		die "Missing required tool(s):$missing"
	fi

	if [ "$OS_NAME" = "darwin" ] && ! command_exists xz; then
		warn "xz command not found; relying on macOS tar/libarchive support for zsh .tar.xz extraction."
	fi
}

ensure_native_build_tools() {
	local missing tool
	if [ "$NATIVE_BUILD_TOOLS_CHECKED" -eq 1 ]; then
		return
	fi

	missing=""
	for tool in make; do
		if ! command_exists "$tool"; then
			missing="$missing $tool"
		fi
	done
	if [ -n "$missing" ]; then
		die "Missing required native build tool(s):$missing"
	fi

	find_compiler
	verify_compiler_works
	NATIVE_BUILD_TOOLS_CHECKED=1
}
