# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Add zmodload zsh/zprof at the top of your ~/.zshrc and zprof at the bottom. Then you get a profile of the startup time usage.
# zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH="/home/dbridgew/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="agnoster"
#ZSH_THEME="terminalparty"
#ZSH_THEME="gnzh"
#ZSH_THEME="robbyrussell"

ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
#ZSH_THEME_RANDOM_CANDIDATES=( "af-magic" "agnoster" "terminalparty" "gnzh" "robbyrussell" )

# Keep track of your history
export HISTSIZE=100000 SAVEHIST=100000 HISTFILE=~/.zhistory

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

function get_mars_env () {
  if (( $MARS_ENV = prod ))
  then echo "-->prod<--"; fi
}

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.


JIRA_URL=http://caljira.wv.mentorg.com
source $HOME/Dotfiles/.aliases
source $HOME/Dotfiles/.exports
source $HOME/Dotfiles/common-git-settings.sh

bgnotify_threshold=30  ## set your own notification threshold
function bgnotify_formatted {
  ## $1=exit_status, $2=command, $3=elapsed_time
  [ $1 -eq 0 ] && title="Success!" || title="FAILURE!"
  bgnotify "$title -- after $3 s -->" "$2" -t 10000;
}

# SSH-Agent features
# To enable agent forwarding support add the following to your zshrc file
#zstyle :omz:plugins:ssh-agent agent-forwarding on


plugins=( )
plugins+=( git-escape-magic )
plugins+=( bgnotify )
plugins+=( ansible )
plugins+=( sudo )
plugins+=( jira )
plugins+=( pip )
plugins+=( zsh-256color )
plugins+=( forgit  )
plugins+=( shrink-path )
plugins+=( ssh-agent )
#plugins+=( term_tab )

# Not working...
#plugins+=( zsh-autocomplete )

# The best history plugin
plugins+=( history-search-multi-word )
zstyle :plugin:history-search-multi-word reset-prompt-protect 1

#plugins+=( tmux )

zbell_duration=60
#plugins+=( zbell )

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
ZSH_TMUX_AUTO_TITLE_SHORT=true
plugins+=( zsh-tmux-auto-title )

plugins+=( git )

# https://github.com/unixorn/git-extra-commands
plugins+=( git-extra-commands )

# https://github.com/supercrabtree/k
plugins+=( k )

#plugins+=( fzf-tab )

# Do not expand aliases _before_ completion has finished
# This allows to re-use completion for the aliases too
setopt completealiases


DISABLE_AUTO_TITLE='true'

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Sourced at the end, per the README
source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source $ZSH/oh-my-zsh.sh

# to get the profiling information
# zprof

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
