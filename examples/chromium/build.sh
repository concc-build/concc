CLIENT=$1
CLIENT_HOST=$(echo $CLIENT | cut -d ':' -f 1)
CLIENT_PORT=$(echo $CLIENT | cut -d ':' -f 2)
shift 1

TARGET=$1
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

  echo "$WORKER: Mounting the chromium directory..."
  ssh -p $WORKER_PORT $WORKER_HOST \
    sshfs -p $CLIENT_PORT $CLIENT_HOST:/chromium/src /chromium/src

  LIMIT=$(ssh -p $WORKER_PORT $WORKER_HOST nproc)
  echo "$WORKER: Maximum number of jobs: $LIMIT"

  echo "Add $WORKER to the worker pool..."
  /opt/concc/worker-pool add $WORKER:22 $LIMIT

  JOBS=$(expr $JOBS + $LIMIT)
done

echo "Maximum number of jobs: $JOBS"

echo "Generating Ninja files..."
gn gen out/Default --args='cc_wrapper="/opt/concc/concc-wrapper"'

echo "Building $TARGET with worker containers..."
autoninja -C out/Default -j $JOBS $TARGET
