include ../common.makefile

# In this example, only CC commands will be distributed, any command can be
# distributed theoretically.
CONCC_CC := "concc-dispatch gcc"
ICECC_CC := "icecc gcc"

BUILDENV := gcc-buildenv
REMOTE_CONTAINER := gcc-worker
REPO := https://github.com/jemalloc/jemalloc.git
CONFIGURE_CMD := ./autogen.sh
BUILD_CMD := make -j $(JOBS) CC=$(CONCC_CC)
NONDIST_CONFIGURE_CMD := $(CONFIGURE_CMD)
NONDIST_BUILD_CMD := make -j $(shell nproc)
ICECC_CONFIGURE_CMD := $(CONFIGURE_CMD)
ICECC_BUILD_CMD := make -j $(ICECC_JOBS) CC=$(ICECC_CC)
CHECK_CMD := make -j $(JOBS) CC=$(CONCC_CC) check
SRC_CLEAN_CMD := make -C workspace/src clean

workspace:
	git clone --depth=1 $(REPO) workspace/src
