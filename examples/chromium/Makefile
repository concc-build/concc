BUILDENV := chromium-buildenv
REMOTE_CONTAINER := chromium-worker
SSH_PORT := 2222
CHROMIUM := 94.0.4606.54
REPO := https://chromium.googlesource.com/chromium/src.git
SCALE := 2

WORKERS := $$(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')
JOBS := $$(concc-worker-pool limit)

.PHONY: all
all: build

.PHONY: build
build: buildenv | src
	docker-compose up -d --scale worker=$(SCALE) worker
	sleep 1
	docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc 'cd src && gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\""'
	docker-compose run --rm client concc -w $(WORKERS) 'autoninja chrome -C src/out/Default -j $(JOBS)'
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
	docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc 'cd src && gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\""'
	docker-compose run --rm -p $(SSH_PORT):22/tcp client concc -c $(shell hostname):$(SSH_PORT) -w $(REMOTE):$(SSH_PORT) 'autoninja chrome -C src/out/Default -j $(JOBS)'
	docker -H ssh://$(REMOTE) stop $(REMOTE_CONTAINER)

.PHONY: check
check: build
	docker-compose up -d --scale worker=$(SCALE) worker
	sleep 1
	docker-compose run --rm client concc -w $(WORKERS) 'autoninja blink_unittests -C src/out/Default -j $(JOBS)'
	docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc 'src/out/Default/blink_unittests'
	docker-compose down -v

.PHONY: clean-all
clean-all: remote-clean clean
	rm -rf src

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
	tar --exclude src -ch . | docker build -t $(BUILDENV) --build-arg='CHROMIUM=$(CHROMIUM)' -

src:
	git clone --depth=1 --branch=$(CHROMIUM) $(REPO) src
	docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc gclient config --unmanaged $(REPO)
	docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc gclient sync --force

.PHONY: src-clean
src-clean:
	docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc 'ninja -C src/out/Default -t clean'
