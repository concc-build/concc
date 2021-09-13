#!/bin/sh
SSH_MAX_SESSIONS=${CONCC_MAX_JOBS:-$(nproc)}
sed -i "s|#MaxSessions .*|MaxSessions $SSH_MAX_SESSIONS|" /etc/ssh/sshd_config
/etc/init.d/ssh start
tail -F /dev/null
