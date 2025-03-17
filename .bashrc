#!/bin/bash
# ~/.bashrc: executed by bash for non-login shells
# Cleaned and organized for better maintainability and compatibility

# If not running interactively, don't do anything
[ -z "$PS1" ] || case $- in
*i*) ;;
*) return ;;
esac

#===========================================================================
# HISTORY SETTINGS
#===========================================================================
# History file location and size
HISTFILE="$HOME/.bash_history"
# Use large history sizes (empty = unlimited on newer bash, reasonable defaults for older)
HISTFILESIZE=1000000
HISTSIZE=1000000
# Don't put duplicate lines or lines starting with space in history
HISTCONTROL=ignoreboth
# Append to history file, don't overwrite
shopt -s histappend 2>/dev/null
# Add timestamps to history
HISTTIMEFORMAT="[%F %T] "
# Combine multiline commands in history
shopt -s cmdhist 2>/dev/null

#===========================================================================
# SHELL OPTIONS
#===========================================================================
# Check window size after each command
shopt -s checkwinsize 2>/dev/null
# Correct minor errors in directory spelling
shopt -s cdspell 2>/dev/null
# Additional spelling correction for directories (newer bash only)
shopt -s dirspell 2>/dev/null
# Allow cd into directory by just typing directory name (newer bash only)
shopt -s autocd 2>/dev/null
# Match all files, directories and subdirectories with ** (newer bash only)
shopt -s globstar 2>/dev/null
# Use extended pattern matching
shopt -s extglob 2>/dev/null

#===========================================================================
# ENVIRONMENT VARIABLES
#===========================================================================
# Set default editor
export EDITOR='vim'
# Terminal settings
export TERM='xterm'
# Core dump settings
ulimit -S -c 0 2>/dev/null
# Disable mail checking
shopt -u mailwarn 2>/dev/null
unset MAILCHECK
# Host file location
export HOSTFILE=$HOME/.hosts
# Less options: ignore case, exit if fits on one screen, allow colors
export LESS="-iXR"
# Enable colors
export CLICOLOR=1

#===========================================================================
# PROMPT SETTINGS
#===========================================================================
# Define colors
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # Define basic colors
    Color_Off="\[\033[0m\]"
    Red="\[\033[0;31m\]"
    Green="\[\033[0;32m\]"
    Yellow="\[\033[0;33m\]"
    Blue="\[\033[0;34m\]"
    Purple="\[\033[0;35m\]"
    Cyan="\[\033[0;36m\]"
    White="\[\033[0;37m\]"
    # Bold colors
    BRed="\[\033[1;31m\]"
    BGreen="\[\033[1;32m\]"
    BYellow="\[\033[1;33m\]"
    BBlue="\[\033[1;34m\]"
    BPurple="\[\033[1;35m\]"
    BCyan="\[\033[1;36m\]"
    BWhite="\[\033[1;37m\]"

    # Function to set prompt
    __prompt_command() {
        # Capture exit status of last command
        local EXIT="$?"
        PS1=""

        # Show exit status
        if [ $EXIT -eq 0 ]; then
            PS1+="${Green}[\!]${Color_Off} "
        else
            PS1+="${Red}[\!]${Color_Off} "
        fi

        # Show client IP if SSH connection
        if [ -n "$SSH_CLIENT" ]; then
            PS1+="${Yellow}(${SSH_CLIENT%% *})${Color_Off} "
        fi

        # Show debian chroot if present
        PS1+="${debian_chroot:+($debian_chroot)}"

        # User, host and directory info
        PS1+="${BBlue}\u${Color_Off}@${BGreen}\h${Color_Off}:${BPurple}\w${Color_Off} \$ "
    }
    PROMPT_COMMAND=__prompt_command

    # Set title for xterm
    case "$TERM" in
    xterm* | rxvt*)
        PS1="\[\e]0;\u@\h: \w\a\]$PS1"
        ;;
    esac
else
    # Simple prompt for older systems
    PS1='\u@\h:\w\$ '
fi

#===========================================================================
# COLORED MAN PAGES
#===========================================================================
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    export LESS_TERMCAP_mb=$'\E[01;31m'
    export LESS_TERMCAP_md=$'\E[01;31m'
    export LESS_TERMCAP_me=$'\E[0m'
    export LESS_TERMCAP_se=$'\E[0m'
    export LESS_TERMCAP_so=$'\E[01;42;30m'
    export LESS_TERMCAP_ue=$'\E[0m'
    export LESS_TERMCAP_us=$'\E[01;32m'
fi

#===========================================================================
# ALIASES
#===========================================================================
# Colors for ls and grep
if [ -x /usr/bin/dircolors ]; then
    # Use colors for ls
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
elif [ "$CLICOLOR" = 1 ]; then
    # macOS and BSD systems
    alias ls='ls -G'
fi

# Common ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Use colordiff if available
if command -v colordiff >/dev/null 2>&1; then
    alias diff='colordiff -u'
fi

#===========================================================================
# SOURCE EXTERNAL FILES
#===========================================================================
# Source local aliases if they exist
if [ -f ~/Dotfiles/.aliases ]; then
    source ~/Dotfiles/.aliases
fi

# Source profile if it exists
if [ -f ~/.profile ]; then
    source ~/.profile
fi

# Source work-specific files
# Note: Comment out or remove if not needed on your system
if [ -f ~/bin/env_init.sh ] && [ -d /user/pete/bin ]; then
    source ~/bin/env_init.sh
fi

# Source fzf completion if installed
if [ -f ~/.fzf.bash ]; then
    source ~/.fzf.bash
fi

# Print welcome message
echo -e "Welcome to BASH, version ${BASH_VERSION%.*}"

# Function to run on exit
_exit() {
    echo -e "exiting..."
}
trap _exit EXIT
