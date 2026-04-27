#!/bin/bash
# =====================================================================
# Unraid Initial Setup Script
# =====================================================================
# Builds and starts a Docker container with zsh, oh-my-zsh, and all
# dotfiles pre-configured. No host packages needed beyond Docker.
#
# Usage:
#   1. Clone this repo to /boot/config/Dotfiles (persistent storage)
#   2. Run: bash /boot/config/Dotfiles/Unraid/unraid_setup.sh
#   3. Attach: docker exec -it dotfiles-shell zsh
# =====================================================================

set -euo pipefail

DOTFILES_DIR="/boot/config/Dotfiles"
UNRAID_DIR="$DOTFILES_DIR/Unraid"

echo_msg() {
    local msg="$1"
    echo ""
    echo "====================================================================="
    echo "$msg"
    echo "====================================================================="
    echo ""
}

# =====================================================================
# Verify prerequisites
# =====================================================================
echo_msg "Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not available."
    echo "Ensure the Unraid Docker service is enabled:"
    echo "  Settings > Docker > Enable Docker: Yes"
    exit 1
fi

if [ ! -f "$UNRAID_DIR/Dockerfile" ]; then
    echo "ERROR: Dockerfile not found at $UNRAID_DIR/Dockerfile"
    echo "Clone the Dotfiles repo to /boot/config/Dotfiles first."
    exit 1
fi

echo "Docker is available."

# =====================================================================
# Build and start the shell container
# =====================================================================
echo_msg "Building dotfiles-shell container..."

if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    # Fallback: build and run without compose
    echo "docker-compose not found, using docker build/run directly..."
    docker build -t dotfiles-shell "$UNRAID_DIR"

    # Stop existing container if running
    docker rm -f dotfiles-shell 2>/dev/null || true

    docker run -d \
        --name dotfiles-shell \
        --hostname unraid-shell \
        --network host \
        --restart unless-stopped \
        -e TERM=xterm-256color \
        -e UNRAID=true \
        -v "$DOTFILES_DIR:/root/Dotfiles:ro" \
        -v /root/.ssh:/root/.ssh:ro \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /mnt/user:/mnt/user \
        dotfiles-shell

    echo_msg "Setup complete!"
    echo "Attach to the shell with:"
    echo "  docker exec -it dotfiles-shell zsh"
    exit 0
fi

cd "$UNRAID_DIR"
$COMPOSE_CMD up -d --build

# =====================================================================
# Register boot script in Unraid go file
# =====================================================================
echo_msg "Registering boot script..."

GO_FILE="/boot/config/go"
BOOT_LINE="bash $DOTFILES_DIR/Unraid/unraid_boot.sh"

if [ -f "$GO_FILE" ]; then
    if ! grep -qF "$BOOT_LINE" "$GO_FILE"; then
        echo "" >> "$GO_FILE"
        echo "# Start dotfiles-shell container on boot" >> "$GO_FILE"
        echo "$BOOT_LINE" >> "$GO_FILE"
        echo "Added boot script to $GO_FILE"
    else
        echo "Boot script already registered in $GO_FILE"
    fi
else
    echo "WARNING: $GO_FILE not found. Manually add to your go file:"
    echo "  $BOOT_LINE"
fi

# =====================================================================
# Done
# =====================================================================
echo_msg "Setup complete!"
echo "Attach to the shell:"
echo "  docker exec -it dotfiles-shell zsh"
echo ""
echo "Add a shell alias on the Unraid host for convenience:"
echo "  echo 'alias shell=\"docker exec -it dotfiles-shell zsh\"' >> /boot/config/go"
