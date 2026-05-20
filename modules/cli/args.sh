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
