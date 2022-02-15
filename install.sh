#!/bin/sh
# SPDX-License-Identifier: MIT

set -e

export LC_ALL=C
export LANG=C

if [ "$USER" = "root" ]; then
  echo "This script needs to be called from an unprivileged user."
  exit 1
fi

cd "$(dirname "$0")"

build_asahi_installer() {(
  echo "Building asahi-installer..."
  echo "  - Setting up..."

  # The 7zip installed by homebrew is called 7zz for some reason...
  mkdir -p ./tmp-bin
  echo '#!/bin/sh' > ./tmp-bin/7z
  echo 'exec 7zz $@' >> ./tmp-bin/7z
  chmod +x ./tmp-bin/7z
  export PATH="$PWD/tmp-bin:$PATH"

  # Use cpio
  export PATH="/opt/homebrew/opt/cpio/bin:$PATH"

  echo "  - Building..."
  ./asahi-installer/build.sh
)}

build_uboot() {(
  echo "Building u-boot..."
  echo "  - Setting up..."

  # TODO: Probably use master at some point, maybe?
  # TODO: Use a git submodule instead for maximum reproducibility
  rm -rf u-boot
  git clone --depth 1 https://github.com/jannau/u-boot -b x2r10g10b10
  cd u-boot

  echo "  - Patching [1/1]..."
  patch -p1 -i ../patches/v2-console-usb-kbd-Limit-poll-frequency-to-improve-performance.diff

  echo "  - Building..."
  make apple_m1_defconfig
  make -j "$(nproc)"

  echo "  - Wrapping up..."
  cat \
    ../asahi-installer/m1n1/build/m1n1.bin \
    $(find ../linux/arch/arm64/boot/dts/apple/ -name "*.dtb") \
    u-boot/nodtb.bin \
  > ../u-boot.bin
)}

build_linux() {(
  echo "Building linux..."
  echo "  - Setting up..."

  # TODO: Probably use the asahi branch or even master at some point, maybe?
  rm -rf linux
  git clone --depth 1 https://github.com/AsahiLinux/linux -b smc/work
  cd linux

  echo "  - Patching [1/6]..."
  cat ../patches/HID-add-Apple-SPI-transport.patch | git am -
  echo "  - Patching [2/6]..."
  cat ../patches/mca-Move-MCLK-enable-disable-to-earlier.patch | git am -
  echo "  - Patching [3/6]..."
  cat ../patches/tas2770-Insert-post-reset-delay.patch | git am -
  echo "  - Patching [4/6]..."
  cat ../patches/dts-t600x-j314-j316-Add-NOR-flash-node.patch | git am -
  echo "  - Patching [5/6]..."
  cat ../patches/dts-t600x-Add-spi3-and-keyboard-nodes.patch | git am -
  echo "  - Patching [6/6]..."
  cat ../patches/0001-4k-iommu-patch.patch | git am -

  echo "  - Configuring..."
  cp ../linux-config .config
  make olddefconfig

  echo "  - Building..."
  make -j "$(nproc)" V=0 bindeb-pkg
)}

modify_step2() {(
  # TODO: unzip a rootfs tar.gz (e.g. alpine-minirootfs-3.15.0-aarch64.tar.gz)
  # TODO: take bootaa64.efi from e.g. alpine-standard-3.15.0-aarch64.iso to boot grub
  # TODO: create a dd-able img (see m1-debian/bootstrap.sh)
  # TODO: actually modify step2.sh for those files to be installed during the asahi install process
)}

install_asahi() {(
  TMP=/tmp/asahi-install
  PKG="$PWD/asahi-installer/installer.tar.gz"

  mkdir -p "$TMP"
  cd "$TMP"

  tar xf "$PKG"

  modify_step2

  echo "The installer needs to run as root."
  echo "Please enter your sudo password if prompted."
  exec sudo ./install.sh
)}

build_asahi_installer
build_linux
build_uboot
install_asahi
