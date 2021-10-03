EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
SEP := ,

SCALE ?= 1
REMOTES ?=
SSH_PORT ?= 2222
JOBS ?= $$(concc-worker-pool limit)

CONCC_TOOLS := masnagam/concc-tools
PROJECT := $$(docker compose ps -q project | xargs docker inspect | jq -r '.[].Name[1:]')
WORKERS := $$(docker compose ps -q worker | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')
REMOTE_WORKERS := $(subst $(SPACE),$(SEP),$(addsuffix :$(SSH_PORT),$(REMOTES)))
TIME := /usr/bin/time -p

ICECC_SCHED ?= icecc
ICECC_JOBS ?= 32
ICECCD := iceccd -d -s $(ICECC_SCHED) && sleep 5

.PHONY: all
all: build

build: local-build

# Project and worker containers will be kept running for debugging.
.PHONY: local-build
local-build: buildenv secrets workspace
	make src-clean
	make local-clean
	docker compose up -d --scale worker=$(SCALE) worker project
	docker compose run --rm client concc -C src -l '$(CONFIGURE_CMD)'
	docker compose run --rm client concc -C src -p $(PROJECT) -w $(WORKERS) '$(TIME) $(BUILD_CMD)'

# Project and worker containers will be kept running for debugging.
.PHONY: remote-build
remote-build: buildenv secrets workspace
	make src-clean
	make remote-clean
	for REMOTE in $(REMOTES); do docker save $(BUILDENV) | docker -H ssh://$$REMOTE load; done
	# FIXME(masnagam/concc#1): replace --privileged with appropriate options
	for REMOTE in $(REMOTES); do docker -H ssh://$$REMOTE run --name $(REMOTE_CONTAINER) --rm --init -d --device /dev/fuse --privileged -p $(SSH_PORT):22/tcp $(BUILDENV) concc-worker; done
	docker compose up -d project
	docker compose run --rm client concc -C src -l '$(CONFIGURE_CMD)'
	docker compose run --rm client concc -C src -p $(shell hostname):$(SSH_PORT) -w $(REMOTE_WORKERS) '$(TIME) $(BUILD_CMD)'

.PHONY: nondist-build
nondist-build: buildenv secrets workspace
	make src-clean
	docker compose run --rm client concc -C src -l '$(NONDIST_CONFIGURE_CMD)'
	docker compose run --rm client concc -C src -l '$(TIME) $(NONDIST_BUILD_CMD)'

.PHONY: icecc-build
icecc-build: buildenv secrets workspace
	make src-clean
	docker compose run --rm client concc -C src -l '$(ICECC_CONFIGURE_CMD)'
	docker compose run --rm -e ICECC_REMOTE_CPP=1 client concc -C src -l '$(ICECCD) && $(TIME) $(ICECC_BUILD_CMD)'

# Project and worker containers will be kept running for debugging.
.PHONY: check
check: build
	docker compose run --rm client concc -C src -p $(PROJECT) -w $(WORKERS) '$(CHECK_CMD)'

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
	-$(SRC_CLEAN_CMD)

.PHONY: local-clean
local-clean:
	docker compose down -v

.PHONY: remote-clean
remote-clean:
	for REMOTE in $(REMOTES); do docker -H ssh://$$REMOTE stop $(REMOTE_CONTAINER) || true; done
	for REMOTE in $(REMOTES); do docker -H ssh://$$REMOTE image rm -f $(BUILDENV); done

.PHONY: buildenv
buildenv: concc-tools
	docker buildx build -t $(BUILDENV) .

.PHONY: concc-tools
concc-tools:
	make -C ../../docker

.PHONY: secrets
secrets: users.conf password

.PHONY: secrets-clean
secrets-clean:
	rm -rf users.conf password

users.conf: password
	echo "concc:$(shell cat $<):$(shell id -u):$(shell id -g):workspace" >$@

password:
	echo 'concc' >$@
