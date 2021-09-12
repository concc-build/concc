# Building with Rust

## Make a buildenv image

```shell
tar --exclude proj -ch . | docker build -t rust-buildenv -
```

## Build

Clone some source tree into the `proj` directory:

```shell
git clone --depth=1 https://github.com/BurntSushi/ripgrep.git proj
```

Launch worker containers:

```shell
docker compose up -d --scale worker=2 worker
```

Then, build it with the worker containers:

```shell
docker compose run --rm user sh /build.sh user:22 \
  $(docker compose ps --format json | jq -r '.[].Name' | sed 's/$/:22/' | tr '\n' ' ')
```

Using `docker stats`, you can confirm that build jobs will be distributed to the worker containers.

`rustc` will be executed on the worker container.  Other jobs like downloading crates will be
performed on the user container.

## Worker containers running on remote machines

Transfer the image from the local machine to the remote machine:

```shell
docker save rust-buildenv | docker -H ssh://$REMOTE load
```

Client and worker containers have to be created from the **same** image so that SSH connections establish.

Launch a worker container on a remote machine:

```shell
docker -H ssh://$REMOTE run --name rust-buildenv --rm --init -d --device /dev/fuse -p 22022:22/tcp \
  --privileged rust-buildenv sh /opt/concc/run-worker.sh
```

Then, build with the remote worker container:

```shell
docker compose run --rm -p 22022:22/tcp user sh /build.sh $(hostname):22022 $REMOTE:22022
```
