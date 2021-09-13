CLIENT=$1
CLIENT_HOST=$(echo $CLIENT | cut -d ':' -f 1)
CLIENT_PORT=$(echo $CLIENT | cut -d ':' -f 2)
shift 1

echo "Starting SSH server..."
/etc/init.d/ssh start

echo "Initialize the worker pool..."
/opt/concc/worker-pool reset

JOBS=0

for WORKER in $@
do
  WORKER_HOST=$(echo $WORKER | cut -d ':' -f 1)
  WORKER_PORT=$(echo $WORKER | cut -d ':' -f 2)

  until ssh -O check -p $WORKER_PORT $WORKER_HOST
  do
    echo "$WORKER: Establishing a SSH control master connection..."
    ssh -p $WORKER_PORT $WORKER_HOST :
  done

  echo "$WORKER: Mounting the proj directory..."
  ssh -p $WORKER_PORT $WORKER_HOST \
    sshfs -p $CLIENT_PORT $CLIENT_HOST:/proj /proj

  LIMIT=$(ssh -p $WORKER_PORT $WORKER_HOST nproc)
  echo "$WORKER: Maximum number of jobs: $LIMIT"

  echo "Add $WORKER to the worker pool..."
  /opt/concc/worker-pool add $WORKER $LIMIT

  JOBS=$(expr $JOBS + $LIMIT)
done

echo "Maximum number of jobs: $JOBS"

echo "Building with worker containers..."
make -j $JOBS CC='/opt/concc/concc-wrapper gcc'
