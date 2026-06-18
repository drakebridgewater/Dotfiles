
# Support both bash (BASH_SOURCE) and zsh ($0)
if [ -n "$BASH_VERSION" ]; then
    THIS_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
elif [ -n "$ZSH_VERSION" ]; then
    THIS_SCRIPT_DIR=$(cd "$(dirname "${(%):-%x}")" && pwd)
else
    THIS_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
fi

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
 
export EDITOR="/usr/bin/vim"
export VISUAL="$EDITOR"

if [ -d /home/gitdet ]; then
    export MANPATH="$MANPATH:/home/gitdet/share/man"
fi
    
if [ -d /usr/mgc ]; then
    export VCO=$(CALIBRE_ENABLE_AOJ_BUILDS=1 /usr/mgc/bin/mgcvco)
fi
if [ -f /user/pete/lib/lserver_manager/lic_server_info ]; then
    eval $(/user/pete/lib/lserver_manager/lic_server_info set -sh --tools calibre,corp)
fi
if [ -f ${THIS_SCRIPT_DIR}/siemens_utils ]; then
    source ${THIS_SCRIPT_DIR}/siemens_utils
fi
if [ -f /user/icdet/bin/calgrid.sh ]; then
    . /user/icdet/bin/calgrid.sh
fi

if [ -f $HOME/.env ]; then
    source "$HOME/.env"
fi

export PATH
PATH=""

POSSIBLE_PATHS=(
    ${HOME}/bin
    /usr/local/bin
    /user/gitdet/bin
    /usr/mgc/bin
    /usr/mgc/peteoss/bin
    /user/pete/bin
    /user/pete/${VCO}/bin
    /user/peteoss/bin
    /user/peteoss/${VCO}/bin
    /user/icdet/bin
    /snap/bin
    /opt/homebrew/bin
    /opt/homebrew/sbin
    /usr/local/bin
    /usr/local/sbin
    /bin
    /usr/bin
    /sbin
    /usr/sbin
    /usr/opt/bin
    /usr/opt/tv
    /user/pevtools/bin
    ${HOME}/.local/bin
    ${THIS_SCRIPT_DIR}/pushover
    ${THIS_SCRIPT_DIR}/bin
    ${THIS_SCRIPT_DIR}/siemens/bin
    ${HOME}/.local/share/JetBrains/Toolbox/scripts
    /boot/config/Dotfiles/bin
    /boot/config/Dotfiles/pushover
)

for p in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$p" ]; then
        PATH=${PATH}${PATH:+:}$p
    fi
done
