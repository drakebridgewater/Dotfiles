FROM alpine:latest

# Install packages
RUN apk add --no-cache \
    zsh \
    git \
    curl \
    tmux \
    vim \
    openssh-client \
    fzf \
    ripgrep \
    bat \
    fd \
    jq \
    htop \
    ncurses \
    shadow \
    sudo \
    python3 \
    nodejs \
    npm

# Set zsh as default shell
RUN sed -i 's|/bin/ash|/usr/bin/zsh|' /etc/passwd

# Install Oh-My-Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins
RUN git clone https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Dotfiles will be mounted at /root/Dotfiles
# Symlinks are created at container start by the entrypoint
WORKDIR /root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["zsh", "-l"]
