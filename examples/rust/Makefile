BUILDENV := rust-buildenv
REMOTE_CONTAINER := rust-worker
SSH_PORT := 2222
REPO := https://github.com/BurntSushi/ripgrep.git
SCALE := 2

WORKERS := $$(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')
JOBS := $$(concc-worker-pool limit)

# In this example, only CC commands will be distributed, but we can distribute any command
# theoretically.
CC := "concc-dispatch gcc"

.PHONY: all
all: build

.PHONY: build
build: buildenv | src
	docker-compose up -d --scale worker=$(SCALE) worker
	sleep 1
	docker-compose run --rm client concc -w $(WORKERS) 'cd src; cargo build --release -j $(JOBS)'
	docker-compose down -v

.PHONY: remote-build
remote-build: buildenv | src
	@if [ -z "$(REMOTE)" ]; then echo 'ERROR: REMOTE not specified' >&2; false; fi
	docker -H ssh://$(REMOTE) stop $(REMOTE_CONTAINER) || true
	docker -H ssh://$(REMOTE) image rm $(BUILDENV) || true
	docker save $(BUILDENV) | docker -H ssh://$(REMOTE) load
	# FIXME(masnagam/concc#1): replace --privileged with appropriate options
	docker -H ssh://$(REMOTE) run --name $(REMOTE_CONTAINER) --rm --init -d --device /dev/fuse --privileged -p $(SSH_PORT):22/tcp $(BUILDENV) concc-worker
	sleep 1
	docker-compose run --rm -p $(SSH_PORT):22/tcp client concc -c $(shell hostname):$(SSH_PORT) -w $(REMOTE):$(SSH_PORT) 'cd src; cargo build --release -j $(JOBS)'
	docker -H ssh://$(REMOTE) stop $(REMOTE_CONTAINER)

.PHONY: check
check: build
	docker-compose up -d --scale worker=$(SCALE) worker
	sleep 1
	docker-compose run --rm client concc -w $(WORKERS) 'cd src; cargo test --release -j $(JOBS)'
	docker-compose down -v

.PHONY: clean-all
clean-all: remote-clean clean
	rm -rf .cargo src

.PHONY: clean
clean: src-clean
	docker-compose down -v || true
	docker image rm $(BUILDENV) || true

.PHONY: remote-clean
remote-clean: src-clean
	@if [ -z "$(REMOTE)" ]; then echo 'ERROR: REMOTE not specified' >&2; false; fi
	docker -H ssh://$(REMOTE) stop $(REMOTE_CONTAINER) || true
	docker -H ssh://$(REMOTE) image rm $(BUILDENV) || true

.PHONY: buildenv
buildenv:
	tar --exclude src -ch . | docker build -t $(BUILDENV) -

src:
	git clone --depth=1 $(REPO) src

.PHONY: src-clean
src-clean:
	(cd src; cargo clean)
