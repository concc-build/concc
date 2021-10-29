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
STRACE_DIR := strace
STRACE_OPTIONS := -ff -ttt -T -v -xx -X raw -y
STRACE_OUTDIR := $(STRACE_DIR)/$(STRACE_TARGET).$(JOBS)
STRACE_JSONL_FILES := $(addsuffix .jsonl,$(wildcard $(STRACE_OUTDIR)/*.strace))
STRACE_ARCHIVE := strace.tar.xz

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
	@if [ $$(echo '$(REMOTES)' | wc -w) -gt 1 ]; \
	then \
	  echo 'ERROR: specify at most single remote server in REMOTES'; \
	  false; \
	fi
	@for N in $$(seq $(NPROC)); \
	do \
	  $(MAKE) strace STRACE_TARGET=local JOBS=$$N; \
	  $(MAKE) strace-jsonl -j $(NPROC) STRACE_TARGET=local JOBS=$$N; \
	  $(MAKE) strace STRACE_TARGET=nondist JOBS=$$N; \
	  $(MAKE) strace-jsonl -j $(NPROC) STRACE_TARGET=nondist JOBS=$$N; \
	  if [ -n '$(REMOTES)' ]; \
	  then \
	    $(MAKE) strace STRACE_TARGET=remote REMOTES=$(REMOTES) JOBS=$$N; \
	    $(MAKE) strace-jsonl -j $(NPROC) STRACE_TARGET=remote JOBS=$$N; \
	  fi \
	done
	@tar -I 'xz -9 -T0' -cvf $@ strace

$(STRACE_OUTDIR):
	@mkdir -p $(STRACE_DIR)
	@if [ '$(STRACE_TARGET)' != remote ]; \
	then \
	  mkdir -p /tmp/$@; \
	fi
	@if [ '$(STRACE_TARGET)' = remote ]; \
	then \
	  ssh $(REMOTES) mkdir -p /tmp/$@; \
	fi
	@$(MAKE) $(STRACE_TARGET)-build REMOTES=$(REMOTES) JOBS=$(JOBS) \
	  GCC='strace $(STRACE_OPTIONS) -o /$@/strace gcc' \
	  DOCKER_OPTIONS='-v /tmp/$(STRACE_DIR):/strace'
	@if [ '$(STRACE_TARGET)' != remote ]; \
	then \
	  cp -R /tmp/$@ $@; \
	  sudo rm -rf /tmp/$@; \
	fi
	@if [ '$(STRACE_TARGET)' = remote ]; \
	then \
	  scp -r $(REMOTES):/tmp/$@ $@; \
	  docker -H ssh://$(REMOTES) exec $(REMOTE_CONTAINER) rm -rf /$@; \
	fi
	@for strace in $$(/bin/ls -1 $@/strace.*); \
	do \
	  mv $$strace $@/$$(echo $$strace | sed 's/.*\.//').strace; \
	done

$(STRACE_ANALYSES_DIR):
	@mkdir -p $@

%.strace.jsonl: %.strace
	@echo "Converting $<..."
	@cat $< | python3 $(PROJ_DIR)/scripts/strace-json.py > $@
