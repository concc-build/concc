PROJ_DIR := $(shell git rev-parse --show-toplevel)
NPROC := $(shell nproc)

SCALE ?= 1
REMOTES ?=
DEBUG_WORKSPACEFS ?= 0
ITERATIONS ?= 10
DOCKER_OPTIONS ?=
TEST_OPTIONS ?=

TOOLS_IMAGE := masnagam/concc-tools
TOOLS_BUILD_OPTIONS ?=
TIME := /usr/bin/time
TIME_TOTAL := $(TIME) -p
TIME_CLIENT ?=
TIME_WORKER ?=
TIME_NONDIST ?=
TIME_ICECC ?=
METRICS_DIR := workspace/metrics
METRICS_JSON_PY := ../../scripts/metrics-json.py
METRICS_HTML_PY := ../../scripts/metrics-html.py

.PHONY: all
all: build

.PHONY: build
build: JOBS ?= $$(concc-worker-pool limit)
build: buildenv workspace workspace/workspacefs.override.yaml
	sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
	concc-boot -C workspace -i $(BUILDENV) -s scripts -l concc -C src '$(CONFIGURE_CMD)'
	concc-boot -C workspace -i $(BUILDENV) -s scripts -w '$(REMOTES)' $(TEST_OPTIONS) concc -C src '$(TIME_TOTAL) $(BUILD_CMD)'

.PHONY: nondist-build
nondist-build: JOBS ?= $(NPROC)
nondist-build: buildenv workspace
	sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
	concc-boot -C workspace -i $(BUILDENV) -s scripts -l concc -C src '$(NONDIST_CONFIGURE_CMD)'
	concc-boot -C workspace -i $(BUILDENV) -s scripts -l $(TEST_OPTIONS) concc -C src '$(TIME_TOTAL) $(NONDIST_BUILD_CMD)'

.PHONY: icecc-build
icecc-build: JOBS ?= 32
icecc-build: buildenv workspace
	sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
	concc-boot -C workspace -i $(BUILDENV) -s scripts -l concc -C src '$(ICECC_CONFIGURE_CMD)'
	concc-boot -C workspace -i $(BUILDENV) -s scripts --icecc -w '$(REMOTES)' $(TEST_OPTIONS) concc -C src -l '$(TIME_TOTAL) $(ICECC_BUILD_CMD)'

.PHONY: check
check: build
	concc-boot -C workspace -i $(BUILDENV) -s scripts concc -C src '$(CHECK_CMD)'

METRICS_HTML_HBS := ../metrics.html.hbs
CONCC_METRICS_FILES := $(addprefix $(METRICS_DIR)/,client.json worker.json)
NONDIST_METRICS_FILES := $(addprefix $(METRICS_DIR)/,nondist.json)
METRICS_FILES := $(CONCC_METRICS_FILES) $(NONDIST_METRICS_FILES)

.PHONY: metrics
metrics: $(METRICS_DIR)/index.html

.PHONY: concc-metrics
concc-metrics: $(CONCC_METRICS_FILES)

.PHONY: nondist-metrics
nondist-metrics: $(NONDIST_METRICS_FILES)

$(METRICS_DIR)/index.html: $(METRICS_HTML_PY) $(METRICS_FILES)
	cat $(METRICS_FILES) | python3 $(METRICS_HTML_PY) >$@

$(METRICS_DIR)/client.times $(METRICS_DIR)/worker.times: | $(METRICS_DIR)
	@for i in $(shell seq $(ITERATIONS)); \
	do \
	  $(MAKE) -e clean; \
	  $(MAKE) -e build \
	    TIME_CLIENT='$(TIME) -v -a -o /$(METRICS_DIR)/client.times' \
	    TIME_WORKER='$(TIME) -v -a -o /$(METRICS_DIR)/worker.times'; \
	done

$(METRICS_DIR)/nondist.times: | $(METRICS_DIR)
	@for i in $(shell seq $(ITERATIONS)); \
	do \
	  $(MAKE) -e clean; \
	  $(MAKE) -e nondist-build \
	    TIME_NONDIST='$(TIME) -v -a -o /$(METRICS_DIR)/nondist.times'; \
	done

$(METRICS_DIR)/%.json: $(METRICS_DIR)/%.times $(METRICS_JSON_PY)
	cat $< | python3 $(METRICS_JSON_PY) $(basename $(notdir $<)) >$@

# You NEED to run `docker image prune` if you want to remove dangling images.
.PHONY: clean-all
clean-all: clean
	rm -rf workspace
	docker image rm -f $(BUILDENV)
	$(MAKE) -C ../../docker clean

.PHONY: clean
clean: src-clean
	concc-boot -C workspace -i $(BUILDENV) -w '$(REMOTES)' --clean

.PHONY: src-clean
src-clean:
	-$(SRC_CLEAN_CMD)

.PHONY: metrics-clean
metrics-clean:
	rm -rf workspace/metrics

.PHONY: buildenv
buildenv: images
	docker buildx build -t $(BUILDENV) $(BUILDENV_BUILD_OPTIONS) .

.PHONY: images
images:
	$(MAKE) -C ../../docker

workspace/metrics: | workspace
	mkdir workspace/metrics
