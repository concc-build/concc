export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends gosu python3 ssh sshfs

sed -i 's|#PasswordAuthentication yes|PasswordAuthentication no|' /etc/ssh/sshd_config

ssh-keygen -q -t ed25519 -N '' -f $HOME/.ssh/id_ed25519
cp $HOME/.ssh/id_ed25519.pub $HOME/.ssh/authorized_keys
cat <<'EOF' >$HOME/.ssh/config
Host *
  StrictHostKeyChecking no
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlMaster auto
  ControlPersist 1m
EOF

# The python3 executable file may be replaced with a script file in order to distribute executions
# of python3 scripts onto worker containers.  Some of executable files contained in //docker/bin
# are python scripts which have to be executed on the client container.  We copy the python3
# executable file as concc-python3 and specify it in the shebang in each script file.
PYTHON3=$(which python3)
cp $PYTHON3 /usr/local/bin/concc-python3

# cleanup
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/tmp/*
