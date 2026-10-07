#!/usr/bin/env bash
# =====================================================================
# Symlink every file in home/ into a target home directory, and every entry
# in config/ (e.g. nvim) into <home>/.config.
# =====================================================================
# Usage: install/symlinks.sh [home_directory]   (defaults to $HOME)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
HOME_SRC="$REPO_DIR/home"
CONFIG_SRC="$REPO_DIR/config"
TARGET="${1:-$HOME}"

if [ ! -d "$HOME_SRC" ]; then
    echo "Error: '$HOME_SRC' does not exist." >&2
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "Error: target home directory '$TARGET' does not exist." >&2
    exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

# link_dir <source_dir> <dest_dir>: symlink each entry of source_dir into dest_dir
link_dir() {
    local src_dir="$1" dest_dir="$2" src name dest
    mkdir -p "$dest_dir"
    for src in "$src_dir"/*; do
        name="$(basename "$src")"
        dest="$dest_dir/$name"

        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
            echo "SKIPPING: '$name' already linked"
            continue
        fi

        if [ -e "$dest" ] || [ -L "$dest" ]; then
            echo "BACKUP:   '$dest' -> '$dest.bak'"
            mv "$dest" "$dest.bak"
        fi

        echo "+ LINK:    $name"
        ln -s "$src" "$dest"
    done
}

shopt -s dotglob nullglob
link_dir "$HOME_SRC" "$TARGET"
# Per-app dirs (nvim, ...) go under .config so ~/.config itself is never replaced
[ -d "$CONFIG_SRC" ] && link_dir "$CONFIG_SRC" "$TARGET/.config"
shopt -u dotglob nullglob

echo "Done. Linked $HOME_SRC -> $TARGET"
