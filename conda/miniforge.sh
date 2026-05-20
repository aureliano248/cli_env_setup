set_selected_conda_paths() {
	local conda_root
	SELECTED_CONDA_SH=""
	case "$SELECTED_CONDA_BIN" in
		*/bin/conda)
			conda_root=${SELECTED_CONDA_BIN%/bin/conda}
			if [ -r "$conda_root/etc/profile.d/conda.sh" ]; then
				SELECTED_CONDA_SH="$conda_root/etc/profile.d/conda.sh"
			fi
			;;
	esac
}

find_reusable_conda() {
	local found
	if [ -x "$MINIFORGE_DIR/bin/conda" ]; then
		printf '%s\n' "$MINIFORGE_DIR/bin/conda"
		return 0
	fi
	found=$(command -v conda 2>/dev/null || true)
	if [ -n "$found" ] && [ -x "$found" ]; then
		printf '%s\n' "$found"
		return 0
	fi
	return 1
}

install_miniforge() {
	local existing installer
	if [ "$FORCE_REBUILD" -eq 0 ]; then
		existing=$(find_reusable_conda || true)
		if [ -n "$existing" ]; then
			# zsh/profile.sh consumes the selected conda paths when writing .zshrc.
			SELECTED_CONDA_BIN=$existing
			set_selected_conda_paths
			if [ "$existing" = "$MINIFORGE_DIR/bin/conda" ]; then
				if stamp_matches "miniforge" "$MINIFORGE_VERSION"; then
					MANAGE_MINIFORGE_CONFIG=1
					log "Miniforge $MINIFORGE_VERSION already installed; skipping."
				else
					warn "Existing conda found under prefix; leaving it in place: $existing"
					warn "Re-run with --force-rebuild to replace it with Miniforge $MINIFORGE_VERSION."
				fi
			else
				log "conda already available at $existing; skipping Miniforge install."
			fi
			return
		fi
	fi

	if [ -d "$MINIFORGE_DIR" ]; then
		if [ "$FORCE_REBUILD" -eq 1 ]; then
			remove_path_under_prefix "$MINIFORGE_DIR"
		else
			# A prefix conda tree without a matching stamp may not be ours.
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
	# Later zshrc generation uses these globals for conda initialization.
	SELECTED_CONDA_BIN="$MINIFORGE_DIR/bin/conda"
	MANAGE_MINIFORGE_CONFIG=1
	set_selected_conda_paths
}

write_condarc() {
	local file tmpdir tmp
	if [ "$MANAGE_MINIFORGE_CONFIG" -eq 0 ]; then
		if [ -n "$SELECTED_CONDA_BIN" ]; then
			log "Skipping prefix conda config; using existing conda at $SELECTED_CONDA_BIN."
		else
			log "Skipping conda config; Miniforge is not installed under this prefix."
		fi
		return
	fi

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
