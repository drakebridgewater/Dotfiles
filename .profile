
# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
 
eval $(/user/pete/lib/lserver_manager/lic_server_info set -sh --tools calibre,corp)
 
export EDITOR="/usr/bin/vim"
export VISUAL="$EDITOR"
export MANPATH="$MANPATH:/home/gitdet/share/man"
export VCO=$(CALIBRE_ENABLE_AOJ_BUILDS=1 /usr/mgc/bin/mgcvco)
 
# setup PATH
export PATH
# PATH=/user/gitdet/opt/git-blame-cache/bin
PATH=${HOME}/bin
# PATH=${PATH}${PATH:+:}${HOME}/bin
PATH=${PATH}${PATH:+:}/user/gitdet/bin
PATH=${PATH}${PATH:+:}/usr/mgc/bin
PATH=${PATH}${PATH:+:}/usr/mgc/peteoss/bin
PATH=${PATH}${PATH:+:}/user/pete/bin
PATH=${PATH}${PATH:+:}/user/pete/${VCO}/bin
PATH=${PATH}${PATH:+:}/user/peteoss/bin
PATH=${PATH}${PATH:+:}/user/peteoss/${VCO}/bin
PATH=${PATH}${PATH:+:}/user/icdet/bin
PATH=${PATH}${PATH:+:}/bin
PATH=${PATH}${PATH:+:}/usr/bin
PATH=${PATH}${PATH:+:}/usr/opt/bin
PATH=${PATH}${PATH:+:}/usr/opt/tv
PATH=${PATH}${PATH:+:}/user/pevtools/bin
PATH=${PATH}${PATH:+:}${HOME}/Dotfiles/pushover/
PATH=${PATH}${PATH:+:}/Dotfiles/bin/

if [ -d $HOME/neovim/bin ]; then
    PATH=${HOME}/neovim/bin${PATH:+:}${PATH}
fi

. /user/icdet/bin/calgrid.sh
