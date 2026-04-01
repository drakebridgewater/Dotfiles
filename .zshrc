if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
  . "$(code --locate-shell-integration-path zsh)" 2>/dev/null
fi

# If not running interactively, don't do anything
[[ $- == *i* ]] || return

# Enable Powerlevel10k instant prompt (must be before ANY output)
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Warn  `SendEnv !TMUX` is not found in ssh config
if [ -n "$SSH_CLIENT" ] && [ -f ~/.ssh/config ] && ! grep -q 'SendEnv !TMUX' ~/.ssh/config 2>/dev/null; then
  echo "Warning: 'SendEnv !TMUX' not found in ~/.ssh/config. This may cause issues with tmux."
fi

source $HOME/Dotfiles/.profile

if [[ -f /user/caldevtools/bin/load-devtools.sh ]]; then
  . /user/caldevtools/bin/load-devtools.sh
fi

# Terminal settings for tmux to fix rendering issues
# Only override TERM when not already inside tmux or screen
if [[ -z "$TMUX" && "$TERM" != screen* && "$TERM" != tmux* ]]; then
  export TERM="xterm-256color"
fi
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

POSSIBLE_HISTORY_OPTIONS=(
  EXTENDED_HISTORY # Save each history entry with a timestamp
  HIST_IGNORE_ALL_DUPS # Remove older duplicates from the history list when a new entry is added
  HIST_IGNORE_SPACE # Don't save commands that start with a space
  HIST_NO_STORE # Don't save commands that have been marked with a leading space or that are duplicates of the previous command
  HIST_REDUCE_BLANKS # Remove superfluous blanks from each command line being added to the history
  HIST_SAVE_NO_DUPS # Don't write duplicate entries in the history file
  HIST_VERIFY # Don't execute immediately upon recalling a history entry, but put it in the command line for editing
  INC_APPEND_HISTORY_TIME # Like INC_APPEND_HISTORY, but also save the time of each command in the history file
  HIST_NO_FUNCTIONS # Don't save function definitions in the history file
)

POSSIBLE_DIRECOTRY_NAV_OPTIONS=(
  PUSHD_IGNORE_DUPS # Don't push the same directory onto the stack
  AUTO_PUSHD # Automatically pushd when changing directories
)

POSSIBLE_OTHER_OPTIONS=(
  # CORRECT # Enable command correction
  # CORRECT_ALL # Enable correction for all arguments, not just the command
  MAIL_WARNING # Warn if mail is waiting
  # RM_STAR_WAIT # Confirm before removing all files
  ALWAYS_TO_END # Always pushd to the end of the directory stack
  # WARN_CREATE_GLOBAL # Warn when creating global variables
  # NOCLOBBER # Prevent overwriting files with redirection
  # PROMPTSUBST # Enable prompt substitution
  INTERACTIVECOMMENTS # Enable interactive comments
  # RCQUOTES # Enable rc quotes
  # RCEXPANDPARAM # Enable rc parameter expansion
  # EXTENDEDGLOB # Enable extended globbing (example: ^, ~, ##, etc.)
  # GLOBSTARSHORT # Enable short globbing for **/*
  # CBases # Enable C-style brace expansion
  # OCTALZEROES # Enable octal zeroes
  BAD_PATTERN # Enable bad pattern checking
  MONITOR # Enable job control
  NOTIFY # Notify of job status immediately
)
ALL_OPTIONS=(
  "${POSSIBLE_DIRECOTRY_NAV_OPTIONS[@]}"
  "${POSSIBLE_HISTORY_OPTIONS[@]}"
  "${POSSIBLE_OTHER_OPTIONS[@]}"
)
for option in "${ALL_OPTIONS[@]}"; do
    setopt "$option"  2> /dev/null || echo "setopt $option not found, skipping $option option."
done

# disable correct on specific commands
# alias docker='nocorrect docker'

# This style defines the path where any cache files containing dumped completion data are stored.
# https://zsh.sourceforge.io/Doc/Release/Completion-System.html#Standard-Styles
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache
zstyle ':completion:*' use-cache on
# This style controls the behavior of the completion system when multiple matches are found. Setting it to 'select' will display a menu of possible completions and allow you to select one using the arrow keys.
zmodload zsh/complist
zstyle ':completion:*' menu select mouse
zstyle ':completion:*' group-name ''
zstyle ':completion:*:*:-command-:*:*' group-order alias builtins functions commands

zstyle ':completion:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
# zstyle ':completion:*' file-list all

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' complete-options true
zstyle ':completion:*' glob '*'

# -- Case-insensitive and dash/underscore-insensitive completion --
# zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}'

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

# matcher-list entries are tried left-to-right; completions from the first
# spec that produces any match are shown.  A leading '+' means "augment the
# previous pass" (i.e. keep its matches and add more from this spec).
local _matchers=(
  # Pass 1 – case & dash/underscore insensitive (e.g. my-func matches MyFunc)
  "$match_specifications[case_and_dash_insensitive]"
  # Pass 2 – any chars may precede a dot separator (e.g. "sf" matches "some.file")
  "$match_specifications[any_before_dot]"
  # Pass 3 – any chars may precede each typed word (prefix-anywhere matching)
  "$match_specifications[any_before_word]"
  # Pass 4 – combined with pass 3: non-separator chars can follow wildcards before a separator
  "+$match_specifications[nonseparators_after_any_before_separator]"
  # Pass 5 – separator characters (-, _, space) can follow a wildcard
  "$match_specifications[separator_after_any]"
  # Pass 6 – retry case & dash insensitive (catches cross-boundary mismatches)
  # "$match_specifications[case_and_dash_insensitive]"
  # Pass 7 – widest net: any chars may appear between any typed chars (fuzzy)
  # "$match_specifications[any_before_any]"
)

zstyle ':completion:*' matcher-list "${_matchers[@]}"
unset _matchers
# unset match_specifications

#===========================================================================
# Source additional configuration files
#===========================================================================
source $HOME/Dotfiles/.aliases

#===========================================================================
# Siemens EDA configuration (only on Siemens hosts)
#===========================================================================
if [[ -d /usr/mgc || -d /wv ]]; then
  # emulate sh -c 'source /wv/iclvqa2/qa/bin/.aliases' || echo "Failed to source /wv/iclvqa2/qa/bin/.aliases"
  [[ -f /wv/calgrid/sge/default/common/settings.sh ]] && \
    { emulate sh -c 'source /wv/calgrid/sge/default/common/settings.sh' || echo "Failed to source /wv/calgrid/sge/default/common/settings.sh"; }
  [[ -f /user/pete/bin/env_init.sh ]] && \
    { emulate sh -c 'source /user/pete/bin/env_init.sh' || echo "Failed to source /user/pete/bin/env_init.sh"; }

  [[ -x /usr/mgc/bin/mgcvco ]] && export VCO=$(/usr/mgc/bin/mgcvco)
  [[ -d /wv/mgc/mgc_server ]] && export MGC_SERVER='/wv/mgc/mgc_server'
  [[ -d /wv/cal_wg_server ]] && export WG_SERVER='/wv/cal_wg_server'

  if type lserver >/dev/null 2>&1; then
    lserver set
  fi
fi

#===========================================================================
# Zsh Autosuggestions configuration
#===========================================================================

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#663399,standout"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
ZSH_AUTOSUGGEST_USE_ASYNC=1

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

#===========================================================================
# UX Improvements
#===========================================================================

# -- History search with Up/Down arrows --
# Type partial command, then Up/Down searches only matching history
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search    # Up arrow
bindkey "^[[B" down-line-or-beginning-search  # Down arrow
bindkey "^[OA" up-line-or-beginning-search    # Up arrow (alternate escape code)
bindkey "^[OB" down-line-or-beginning-search  # Down arrow (alternate escape code)

# -- Edit command line in $EDITOR (Ctrl+X Ctrl+E) --
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# -- Word navigation with Ctrl+Left/Right (works in tmux + SSH) --
bindkey '^[[1;5D' backward-word   # Ctrl+Left
bindkey '^[[1;5C' forward-word    # Ctrl+Right
bindkey '^[b'     backward-word   # Alt+Left fallback
bindkey '^[f'     forward-word    # Alt+Right fallback


# -- Directory stack shortcut (works with AUTO_PUSHD) --
# Type 'd' to see recent directories, then cd ~N to jump (e.g., cd ~3)
alias d='dirs -v | head -20'

# -- run-help: context-aware help for builtins (replaces man for zsh builtins) --
unalias run-help 2>/dev/null
autoload -Uz run-help
alias help='run-help'

# -- take: mkdir + cd in one step --
take() { mkdir -p "$1" && cd "$1"; }

# Load p10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# tmux-git-autofetch() {(/home/drabri2r/.tmux/plugins/tmux-git-autofetch/git-autofetch.tmux --current &)}
# add-zsh-hook chpwd tmux-git-autofetch

