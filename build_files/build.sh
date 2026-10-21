#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

dnf5 install -y alacritty fish greetd helix niri

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

### Prune services

# fedora-bootc base image does not come with ModemManager?
# systemctl disable ModemManager.service avahi-daemon.service avahi-daemon.socket
systemctl disable avahi-daemon.service avahi-daemon.socket

### Configure greeter

# enable if switching to fedora-silverblue base image
# systemctl disable gdm.service
systemctl enable greetd.service

useradd --home-dir / --no-create-home --system --shell /bin/nologin greeter

### Create the arcade user

useradd --create-home --shell /usr/bin/fish arcade

### Install RetroArch
#
# Built from source: the pinned upstream commit with retroarch/*.patch
# applied (ScreenScraper game media, XMB game backgrounds). The patches
# are made against this commit, so bump both together.

RETROARCH_COMMIT=7ef299dd3c851e6b87db4a376e4ce55b66e8f7fb

dnf5 install -y \
    gcc gcc-c++ make git pkgconf-pkg-config \
    mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel libdrm-devel \
    vulkan-headers vulkan-loader-devel \
    libX11-devel libXext-devel libXxf86vm-devel libXrandr-devel libXinerama-devel \
    libxkbcommon-devel wayland-devel wayland-protocols-devel \
    alsa-lib-devel pulseaudio-libs-devel pipewire-devel \
    systemd-devel freetype-devel zlib-ng-compat-devel

git init /tmp/retroarch
git -C /tmp/retroarch fetch --depth 1 https://github.com/libretro/RetroArch.git "$RETROARCH_COMMIT"
git -C /tmp/retroarch checkout FETCH_HEAD
git -C /tmp/retroarch apply /ctx/retroarch/*.patch

# Menu icons and fonts, installed to /usr/share/retroarch/assets
git clone --depth 1 https://github.com/libretro/retroarch-assets.git /tmp/retroarch/media/assets

cd /tmp/retroarch
./configure --prefix=/usr --disable-qt --disable-ffmpeg
make -j"$(nproc)"
make install HAVE_ASSETS=1
cd /
rm -rf /tmp/retroarch

dnf5 remove -y gcc gcc-c++

# Existing cabinets launch /opt/RetroArch/RetroArch.AppImage (in /var, so
# image updates never touch it or the saves beside it); this switches
# that path to the build above at boot, keeping the AppImage as a backup.
chmod 755 /usr/bin/arcade-retroarch /usr/libexec/arcade/retroarch-switch
systemctl enable arcade-retroarch-switch.service
