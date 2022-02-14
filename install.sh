#!/bin/sh

set -e

export LC_ALL=C
export LANG=C

if [ "$USER" = "root" ]; then
  echo "This script needs to be called from an unprivileged user."
  exit 1
fi

cd "$(dirname "$0")"

build_asahi_installer() {(
  # The 7zip installed by homebrew is called 7zz for some reason...
  mkdir -p ./tmp-bin
  echo '#!/bin/sh' > ./tmp-bin/7z
  echo 'exec 7zz $@' >> ./tmp-bin/7z
  chmod +x ./tmp-bin/7z
  export PATH="$PWD/tmp-bin:$PATH"

  # Use cpio
  export PATH="/opt/homebrew/opt/cpio/bin:$PATH"

  ./asahi-installer/build.sh
)}

install_asahi() {(
  TMP=/tmp/asahi-install
  PKG="$PWD/asahi-installer/installer.tar.gz"

  mkdir -p "$TMP"
  cd "$TMP"

  tar xf "$PKG"

  echo "The installer needs to run as root."
  echo "Please enter your sudo password if prompted."
  exec sudo ./install.sh
)}

build_asahi_installer
install_asahi
