# Shared loader for bashrc.d function files.
# Sourced by .zshrc, .bashrc, .zshrc.legacy and shell/minimal.sh so that load
# order and error handling live in exactly one place.

_dotfiles_load_bashrcd() {
    local dir="${1:-${DOTFILES_DIR:-$HOME/Dotfiles}/shell/common}"
    [ -d "$dir" ] || return 0

    # logging defines die/info/error used by the other files, so it goes first
    # rather than relying on where it happens to fall in glob order.
    if [ -r "$dir/logging" ]; then
        . "$dir/logging" || echo "dotfiles: failed to load $dir/logging" >&2
    fi

    local f
    for f in "$dir"/*; do
        case "$f" in
            */logging | *.bak | *~ | *.swp | *.disabled) continue ;;
        esac
        [ -f "$f" ] && [ -r "$f" ] || continue
        # Isolate failures: a broken helper must not abort the rest of the rc.
        . "$f" || echo "dotfiles: failed to load $f" >&2
    done
}
