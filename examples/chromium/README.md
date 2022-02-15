# Building Chromium

## Make a buildenv image

```shell
make base-images
export CHROMIUM=96.0.4664.110
docker buildx build -t chromium-buildenv --build-arg='CHROMIUM=$CHROMIUM' .
```

## Prepare a project workspace

Get the Chromium source code:

```shell
git clone --depth=1 --branch=$CHROMIUM \
  https://chromium.googlesource.com/chromium/src.git workspace/src
concc-boot -C workspace -i chromium-buildenv -s scripts -l \
  concc gclient config --unmanaged https://chromium.googlesource.com/chromium/src.git
concc-boot -C workspace -i chromium-buildenv -s scripts -l \
  concc gclient sync --force
```

This may take several hours depending on your network environment.

Increase the VM memory more than 8GB before running the commands above if you
use Docker Desktop for Mac.

Create `workspacefs.override.yaml`:

```shell
cat <<EOF >workspace/workspacefs.override.yaml
cache:
  negative:
    excludes:
      - src/out/*
EOF
```

## Build with worker containers

Generate Ninja files:

```shell
concc-boot -C workspace -i chromium-buildenv -s scripts -l \
  concc -C src \
  'gn gen out/Default --args="clang_base_path=\"/opt/clang\" cc_wrapper=\"concc-exec\"" is_debug=false'
```

Then, build a target with worker containers:

```shell
concc-boot -C workspace -i chromium-buildenv -s scripts \
  concc -C src \
  'autoninja -C out/Default -j $(concc-worker-pool limit) chrome'
```

Specify worker hosts when building with remote worker containers:

```shell
concc-boot -C workspace -i gcc-buildenv -s scripts -w remote \
  concc -C src \
  'autoninja -C out/Default -j $(concc-worker-pool limit) chrome'
```

where `remote` must be accessible via SSH.

Building chrome takes a long time depending on your environment.  We recommend
to build nasm instead of it if you like to save the build time for confirmation.
