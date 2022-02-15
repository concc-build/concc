# Building with concc

The simplest way is running `make` as follows:

```shell
make -C <sub-dir> build
```

If you want to build with remote machines, run `make` with the `REMOTES`
parameter:

```shell
make -C <sub-dir> build REMOTES='remote'
```

where remote hosts specified in the `REMOTES` parameter must be accessible via
SSH.

See `README.md` in each sub-directory if you want to build without using our
Makefile files.

Cleanup:

```shell
# Cleanup the build result.
make  -C <sub-dir> clean

# Cleanup all including Docker images and source files.
#
# mikefarah/yq and build caches are NOT removed.  Those have to be removed
# manually if needed.
make -C <sub-dir> clean-all
```
