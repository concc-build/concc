include ../common.makefile

# Using strace
# ------------
# Specify GCC like below:
#
#   GCC='strace -ttT -ff -o /workspace/strace/gcc gcc'
#
# /workspace/strace must be created before building.

GCC ?= gcc

# In this example, only CC commands will be distributed, any command can be
# distributed theoretically.
CONCC_CC = "$(TIME_CLIENT) concc-dispatch $(TIME_WORKER) $(GCC)"
NONDIST_CC = "$(TIME_NONDIST) $(STRACE) $(GCC)"
ICECC_CC = "$(TIME_ICECC) icecc $(GCC)"

BUILDENV := gcc-buildenv
REMOTE_CONTAINER := gcc-worker
REPO := https://github.com/jemalloc/jemalloc.git
CONFIGURE_CMD := ./autogen.sh
BUILD_CMD = make -j $(JOBS) CC=$(CONCC_CC)
NONDIST_CONFIGURE_CMD := $(CONFIGURE_CMD)
NONDIST_BUILD_CMD = make -j $(JOBS) CC=$(NONDIST_CC)
ICECC_CONFIGURE_CMD := $(CONFIGURE_CMD)
ICECC_BUILD_CMD = make -j $(JOBS) CC=$(ICECC_CC)
CHECK_CMD = make -j $(JOBS) CC=$(CONCC_CC) check
SRC_CLEAN_CMD := make -C workspace/src clean

workspace:
	git clone --depth=1 $(REPO) workspace/src
