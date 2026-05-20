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
	if [ -n "$SELECTED_ZSH_BIN" ]; then
		log "Open a new SSH/login shell or run: exec \"$SELECTED_ZSH_BIN\" -l"
	else
		log "Open a new SSH/login shell after installing or exposing zsh."
	fi
}
