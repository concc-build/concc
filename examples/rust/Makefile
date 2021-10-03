include ../common.makefile

RUSTC_WRAPPER := concc-dispatch

BUILDENV := rust-buildenv
REMOTE_CONTAINER := rust-worker
REPO := https://github.com/BurntSushi/ripgrep.git
CONFIGURE_CMD :=
BUILD_CMD := 'RUSTC_WRAPPER=$(RUSTC_WRAPPER) cargo build --release -j $(JOBS)'
NONDIST_CONFIGURE_CMD :=
NONDIST_BUILD_CMD := 'cargo build --release'
CHECK_CMD := 'RUSTC_WRAPPER=$(RUSTC_WRAPPER) cargo test --release -j $(JOBS)'
SRC_CLEAN_CMD := cd workspace/src && cargo clean

workspace:
	git clone --depth=1 $(REPO) workspace/src
