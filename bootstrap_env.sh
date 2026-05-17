#!/usr/bin/env bash
#
# Bootstrap a no-sudo CLI environment under a user-owned prefix.
# Supports macOS and Ubuntu-style Linux with Bash 3.2 compatible syntax.

set -euo pipefail
IFS='
	'

SCRIPT_NAME=${0##*/}

ZSH_VERSION="5.9"
NCURSES_VERSION="6.5"
LIBEVENT_VERSION="2.1.12-stable"
TMUX_VERSION="3.6a"
MINIFORGE_VERSION="26.1.1-3"

OMZ_COMMIT="3604dc23e0d95b5ce9a3932838a7b103ef5ff0c1"
ZSH_AUTOSUGGESTIONS_VERSION="v0.7.1"
ZSH_COMPLETIONS_VERSION="0.36.0"
ZSH_SYNTAX_HIGHLIGHTING_VERSION="0.8.0"

DRY_RUN=0
FORCE_REBUILD=0
ASSUME_YES=0
NO_SSH_KEY=0

OS_NAME=""
ARCH_NAME=""
MINIFORGE_OS=""
MINIFORGE_ARCH=""
SHLIB_EXT=""
CC_BIN=""

PREFIX=""
JOBS=""
SOURCE_DIR=""
STATE_DIR=""
MINIFORGE_DIR=""
LOGIN_PROFILE_FILE=""
BACKUP_SUFFIX=""

ZSH_URL=""
NCURSES_URL=""
LIBEVENT_URL=""
TMUX_URL=""
MINIFORGE_URL=""
OMZ_URL=""
ZSH_AUTOSUGGESTIONS_URL=""
ZSH_COMPLETIONS_URL=""
ZSH_SYNTAX_HIGHLIGHTING_URL=""

log() {
	printf '%s\n' "$*"
}

warn() {
	printf 'WARN: %s\n' "$*" >&2
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<USAGE
Usage: bash $SCRIPT_NAME [--prefix DIR] [--jobs N] [--dry-run] [--force-rebuild] [--yes] [--no-ssh-key]

Install a no-sudo CLI environment under \${BOOTSTRAP_PREFIX:-\$HOME/.local}.

Options:
  --prefix DIR       Install root. Defaults to BOOTSTRAP_PREFIX or \$HOME/.local.
  --jobs N           Parallel build jobs. Defaults to BOOTSTRAP_JOBS or CPU count.
  --dry-run          Print detected platform, URLs, and planned writes without changing files.
  --force-rebuild    Re-extract and rebuild managed source components.
  --yes              Assume yes for optional prompts; SSH still requires a pasted key.
  --no-ssh-key       Skip SSH authorized_keys setup.
  -h, --help         Show this help.

Installed versions:
  zsh $ZSH_VERSION
  ncurses $NCURSES_VERSION
  libevent $LIBEVENT_VERSION
  tmux $TMUX_VERSION
  Miniforge $MINIFORGE_VERSION
  Oh My Zsh $OMZ_COMMIT
  zsh-autosuggestions $ZSH_AUTOSUGGESTIONS_VERSION
  zsh-completions $ZSH_COMPLETIONS_VERSION
  zsh-syntax-highlighting $ZSH_SYNTAX_HIGHLIGHTING_VERSION
USAGE
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
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

ensure_dir() {
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: mkdir -p $1"
	else
		mkdir -p "$1"
	fi
}

run_cmd() {
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: $(format_args "$@")"
	else
		"$@"
	fi
}

run_in_dir() {
	local dir
	dir=$1
	shift
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: (cd $(shell_quote "$dir") && $(format_args "$@"))"
	else
		(cd "$dir" && "$@")
	fi
}

parse_args() {
	if [ -z "${HOME:-}" ]; then
		die "HOME is not set"
	fi

	PREFIX=${BOOTSTRAP_PREFIX:-"$HOME/.local"}
	JOBS=${BOOTSTRAP_JOBS:-}

	while [ "$#" -gt 0 ]; do
		case "$1" in
			--prefix)
				shift
				[ "$#" -gt 0 ] || die "--prefix requires a directory"
				PREFIX=$1
				;;
			--prefix=*)
				PREFIX=${1#--prefix=}
				;;
			--jobs)
				shift
				[ "$#" -gt 0 ] || die "--jobs requires a positive integer"
				JOBS=$1
				;;
			--jobs=*)
				JOBS=${1#--jobs=}
				;;
			--dry-run)
				DRY_RUN=1
				;;
			--force-rebuild)
				FORCE_REBUILD=1
				;;
			--yes)
				ASSUME_YES=1
				;;
			--no-ssh-key)
				NO_SSH_KEY=1
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				die "Unknown option: $1"
				;;
		esac
		shift
	done

	[ -n "$PREFIX" ] || die "Install prefix cannot be empty"
	PREFIX=$(absolute_path "$PREFIX")
	PREFIX=$(strip_trailing_slash "$PREFIX")

	case "$PREFIX" in
		*[![:print:]]*) die "Prefix contains non-printable characters: $PREFIX" ;;
	esac
	case "$PREFIX" in
		*[[:space:]]*) die "Prefix paths containing whitespace are not supported by autotools builds: $PREFIX" ;;
	esac
	case "$PREFIX" in
		*:*) die "Prefix paths containing ':' are not supported because PATH-style variables use ':' separators: $PREFIX" ;;
	esac
	case "$PREFIX" in
		/) die "Refusing to use / as the install prefix" ;;
	esac

	SOURCE_DIR="$PREFIX/source"
	STATE_DIR="$PREFIX/.bootstrap_env/state"
	MINIFORGE_DIR="$PREFIX/miniforge3"
	BACKUP_SUFFIX=$(date +%Y%m%d%H%M%S)
}

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

choose_login_profile_file() {
	if [ -f "$HOME/.bash_profile" ]; then
		LOGIN_PROFILE_FILE="$HOME/.bash_profile"
	else
		LOGIN_PROFILE_FILE="$HOME/.profile"
	fi
}

set_urls() {
	ZSH_URL="https://downloads.sourceforge.net/project/zsh/zsh/$ZSH_VERSION/zsh-$ZSH_VERSION.tar.xz"
	NCURSES_URL="https://ftp.gnu.org/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz"
	LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_VERSION/libevent-$LIBEVENT_VERSION.tar.gz"
	TMUX_URL="https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz"
	MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/$MINIFORGE_VERSION/Miniforge3-$MINIFORGE_VERSION-$MINIFORGE_OS-$MINIFORGE_ARCH.sh"
	OMZ_URL="https://github.com/ohmyzsh/ohmyzsh/archive/$OMZ_COMMIT.tar.gz"
	ZSH_AUTOSUGGESTIONS_URL="https://github.com/zsh-users/zsh-autosuggestions/archive/refs/tags/$ZSH_AUTOSUGGESTIONS_VERSION.tar.gz"
	ZSH_COMPLETIONS_URL="https://github.com/zsh-users/zsh-completions/archive/refs/tags/$ZSH_COMPLETIONS_VERSION.tar.gz"
	ZSH_SYNTAX_HIGHLIGHTING_URL="https://github.com/zsh-users/zsh-syntax-highlighting/archive/refs/tags/$ZSH_SYNTAX_HIGHLIGHTING_VERSION.tar.gz"
}

print_summary() {
	log "Target platform: $OS_NAME/$ARCH_NAME"
	log "Install prefix: $PREFIX"
	log "Source cache: $SOURCE_DIR"
	log "Build jobs: $JOBS"
	if [ "$DRY_RUN" -eq 1 ]; then
		log ""
		log "DRY-RUN source URLs:"
		log "  zsh: $ZSH_URL"
		log "  ncurses: $NCURSES_URL"
		log "  libevent: $LIBEVENT_URL"
		log "  tmux: $TMUX_URL"
		log "  Miniforge: $MINIFORGE_URL"
		log "  Oh My Zsh: $OMZ_URL"
		log "  zsh-autosuggestions: $ZSH_AUTOSUGGESTIONS_URL"
		log "  zsh-completions: $ZSH_COMPLETIONS_URL"
		log "  zsh-syntax-highlighting: $ZSH_SYNTAX_HIGHLIGHTING_URL"
		log ""
		log "DRY-RUN managed files:"
		log "  $HOME/.zshrc"
		log "  $LOGIN_PROFILE_FILE"
		log "  $MINIFORGE_DIR/.condarc"
		log "  $HOME/.ssh/authorized_keys (optional)"
	fi
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

	find_compiler

	missing=""
	for tool in make tar sed awk grep cmp cat cp mv rm mkdir chmod date mktemp uname env; do
		if ! command_exists "$tool"; then
			missing="$missing $tool"
		fi
	done

	if ! command_exists curl && ! command_exists wget; then
		missing="$missing curl-or-wget"
	fi

	if [ "$OS_NAME" = "linux" ] && ! command_exists xz; then
		missing="$missing xz"
	fi

	if [ -n "$missing" ]; then
		die "Missing required tool(s):$missing"
	fi

	verify_compiler_works

	if [ "$OS_NAME" = "darwin" ] && ! command_exists xz; then
		warn "xz command not found; relying on macOS tar/libarchive support for zsh .tar.xz extraction."
	fi
}

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
	else
		wget --tries=3 -O "$output" "$url"
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

is_ncurses_installed() {
	stamp_matches "ncurses" "$NCURSES_VERSION" || return 1
	file_exists_any \
		"$PREFIX/lib/libncursesw.a" \
		"$PREFIX/lib/libncursesw.$SHLIB_EXT" \
		"$PREFIX/lib/libncursesw.so" \
		"$PREFIX/lib/libncursesw.dylib"
}

build_ncurses() {
	local src
	if [ "$FORCE_REBUILD" -eq 0 ] && is_ncurses_installed; then
		log "ncurses $NCURSES_VERSION already installed; skipping."
		return
	fi

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

is_libevent_installed() {
	stamp_matches "libevent" "$LIBEVENT_VERSION" || return 1
	file_exists_any \
		"$PREFIX/lib/libevent.a" \
		"$PREFIX/lib/libevent.$SHLIB_EXT" \
		"$PREFIX/lib/libevent.so" \
		"$PREFIX/lib/libevent.dylib"
}

build_libevent() {
	local src
	if [ "$FORCE_REBUILD" -eq 0 ] && is_libevent_installed; then
		log "libevent $LIBEVENT_VERSION already installed; skipping."
		return
	fi

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

is_zsh_installed() {
	stamp_matches "zsh" "$ZSH_VERSION" || return 1
	[ -x "$PREFIX/bin/zsh" ] || return 1
	"$PREFIX/bin/zsh" --version 2>/dev/null | grep -q "zsh $ZSH_VERSION"
}

build_zsh() {
	local src
	if [ "$FORCE_REBUILD" -eq 0 ] && is_zsh_installed; then
		log "zsh $ZSH_VERSION already installed; skipping."
		return
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
}

is_tmux_installed() {
	stamp_matches "tmux" "$TMUX_VERSION" || return 1
	[ -x "$PREFIX/bin/tmux" ] || return 1
	"$PREFIX/bin/tmux" -V 2>/dev/null | grep -q "tmux $TMUX_VERSION"
}

build_tmux() {
	local src pkg_config_path cppflags ldflags
	if [ "$FORCE_REBUILD" -eq 0 ] && is_tmux_installed; then
		log "tmux $TMUX_VERSION already installed; skipping."
		return
	fi

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

	download_file "$url" "$SOURCE_DIR/$archive"
	unpack_archive "$SOURCE_DIR/$archive" "$dest"
	write_stamp "$component" "$version"
}

install_oh_my_zsh_and_plugins() {
	local omz_dir custom_plugins
	omz_dir="$PREFIX/share/oh-my-zsh"
	custom_plugins="$omz_dir/custom/plugins"

	install_archive_component "oh-my-zsh" "$OMZ_COMMIT" "$OMZ_URL" "oh-my-zsh-$OMZ_COMMIT.tar.gz" "$omz_dir"

	ensure_dir "$custom_plugins"
	install_archive_component "zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_VERSION" "$ZSH_AUTOSUGGESTIONS_URL" \
		"zsh-autosuggestions-$ZSH_AUTOSUGGESTIONS_VERSION.tar.gz" \
		"$custom_plugins/zsh-autosuggestions"
	install_archive_component "zsh-completions" "$ZSH_COMPLETIONS_VERSION" "$ZSH_COMPLETIONS_URL" \
		"zsh-completions-$ZSH_COMPLETIONS_VERSION.tar.gz" \
		"$custom_plugins/zsh-completions"
	install_archive_component "zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_VERSION" "$ZSH_SYNTAX_HIGHLIGHTING_URL" \
		"zsh-syntax-highlighting-$ZSH_SYNTAX_HIGHLIGHTING_VERSION.tar.gz" \
		"$custom_plugins/zsh-syntax-highlighting"
}

is_miniforge_installed() {
	stamp_matches "miniforge" "$MINIFORGE_VERSION" || return 1
	[ -x "$MINIFORGE_DIR/bin/conda" ]
}

install_miniforge() {
	local installer
	if [ "$FORCE_REBUILD" -eq 0 ] && is_miniforge_installed; then
		log "Miniforge $MINIFORGE_VERSION already installed; skipping."
		return
	fi

	if [ -d "$MINIFORGE_DIR" ]; then
		if [ "$FORCE_REBUILD" -eq 1 ]; then
			remove_path_under_prefix "$MINIFORGE_DIR"
		else
			warn "Existing Miniforge directory found without matching bootstrap stamp: $MINIFORGE_DIR"
			warn "Leaving it in place. Re-run with --force-rebuild to replace it."
			return
		fi
	fi

	installer="$SOURCE_DIR/Miniforge3-$MINIFORGE_VERSION-$MINIFORGE_OS-$MINIFORGE_ARCH.sh"
	download_file "$MINIFORGE_URL" "$installer"
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: bash $installer -b -p $MINIFORGE_DIR"
	else
		bash "$installer" -b -p "$MINIFORGE_DIR"
	fi
	write_stamp "miniforge" "$MINIFORGE_VERSION"
}

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

write_condarc() {
	local file tmpdir tmp
	file="$MINIFORGE_DIR/.condarc"
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: write conda-forge-only config $file"
		return
	fi

	mkdir -p "$MINIFORGE_DIR"
	tmpdir=$(make_temp_dir)
	tmp="$tmpdir/condarc"
	cat > "$tmp" <<'EOF'
channels:
  - conda-forge
channel_priority: strict
auto_activate_base: false
EOF
	if [ -f "$file" ] && cmp -s "$tmp" "$file"; then
		rm -rf "$tmpdir"
		log "Conda config already current: $file"
		return
	fi
	backup_file "$file"
	mv "$tmp" "$file"
	rm -rf "$tmpdir"
	log "Wrote conda config: $file"
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

configure_zshrc() {
	local tmpdir block q_prefix start end
	start="# >>> bootstrap_env zsh managed block >>>"
	end="# <<< bootstrap_env zsh managed block <<<"

	if [ "$DRY_RUN" -eq 1 ]; then
		write_managed_block "$HOME/.zshrc" "$start" "$end" "/dev/null"
		return
	fi

	tmpdir=$(make_temp_dir)
	block="$tmpdir/zshrc.block"
	q_prefix=$(shell_quote "$PREFIX")

	cat > "$block" <<EOF
export BOOTSTRAP_PREFIX=$q_prefix
if [ -d "\$BOOTSTRAP_PREFIX/bin" ]; then
  case ":\$PATH:" in
    *":\$BOOTSTRAP_PREFIX/bin:"*) ;;
    *) export PATH="\$BOOTSTRAP_PREFIX/bin:\$PATH" ;;
  esac
fi

export ZSH="\$BOOTSTRAP_PREFIX/share/oh-my-zsh"
export ZSH_CUSTOM="\$ZSH/custom"
ZSH_THEME="robbyrussell"
ZSH_DISABLE_COMPFIX=true
fpath=("\$ZSH_CUSTOM/plugins/zsh-completions/src" \$fpath)
plugins=(z zsh-autosuggestions zsh-syntax-highlighting)

if [ -r "\$ZSH/oh-my-zsh.sh" ]; then
  source "\$ZSH/oh-my-zsh.sh"
fi

export CONDARC="\$BOOTSTRAP_PREFIX/miniforge3/.condarc"
if [ -r "\$BOOTSTRAP_PREFIX/miniforge3/etc/profile.d/conda.sh" ]; then
  . "\$BOOTSTRAP_PREFIX/miniforge3/etc/profile.d/conda.sh"
elif [ -d "\$BOOTSTRAP_PREFIX/miniforge3/bin" ]; then
  case ":\$PATH:" in
    *":\$BOOTSTRAP_PREFIX/miniforge3/bin:"*) ;;
    *) export PATH="\$BOOTSTRAP_PREFIX/miniforge3/bin:\$PATH" ;;
  esac
fi
EOF

	write_managed_block "$HOME/.zshrc" "$start" "$end" "$block"
	rm -rf "$tmpdir"
}

configure_login_profile() {
	local tmpdir block q_zsh start end
	start="# >>> bootstrap_env login-shell managed block >>>"
	end="# <<< bootstrap_env login-shell managed block <<<"

	if [ "$DRY_RUN" -eq 1 ]; then
		write_managed_block "$LOGIN_PROFILE_FILE" "$start" "$end" "/dev/null"
		return
	fi

	tmpdir=$(make_temp_dir)
	block="$tmpdir/login.block"
	q_zsh=$(shell_quote "$PREFIX/bin/zsh")

	cat > "$block" <<EOF
_BOOTSTRAP_ENV_ZSH=$q_zsh
if [ -z "\${ZSH_VERSION:-}" ] && [ -z "\${BOOTSTRAP_ENV_ZSH_LOGIN:-}" ] && [ -x "\$_BOOTSTRAP_ENV_ZSH" ]; then
  case "\$-" in
    *i*)
      export BOOTSTRAP_ENV_ZSH_LOGIN=1
      exec "\$_BOOTSTRAP_ENV_ZSH" -l
      ;;
  esac
fi
unset _BOOTSTRAP_ENV_ZSH
EOF

	write_managed_block "$LOGIN_PROFILE_FILE" "$start" "$end" "$block"
	rm -rf "$tmpdir"
}

is_valid_ssh_public_key() {
	case "$1" in
		ssh-rsa\ ?*|ssh-ed25519\ ?*|ecdsa-sha2-nistp256\ ?*|ecdsa-sha2-nistp384\ ?*|ecdsa-sha2-nistp521\ ?*|sk-ssh-ed25519@openssh.com\ ?*|sk-ecdsa-sha2-nistp256@openssh.com\ ?*)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

configure_ssh_key() {
	local answer key ssh_dir auth_keys

	if [ "$NO_SSH_KEY" -eq 1 ]; then
		log "Skipping SSH public key setup."
		return
	fi
	if [ "$DRY_RUN" -eq 1 ]; then
		log "DRY-RUN: would optionally append an SSH public key to $HOME/.ssh/authorized_keys"
		return
	fi
	if [ ! -t 0 ]; then
		log "Skipping SSH public key setup because stdin is not interactive."
		return
	fi

	answer="n"
	if [ "$ASSUME_YES" -eq 1 ]; then
		answer="y"
	else
		printf 'Add an SSH public key to %s/.ssh/authorized_keys? [y/N] ' "$HOME"
		if ! read -r answer; then
			log "No SSH prompt response provided; skipping."
			return
		fi
	fi

	case "$answer" in
		y|Y|yes|YES)
			;;
		*)
			log "Skipping SSH public key setup."
			return
			;;
	esac

	printf 'Paste one SSH public key line (empty to skip): '
	if ! read -r key; then
		log "No SSH key provided; skipping."
		return
	fi
	if [ -z "$key" ]; then
		log "No SSH key provided; skipping."
		return
	fi
	if ! is_valid_ssh_public_key "$key"; then
		die "Invalid or unsupported SSH public key format. Expected ssh-ed25519, ssh-rsa, ecdsa-sha2-*, or FIDO sk-*."
	fi

	ssh_dir="$HOME/.ssh"
	auth_keys="$ssh_dir/authorized_keys"
	mkdir -p "$ssh_dir"
	chmod 700 "$ssh_dir"
	if [ -f "$auth_keys" ] && grep -Fqx "$key" "$auth_keys"; then
		chmod 600 "$auth_keys"
		log "SSH public key already present: $auth_keys"
		return
	fi

	backup_file "$auth_keys"
	if [ -s "$auth_keys" ]; then
		printf '\n' >> "$auth_keys"
	fi
	printf '%s\n' "$key" >> "$auth_keys"
	chmod 600 "$auth_keys"
	log "Appended SSH public key: $auth_keys"
}

main() {
	parse_args "$@"
	detect_platform
	detect_jobs
	choose_login_profile_file
	set_urls
	print_summary
	check_prerequisites

	build_ncurses
	build_libevent
	build_zsh
	build_tmux
	install_miniforge
	write_condarc
	install_oh_my_zsh_and_plugins
	configure_zshrc
	configure_login_profile
	configure_ssh_key

	log ""
	log "Bootstrap complete."
	log "Open a new SSH/login shell or run: exec \"$PREFIX/bin/zsh\" -l"
}

main "$@"
