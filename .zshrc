if [[ -r ~/.local/lib/python2.7/site-packages/powerline/bindings/zsh/powerline.zsh ]]; then
    source ~/.local/lib/python2.7/site-packages/powerline/bindings/zsh/powerline.zsh
fi

# Path to your oh-my-zsh installation.
export ZSH=/home/dbridgew/.oh-my-zsh
export LD_LIBRARY_PATH=/usr/local/lib

unset autologout

export MARS_ENV="devel"
export MARS_TEAM="mars_drake"
export MARS_UNITTEST_KEYSPACE_ID="unittest_dbridgew"

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="agnoster"
# ZSH_THEME="agnosterzak"

# Keep track of your history
export HISTSIZE=100000 SAVEHIST=100000 HISTFILE=~/.zhistory

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

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
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder


# Check network settings
 ping -c 1 8.8.8.8 > /dev/null 2>&1
 connected=$?
 if [ $connected -eq 0 ]
 then
     export EXT=`curl -s http://whatismyip.akamai.com/ -m 3`
     export HIP=`dig +short mobkilla.no-ip.biz @8.8.8.8`
 else
     echo "Network Unreachable"
     export EXT=0
     export HIP=2
 fi

#------------------------------------------
#------WELCOME MESSAGE---------------------
# customize this first message with a message of your choice.
# this will display the username, date, time, a calendar, the amount of users, and the up time.
clear
# Gotta love ASCII art with figlet
if which figlet > /dev/null 2>&1; then
    figlet "Welcome, $NICKNAME";
fi
echo -e ""
echo -ne "Today is "; date
echo -e ""
if [ -e $HOME/bin/intro ]; then
    if [ -e $HOME/.intro_cache ];then
        if test `find "$HOME/.intro_cache" -mmin +15` 2>&1 > /dev/null
        then
            #echo "new"
            if [ $connected -eq 0 ]  # Connected to the internet
            then
                $HOME/bin/intro | tee $HOME/.intro_cache
            fi
        else
            #echo "old"
            cat $HOME/.intro_cache
        fi
    else
        if [ $connected -eq 0 ]; then
            $HOME/bin/intro | tee $HOME/.intro_cache
        fi
    fi
else
    echo -e "";  cal | grep --color -EC6 "\b$(date +%e | sed "s/ //g")" ;
fi
echo -ne "Up time:";uptime | awk /'up/'
echo "";
echo "You are on $HOST"


# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(tmux web-search extract compleat colored-man-pages colorize cp copyfile zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh
zstyle ':completion:*' users

# User configuration

PATH=$HOME/bin
PATH=${PATH}:$HOME/bin/$VCO
PATH=${PATH}:$HOME/tools/$VCO/bin
PATH=${PATH}:/bin
PATH=${PATH}:/scratch1/bin
PATH=${PATH}:/sbin
PATH=${PATH}:/usr/local/bin
PATH=${PATH}:/usr/bin
PATH=${PATH}:/usr/sbin
PATH=${PATH}:/usr/X11R6/bin
PATH=${PATH}:/usr/local/sbin
PATH=${PATH}:/usr/mgc/bin
PATH=${PATH}:/usr/mgc/peteoss/bin
PATH=${PATH}:/user/icdet/bin
PATH=${PATH}:/user/pete/bin
PATH=${PATH}:/user/pete/$VCO/bin
PATH=${PATH}:/user/peteoss/bin
PATH=${PATH}:/user/peteoss/$VCO/bin
PATH=${PATH}:/user/pevtools/bin
PATH=${PATH}:/user/pevtools/$VCO/bin
PATH=${PATH}:/usr/calibre/bin
PATH=${PATH}:/wv/cal_aws/tools/bin
PATH=${PATH}:/user/icbuild/roundup/bin
PATH=${PATH}:/wv/mgc/mgc_server/bin
PATH=${PATH}:/user/peteoss/aoi/bin
PATH=${PATH}:/home/dbridgew/local/bin
PATH=${PATH}:/home/dbridgew/Dotfiles/pushover/

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

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#


##=========================================================================
# Mentor Graphics
#==========================================================================
source $HOME/.aliases

export MGC_HOME=/wv/icdet/work_areas/d_top_last/ic/ic_superproj/aoi/Mgc_home
export LM_LICENSE_FILE="1717@wv-lic-01:1717@wv-lic-02:1717@wv-lic-03:1717@wv-lic-04:1717@wv-lic-05:1700@pevlic:1700@pevlic4:1700@pevlic2"

export CVSROOT=':pserver:calcvs:/cvs/qa'

#source /wv/icdet/bin/detalias.bsh
source /user/icdet/bin/calgrid.sh
export GRID_SRC=`source /wv/calgrid/sge/default/common/settings.sh`


# So that compilation of calibre take less time by using multicore
export GMAKE_LIB_PARALLEL=-j2
export GMAKE_EXEC_PARALLEL=-j2


# key bindings
bindkey "e[1~" beginning-of-line
bindkey "e[4~" end-of-line
bindkey "e[5~" beginning-of-history
bindkey "e[6~" end-of-history
bindkey "e[3~" delete-char
bindkey "e[2~" quoted-insert
bindkey "e[5C" forward-word
bindkey "eOc" emacs-forward-word
bindkey "e[5D" backward-word
bindkey "eOd" emacs-backward-word
bindkey "ee[C" forward-word
bindkey "ee[D" backward-word
bindkey "^H" backward-delete-word
# for rxvt
bindkey "e[8~" end-of-line
bindkey "e[7~" beginning-of-line
# for non RH/Debian xterm, can't hurt for RH/DEbian xterm
bindkey "eOH" beginning-of-line
bindkey "eOF" end-of-line
# for freebsd console
bindkey "e[H" beginning-of-line
bindkey "e[F" end-of-line
# completion in the middle of a line
bindkey '^i' expand-or-complete-prefix

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
