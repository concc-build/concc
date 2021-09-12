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
