CARGO_REGISTRY=/usr/local/cargo/registry

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

  echo "$WORKER: Mounting the proj directory..."
  ssh -p $WORKER_PORT $WORKER_HOST \
    sshfs -p $CLIENT_PORT $CLIENT_HOST:/proj /proj

  echo "$WORKER: Mounting the Cargo registry..."
  mkdir -p $CARGO_REGISTRY
  ssh -p $WORKER_PORT $WORKER_HOST mkdir -p $CARGO_REGISTRY
  ssh -p $WORKER_PORT $WORKER_HOST \
    sshfs -p $CLIENT_PORT $CLIENT_HOST:$CARGO_REGISTRY $CARGO_REGISTRY

  LIMIT=$(ssh -p $WORKER_PORT $WORKER_HOST nproc)
  echo "$WORKER: Maximum number of jobs: $LIMIT"

  echo "Add $WORKER to the worker pool..."
  /opt/concc/worker-pool add $WORKER $LIMIT

  JOBS=$(expr $JOBS + $LIMIT)
done

echo "Maximum number of jobs: $JOBS"

echo "Building with worker containers..."
export RUSTC_WRAPPER='/opt/concc/concc-wrapper'
cargo build --release -j $JOBS
