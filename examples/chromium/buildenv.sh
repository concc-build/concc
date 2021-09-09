CHROMIUM="$1"

CHROMIUM_SRC=https://chromium.googlesource.com/chromium/src
DEPS="$CHROMIUM_SRC/+/$CHROMIUM/DEPS?format=TEXT"
INSTALL_BUILD_DEPS_SH="$CHROMIUM_SRC/+/$CHROMIUM/build/install-build-deps.sh?format=TEXT"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git lsb-release

git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git \
  /opt/depot_tools
rm -rf /opt/depot_tools/.git  # disable auto update
chmod o+rw /opt/depot_tools  # some files will be created when running it

curl -fsSL $INSTALL_BUILD_DEPS_SH | base64 -d | sed -e 's|sudo||g' | \
  sed -e 's|snapcraft|curl|g' | \
  bash -es -- --no-chromeos-fonts --no-prompt

# cleanup
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/tmp/*
rm -rf /tmp/*
