# Building with Rust

## Make a buildenv image

```shell
tar --exclude project -ch . | docker build -t rust-buildenv -
```

## Build

Clone some source tree into the `project` directory:

```shell
git clone --depth=1 https://github.com/BurntSushi/ripgrep.git project
```

Launch worker containers:

```shell
docker-compose up -d --scale worker=2 worker
```

Then, build it with the worker containers:

```shell
docker-compose run --rm \
  -e CARGO_HOME=/home/concc/.cargo \
  -e RUSTC_WRAPPER=/usr/local/bin/concc-wrapper \
  client concc \
  -w "$(docker-compose ps -q | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')" \
  'cargo build --release -j $(concc-worker-pool limit)'
```

Using `docker stats`, you can confirm that build jobs will be distributed to the worker containers.

`rustc` will be executed on the worker container.  Other jobs like downloading crates will be
performed on the user container.

## Build with remote worker containers

Transfer the image from the local machine to the remote machine:

```shell
docker save rust-buildenv | docker -H ssh://$REMOTE load
```

Client and worker containers have to be created from the **same** image so that SSH connections establish.

Launch a worker container on a remote machine:

```shell
docker -H ssh://$REMOTE run --name rust-buildenv --rm --init -d --device /dev/fuse \
  -p 2222:22/tcp --privileged rust-buildenv concc-worker
```

Then, build with the remote worker container:

```shell
docker-compose run --rm -p 2222:22/tcp \
  -e CARGO_HOME=/home/concc/.cargo \
  -e RUSTC_WRAPPER=/usr/local/bin/concc-wrapper \
  client concc -c $(hostname):2222 -w $REMOTE:2222 \
  'cargo build --release -j $(concc-worker-pool limit)'
```
