#!/bin/bash

set -ouex pipefail

# Fedora packages

FEDORA_PACKAGES=(
    incus
    incus-agent
    fastfetch
    fish
    lxc
    podman-compose
    podman-machine
    rclone
    zsh
)

dnf -y install  "${FEDORA_PACKAGES[@]}"

# Docker packages from their repo

dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sed -i "s/enabled=.*/enabled=0/g" /etc/yum.repos.d/docker-ce.repo
dnf -y install --enablerepo=docker-ce-stable \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    docker-model-plugin

# VSCode package from Microsoft repo
echo "Installing VSCode from official repo..."
tee /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
sed -i "s/enabled=.*/enabled=0/g" /etc/yum.repos.d/vscode.repo
dnf -y install --enablerepo=code \
    code

# Install tailscale package from their repo
echo "Installing tailscale from official repo..."
dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf config-manager setopt tailscale-stable.enabled=0
dnf -y install --enablerepo='tailscale-stable' tailscale


systemctl enable podman.socket
