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

# enable cout in RVE
#export MGC_YS_TRANSCRIPT_FILE=null

# gmake lv_verify   to run gui systests
export MGC_RUN_GUI_SYSTESTS_DURING_BUILD=1
alias calsystest='gmake lcl_exec systests lv_verify'

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

alias tkrve='$MGC_HOME/bin/calibre -rve'
alias qtrve='$MGC_HOME/bin/calibre -rve -qt'
alias drc='$MGC_HOME/bin/calibre -gui -drc'
alias xact='$MGC_HOME/bin/calibre -gui -xact'
alias cixact='$MGC_HOME/bin/calibre -gui -xact'

#Windows 7 VM
alias win7='rdesktop -d mgc -u dbridgew -a 16 -f orw-drake-7vm -r sound:local -r disk:USB=/scratch1 -r clipboard:PRIMARYCLIPBOARD -x lan -g 1590x1130'

alias rve_regr='/wv/pev_aut/rve_tot/calibre/.env/gui/bin/rve_regr'

alias repo='cd /wv/rve_regr_results/dbridgew/calibre/rve/rve-drc-qt/suite-drc-rve/ ; la'

export CVSROOT=':pserver:calcvs:/cvs/qa'

#squish specific
alias rveqatst='rsh -l rveqatst localhost'
alias rve_regr='/wv/pev_aut/rve_tot/calibre/.env/gui/bin/rve_regr'
alias squishide='/home/rveqatst/squish-5.0.0-qt47x-linux64/bin/squishide &'
export DESIGN_DIR="/user/pev/qa/qa_data_dir"

alias vncs='vncserver -alwaysshared -geometry 1590x1050'
alias vncv='vncviewer calintern2:1'
alias vncC2022="vncserver -geometry 1200x925 -depth 24  -alwaysshared"
alias vncC2040="vncserver -geometry 1200x950 -depth 24 -alwaysshared"
alias vncC2042="vncserver -geometry 1500x825 -depth 24 -alwaysshared"

alias vnc0='/wv/grayburn/local/aoi/bin/x11vnc'

source /wv/icdet/bin/detalias.bsh

set VCO=`/usr/mgc/bin/mgcvco`
export PATH="/usr/local/bin:/usr/bin:/usr/mgc/bin:/user/tjackson/bin/${VCO}:/user/tjackson/bin:/user/pevtools/bin:/user/pevtools/$VCO/bin:/wv/icdet/bin:/usr/local/bin:/usr/opt/bin:/bin:/usr/bin/X11:/usr/contrib/bin"


alias fds='find ./Dsrc/ -name "*.[Cc]" -o -name "*.cxx" -o -name "*.cpp" -o -name "*.[hH]" -o -name "*.hxx" -o -name "*.tcl" -o -name "*.tk" -o -name "*.png" -o -name "*.gif" -o -name "*.ui" -o -name "*.qml" -o -name "*.qrc" '
alias qtcreator='/wv/iit/qtcreator/aoi/bin/qtcreator.sh'

# So that compilation of calibre take less time by using multicore
export GMAKE_LIB_PARALLEL=-j2
export GMAKE_EXEC_PARALLEL=-j2
##==========================================================================
# Aliases
#===========================================================================

#alias python='python3'
alias svn='python2 /home/dbridgew/bin/svn-color/svn-color.py'
alias sbrc='source ~/.bashrc'
alias vi='vim'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# -> Prevents accidentally clobbering files.
alias mkdir='mkdir -p'
alias encoding='file -bi'

alias h='history'
alias j='jobs -l'
alias which='type -a'
alias ..='cd ..'
alias libpath='echo -e ${LD_LIBRARY_PATH//:/\\n}'
alias print='/usr/bin/lp -o nobanner -d $LPDEST'
            # Assumes LPDEST is defined (default printer)
alias pjet='enscript -h -G -fCourier9 -d $LPDEST'
            # Pretty-print using enscript

alias du='du -kh'       # Makes a more readable output.
alias df='df -kTh'

alias dt='dmesg | tail'
alias grep='grep --color=auto'
export GREP_OPTIONS='--exclude-dir=CVS'


 #ls family
alias ll="ls -l --group-directories-first"
alias ls='ls -hF --color'  # add colors for filetype recognition
alias la='ls -Al'          # show hidden files
alias lx='ls -lXB'         # sort by extension
alias lk='ls -lSr'         # sort by size, biggest last
alias lc='ls -ltcr'        # sort by and show change time, most recent last
alias lu='ls -ltur'        # sort by and show access time, most recent last
alias lt='ls -ltr'         # sort by date, most recent last
alias lm='ls -al |more'    # pipe through 'more'
alias lr='ls -lR'          # recursive ls
alias tree='tree -Csu'     # nice alternative to 'recursive ls'

# Compile alias
alias upgrub='sudo grub-mkconfig -o /boot/grub/grub.cfg'

alias cctags='ctags -R --languages=C,C++ --c++-kinds=+p --fields=+iaS --extra=+q ./'
alias indentkr='indent -kr -i8'
alias indentkernel='indent -kr -i8 -ts8 -sob -l80 -ss -bs -psl'

alias packer='packer-color'

# Things i'll forget otherwise...
alias wgetall='wget --mirror -p --convert-links -P' # ./LOCAL_DIR WEBSITE-URL

#==========================================================================
# Some general settings
#===========================================================================

# Use extended pattern matching (not sure if toggled on reboot or not)
shopt -s extglob
# Check using rm !(args).

export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
export CLICOLOR=1
#export LSCOLORS=ExFxCxDxBxegedabagacad

ulimit -S -c 0 # Don't post core dumps

shopt -u mailwarn
unset MAILCHECK # Don't warn of new mail

export HOSTFILE=$HOME/.hosts # Put list of remote hosts in local file

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Erase duplicates in history
export HISTCONTROL=erasedups

# Store 10k history entries
export HISTSIZE=10000

# Append to the history file when exiting instead of overwriting it
shopt -s histappend

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

if [ "$SSH_CONNECTION" ]; then
	UC=$COLOR_CYAN
elif [ $UID -eq "0" ]; then
	UC=$COLOR_RED
else
	UC=$COLOR_BLUE
fi

# Replace \W with \w in promts for full paths
# Important lesson here:
# For variables to change after bash is instantiated, you need to escape the
# "$" character, otherwise it is expanded on instantiation of the bash instance.
function fastprompt() {
    case $TERM in
        *term | rxvt )
	     PS1="$TITLEBAR\n${UC}\u@\h ${COLOR_LIGHT_GREEN}\${PWD} ${COLOR_CYAN}\n-> " ;;
         linux )
             PS1="${UC}[\h]$NC \W > " ;;
        *)
            PS1="[\h] \W > " ;;
    esac
}

fastprompt
