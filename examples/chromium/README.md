# Building Chromium

## Build a buildenv image

```shell
tar --exclude src -ch . | \
  docker build -t chromium-buildenv --build-arg='CHROMIUM=94.0.4606.54' -
```

## Get the Chromium source code

```shell
git clone --depth=1 --branch=94.0.4606.54 \
  https://chromium.googlesource.com/chromium/src.git src
docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc \
  gclient config --unmanaged https://chromium.googlesource.com/chromium/src.git
docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc \
  gclient sync --force
```

This may take several hours depending on your network environment.

Increase the VM memory more than 8GB before running the commands above if you
use Docker Desktop for Mac.

## Build

Launch worker containers:

```shell
docker-compose up -d --scale worker=2 worker
```

Generate Ninja files:

```shell
docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc \
  'cd src && gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\""'
```

Then, build a target with worker containers:

```shell
docker-compose run --rm client concc \
  -w "$(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')" \
  'autoninja -C src/out/Default -j $(concc-worker-pool limit) chrome'
```

Building chrome takes a long time depending on your environment.  We recommend to build nasm
instead of it if you like to save the build time for confirmation.

## Build with remote worker containers

Transfer the image from the local machine to the remote machine:

```shell
docker save chromium-buildenv | docker -H ssh://$REMOTE load
```

Client and worker containers have to be created from the **same** image so that SSH connections establish.

Launch a worker container on a remote machine:

```shell
docker -H ssh://$REMOTE run --name chromium-buildenv --rm --init -d --device /dev/fuse \
  -p 2222:22/tcp --privileged chromium-buildenv concc-worker
```

Generate Ninja files:

```shell
docker-compose run --rm -e CONCC_RUN_LOCALLY=1 client concc \
  'cd src && gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\""'
```

Then, build with the remote worker container:

```shell
docker-compose run --rm -p 2222:22/tcp client concc -c $(hostname):2222 -w $REMOTE:2222 \
  'autoninja -C src/out/Default -j $(concc-worker-pool limit) chrome'
```
