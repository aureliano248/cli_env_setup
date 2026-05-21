choose_login_profile_file() {
	# configure_login_profile writes to the selected login profile later.
	if [ -f "$HOME/.bash_profile" ]; then
		LOGIN_PROFILE_FILE="$HOME/.bash_profile"
	else
		LOGIN_PROFILE_FILE="$HOME/.profile"
	fi
}

configure_zshrc() {
	local conda_bin_dir q_conda_bin_dir q_conda_sh q_condarc q_omz q_prefix q_zsh_custom tmpdir block start end
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
# bootstrap_env: prefix-built commands
export BOOTSTRAP_PREFIX=$q_prefix
if [ -d "\$BOOTSTRAP_PREFIX/bin" ]; then
  case ":\$PATH:" in
    *":\$BOOTSTRAP_PREFIX/bin:"*) ;;
    *) export PATH="\$BOOTSTRAP_PREFIX/bin:\$PATH" ;;
  esac
fi
EOF

	if [ -n "$SELECTED_OMZ_DIR" ] && [ -n "$SELECTED_ZSH_CUSTOM_DIR" ]; then
		q_omz=$(shell_quote "$SELECTED_OMZ_DIR")
		q_zsh_custom=$(shell_quote "$SELECTED_ZSH_CUSTOM_DIR")
		cat >> "$block" <<EOF

# bootstrap_env: Oh My Zsh
export ZSH=$q_omz
export ZSH_CUSTOM=$q_zsh_custom
ZSH_THEME="robbyrussell"
ZSH_DISABLE_COMPFIX=true
fpath=("\$ZSH_CUSTOM/plugins/zsh-completions/src" \$fpath)
plugins=(z zsh-autosuggestions zsh-syntax-highlighting)

if [ -r "\$ZSH/oh-my-zsh.sh" ]; then
  source "\$ZSH/oh-my-zsh.sh"
fi
EOF
	else
		warn "No reusable or installed Oh My Zsh was selected; writing prefix PATH only."
	fi

	if [ -n "$SELECTED_CONDA_BIN" ]; then
		conda_bin_dir=${SELECTED_CONDA_BIN%/conda}
		q_conda_bin_dir=$(shell_quote "$conda_bin_dir")
		q_conda_sh=$(shell_quote "$SELECTED_CONDA_SH")
		{
			printf '\n'
			printf '# bootstrap_env: conda\n'
			if [ "$MANAGE_MINIFORGE_CONFIG" -eq 1 ]; then
				q_condarc=$(shell_quote "$MINIFORGE_DIR/.condarc")
				printf 'export CONDARC=%s\n' "$q_condarc"
			fi
			cat <<EOF
_BOOTSTRAP_ENV_CONDA_BIN_DIR=$q_conda_bin_dir
if [ -r $q_conda_sh ]; then
  . $q_conda_sh
elif [ -d "\$_BOOTSTRAP_ENV_CONDA_BIN_DIR" ]; then
  case ":\$PATH:" in
    *":\$_BOOTSTRAP_ENV_CONDA_BIN_DIR:"*) ;;
    *) export PATH="\$_BOOTSTRAP_ENV_CONDA_BIN_DIR:\$PATH" ;;
  esac
fi
unset _BOOTSTRAP_ENV_CONDA_BIN_DIR
EOF
		} >> "$block"
	fi

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
	if [ -z "$SELECTED_ZSH_BIN" ]; then
		warn "No reusable or installed zsh was selected; skipping login-shell zsh handoff."
		rm -rf "$tmpdir"
		return
	fi
	q_zsh=$(shell_quote "$SELECTED_ZSH_BIN")

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
