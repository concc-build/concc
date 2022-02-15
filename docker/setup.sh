export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends fuse3 gosu libglib2.0-0 ssh sshpass
apt-get install -y --no-install-recommends strace  # for tracing syscalls
apt-get install -y --no-install-recommends time  # for measurements
apt-get install -y --no-install-recommends iproute2  # for simulating a high rtt
apt-get install -y --no-install-recommends iputils-ping  # for measuring rtt
apt-get install -y --no-install-recommends icecc icecream-sundae  # for performance comparison

YQ_VERSION=v4.16.2
YQ_BINARY=yq_linux_amd64
YQ_DL_URL=https://github.com/mikefarah/yq/releases/download
apt-get install -y --no-install-recommends ca-certificates curl
curl -fsSL $YQ_DL_URL/$YQ_VERSION/$YQ_BINARY >/usr/local/bin/yq
chmod +x /usr/local/bin/yq

ssh-keygen -q -t ed25519 -N '' -f $HOME/.ssh/id_ed25519
cp $HOME/.ssh/id_ed25519.pub $HOME/.ssh/authorized_keys
cat <<'EOF' >$HOME/.ssh/config
Host *
  StrictHostKeyChecking no
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlMaster auto
  ControlPersist 1m
EOF

# cleanup
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/tmp/*
