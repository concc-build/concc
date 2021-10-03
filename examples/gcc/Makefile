include ../common.makefile

# In this example, only CC commands will be distributed, any command can be
# distributed theoretically.
CC := "concc-dispatch gcc"

BUILDENV := gcc-buildenv
REMOTE_CONTAINER := gcc-worker
REPO := https://github.com/jemalloc/jemalloc.git
CONFIGURE_CMD := './autogen.sh'
BUILD_CMD := 'make -j $(JOBS) CC=$(CC)'
NONDIST_CONFIGURE_CMD := $(CONFIGURE_CMD)
NONDIST_BUILD_CMD := 'make -j $(shell nproc)'
CHECK_CMD := 'make -j $(JOBS) CC=$(CC) check'
SRC_CLEAN_CMD := make -C workspace/src clean

workspace:
	git clone --depth=1 $(REPO) workspace/src
