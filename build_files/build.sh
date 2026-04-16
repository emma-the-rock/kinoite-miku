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
    waydroid
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

## Install CachyOS Kernel

dnf copr enable -y bieszczaders/kernel-cachyos-addons

# Adds required package for the scheduler
dnf install -y \
    --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons" \
    --allowerasing \
    libcap-ng libcap-ng-devel bore-sysctl cachyos-ksm-settings procps-ng procps-ng-devel uksmd libbpf scx-scheds scx-tools scx-manager cachyos-settings

# Adds the longterm kernel repo
dnf copr enable -y bieszczaders/kernel-cachyos-lto

# Remove useless kernels
readarray -t OLD_KERNELS < <(rpm -qa 'kernel-*')
if (( ${#OLD_KERNELS[@]} )); then
    rpm -e --justdb --nodeps "${OLD_KERNELS[@]}"
    dnf versionlock delete "${OLD_KERNELS[@]}" || true
    rm -rf /usr/lib/modules/*
    rm -rf /lib/modules/*
fi

# Install kernel packages (noscripts required for 43+)
dnf install -y \
    --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-lto" \
    --allowerasing \
    --setopt=tsflags=noscripts \
    kernel-cachyos-lto \
    kernel-cachyos-lto-devel-matched \
    kernel-cachyos-lto-devel \
    kernel-cachyos-lto-modules \
    kernel-cachyos-lto-core

KERNEL_VERSION="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-cachyos-lto)"

# Depmod (required for fedora 43+)
depmod -a "${KERNEL_VERSION}"

# Copy vmlinuz
VMLINUZ_SOURCE="/usr/lib/kernel/vmlinuz-${KERNEL_VERSION}"
VMLINUZ_TARGET="/usr/lib/modules/${KERNEL_VERSION}/vmlinuz"
if [[ -f "${VMLINUZ_SOURCE}" ]]; then
    cp "${VMLINUZ_SOURCE}" "${VMLINUZ_TARGET}"
fi

# Lock kernel packages
dnf versionlock add "kernel-cachyos-lto-${KERNEL_VERSION}" || true
dnf versionlock add "kernel-cachyos-lto-modules-${KERNEL_VERSION}" || true


# Dracut stuff
export DRACUT_NO_XATTR=1
dracut --force \
  --no-hostonly \
  --kver "${KERNEL_VERSION}" \
  --add-drivers "btrfs nvme xfs ext4" \
  --reproducible -v --add ostree \
  -f "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"


systemctl enable podman.socket
systemctl enable tailscaled.service