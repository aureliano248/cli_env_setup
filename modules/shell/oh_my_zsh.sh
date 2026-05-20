is_oh_my_zsh_dir() {
	[ -r "$1/oh-my-zsh.sh" ]
}

find_reusable_oh_my_zsh() {
	if is_oh_my_zsh_dir "$PREFIX/share/oh-my-zsh"; then
		printf '%s\n' "$PREFIX/share/oh-my-zsh"
		return 0
	fi
	if [ -n "${ZSH:-}" ] && is_oh_my_zsh_dir "$ZSH"; then
		printf '%s\n' "$ZSH"
		return 0
	fi
	if is_oh_my_zsh_dir "$HOME/.oh-my-zsh"; then
		printf '%s\n' "$HOME/.oh-my-zsh"
		return 0
	fi
	return 1
}

install_oh_my_zsh_and_plugins() {
	local existing omz_dir custom_dir custom_plugins
	omz_dir="$PREFIX/share/oh-my-zsh"

	if [ "$FORCE_REBUILD" -eq 0 ]; then
		existing=$(find_reusable_oh_my_zsh || true)
		if [ -n "$existing" ]; then
			SELECTED_OMZ_DIR=$existing
			if [ "$existing" = "$omz_dir" ] && stamp_matches "oh-my-zsh" "$OMZ_COMMIT"; then
				log "Oh My Zsh $OMZ_COMMIT already installed; skipping."
			elif [ "$existing" = "$omz_dir" ]; then
				warn "Existing Oh My Zsh found under prefix; leaving it in place: $existing"
				warn "Re-run with --force-rebuild to replace it with commit $OMZ_COMMIT."
			else
				log "Oh My Zsh already available at $existing; skipping Oh My Zsh install."
			fi
		fi
	fi

	if [ -z "$SELECTED_OMZ_DIR" ]; then
		install_archive_component "oh-my-zsh" "$OMZ_COMMIT" "$OMZ_URL" "oh-my-zsh-$OMZ_COMMIT.tar.gz" "$omz_dir"
		if [ "$DRY_RUN" -eq 1 ] || is_oh_my_zsh_dir "$omz_dir"; then
			SELECTED_OMZ_DIR=$omz_dir
		else
			warn "Oh My Zsh is not available; leaving existing path untouched: $omz_dir"
			warn "Re-run with --force-rebuild to replace it."
			return
		fi
	fi

	if [ "$SELECTED_OMZ_DIR" = "$omz_dir" ]; then
		custom_dir="$omz_dir/custom"
	else
		custom_dir="$PREFIX/share/oh-my-zsh-custom"
	fi
	SELECTED_ZSH_CUSTOM_DIR=$custom_dir
	custom_plugins="$custom_dir/plugins"
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
