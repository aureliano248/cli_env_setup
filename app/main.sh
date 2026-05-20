main() {
	# Normalize user input before any install decision reads global state.
	parse_args "$@"
	detect_platform
	detect_jobs
	choose_login_profile_file
	set_urls
	print_summary
	check_prerequisites

	# Build only missing native terminal tools and their managed dependencies.
	build_ncurses
	build_libevent
	build_zsh
	build_tmux

	# Select or install shell/runtime integrations, then write managed blocks.
	install_miniforge
	write_condarc
	install_oh_my_zsh_and_plugins
	configure_zshrc
	configure_login_profile
	configure_ssh_key

	# SELECTED_ZSH_BIN is set by zsh/zsh.sh and consumed by login guidance.
	log ""
	log "Bootstrap complete."
	if [ -n "$SELECTED_ZSH_BIN" ]; then
		log "Open a new SSH/login shell or run: exec \"$SELECTED_ZSH_BIN\" -l"
	else
		log "Open a new SSH/login shell after installing or exposing zsh."
	fi
}
