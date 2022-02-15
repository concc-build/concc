# Building with Rust

## Make a buildenv image

```shell
make base-images
docker buildx build -t rust-buildenv .
```

## Prepare a project workspace

Clone some source tree into the `workspace/src` directory:

```shell
git clone --depth=1 https://github.com/BurntSushi/ripgrep.git workspace/src
```

Create `workspacefs.override.yaml`:

```shell
cat <<EOF >workspace/workspacefs.override.yaml
cache:
  negative:
    excludes:
      - .cargo
EOF
```

## Build with worker containers

Build it with worker containers:

```shell
concc-boot -C workspace -i gcc-buildenv -s scripts \
  concc -C src \
  'env RUSTC_WRAPPER=concc-exec cargo build --release -j $(concc-worker-pool limit)'
```

Specify worker hosts when building with remote worker containers:

```shell
concc-boot -C workspace -i gcc-buildenv -s scripts -w remote \
  concc -C src \
  'env RUSTC_WRAPPER=concc-exec cargo build --release -j $(concc-worker-pool limit)'
```

where `remote` must be accessible via SSH.

Using `docker stats`, you can confirm that build jobs will be distributed to the
worker containers.

`rustc` will be executed on worker containers.  Other jobs like downloading
crates will be performed on the user container.
