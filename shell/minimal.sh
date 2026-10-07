# Minimal environment for landing on an unfamiliar or bare machine.
# PATH, helper functions, history and a plain prompt — no oh-my-zsh, zinit,
# p10k, network access or anything that writes outside $HOME.
# Opt in with DOTFILES_MINIMAL=1; .zshrc also falls back here automatically
# when oh-my-zsh isn't installed.

if [ -r "$HOME/.profile" ]; then
    . "$HOME/.profile"
elif [ -r "$HOME/Dotfiles/home/.profile" ]; then
    . "$HOME/Dotfiles/home/.profile"
fi

if [ -r "${DOTFILES_DIR:-$HOME/Dotfiles}/shell/loader.sh" ]; then
    . "${DOTFILES_DIR:-$HOME/Dotfiles}/shell/loader.sh"
    _dotfiles_load_bashrcd
fi

export EDITOR="${EDITOR:-vim}"
export VISUAL="$EDITOR"
export PAGER="${PAGER:-less}"
export LESS="-R"

alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

HISTSIZE=10000
# $HOME may be read-only or foreign-owned in containers; fall back to TMPDIR.
if [ -w "$HOME" ]; then
    HISTFILE="$HOME/.histfile"
else
    HISTFILE="${TMPDIR:-/tmp}/histfile-$(id -u)"
fi

if [ -n "$ZSH_VERSION" ]; then
    SAVEHIST=$HISTSIZE
    setopt APPEND_HISTORY HIST_IGNORE_DUPS INTERACTIVE_COMMENTS 2>/dev/null
    bindkey -e
    autoload -Uz compinit && compinit -u 2>/dev/null
    PS1='%n@%m:%~%# '
elif [ -n "$BASH_VERSION" ]; then
    HISTFILESIZE=$HISTSIZE
    shopt -s histappend checkwinsize 2>/dev/null
    PS1='\u@\h:\w\$ '
fi

export DOTFILES_MINIMAL=1
