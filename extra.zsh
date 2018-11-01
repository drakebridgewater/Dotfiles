REPORTTIME=5 # Prints system usage for any command running longer than 5 seconds.
NOTIFY_CMD_RUNTIME=5 #900 # Notifies you of any command finishing that took longer than 900 seconds (15 munites)
NO_NOTIFY_LIST=~/.zsh_no_notify

if [[ -x `which kdialog` ]]; then
    function notify_on_long_run_preexec () {
        zsh_notifier_cmd="$1"
        zsh_notifier_time="`date +%s`"
    }
    
    function notify_on_long_run_precmd () {
        local time_taken
        if [[ "${zsh_notifier_cmd}" != "" ]]; then
            if ! grep -Fxq "$(echo $zsh_notifier_cmd | awk '{ print $1 }')" $NO_NOTIFY_LIST; then
                time_taken=$(( `date +%s` - ${zsh_notifier_time} ))
                if (( $time_taken > $NOTIFY_CMD_RUNTIME )); then
                    if [[ "${zsh_notifier_cmd}" != "" ]]; then
                        kdialog --msgbox "Command ($zsh_notifier_cmd) finished after $time_taken seconds."
                    fi
                fi
            fi
        fi
        zsh_notifier_cmd=
    }
    if [[ $NOPRECMD -eq 0 ]]; then
        add-zsh-hook precmd notify_on_long_run_precmd
        add-zsh-hook preexec notify_on_long_run_preexec
    fi
fi
