# Building Chromium

## Build a buildenv image

```shell
tar --exclude src -ch . | docker build -t chromium-buildenv -
```

## Get the Chromium source code

```shell
docker run --rm -it -v $(pwd)/proj:/proj chromium-buildenv fetch --nohooks --no-history chromium
```

This may take several hours depending on your network environment.

Increase the VM memory more than 4GB before running the command above if you use Docker Desktop
for Mac.  Otherwise, you'll see messages like below:

```text
________ running 'git -c core.deltaBaseCacheLimit=2g clone --no-checkout --progress https://chromium.googlesource.com/chromium/src.git --depth=1 /proj/_gclient_src_xll8glrp' in '/proj'
Cloning into '/proj/_gclient_src_xll8glrp'...
1>WARNING: subprocess '"git" "-c" "core.deltaBaseCacheLimit=2g" "clone" "--no-checkout" "--progress" "https://chromium.googlesource.com/chromium/src.git" "--depth=1" "/proj/_gclient_src_xll8glrp"' in /proj failed; will retry after a short nap...
```

Running with 6GB works fine.  We confirmed that `gclient` consumed memory more than 4GB while
fetching `//third_party/angle/third_party/VK-GL-CTS/src`.

## Build

Launch worker containers:

```shell
docker-compose up -d --scale worker=2 worker
```

Then, build a target with worker containers:

```shell
docker-compose run --rm user sh /build.sh user:22 chrome \
  $(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | \
    sed 's/$/:22/' | tr '\n' ' ')
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
  -p 22022:22/tcp --privileged chromium-buildenv sh /opt/concc/run-worker.sh
```

Then, build with the remote worker container:

```shell
docker-compose run --rm -p 22022:22/tcp user sh /build.sh $(hostname):22022 chrome $REMOTE:22022
```
