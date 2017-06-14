#===========================================================================
# Personal ~/.bashrc FILE
# By Drake bridgewater (drake.bridgewater@gmail.com)
#
# This file contains aliases, functions, and other features for bash
#===========================================================================

#===========================================================================
# Exports
#===========================================================================
export EDITOR='vim'
export TERM='rxvt'

#===========================================================================
# Sources
#===========================================================================
#source /usr/share/git/completion/git-completion.bash
#source ~/.git-prompt.sh
#source /opt/intel/bin/compilervars.sh intel64

eval $( dircolors -b $HOME/.config/LS_COLORS )

##=========================================================================
# Mentor Graphics
#==========================================================================
source $HOME/.aliases

export LD_LIBRARY_PATH='/usr/local/lib'
# enable cout in RVE
#export MGC_YS_TRANSCRIPT_FILE=null

# gmake lv_verify   to run gui systests
export MGC_RUN_GUI_SYSTESTS_DURING_BUILD=1
export MARS_ENV='devel'

# faster builds
set pcount =`/user/icdet/bin/count_processors`
export PB="-j"$pcount;
export GMAKE_LIB_PARALLEL="-j"$pcount
export GMAKE_EXEC_PARALLEL=-j`/home/icdet/bin/figure_gmake_exec_ness`

# for regressions
export TEST_SUITE_TOP=/wv/pev_aut/rve_tot/calibre

export MGC_HOME=/wv/icdet/work_areas/d_top_last/ic/ic_superproj/aoi/Mgc_home
export LM_LICENSE_FILE="1717@wv-lic-01:1717@wv-lic-02:1717@wv-lic-03:1717@wv-lic-04:1717@wv-lic-05:1700@pevlic:1700@pevlic4:1700@pevlic2"

export CALIBRE_ENABLE_QT_RVE=17910110
export CALIBRE_ENABLE_CI_XACT=1009968
export CALIBRE_REALTIME_RVE_ENABLE=101314
export CVSROOT=':pserver:calcvs:/cvs/qa'
set VCO=`/usr/mgc/bin/mgcvco`
export PATH="/user/peteoss/bin:/user/peteoss/$VCO/bin:/user/pete/bin:user/pete/$VCO/bin:/usr/local/bin:/usr/bin:/usr/mgc/bin:/wv/icdet/bin:/usr/opt/bin:/bin:/usr/bin/X11:/usr/contrib/bin:/user/icdet/bin:/usr/mgc/bin:/user/pevtools/aoi/bin:~/bin:$HOME/local/bin:./"


# So that compilation of calibre take less time by using multicore
export GMAKE_LIB_PARALLEL=-j2
export GMAKE_EXEC_PARALLEL=-j2

#==========================================================================
# Some general settings
#===========================================================================

# ignore case, long prompt, exit if it fits on one screen, allow colors for ls and grep
export LESS="-iXR"

# save all the histories
export HISTFILESIZE=1000000
export HISTSIZE=1000000
export HISTFILE="$HOME/.history"

# shell options
shopt -s histappend # merge session histories
shopt -s cmdhist # combine multiline commands in history
shopt -s cdspell # cd tries to fix typos
shopt -s dirspell 2>/dev/null
shopt -s autocd 2>/dev/null
shopt -s checkwinsize # resize ouput to fit window

# Use extended pattern matching (not sure if toggled on reboot or not)
shopt -s extglob
# Check using rm !(args).

export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

ulimit -S -c 0 # Don't post core dumps

shopt -u mailwarn
unset MAILCHECK # Don't warn of new mail

export HOSTFILE=$HOME/.hosts # Put list of remote hosts in local file

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# use colordiff instead of diff if available
command -v colordiff >/dev/null 2>&1 && alias diff="colordiff -u"

#==========================================================================
# Greeting, motd (message of the day) settings
#==========================================================================

export COLOR_NC='\e[0m' # No Color
export COLOR_WHITE='\e[1;37m'
export COLOR_BLACK='\e[0;30m'
export COLOR_BLUE='\e[0;34m'
export COLOR_LIGHT_BLUE='\e[1;34m'
export COLOR_GREEN='\e[0;32m'
export COLOR_LIGHT_GREEN='\e[1;32m'
export COLOR_CYAN='\e[0;36m'
export COLOR_LIGHT_CYAN='\e[1;36m'
export COLOR_RED='\e[0;31m'
export COLOR_LIGHT_RED='\e[1;31m'
export COLOR_PURPLE='\e[0;35m'
export COLOR_LIGHT_PURPLE='\e[1;35m'
export COLOR_BROWN='\e[0;33m'
export COLOR_YELLOW='\e[1;33m'
export COLOR_GRAY='\e[0;30m'
export COLOR_LIGHT_GRAY='\e[0;37m'

echo -e "${COLOR_BLUE}Welcome to BASH, version ${COLOR_LIGHT_BLUE}${BASH_VERSION%.*}${COLOR_NC}"
function_exit() { # Function to run when exiting shell
    echo -e "${COLOR_RED}exiting...${NC}"
}
trap _exit EXIT

#==========================================================================
# Shell Prompt
#==========================================================================




##################

### COLORED MAN PAGES ###
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'        # end the info box
export LESS_TERMCAP_so=$'\E[01;42;30m' # begin the info box
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'


# ignore case, long prompt, exit if it fits on one screen, allow colors for ls and grep
export LESS="-iXR"

###COLOR-CODES####
Color_Off="\033[0m"
###-Regular-###
Red="\033[0;31m"
Green="\033[0;32m"
Yellow="\033[0;33m"
Blue="\033[0;34m"
Purple="\033[0;35m"
Cyan="\033[0;36m"
White="\033[0;37m"
####-Bold-####
BRed="\033[1;31m"
BGreen="\033[1;"
BYellow="\033[1;33m"
BBlue="\033[1;34m"
BPurple="\033[1;35m"
###-Intensive-###
IRed="\033[0;91m"
IGreen="\033[0;92m"
IYellow="\033[0;93m"
IBlue="\033[0;94m"
IPurple="\033[0;95m"
ICyan="\033[0;96m"
IWhite="\033[0;97m"
##################

# set up command prompt
function __prompt_command()
{
    # capture the exit status of the last command
    EXIT="$?"
    PS1=""

    if [ $EXIT -eq 0 ]; then PS1+="\[$Green\][\!]\[$Color_Off\] "; else  PS1+="\[$Red\][\!]\[$Color_Off\] "; fi

    # if logged in via ssh shows the ip of the client
    if [ -n "$SSH_CLIENT" ]; then PS1+="\[$Yellow\]("${SSH_CLIENT%% *}") \[$Color_Off\]"; fi

    # debian chroot stuff (take it or leave it)
    PS1+="${debian_chroot:+($debian_chroot)}"

    # basic information (user@host:path)
    PS1+="\[$BBlue\]\u\[$Color_Off\]@\[$IGreen\]\h\[$Color_Off\] : \[$BPurple\]\w\[$Color_Off\] "

#    if hash git 2>/dev/null; then

        # Display the branch name of git repository
        #   Green   ->  clean
        #   purple  ->  untracked files
        #   cyan    ->  staged files
        #   yellow  ->  staged files, and some untracked
        #   red     ->  files to commit
#        local git_status="`git status -unormal 2>&1`"

#        if ! [[ "$git_status" =~ Not\ a\ git\ repo ]]; then

#            if [[ "$git_status" =~ nothing\ to\ commit ]]; then
#                local Color_On=$Green
#            elif [[ "$git_status" =~ nothing\ added\ to\ commit\ but\ untracked\ files\ present ]]; then
#                local Color_On=$Purple
#            elif [[ "$git_status" =~ Untracked\ files: ]]; then
#                local Color_On=$Yellow
#            elif [[ "$git_status" =~ Changes\ not\ staged\ for ]]; then
#                local Color_On=$Red
#            elif [[ "$git_status" =~ Changes\ to\ be\ committed ]]; then
#                local Color_On=$Cyan
#            else
#                local Color_On=$Red
#            fi
#
#            if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
#                branch=${BASH_REMATCH[1]}
#            else
#                # Detached HEAD.  (branch=HEAD is a faster alternative.)
#                branch="(`git describe --all --contains --abbrev=4 HEAD 2> /dev/null ||
#                    echo HEAD`)"
#            fi
#
#            PS1+="\[$Color_On\][$branch]\[$Color_Off\] "
#        fi
#    fi

    # prompt $ or # for root
    PS1+="\$ "
}
PROMPT_COMMAND=__prompt_command

# enable color support of ls and also add handy aliases
if [ "$TERM" != "dumb" ]; then
    # dircolors doesn't seem to exist on my mac (adds color to ls)
    command -v dircolors >/dev/null 2>&1 && eval "`dircolors -b`"

    # force ls to always use color and typ indicators
    alias ls='ls -hF --color=auto'

    # make the dir command work kinda like in windows (long format)
    alias dir='ls --color=auto --format=long'
fi


[ -f ~/.fzf.bash ] && source ~/.fzf.bash
