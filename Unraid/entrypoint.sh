#!/bin/sh
# Entrypoint for the Unraid dotfiles shell container.
# Creates symlinks from the mounted Dotfiles into $HOME, then exec's the CMD.

DOTFILES_DIR="$HOME/Dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
    # Run the standard symlink setup (handles backups and skip logic)
    bash "$DOTFILES_DIR/setup_dotfile_symlinks" "$HOME" 2>&1 | grep -v "^SKIPPING" || true
fi

exec "$@"
