include ../common.makefile

TARGETS ?= chrome

CHROMIUM := 94.0.4606.54
GN_ARGS := "clang_base_path=\"/opt/clang\" compiler_timing=true cc_wrapper=\"concc-dispatch\""
NONDIST_GN_ARGS := "clang_base_path=\"/opt/clang\" compiler_timing=true"
ICECC_GN_ARGS := "clang_base_path=\"/opt/clang\" cc_wrapper=\"icecc\""

BUILDENV := chromium-buildenv
REMOTE_CONTAINER := chromium-worker
REPO := https://chromium.googlesource.com/chromium/src.git
CONFIGURE_CMD := gn gen out/Default --args=$(GN_ARGS)
BUILD_CMD = autoninja -C out/Default -j $(JOBS) $(TARGETS)
NONDIST_CONFIGURE_CMD := gn gen out/Default --args=$(NONDIST_GN_ARGS)
NONDIST_BUILD_CMD = $(BUILD_CMD)
ICECC_CONFIGURE_CMD := gn gen out/Default --args=$(ICECC_GN_ARGS)
ICECC_BUILD_CMD = $(BUILD_CMD)
CHECK_CMD = autoninja -C out/Default -j $(JOBS) blink_unittests && out/Default/blink_unittests
SRC_CLEAN_CMD := rm -rf workspace/src/out

workspace: | buildenv secrets
	git clone --depth=1 --branch=$(CHROMIUM) $(REPO) workspace/src
	docker compose run --rm client concc -l gclient config --unmanaged $(REPO)
	docker compose run --rm client concc -l gclient sync --force
