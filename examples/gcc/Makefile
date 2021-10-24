include ../common.makefile

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

STRACE_TARGET ?=
STRACE_DIR := workspace/strace
STRACE_OPTIONS := -ff -ttt -T -v -xx -X raw -y
STRACE_OUTDIR := $(STRACE_DIR)/$(STRACE_TARGET).$(JOBS)
STRACE_JSONL_FILES := $(addsuffix .jsonl,$(wildcard $(STRACE_OUTDIR)/*.strace))
STRACE_ARCHIVE := workspace/strace.tar.xz

.PHONY: strace
strace: $(STRACE_OUTDIR)

.PHONY: strace-jsonl
strace-jsonl: $(addsuffix .jsonl,$(wildcard $(STRACE_OUTDIR)/*.strace))

.PHONY: strace-archive
strace-archive: $(STRACE_ARCHIVE)

.PHONY: strace-clean
strace-clean:
	@rm -rf $(STRACE_DIR) $(STRACE_ARCHIVE)

$(STRACE_ARCHIVE):
	@$(MAKE) strace STRACE_TARGET=concc JOBS=1
	@$(MAKE) strace STRACE_TARGET=concc JOBS=4
	@$(MAKE) strace STRACE_TARGET=nondist JOBS=1
	@$(MAKE) strace STRACE_TARGET=nondist JOBS=4
	@$(MAKE) strace-jsonl -j $(nproc) STRACE_TARGET=concc JOBS=1
	@$(MAKE) strace-jsonl -j $(nproc) STRACE_TARGET=concc JOBS=4
	@$(MAKE) strace-jsonl -j $(nproc) STRACE_TARGET=nondist JOBS=1
	@$(MAKE) strace-jsonl -j $(nproc) STRACE_TARGET=nondist JOBS=4
	@tar -C workspace -cJvf $@ strace

$(STRACE_OUTDIR):
	@mkdir -p $@
	@$(MAKE) $(STRACE_TARGET)-build JOBS=$(JOBS) \
	  GCC='strace $(STRACE_OPTIONS) -o /$@/strace gcc'
	@for strace in $$(/bin/ls -1 $@/strace.*); \
	do \
	  mv $$strace $@/$$(echo $$strace | sed 's/.*\.//').strace; \
	done

$(STRACE_ANALYSES_DIR):
	@mkdir -p $@

%.strace.jsonl: %.strace
	@echo "Converting $<..."
	@cat $< | python3 $(PROJ_DIR)/scripts/strace-json.py > $@
