
# Support both bash (BASH_SOURCE) and zsh ($0)
if [ -n "$BASH_VERSION" ]; then
    THIS_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
elif [ -n "$ZSH_VERSION" ]; then
    THIS_SCRIPT_DIR=$(cd "$(dirname "${(%):-%x}")" && pwd)
else
    THIS_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
fi

# This file is normally reached as ~/.profile, a symlink into the repo, so the
# directory above must be resolved through the link to find the repo root.
if [ -L "$THIS_SCRIPT_DIR/.profile" ] || [ -L "$HOME/.profile" ]; then
    _dot_real=$(readlink -f "$HOME/.profile" 2>/dev/null)
    [ -n "$_dot_real" ] && THIS_SCRIPT_DIR=$(dirname "$_dot_real")
    unset _dot_real
fi
DOTFILES_DIR=$(dirname "$THIS_SCRIPT_DIR")
export DOTFILES_DIR

export EDITOR="vim"
export VISUAL="$EDITOR"

if [ -d /usr/mgc ]; then
    export VCO=$(CALIBRE_ENABLE_AOJ_BUILDS=1 /usr/mgc/bin/mgcvco)
fi

export MANPATH
MANPATH=""
if command -v manpath >/dev/null 2>&1; then
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
fi

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
    ${DOTFILES_DIR}/bin
    ${HOME}/.local/share/JetBrains/Toolbox/scripts
    /boot/config/Dotfiles/bin
)

for p in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$p" ]; then
        PATH=${PATH}${PATH:+:}$p
    fi
done


if [ -f /user/pete/bin/env_init.sh ]; then
    # Licensing server imports - env_init.sh gives us the lserver command among other things
    . /user/pete/bin/env_init.sh
    # lserver set --tools calibre,tv   # slow; run by hand when licenses are needed
fi
# Work-only helpers: they shell out to /usr/mgc tooling, so gate them on the
# same markers .zshrc uses rather than on the file merely existing in the repo.
if [ -d /usr/mgc ] || [ -d /wv ]; then
    [ -d "${DOTFILES_DIR}/bin/work" ] && PATH="${PATH}:${DOTFILES_DIR}/bin/work"
    [ -f "${DOTFILES_DIR}/shell/work/siemens_utils" ] && . "${DOTFILES_DIR}/shell/work/siemens_utils"
fi
if [ -f /user/icdet/bin/calgrid.sh ]; then
    . /user/icdet/bin/calgrid.sh
fi

if [ -r "$HOME/.env" ]; then
    source "$HOME/.env"
fi