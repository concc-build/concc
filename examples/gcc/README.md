# Building with GCC

## Make a buildenv image

```shell
make base-images
docker buildx build -t concc-poc/gcc-buildenv .
```

## Prepare a project workspace

Clone some source tree into the `workspace/src` directory:

```shell
git clone --depth=1 https://github.com/facebook/zstd.git workspace/src
```

## Build with worker containers

Run `configure` if needed:

```shell
concc-boot -C workspace -i concc-poc/gcc-buildenv -s scripts -l \
  concc -C src './autogen.sh'
```

Then, build it with worker containers:

```shell
concc-boot -C workspace -i concc-poc/gcc-buildenv -s scripts \
  concc -C src \
  'make -j $(concc-worker-pool limit) CC="concc-exec gcc"'
```

Specify worker hosts when building with remote worker containers:

```shell
concc-boot -C workspace -i concc-poc/gcc-buildenv -s scripts -w remote \
  concc -C src \
  'make -j $(concc-worker-pool limit) CC="concc-exec gcc"'
```

where `remote` must be accessible via SSH.

Using `docker stats`, you can confirm that build jobs will be distributed to the
worker containers.

`gcc` will be executed on worker containers.  Unlike `icecc`, all preprocessor
directives including `#include` directives are processed on the worker
containers.
