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
docker compose up -d --scale worker=2 worker
```

Then, build it with worker containers:

```shell
docker compose run --rm user sh /build.sh 22 \
  $(docker compose ps --format json | jq -r '.[].Name' | sed 's/$/:22/' | tr '\n' ' ')
```

Using `docker stats`, you can confirm that build jobs will be distributed to the worker containers.

`gcc` will be executed on the worker container.  Unlike `icecc`, all preprocessor directives
including `#include` directives are processed on the worker container.
