# Return true if executing inside a Docker, LXC or systemd-nspawn container.
prompt_caja_is_inside_container() {
    local -r cgroup_file='/proc/1/cgroup'
    local -r nspawn_file='/run/host/container-manager'
    [[ -r "$cgroup_file" && "$(< $cgroup_file)" = *(lxc|docker)* ]] \
        || [[ "$container" == "lxc" ]] \
        || [[ -r "$nspawn_file" ]]
}

# borrowed from pure zsh theme
prompt_caja_state_setup() {
    setopt localoptions noshwordsplit

    # Check SSH_CONNECTION and the current state.
    local ssh_connection=${SSH_CONNECTION:-$PROMPT_CAJA_SSH_CONNECTION}
    local username hostname title
    if [[ -z $ssh_connection ]] && (( $+commands[who] )); then
    # When changing user on a remote system, the $SSH_CONNECTION
    # environment variable can be lost. Attempt detection via `who`.
    local who_out
    who_out=$(who -m 2>/dev/null)
    if (( $? )); then
        # Who am I not supported, fallback to plain who.
        local -a who_in
        who_in=( ${(f)"$(who 2>/dev/null)"} )
        who_out="${(M)who_in:#*[[:space:]]${TTY#/dev/}[[:space:]]*}"
    fi

    local reIPv6='(([0-9a-fA-F]+:)|:){2,}[0-9a-fA-F]+'  # Simplified, only checks partial pattern.
    local reIPv4='([0-9]{1,3}\.){3}[0-9]+'   # Simplified, allows invalid ranges.
    # Here we assume two non-consecutive periods represents a
    # hostname. This matches `foo.bar.baz`, but not `foo.bar`.
    local reHostname='([.][^. ]+){2}'

    # Usually the remote address is surrounded by parenthesis, but
    # not on all systems (e.g. busybox).
    local -H MATCH MBEGIN MEND
    if [[ $who_out =~ "\(?($reIPv4|$reIPv6|$reHostname)\)?\$" ]]; then
        ssh_connection=$MATCH

        # Export variable to allow detection propagation inside
        # shells spawned by this one (e.g. tmux does not always
        # inherit the same tty, which breaks detection).
        export PROMPT_CAJA_SSH_CONNECTION=$ssh_connection
    fi
    unset MATCH MBEGIN MEND
    fi

    hostname='%F{$prompt_colors[host]}@%m%f'
    # Show at least username, this is what caja wants.
    username='%F{$prompt_colors[user]}%n%f'

    # Show `username@host` if logged in through SSH.
    if [[ -n $ssh_connection ]]; then
        username='%F{$prompt_colors[user]}%n%f'"$hostname"
        title=%n"$hostname"
    fi

    # Show `username@host` if inside a container and not in GitHub Codespaces.
    if [[ -z "${CODESPACES}" ]]; then
        prompt_caja_is_inside_container && username='%F{$prompt_colors[user]}%n%f'"$hostname"
        title=%n"$hostname"
    fi

    # Show `username@host` if root, with username in default color.
    if [[ $UID -eq 0 ]]; then
        username='%F{$prompt_colors[user:root]}%n%f'"$hostname"
        title=%n"$hostname"
    fi

    typeset -gA prompt_caja_state
    #prompt_pure_state[version]="1.20.1"
    prompt_caja_state+=(
        username    "$username"
        title       "$title"
    )
}

# borrowed from pure zsh theme
prompt_caja_set_title() {
    setopt localoptions noshwordsplit

    # Emacs terminal does not support settings the title.
    (( ${+EMACS} || ${+INSIDE_EMACS} )) && return

    # Don't set title over serial console.
    case $TTY in
        /dev/ttyS[0-9]*) return;;
    esac

    # Show hostname if connected via SSH.
    local hostname=
    if [[ -n $prompt_caja_state[title] ]]; then
        # Expand in-place in case ignore-escape is used.
        hostname="${(%):-(%n@%m) }"
    fi

    local -a opts
    case $1 in
        expand-prompt) opts=(-P);;
        ignore-escape) opts=(-r);;
    esac

    # Set title atomically in one print statement so that it works
    # when XTRACE is enabled.
    print -n $opts $'\e]0;'${hostname}${2}$'\a'
}

prompt_caja_precmd() {
    vcs_info  # Always load before displaying prompt.

    if [ -z ${vcs_info_msg_0_} ]; then
        pre_str="%F{$prompt_colors[path]}%5~%f"
    else
        pre_str="$vcs_info_msg_0_"
    fi
    # print $pre_str

    # Shows the full path in the title.
    prompt_caja_set_title 'expand-prompt' '%~'
}

prompt_caja_setup() {
    autoload -Uz vcs_info

    # Set colors for caja.
    typeset -gA prompt_colors_default prompt_colors
    prompt_colors_default=(
        git:unstaged        red
        git:staged          green
        vcs:other           yellow
        git:path            cyan
        prompt:error        red
        host                \#6c6c6c
        user                \#6c6c6c
        user:root           red
        tty                 \#6c6c6c
        path                cyan
        shlvl               magenta
        at                  \#6c6c6c
        time                cyan
    )
    prompt_colors=("${(@kv)prompt_colors_default}")

    # Details according to
    # https://voracious.dev/a-guide-to-customizing-the-zsh-shell-prompt and
    # https://arjanvandergaag.nl/blog/customize-zsh-prompt-with-vcs-info.html
    zstyle ':vcs_info:git*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' unstagedstr "%F{$prompt_colors[git:unstaged]}*%f"
    zstyle ':vcs_info:*' stagedstr "%F{$prompt_colors[git:staged]}*%f"
    zstyle ':vcs_info:*' formats "%s %F{$prompt_colors[vcs:other]}%b%u%c%f"
    zstyle ':vcs_info:git*' formats "%s %F{$prompt_colors[git:path]}%r/%S%f %b%m%u%c"

    # Run prompt setup parts borrowed from pure.
    prompt_caja_state_setup

    # Assemble the new prompt:
    local ps1=(
        $prompt_caja_state[username]    # user, host
                                        # (As formatted in prompt_caja_state_setup.)
        '%F{$prompt_colors[tty]} %y%f ' # tty
        '${pre_str}'                    # path or vcs_info from prompt_caja_precmd
        $'\n'
                                        # SHLVL counter conditions
        '%(2L.%F{$prompt_colors[shlvl]}%L%f %F{$prompt_colors[at]}at%f.%F{$prompt_colors[at]}at%f) '
        '%F{$prompt_colors[time]}%*%f ' # HH:MM:SS
                                        # Conditional, warn when last cmd failed.
        '%B%(?.%#.%F{$prompt_colors[prompt:error]}%#%f)%b '
    )
    PS1="${(j::)ps1}"
    PS2='%(4_:... :)%3_> '

    prompt_opts=( cr percent subst )
    add-zsh-hook precmd prompt_caja_precmd
}

prompt_caja_help() {
    cat << "EOF"
Some nice description will go here...

Some code in this theme was stolen from Sindre Sorhus's `pure` zsh theme.
EOF
}

prompt_caja_setup "$@"
