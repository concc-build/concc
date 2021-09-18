# Building with GCC

## Make a buildenv image

```shell
tar --exclude project -ch . | docker build -t gcc-buildenv -
```

## Build

Clone some source tree into the `project` directory:

```shell
git clone --depth=1 https://github.com/facebook/zstd.git project
```

Launch worker containers:

```shell
docker-compose up -d --scale worker=2 worker
```

Then, build it with worker containers:

```shell
docker-compose run --rm client concc \
  -w "$(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')" \
  'make -j $(concc-worker-pool limit) CC="concc-wrapper gcc"'
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
docker -H ssh://$REMOTE run --name gcc-buildenv --rm --init -d --device /dev/fuse \
  -p 2222:22/tcp --privileged gcc-buildenv concc-worker
```

Then, build with the remote worker container:

```shell
docker-compose run --rm -p 2222:22/tcp client concc -c $(hostname):2222 -w $REMOTE:2222 \
  'make -j $(concc-worker-pool limit) CC="concc-worker gcc"'
```
