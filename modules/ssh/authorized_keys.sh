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
