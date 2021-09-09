export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends python3 ssh sshfs

sed -i 's|#PasswordAuthentication yes|PasswordAuthentication no|' /etc/ssh/sshd_config

ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519
cp /root/.ssh/id_ed25519.pub /root/.ssh/authorized_keys
cat <<EOF >/root/.ssh/config
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
