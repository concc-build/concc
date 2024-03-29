include ../common.makefile

TARGETS ?= chrome

CHROMIUM := 96.0.4664.110
# Disable NaCl.
# concc builds successfully even when NaCl is enabled.
# However, icecc fails building when enabling NaCl.
COMMON_GN_ARGS := is_debug=false clang_base_path=\"/opt/clang\" enable_nacl=false
GN_ARGS := "$(COMMON_GN_ARGS) cc_wrapper=\"concc-exec\""
NONDIST_GN_ARGS := "$(COMMON_GN_ARGS)"
ICECC_GN_ARGS := "$(COMMON_GN_ARGS) cc_wrapper=\"icecc\" use_debug_fission=false"
ICECC_VERSION := /opt/clang.chromium.$(CHROMIUM).tar.gz
ICECC_ENV := ICECC_REMOTE_CPP=1 ICECC_VERSION=$(ICECC_VERSION)

BUILDENV := concc-poc/chromium-buildenv
BUILDENV_BUILD_OPTIONS := --build-arg CHROMIUM=$(CHROMIUM)
REPO := https://chromium.googlesource.com/chromium/src.git
CONFIGURE_CMD := gn gen out/Default --args=$(GN_ARGS)
BUILD_CMD = autoninja -C out/Default -j $(JOBS) $(TARGETS)
NONDIST_CONFIGURE_CMD := gn gen out/Default --args=$(NONDIST_GN_ARGS)
NONDIST_BUILD_CMD = $(BUILD_CMD)
ICECC_CONFIGURE_CMD := gn gen out/Default --args=$(ICECC_GN_ARGS)
ICECC_BUILD_CMD = env $(ICECC_ENV) $(BUILD_CMD)
CHECK_CMD = autoninja -C out/Default -j $(JOBS) blink_unittests && out/Default/blink_unittests
SRC_CLEAN_CMD := rm -rf workspace/src/out

workspace: | buildenv
	git clone --depth=1 --branch=$(CHROMIUM) $(REPO) workspace/src
	concc-boot -C workspace -i $(BUILDENV) -s scripts -l concc gclient config --unmanaged $(REPO)
	concc-boot -C workspace -i $(BUILDENV) -s scripts -l concc gclient sync --force

workspace/workspacefs.override.yaml: workspacefs.override.yaml workspace
	-@cp -f $< $@
