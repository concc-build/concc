CHROMIUM="$1"

CHROMIUM_SRC=https://chromium.googlesource.com/chromium/src
DEPS="$CHROMIUM_SRC/+/$CHROMIUM/DEPS?format=TEXT"
INSTALL_BUILD_DEPS_SH="$CHROMIUM_SRC/+/$CHROMIUM/build/install-build-deps.sh?format=TEXT"
CLANG_UPDATE_PY="$CHROMIUM_SRC/+/$CHROMIUM/tools/clang/scripts/update.py?format=TEXT"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl file git lsb-release
apt-get install -y --no-install-recommends icecc

git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git \
  /opt/depot_tools
rm -rf /opt/depot_tools/.git  # disable auto update
chmod o+rw /opt/depot_tools  # some files will be created when running it

curl -fsSL $INSTALL_BUILD_DEPS_SH | base64 -d | sed -e 's|sudo||g' | \
  sed -e 's|snapcraft|curl|g' | \
  bash -es -- --no-chromeos-fonts --no-prompt

mkdir -p /opt/clang
curl -fsSL $CLANG_UPDATE_PY | base64 -d | python3 - --output-dir=/opt/clang

icecc-create-env --clang /opt/clang/bin/clang
mv $(/bin/ls -1 *.tar.gz) /opt/clang.chromium.$CHROMIUM.tar.gz

# cleanup
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/tmp/*
rm -rf /tmp/*
