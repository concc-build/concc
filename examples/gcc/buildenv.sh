export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends autoconf automake build-essential

# cleanup
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/tmp/*
rm -rf /tmp/*
