include ../common.makefile

RUSTC_WRAPPER := concc-exec

BUILDENV := concc-poc/rust-buildenv
REPO := https://github.com/BurntSushi/ripgrep.git
CONFIGURE_CMD := true
BUILD_CMD = env RUSTC_WRAPPER=$(RUSTC_WRAPPER) cargo build --release -j $(JOBS)
NONDIST_CONFIGURE_CMD := $(CONFIGURE_CMD)
NONDIST_BUILD_CMD = cargo build --release -j $(JOBS)
ICECC_CONFIGURE_CMD := false
ICECC_BUILD_CMD := false
CHECK_CMD = env RUSTC_WRAPPER=$(RUSTC_WRAPPER) cargo test --release -j $(JOBS)
SRC_CLEAN_CMD := cd workspace/src && cargo clean

workspace:
	git clone --depth=1 $(REPO) workspace/src

workspace/workspacefs.override.yaml: workspacefs.override.yaml workspace
	-@cp -f $< $@
