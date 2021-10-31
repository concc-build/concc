export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  build-essential ca-certificates curl git meson ninja-build \
  libfuse3-dev libglib2.0-dev

git clone --depth=1 https://github.com/libfuse/sshfs.git /sshfs-src
meson --buildtype=release /sshfs-src
ninja
strip ./sshfs
./sshfs --version
