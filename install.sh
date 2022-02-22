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
  docker build -t m1-asahi -f Dockerfile.asahi src
  docker run --rm m1-asahi cat installer.tar.gz > src/dest/installer.tar.gz
  docker run --rm m1-asahi cat package/m1n1.bin > src/dest/m1n1.bin
)}

build_uboot() {(
  docker build -t m1-uboot -f Dockerfile.uboot src
  docker run --rm m1-uboot cat u-boot-nodtb.bin > src/dest/u-boot-nodtb.bin
  cat src/dest/m1n1.bin src/dest/linux.dtb src/dest/u-boot-nodtb.bin > src/dest/u-boot.bin
)}

build_linux() {(
  docker build -t m1-linux -f Dockerfile.linux src
  docker run --rm m1-linux cat linux.deb > src/dest/linux.deb
  docker run --rm m1-linux cat linux.dtb > src/dest/linux.dtb
)}

build_media() {(
  docker build -t m1-media -f Dockerfile.media src
  docker run --rm m1-media cat m1.tar.gz > src/dest/m1.tar.gz
)}

modify_step2() {(
  # TODO: take bootaa64.efi from e.g. alpine-standard-3.15.0-aarch64.iso to boot grub
  # TODO: create a dd-able img (see m1-debian/bootstrap.sh)
  # TODO: actually modify step2.sh for those files to be installed during the asahi install process
  return
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

mkdir -p src/dest

build_asahi_installer
build_linux
build_uboot
build_media
#install_asahi
