
# Support both bash (BASH_SOURCE) and zsh ($0)
if [ -n "$BASH_VERSION" ]; then
    THIS_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
elif [ -n "$ZSH_VERSION" ]; then
    THIS_SCRIPT_DIR=$(cd "$(dirname "${(%):-%x}")" && pwd)
else
    THIS_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
fi

export EDITOR="vim"
export VISUAL="$EDITOR"

if [ -d /usr/mgc ]; then
    export VCO=$(CALIBRE_ENABLE_AOJ_BUILDS=1 /usr/mgc/bin/mgcvco)
fi

export MANPATH
MANPATH=""
# We want to pick up git here as it's newer/better than /user/gitdet
POSSIBLE_MANPATHS=(
    /home/gitdet/share/man
    /opt/puppetlabs/puppet/share/man
)
for mp in "${POSSIBLE_MANPATHS[@]}"; do
    if [ -d "$mp" ]; then
        MANPATH=${MANPATH}${MANPATH:+:}$mp
    fi
done
MANPATH=${MANPATH}${MANPATH:+:}$(manpath -g)

export PATH
PATH=""

POSSIBLE_PATHS=(
    ${HOME}/bin
    /usr/local/bin
    /user/calibre/container-tools/bin
    /user/gitdet/bin
    /usr/mgc/bin
    /usr/mgc/peteoss/bin
    /user/pete/bin
    /user/pete/${VCO}/bin
    /user/peteoss/bin
    /user/peteoss/${VCO}/bin
    /user/icdet/bin
    /bin
    /usr/bin
    /usr/opt/bin
    /usr/opt/tv
    /usr/opt/udb_latest # For udb
    /user/cqi/toolsets/any/bin
    /user/pevtools/bin
    ${HOME}/.local/bin
    /snap/bin
    /opt/homebrew/bin
    /usr/local/bin
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


if [ -f /user/pete/bin/env_init.sh ]; then
    # Licensing server imports - env_init.sh gives us the lserver command among other things
    . /user/pete/bin/env_init.sh
    lserver set --tools calibre,tv
fi
if [ -f ${THIS_SCRIPT_DIR}/siemens_utils ]; then
    source ${THIS_SCRIPT_DIR}/siemens_utils
fi
if [ -f /user/icdet/bin/calgrid.sh ]; then
    . /user/icdet/bin/calgrid.sh
fi

if [ -r "$HOME/.env" ]; then
    source "$HOME/.env"
fi