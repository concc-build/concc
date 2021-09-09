# Building Chromium

## Build a buildenv image

```shell
tar --exclude src -ch . | docker build -t chromium-buildenv -
```

## Get the Chromium source code

```shell
docker run --rm -it -v $(pwd):/chromium chromium-buildenv fetch --nohooks --no-history chromium
```

This may take several hours depending on your network environment.

Increase the VM memory more than 4GB before running the command above if you use Docker Desktop
for Mac.  Otherwise, you'll see messages like below:

```text
________ running 'git -c core.deltaBaseCacheLimit=2g clone --no-checkout --progress https://chromium.googlesource.com/chromium/src.git --depth=1 /chromium/_gclient_src_xll8glrp' in '/chromium'
Cloning into '/chromium/_gclient_src_xll8glrp'...
1>WARNING: subprocess '"git" "-c" "core.deltaBaseCacheLimit=2g" "clone" "--no-checkout" "--progress" "https://chromium.googlesource.com/chromium/src.git" "--depth=1" "/chromium/_gclient_src_xll8glrp"' in /chromium failed; will retry after a short nap...
```

Running with 6GB works fine.  We confirmed that `gclient` consumed memory more than 4GB while
fetching `//third_party/angle/third_party/VK-GL-CTS/src`.

## Build

Launch worker containers:

```shell
docker compose up -d --scale worker=2 worker
```

Then, build a target with worker containers:

```shell
docker compose run --rm user sh /build.sh 22 chrome \
  $(docker compose ps --format json | jq -r '.[].Name' | sed 's/$/:22/' | tr '\n' ' ')
```

Building chrome takes a long time depending on your environment.  We recommend to build nasm
instead of it if you like to save the build time for confirmation.
