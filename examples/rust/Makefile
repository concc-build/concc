include ../common.makefile

RUSTC_WRAPPER := concc-exec

BUILDENV := rust-buildenv
REMOTE_CONTAINER := rust-worker
REPO := https://github.com/BurntSushi/ripgrep.git
CONFIGURE_CMD := true
BUILD_CMD = env RUSTC_WRAPPER=$(RUSTC_WRAPPER) cargo build --release -j $(JOBS)
NONDIST_CONFIGURE_CMD := $(CONFIGURE_CMD)
NONDIST_BUILD_CMD = cargo build --release -j $(JOBS)
ICECC_CONFIGURE_CMD := false
ICECC_BUILD_CMD := false
CHECK_CMD = env RUSTC_WRAPPER=$(RUSTC_WRAPPER) cargo test --release -j $(JOBS)
SRC_CLEAN_CMD := cd workspace/src && cargo clean

# Pre-make the .cargo directory in order to avoid build errors.
# This directory will be created in `cargo build` for downloading dependent crates
# on the client container.  This causes an inconsistency between the client
# container and remote containers.
workspace:
	git clone --depth=1 $(REPO) workspace/src
	mkdir -p workspace/.cargo
