#!/bin/sh

PROJDIR=$(cd $(dirname $0)/..; pwd)
WORKDIR=$PROJDIR/examples/gcc

mkdir -p $WORKDIR/workspace/strace_concc_1job
make -C $WORKDIR build JOBS=1 GCC='strace -ttT -ff -o /workspace/strace_concc_1job/gcc gcc'

mkdir -p $WORKDIR/workspace/strace_concc_$(nproc)jobs
make -C $WORKDIR build JOBS=$(nproc) GCC="strace -ttT -ff -o /workspace/strace_concc_$(nproc)jobs/gcc gcc"

mkdir -p $WORKDIR/workspace/strace_nondist_1job
make -C $WORKDIR nondist-build JOBS=1 GCC='strace -ttT -ff -o /workspace/strace_nondist_1job/gcc gcc'

mkdir -p $WORKDIR/workspace/strace_nondist_$(nproc)jobs
make -C $WORKDIR nondist-build JOBS=$(nproc) GCC="strace -ttT -ff -o /workspace/strace_nondist_$(nproc)jobs/gcc gcc"
