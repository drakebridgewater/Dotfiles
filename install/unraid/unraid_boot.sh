#!/bin/bash
# =====================================================================
# Unraid Boot Script — Starts the dotfiles shell container
# =====================================================================
# Called from /boot/config/go on every boot to start the pre-built
# dotfiles-shell Docker container.
#
# Added to /boot/config/go by unraid_setup.sh:
#   bash /boot/config/Dotfiles/Unraid/unraid_boot.sh
# =====================================================================

DOTFILES_DIR="/boot/config/Dotfiles"
UNRAID_DIR="$DOTFILES_DIR/Unraid"

# Check if Docker is installed at all
if ! command -v docker >/dev/null 2>&1; then
    echo "[unraid_boot] Docker command not found, skipping shell container start."
    exit 0
fi

# Check if Docker is disabled in Unraid settings.
# When disabled, the Docker config has DOCKER_ENABLED="no" and dockerd won't start.
DOCKER_CFG="/boot/config/docker.cfg"
if [ -f "$DOCKER_CFG" ]; then
    DOCKER_ENABLED=$(grep -oP '^DOCKER_ENABLED="\K[^"]+' "$DOCKER_CFG" 2>/dev/null || echo "")
    if [ "$DOCKER_ENABLED" = "no" ]; then
        echo "[unraid_boot] Docker is disabled in Unraid settings, skipping shell container start."
        exit 0
    fi
fi

# Wait for Docker daemon to be ready (it starts async on Unraid boot)
DOCKER_READY=false
for i in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
        DOCKER_READY=true
        break
    fi
    # If dockerd process isn't running at all, Docker is likely disabled or failed
    if ! pgrep -x dockerd >/dev/null 2>&1; then
        echo "[unraid_boot] dockerd process not running, skipping shell container start."
        exit 0
    fi
    sleep 2
done

if [ "$DOCKER_READY" != "true" ]; then
    echo "[unraid_boot] Docker not ready after 60s, skipping shell container start."
    exit 0
fi

# Start the container (rebuild if image is missing)
if docker image inspect dotfiles-shell >/dev/null 2>&1 || \
   docker image inspect "$(grep -oP 'image:\s*\K\S+' "$UNRAID_DIR/docker-compose.yml" 2>/dev/null)" >/dev/null 2>&1; then
    # Image exists, just start the container
    if command -v docker-compose >/dev/null 2>&1; then
        cd "$UNRAID_DIR" && docker-compose up -d 2>&1
    elif docker compose version >/dev/null 2>&1; then
        cd "$UNRAID_DIR" && docker compose up -d 2>&1
    else
        docker start dotfiles-shell 2>/dev/null || \
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
                dotfiles-shell 2>&1
    fi
else
    echo "[unraid_boot] dotfiles-shell image not found. Run unraid_setup.sh to build it."
fi
