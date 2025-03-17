# # if not running interactively, don't do anything
[[ $- == *i* ]] || return

source $HOME/Dotfiles/.profile

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ssh-agent setup (must before sourcing oh-my-zsh)
zstyle :omz:plugins:ssh-agent agent-forwarding yes

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=( )
plugins+=( git )
#plugins+=( git-escape-magic )
#plugins+=( bgnotify )
#plugins+=( ansible )
plugins+=( sudo )
#plugins+=( jira )
#plugins+=( pip )
#plugins+=( zsh-256color )
#plugins+=( shrink-path )
plugins+=( ssh-agent )
#plugins+=( term_tab )
#plugins+=( tmux )
plugins+=( docker )

# zbell_duration=60
# plugins+=( zbell )


# https://github.com/mbenford/zsh-tmux-auto-title
# ZSH_TMUX_AUTO_TITLE_TARGET			Sets whether the window title or the pane title should be changed. Defaults to pane.
# ZSH_TMUX_AUTO_TITLE_SHORT			Displays only the command name, instead of the full command line. Defaults to false.
# ZSH_TMUX_AUTO_TITLE_SHORT_EXCLUDE		Regular expression that defines what commands should never be shortened. Defaults to "".
# ZSH_TMUX_AUTO_TITLE_EXPAND_ALIASES		Determines whether aliases should be expanded or kept as is. Defaults to true.
# ZSH_TMUX_AUTO_TITLE_IDLE_TEXT			Text to be used when no command is running. It can be either a plain string or one of the following variables:
# 							%pwd: current directory;
# 							%shell: current shell;
# 							%last: last command, prefixed by an exclamation mark.
# 							Defaults to %shell.
# ZSH_TMUX_AUTO_TITLE_IDLE_DELAY		Delay, in seconds, before the idle text is displayed. Defaults to 1.
# ZSH_TMUX_AUTO_TITLE_SHORT=true
# plugins+=( zsh-tmux-auto-title )



#===========================================================================
#===========================================================================
# User configuration
#===========================================================================
#===========================================================================
# the detailed meaning of the below three variable can be found in `man zshparam`.
export HISTFILE=~/.histfile
export HISTSIZE=1000000   # the number of items for the internal history list
export SAVEHIST=1000000   # maximum number of items for the history file

# The meaning of these options can be found in man page of `zshoptions`.
setopt HIST_IGNORE_ALL_DUPS  # do not put duplicated command into history list
setopt HIST_SAVE_NO_DUPS  # do not save duplicated command
setopt HIST_REDUCE_BLANKS  # remove unnecessary blanks
setopt INC_APPEND_HISTORY_TIME  # append command to history file immediately after execution
setopt EXTENDED_HISTORY  # record command start time
setopt HIST_IGNORE_SPACE   # Remove command lines from the history list when the first character on the line is a space
setopt HIST_NO_STORE # Remove the history (fc -l) command from the history list when invoked.
setopt HIST_VERIFY # Do not execute immediately upon history expansion.

#===========================================================================
# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#===========================================================================

source $HOME/Dotfiles/.aliases
#source $HOME/Dotfiles/.secrets
#source $HOME/Dotfiles/common-git-settings.sh
# source $HOME/Dotfiles/.exports
# source $HOME/Dotfiles/.kcat-aliases

#===========================================================================
# Siemens EDA
#===========================================================================

#source /wv/pevtools/bin/.aliases
# emulate sh -c 'source /wv/icdet/bin/detalias.sh'
emulate sh -c 'source /wv/iclvqa2/qa/bin/.aliases'
emulate sh -c 'source /wv/calgrid/sge/default/common/settings.sh'
emulate sh -c 'source /user/pete/bin/env_init.sh'

export VCO=$(/usr/mgc/bin/mgcvco)
export MGC_SERVER='/wv/mgc/mgc_server'
export WG_SERVER='/wv/cal_wg_server'

lserver set

#===========================================================================
#
#===========================================================================

### Added by Zinit's installer
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


# test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh" || true

# Load Angular CLI autocompletion.
# source <(ng completion script)
#
# source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


## Oh My Zsh Setting
ZSH_THEME="robbyrussell"

## Zinit Setting
# Must Load OMZ Git library
zi snippet OMZL::git.zsh

# Load Git plugin from OMZ
zi snippet OMZP::git
zi cdclear -q # <- forget completions provided up to this moment

setopt promptsubst

# Load Prompt
zi snippet OMZT::robbyrussell

# Load powerlevel10k theme
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k

# Load pure theme
zinit ice pick"async.zsh" src"pure.zsh" # with zsh-async library that's bundled with it.
zinit light sindresorhus/pure

# Load starship theme
# line 1: `starship` binary as command, from github release
# line 2: starship setup at clone(create init.zsh, completion)
# line 3: pull behavior same as clone, source init.zsh
# zinit ice as"command" from"gh-r" \
#           atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
#           atpull"%atclone" src"init.zsh"
# zinit light starship/starship

# ogham/exa also uses the definitions
#zinit ice wait"0c" lucid reset \
#    atclone"local P=${${(M)OSTYPE:#*darwin*}:+g}
#            \${P}sed -i \
#            '/DIR/c\DIR 38;5;63;1' LS_COLORS; \
#            \${P}dircolors -b LS_COLORS > c.zsh" \
#    atpull'%atclone' pick"c.zsh" nocompile'!' \
#    atload'zstyle ":completion:*" list-colors “${(s.:.)LS_COLORS}”'
#zinit light trapd00r/LS_COLORS

# diff-so-fancy
zinit ice wait"2" lucid as"program" pick"bin/git-dsf"
zinit load zdharma-continuum/zsh-diff-so-fancy

# junegunn/fzf-bin
zinit ice from"gh-r" as"program"
zinit light junegunn/fzf-bin

# sharkdp/fd, replacement for find
zinit ice as"command" from"gh-r" mv"fd* -> fd" pick"fd/fd"
zinit light sharkdp/fd

# sharkdp/bat, replacement for cat
zinit ice as"command" from"gh-r" mv"bat* -> bat" pick"bat/bat"
zinit light sharkdp/bat

# ogham/exa, replacement for ls
zinit ice wait"2" lucid from"gh-r" as"program" mv"exa* -> exa"
zinit light ogham/exa

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

