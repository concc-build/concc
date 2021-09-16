# Building with GCC

## Make a buildenv image

```shell
tar --exclude proj -ch . | docker build -t gcc-buildenv -
```

## Build

Clone some source tree into the `proj` directory:

```shell
git clone --depth=1 https://github.com/facebook/zstd.git proj
```

Launch worker containers:

```shell
docker-compose up -d --scale worker=2 worker
```

Then, build it with worker containers:

```shell
docker-compose run --rm user sh /build.sh user:22 \
  $(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | \
    sed 's/$/:22/' | tr '\n' ' ')
```

Using `docker stats`, you can confirm that build jobs will be distributed to the worker containers.

`gcc` will be executed on the worker container.  Unlike `icecc`, all preprocessor directives
including `#include` directives are processed on the worker container.

## Build with remote Worker containers

Transfer the image from the local machine to the remote machine:

```shell
docker save gcc-buildenv | docker -H ssh://$REMOTE load
```

Client and worker containers have to be created from the **same** image so that SSH connections establish.

Launch a worker container on a remote machine:

```shell
docker -H ssh://$REMOTE run --name gcc-buildenv --rm --init -d --device /dev/fuse -p 22022:22/tcp \
  --privileged gcc-buildenv sh /opt/concc/run-worker.sh
```

Then, build with the remote worker container:

```shell
docker-compose run --rm -p 22022:22/tcp user sh /build.sh $(hostname):22022 $REMOTE:22022
```
