PROGNAME=$(basename $0)
BASEDIR=$(cd $(dirname $0); pwd)
PROJDIR=$BASEDIR/..

log() {
  echo "$1" >&2
}

vlog() {
  if [ $VERBOSE -ge $1 ]
  then
    log "LOG($1): $2"
  fi
}

error() {
  log "ERROR: $1"
  exit 1
}

measure() {
  EXAMPLE="examples/$1"
  DELAY="$2"

  if [ "$DELAY" = '0' ]
  then
    log "Measuring $EXAMPLE without delay..."
    TEST_OPTIONS='--keep'
  else
    log "Measuring $EXAMPLE with ${DELAY}ms delay..."
    TEST_OPTIONS="--keep --rtt-delay ${DELAY}ms"
  fi

  # The output from `/usr/bin/time -p` contains '\r'.
  ELAPSED=$(make -C $PROJDIR/$EXAMPLE build TEST_OPTIONS="$TEST_OPTIONS" 2>&1 | \
            grep -e '^real ' | cut -d ' ' -f 2 | tr -d '\r')
  NREQS=$(docker exec concc-poc-worker cat .workspacefs.d/sftp.requests | \
          awk '{sum+=$2;}END{print sum;}')
  make -C $PROJDIR/$EXAMPLE clean >/dev/null 2>&1
  echo concc $DELAY $ELAPSED $NREQS

  ELAPSED=$(make -C $PROJDIR/$EXAMPLE icecc-build JOBS=$(nproc) 2>&1 | \
            grep -e '^real ' | cut -d ' ' -f 2 | tr -d '\r')
  echo icecc $DELAY $ELAPSED
}

for A in gcc
do
  for B in 0 1 2 3 4 5 10
  do
    measure $A $B
  done
done
