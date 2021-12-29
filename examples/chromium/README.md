# Building Chromium

## Build a buildenv image

```shell
export CHROMIUM=96.0.4664.110
docker buildx build -t chromium-buildenv --build-arg='CHROMIUM=$CHROMIUM' .
```

## Create a SFTP account

```shell
echo "password" >password
echo "concc:$(cat password):$(id -u):$(id -g):workspace" >users.conf
```

## Get the Chromium source code

```shell
git clone --depth=1 --branch=$CHROMIUM \
  https://chromium.googlesource.com/chromium/src.git workspace/src
docker compose run --rm client concc -l \
  gclient config --unmanaged https://chromium.googlesource.com/chromium/src.git
docker compose run --rm client concc -l gclient sync --force
```

This may take several hours depending on your network environment.

Increase the VM memory more than 8GB before running the commands above if you
use Docker Desktop for Mac.

## Build

Launch worker containers:

```shell
docker compose up -d worker
```

Launch a project container:

```shell
docker compose up -d project
```

Generate Ninja files:

```shell
docker compose run --rm client concc -C src -l \
  'gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\"" is_debug=false'
```

Create `.netfs.cache.yml`:

```shell
cat <<EOF >workspace/.netfs.cache.yml
cache:
  dentry-cache:
    excludes:
      - src/out/*
  attr:
    timeout: 1d
    excludes:
      - src/out/*
  entry:
    timeout: 1d
    excludes:
      - src/out/*
  negative:
    timeout: 1d
    excludes:
      - src/out/*
EOF
```

Then, build a target with worker containers:

```shell
docker compose run --rm client concc -C src \
  -p "$(docker compose ps -q project | xargs docker inspect | jq -r '.[].Name[1:]')" \
  -w "$(docker compose ps -q worker | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')" \
  'autoninja -C out/Default -j $(concc-worker-pool limit) chrome'
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
docker -H ssh://$REMOTE run --name chromium-buildenv --rm --init -d \
  --device /dev/fuse --privileged -p 2222:22/tcp chromium-buildenv \
  concc-worker
```

Launch a project container:

```shell
docker compose up -d project
```

Generate Ninja files:

```shell
docker compose run --rm client concc -C src -l \
  'gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-dispatch\""'
```

Create `.netfs.cache.yml`, and then build with the remote worker container:

```shell
docker compose run --rm client \
  concc -C src -p $(hostname):2222 -w $REMOTE:2222 \
  'autoninja -C out/Default -j $(concc-worker-pool limit) chrome'
```
