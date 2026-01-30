# If not running interactively, don't do anything
[[ $- == *i* ]] || return

# Warn  `SendEnv !TMUX` is not found in ssh config
if [ -n "$SSH_CLIENT" ] && ! grep -q 'SendEnv !TMUX' ~/.ssh/config; then
  echo "Warning: 'SendEnv !TMUX' not found in ~/.ssh/config. This may cause issues with tmux."
fi

source $HOME/Dotfiles/.profile

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Terminal settings for tmux to fix rendering issues
export TERM="xterm-256color"
alias tmux="TERM=xterm-256color tmux"

# ssh-agent setup (must before sourcing oh-my-zsh)
zstyle :omz:plugins:ssh-agent agent-forwarding yes

# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

# Oh My Zsh Theme
# ZSH_THEME="robbyrussell" // added to Zinit

# Update frequency
export UPDATE_ZSH_DAYS=13

# Enable command auto-correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion
COMPLETION_WAITING_DOTS="true"

# Plugins
plugins=(
  sudo
  ssh-agent
  docker
  isodate
  zsh-autosuggestions
  zsh-syntax-highlighting
  colored-man-pages
)

source $ZSH/oh-my-zsh.sh

#===========================================================================
# History Configuration
#===========================================================================
export HISTFILE=~/.histfile
export HISTSIZE=1000000
export SAVEHIST=1000000

# History options
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE # Ignore commands that start with a space
setopt HIST_NO_STORE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY_TIME

# Directory navigation options
setopt PUSHD_IGNORE_DUPS
setopt AUTO_PUSHD

# Misc options
setopt CORRECT # Enable command correction
setopt MAIL_WARNING # Warn if mail is waiting
setopt RM_STAR_WAIT # Confirm before removing all files
setopt ALWAYS_TO_END # Always pushd to the end of the directory stack
 # setopt WARN_CREATE_GLOBAL # Warn when creating global variables
setopt NOCLOBBER # Prevent overwriting files with redirection
 # setopt PROMPTSUBST # Enable prompt substitution
setopt INTERACTIVECOMMENTS # Enable interactive comments
 # setopt RCQUOTES # Enable rc quotes
 # setopt RCEXPANDPARAM # Enable rc parameter expansion
 # setopt EXTENDEDGLOB # Enable extended globbing (example: ^, ~, ##, etc.)
 # setopt GLOBSTARSHORT # Enable short globbing for **/*
 # setopt CBases # Enable C-style brace expansion
 # setopt OCTALZEROES # Enable octal zeroes

# This style defines the path where any cache files containing dumped completion data are stored.
# https://zsh.sourceforge.io/Doc/Release/Completion-System.html#Standard-Styles
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache

# [matcher-list] can be set to a list of match specifications that are to be applied everywhere
# Case insensitivity and dash/underscore insensitivity
typeset -A match_specifications=(
  [any_before_any]='r:|?=**'
  [any_before_dot]='r:|[.]=**'
  [any_before_word]='l:|=*'
  [case_and_dash_insensitive]='m:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}'
  [nonseparators_after_any_before_separator]='r:?||[-_ \]=*'
  [separator_after_any]='l:?|=[-_ \]'
)
zstyle ':completion:*' matcher-list \
  "$match_specifications[case_and_dash_insensitive] $match_specifications[any_before_dot] $match_specifications[any_before_word]" \
  "+$match_specifications[nonseparators_after_any_before_separator] $match_specifications[separator_after_any]" \
  "$match_specifications[case_and_dash_insensitive] $match_specifications[any_before_any]"
unset match_specifications

#===========================================================================
# Source additional configuration files
#===========================================================================
source $HOME/Dotfiles/.aliases

#===========================================================================
# Siemens EDA configuration
#===========================================================================
# emulate sh -c 'source /wv/iclvqa2/qa/bin/.aliases' || echo "Failed to source /wv/iclvqa2/qa/bin/.aliases"
emulate sh -c 'source /wv/calgrid/sge/default/common/settings.sh' || echo "Failed to source /wv/calgrid/sge/default/common/settings.sh"
emulate sh -c 'source /user/pete/bin/env_init.sh' || echo "Failed to source /user/pete/bin/env_init.sh"

export VCO=$(/usr/mgc/bin/mgcvco)
export MGC_SERVER='/wv/mgc/mgc_server'
export WG_SERVER='/wv/cal_wg_server'

if type lserver >/dev/null 2>&1; then
  lserver set
else
  echo "lserver command not found, skipping lserver configuration."
fi

#===========================================================================
# Zinit Plugin Manager
#===========================================================================
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
  print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
  command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
  command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
    print -P "%F{33} %F{34}Installation successful.%f%b" || \
    print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
((${+_comps})) && _comps[zinit]=_zinit

if type setopt >/dev/null 2>&1; then
  setopt promptsubst
else
  echo "setopt command not found, skipping promptsubst option."
fi

# Skip Zinit when zi doesn't exist
if type zi >/dev/null 2>&1; then
  # Zinit plugins/Setting
  # Must Load OMZ Git library
  zi snippet OMZL::git.zsh

  # Load Git plugin from OMZ
  zi snippet OMZP::git
  zi cdclear -q # <- forget completions provided up to this moment

  # Load theme
  zi snippet OMZT::robbyrussell

  # Powerlevel10k theme
  zinit ice depth"1"
  zinit light romkatv/powerlevel10k

  # Utilities
  zinit ice wait"2" lucid as"program" pick"bin/git-dsf"
  zinit load zdharma-continuum/zsh-diff-so-fancy

  # Adds 'fd' command: A simple, fast and user-friendly alternative to 'find'.
  zinit ice as"command" from"gh-r" mv"fd* -> fd" pick"fd/fd"
  zinit light sharkdp/fd

  # Adds 'bat' command: A cat clone with syntax highlighting and Git integration.
  zinit ice as"command" from"gh-r" mv"bat* -> bat" pick"bat/bat"
  zinit light sharkdp/bat

else
  echo "Zinit (zi) command not found, skipping Zinit plugins."
fi

# Load p10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# tmux-git-autofetch() {(/home/drabri2r/.tmux/plugins/tmux-git-autofetch/git-autofetch.tmux --current &)}
# add-zsh-hook chpwd tmux-git-autofetch

