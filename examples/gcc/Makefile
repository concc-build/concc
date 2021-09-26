BUILDENV := gcc-buildenv
REMOTE_CONTAINER := gcc-worker
SSH_PORT := 2222
REPO := https://github.com/jemalloc/jemalloc.git
SCALE := 2

PROJECT := $$(docker-compose ps -q project | xargs docker inspect | jq -r '.[].Name[1:]')
WORKERS := $$(docker-compose ps -q worker | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')
JOBS := $$(concc-worker-pool limit)

# In this example, only CC commands will be distributed, any command can be
# distributed theoretically.
CC := "concc-dispatch gcc"

.PHONY: all
all: build

# Project and worker containers will be kept running for debugging.
.PHONY: build
build: buildenv local-clean | secrets.txt workspace
	docker-compose up -d --scale worker=$(SCALE) worker project
	docker-compose run --rm client concc -C src ./autogen.sh
	docker-compose run --rm client concc -C src -p $(PROJECT) -w $(WORKERS) 'make -j $(JOBS) CC=$(CC)'

# Project and worker containers will be kept running for debugging.
.PHONY: remote-build
remote-build: buildenv remote-clean | secrets.txt workspace
	docker save $(BUILDENV) | docker -H ssh://$(REMOTE) load
	# FIXME(masnagam/concc#1): replace --privileged with appropriate options
	docker -H ssh://$(REMOTE) run --name $(REMOTE_CONTAINER) --rm --init -d --device /dev/fuse --privileged -p $(SSH_PORT):22/tcp $(BUILDENV) concc-worker
	docker-compose up -d project
	docker-compose run --rm client concc -C src ./autogen.sh
	docker-compose run --rm client concc -C src -p $(shell hostname):$(SSH_PORT) -w $(REMOTE):$(SSH_PORT) 'make -j $(JOBS) CC=$(CC)'

# Project and worker containers will be kept running for debugging.
.PHONY: check
check: build
	docker-compose run --rm client concc -C src -p $(PROJECT) -w $(WORKERS) 'make -j $(JOBS) CC=$(CC) check'

# You NEED to run `docker image prune` if you want to remove dangling images.
.PHONY: clean-all
clean-all: src-clean local-clean remote-clean
	rm -rf secrets.txt workspace
	docker image rm -f $(BUILDENV)

.PHONY: clean
clean: src-clean local-clean

.PHONY: src-clean
src-clean:
	-make -C workspace/src clean

.PHONY: local-clean
local-clean:
	docker-compose down -v

.PHONY: remote-clean
remote-clean:
	@if [ -z "$(REMOTE)" ]; then echo 'ERROR: REMOTE not specified' >&2; false; fi
	-docker -H ssh://$(REMOTE) stop $(REMOTE_CONTAINER)
	docker -H ssh://$(REMOTE) image rm -f $(BUILDENV)

.PHONY: buildenv
buildenv:
	tar --exclude secrets.txt --exclude workspace -ch . | docker build -t $(BUILDENV) -

workspace:
	git clone --depth=1 $(REPO) workspace/src

secrets.txt:
	echo "concc:gcc:$(shell id -u):$(shell id -g):workspace" >secrets.txt
