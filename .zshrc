# If not running interactively, don't do anything
[[ $- == *i* ]] || return

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
ZSH_THEME="robbyrussell"

# Update frequency
export UPDATE_ZSH_DAYS=13

# Enable command auto-correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion
COMPLETION_WAITING_DOTS="true"

# Plugins
plugins=(
  git
  sudo
  ssh-agent
  docker
  isodate
)

source $ZSH/oh-my-zsh.sh

#===========================================================================
# History Configuration
#===========================================================================
export HISTFILE=~/.histfile
export HISTSIZE=1000000
export SAVEHIST=1000000

# History options
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY_TIME
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_SPACE
setopt HIST_NO_STORE
setopt HIST_VERIFY

#===========================================================================
# Source additional configuration files
#===========================================================================
source $HOME/Dotfiles/.aliases

#===========================================================================
# Siemens EDA configuration
#===========================================================================
emulate sh -c 'source /wv/iclvqa2/qa/bin/.aliases'
emulate sh -c 'source /wv/calgrid/sge/default/common/settings.sh'
emulate sh -c 'source /user/pete/bin/env_init.sh'

export VCO=$(/usr/mgc/bin/mgcvco)
export MGC_SERVER='/wv/mgc/mgc_server'
export WG_SERVER='/wv/cal_wg_server'

lserver set

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
(( ${+_comps} )) && _comps[zinit]=_zinit

setopt promptsubst

# Zinit plugins
zi snippet OMZL::git.zsh
zi snippet OMZP::git
zi cdclear -q

# Load theme
zi snippet OMZT::robbyrussell

# Powerlevel10k theme
zinit ice depth"1"
zinit light romkatv/powerlevel10k

# Utilities
zinit ice wait"2" lucid as"program" pick"bin/git-dsf"
zinit load zdharma-continuum/zsh-diff-so-fancy

zinit ice from"gh-r" as"program"
zinit light junegunn/fzf-bin

zinit ice as"command" from"gh-r" mv"fd* -> fd" pick"fd/fd"
zinit light sharkdp/fd

zinit ice as"command" from"gh-r" mv"bat* -> bat" pick"bat/bat"
zinit light sharkdp/bat

zinit ice wait"2" lucid from"gh-r" as"program" mv"exa* -> exa"
zinit light ogham/exa

# Load p10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
tmux-git-autofetch() {(/home/drabri2r/.tmux/plugins/tmux-git-autofetch/git-autofetch.tmux --current &)}
add-zsh-hook chpwd tmux-git-autofetch
    
