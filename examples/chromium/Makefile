BUILDENV := chromium-buildenv
REMOTE_CONTAINER := chromium-worker
SSH_PORT := 2222
CHROMIUM := 94.0.4606.54
REPO := https://chromium.googlesource.com/chromium/src.git
SCALE := 2

WORKERS := $$(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')
JOBS := $$(concc-worker-pool limit)

TARGETS ?= chrome

.PHONY: all
all: build

# Worker containers will be kept running for debugging.
.PHONY: build
build: buildenv local-clean | src
	docker-compose up -d --scale worker=$(SCALE) worker
	sleep 1
	docker-compose run --rm client concc -C src -l 'gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\""'
	docker-compose run --rm client concc -C src -w $(WORKERS) 'autoninja -C out/Default -j $(JOBS) $(TARGETS)'

# Worker containers will be kept running for debugging.
.PHONY: remote-build
remote-build: buildenv remote-clean | src
	docker save $(BUILDENV) | docker -H ssh://$(REMOTE) load
	# FIXME(masnagam/concc#1): replace --privileged with appropriate options
	docker -H ssh://$(REMOTE) run --name $(REMOTE_CONTAINER) --rm --init -d --device /dev/fuse --privileged -p $(SSH_PORT):22/tcp $(BUILDENV) concc-worker
	sleep 1
	docker-compose run --rm client concc -C src -l 'gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\""'
	docker-compose run --rm -p $(SSH_PORT):22/tcp client concc -C src -c $(shell hostname):$(SSH_PORT) -w $(REMOTE):$(SSH_PORT) 'autoninja -C out/Default -j $(JOBS) $(TARGETS)'

# Worker containers will be kept running for debugging.
.PHONY: check
check: build
	docker-compose run --rm client concc -C src -w $(WORKERS) 'autoninja -C out/Default -j $(JOBS) blink_unittests'
	docker-compose run --rm client concc -C src -l 'out/Default/blink_unittests'

# You NEED to run `docker image prune` if you want to remove dangling images.
.PHONY: clean-all
clean-all: src-clean local-clean remote-clean
	rm -rf .cipd .gclient .gclient_entries _bad_scm src
	docker image rm -f $(BUILDENV)

.PHONY: clean
clean: src-clean local-clean

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
	tar --exclude src -ch . | docker build -t $(BUILDENV) --build-arg='CHROMIUM=$(CHROMIUM)' -

src:
	git clone --depth=1 --branch=$(CHROMIUM) $(REPO) src
	docker-compose run --rm client concc -l gclient config --unmanaged $(REPO)
	docker-compose run --rm client concc -l gclient sync --force

.PHONY: src-clean
src-clean:
	rm -rf src/out
