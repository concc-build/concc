export CONCC_DIR=/home/concc

CLIENT=$1
CLIENT_HOST=$(echo $CLIENT | cut -d ':' -f 1)
CLIENT_PORT=$(echo $CLIENT | cut -d ':' -f 2)
shift 1

echo "Starting SSH server..."
/etc/init.d/ssh start

CONCC_UID=$(ls -ld | cut -d ' ' -f 3)
if getent passwd $CONCC_UID
then
   CONCC_UID=$(getenv passwd $CONCC_UID | cut -d ':' -f 3)
fi

CONCC_GID=$(ls -ld | cut -d ' ' -f 4)
if getent group $CONCC_GID
then
  CONCC_GID=$(getenv group $CONCC_GID | cut -d ':' -f 3)
fi

echo "Creating a user account for concc with $CONCC_UID:$CONCC_GID..."
groupadd -o -g $CONCC_GID concc
useradd -o -m -g $CONCC_GID -u $CONCC_UID concc

echo "Copying /home/concc/.ssh from /root/.ssh..."
cp -R $HOME/.ssh /home/concc/
chown -R concc:concc /home/concc/.ssh

echo "Initializing the worker pool..."
gosu concc /opt/concc/worker-pool reset

JOBS=0

for WORKER in $@
do
  WORKER_HOST=$(echo $WORKER | cut -d ':' -f 1)
  WORKER_PORT=$(echo $WORKER | cut -d ':' -f 2)

  echo "$WORKER: Creating a user account for concc with $CONCC_UID:$CONCC_GID..."
  ssh -p $WORKER_PORT $WORKER_HOST groupadd -o -g $CONCC_GID concc
  ssh -p $WORKER_PORT $WORKER_HOST useradd -o -m -g $CONCC_GID -u $CONCC_UID concc

  echo "$WORKER: Copying /home/concc/.ssh..."
  scp -P $WORKER_PORT -r /home/concc/.ssh $WORKER_HOST:/home/concc/
  ssh -p $WORKER_PORT $WORKER_HOST chown -R concc:concc /home/concc/.ssh

  until ssh -O check -p $WORKER_PORT concc@$WORKER_HOST
  do
    echo "$WORKER: Establishing a SSH control master connection..."
    ssh -p $WORKER_PORT concc@$WORKER_HOST :
  done

  echo "$WORKER: Mounting the proj directory..."
  ssh -p $WORKER_PORT $WORKER_HOST chown concc:concc /proj
  ssh -p $WORKER_PORT concc@$WORKER_HOST \
    sshfs -p $CLIENT_PORT concc@$CLIENT_HOST:/proj /proj

  LIMIT=$(ssh -p $WORKER_PORT $WORKER_HOST nproc)
  echo "$WORKER: Maximum number of jobs: $LIMIT"

  echo "Add $WORKER to the worker pool..."
  gosu concc /opt/concc/worker-pool add $WORKER $LIMIT

  JOBS=$(expr $JOBS + $LIMIT)
done

echo "Maximum number of jobs: $JOBS"

echo "Building with worker containers..."
gosu concc make -j $JOBS CC='/opt/concc/concc-wrapper gcc'
