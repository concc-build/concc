EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
SEP := ,

CONCC_TOOLS := masnagam/concc-tools
BUILDENV := rust-buildenv
REMOTE_CONTAINER := rust-worker
SSH_PORT := 2222
REPO := https://github.com/BurntSushi/ripgrep.git
SCALE := 2
REMOTES ?=

PROJECT := $$(docker compose ps -q project | xargs docker inspect | jq -r '.[].Name[1:]')
WORKERS := $$(docker compose ps -q worker | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')
REMOTE_WORKERS := $(subst $(SPACE),$(SEP),$(addsuffix :$(SSH_PORT),$(REMOTES)))
JOBS := $$(concc-worker-pool limit)

.PHONY: all
all: build

# Project and worker containers will be kept running for debugging.
.PHONY: build
build: buildenv local-clean | secrets workspace
	docker compose up -d --scale worker=$(SCALE) worker project
	docker compose run --rm client concc -C src -p $(PROJECT) -w $(WORKERS) 'cargo build --release -j $(JOBS)'

# Project and worker containers will be kept running for debugging.
.PHONY: remote-build
remote-build: buildenv remote-clean | secrets workspace
	for REMOTE in $(REMOTES); do docker save $(BUILDENV) | docker -H ssh://$$REMOTE load; done
	# FIXME(masnagam/concc#1): replace --privileged with appropriate options
	for REMOTE in $(REMOTES); do docker -H ssh://$$REMOTE run --name $(REMOTE_CONTAINER) --rm --init -d --device /dev/fuse --privileged -p $(SSH_PORT):22/tcp $(BUILDENV) concc-worker; done
	docker compose up -d project
	docker compose run --rm client concc -C src -p $(shell hostname):$(SSH_PORT) -w $(REMOTE_WORKERS) 'cargo build --release -j $(JOBS)'

# Project and worker containers will be kept running for debugging.
.PHONY: check
check: build
	docker compose run --rm client concc -C src -w $(WORKERS) 'cargo test --release -j $(JOBS)'

# You NEED to run `docker image prune` if you want to remove dangling images.
.PHONY: clean-all
clean-all: src-clean local-clean remote-clean
	make secrets-clean
	rm -rf workspace
	docker image rm -f $(BUILDENV)
	docker image rm -f $(CONCC_TOOLS)

.PHONY: clean
clean: src-clean local-clean

.PHONY: src-clean
src-clean:
	-cd workspace/src && cargo clean

.PHONY: local-clean
local-clean:
	docker compose down -v

.PHONY: remote-clean
remote-clean:
	@if [ -z "$(REMOTES)" ]; then echo 'ERROR: REMOTES not specified' >&2; false; fi
	for REMOTE in $(REMOTES); do docker -H ssh://$$REMOTE stop $(REMOTE_CONTAINER) || true; done
	for REMOTE in $(REMOTES); do docker -H ssh://$$REMOTE image rm -f $(BUILDENV); done

.PHONY: buildenv
buildenv: concc-tools
	tar --exclude secrets --exclude workspace -ch . | docker build -t $(BUILDENV) -

.PHONY: concc-tools
concc-tools:
	make -C ../../docker

workspace:
	git clone --depth=1 $(REPO) workspace/src

.PHONY: secrets
secrets: users.conf password

.PHONY: secrets-clean
secrets-clean:
	rm -rf users.conf password

users.conf: password
	echo "concc:$(shell cat $<):$(shell id -u):$(shell id -g):workspace" >$@

password:
	echo 'rust' >$@
