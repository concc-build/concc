# Building with Rust

## Make a buildenv image

```shell
docker buildx build -t rust-buildenv .
```

## Build with local worker containers

Clone some source tree into the `workspace/src` directory:

```shell
git clone --depth=1 https://github.com/BurntSushi/ripgrep.git workspace/src
```

Launch worker containers:

```shell
docker compose up -d worker
```

Launch a project container:

```shell
docker compose up -d project
```

Then, build it with the worker containers:

```shell
docker compose run --rm client concc -C src \
  -p "$(docker compose ps -q project | xargs docker inspect | jq -r '.[].Name[1:]')" \
  -w "$(docker compose ps -q worker | xargs docker inspect | jq -r '.[].Name[1:]' | tr '\n' ',')" \
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
docker -H ssh://$REMOTE run --name rust-worker --rm --init -d --device /dev/fuse \
  -p 2222:22/tcp --privileged rust-buildenv concc-worker
```

Launch a project container:

```shell
docker compose up -d project
```

Then, build with the remote worker container:

```shell
docker compose run --rm client \
  concc -C src -p $(hostname):2222 -w $REMOTE:2222 \
  'cargo build --release -j $(concc-worker-pool limit)'
```
