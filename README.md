# concc

> A PoC implementation of a distributed build system using Docker containers

## About this project

This is an experimental project for studying the feasibility of a distributed
build system using Docker containers.  A simple distributed build system is
built for a proof of the concept.

In this project, we also study necessary components which compose a distributed
build system.

## Quick start with examples

The [examples](./examples) folder contains simple distributed build systems.
Each system is dedicated to a particular project.  For example, the
[examples/rust](./examples/rust) contains a simple distributed build system for
projects using Rust.

For simplicity, Docker containers used in example distributed build systems are
executed on your local machine.  However, it can be possible to execute worker
containers on remote machines with small changes to reproduction steps described
in README.md contained in each folder.

## Motivation

Distributed build systems make it possible to increase software productivity by
saving time needed for building artifacts from a large source tree.  One of
important metrics of these systems is the scalability of compilation throughput
for the size of cluster of build machines.  The compilation throughput of an
ideal system follows Amdahl's law.  And it's theoretically limited by the
percentage of non-parallelizable parts in the whole.

[Icecream] (formerly icecc) is a widely used distributed build system for C/C++
projects. Icecream processes `#include` directives on the client machine and
distribute remaining preprocessing to remote machines in order to improve the
compilation throughput.  However, processing `#include` directives on the client
machine cause high CPU usage when the client performs a lot of build jobs in
parallel.  As a result, the compilation throughput peaks out before reaching the
theoretical limit if the client machine does not equip a powerful CPU.

The issue regardin `#include` directives has been solved in [distcc] which is
another famous distributed build system.  distcc with the pump mode sends
included header files to remote build servers so that preprocessing can be
distributed.  However, distcc is highly optimized for C, C++ and Objective-C
projects.  And it does not support other programming languages.

A [Docker] container seems be to be used initially for encapsulation of a single
service like a web server.  After a short time, someone started to use it as a
build environment.  This method saves time to prepare a build environment
on each local machine, avoids problems caused by incorrect preparations, and
makes it possible to deliver the build environment as a Docker image.

Normally, a Docker image for a build environment includes all stuffs needed for
building artifacts other than the source tree for them.  This means that we can
simply distribute C/C++ preprocessing on remote machines if we can mount the
source tree onto the remote machines.  And there are a lot of such software at
this point.  [SSHFS] is one of them.

As described so far, we are possibly able to build a distributed build system
using Docker containers with smaller effort than before.

## Basic idea

As described in the previous section, the basic idea is very simple:

1. Create a Docker image containing all stuffs needed to build artifacts
2. Create containers and mount the source tree of the target artifacts
3. Distribute build jobs to the containers

The component diagram is shown below:

```text
                              Docker Registry
+--------------+
| Docker Image |
+--------------+
   |
---+-------------------------------------------------------------------
   |                          Local Machine
   |       +------------------+             +-------------+
   +------>| Client Container |<------------| Source Tree |
   |       +------------------+    Mount    +-------------+
   |          |                                 |
   |          |                                 | Mount
   |          |                                 V
   |          |                          +-------------------+
   |          |                          | Project Container |
   |          |                          +-------------------+
   |          |                                 |
---+----------+---------------------------------+----------------------
   |          |               Remote Machine    |
   |          |                                 |
   |          | Run build commands via SSH      |
   |          V                                 |
   |       +------------------+                 |
   +------>| Worker Container |<----------------+
           +------------------+    Mount the source tree
                                   via Project Container
                                   with R/W permission
```

Each client container contains the following commands:

* [concc](./docker/bin/concc)
  * The entry point of a client container
* [concc-worker](./docker/bin/concc-worker)
  * The entry point of a worker container
* [concc-dispatch](./docker/bin/concc-dispatch)
  * Distributes executions onto worker containers
* [concc-scriptify](./docker/bin/concc-scriptify)
  * Makes a script from a command, which will be executed on a worker container
* [concc-worker-pool](./docker/bin/concc-worker-pool)
  * Manages available worker containers
  * Assigns a worker container in the pool for a build job

## Performance comparison

The following table is a performance comparison using
[examples/chromium](./examples/chromium).

| BUILD SYSTEM   | #JOBS | TIME (REAL) | TIME (USER) | TIME (SYS) |
|----------------|-------|-------------|-------------|------------|
| concc          | 32    | 57m48.990s  | 0m8.009s    | 0m20.441s  |
| concc          | 64    | 40m35.554s  | 0m11.120s   | 0m30.298s  |
| Icecream/1.3.1 | 32    | 63m31.931s  | 0m6.183s    | 0m15.850s  |
| Icecream/1.3.1 | 64    | 65m4.077s   | 0m6.610s    | 0m15.124s  |

Build environment:

* Local Machine
  * VirtualBox 6.1 (4x vCPU, 16 GB RAM) on MacBook Pro (macOS 12.1)
    * Host IO cache is enabled
  * OS: Arch Linux (linux-lts)
  * CPU: 2.3 GHz Quad-Core Intel Core i7
  * RAM: 32 GB 3733 HMz LPDDR4X
  * SSD: 1 TB
* 2x Remote Machines
  * OS: Debian 11
  * CPU: Ryzen 9 3950X
  * RAM: 32 GB DDR4
  * SSD: 512 GB
  * RTT: min/avg/max/mdev = 0.720/1.395/2.274/0.497 ms

Commands used for measurements:

```shell
# concc
time make remote-build REMOTES='build1'         # 32 jobs
time make remote-build REMOTES='build1 build2'  # 64 jobs

# icecc
time make icecc-build JOBS=32
time make icecc-build JOBS=64
```

Icecream often consumed 90% or more of the CPU usage on the local machine.  On
the other hand, concc consumed less then Icecream even when running 64 jobs.
Probably, concc can perform more build jobs in parallel.

Icecream may be faster than concc if it runs on a powerful machine.  As
described in the previous section, one of causes of the slowdown is
preprocessing `#include` directives with high degree of parallelism on the local
machine.  Generally, it requires many computation resources.

concc stably consumed CPU resources on remote machines.  The peak value of the
CPU usage Icecream consumed was higher than concc, but its CPU usage is more
fluctuational than concc.

concc sometimes stopped due to IO errors which were probably caused by some bugs
in the build system.

## System Requirements

* Linux with a FUSE module
* Docker

## Dependencies

* fusermount or fusermount3
  * Neither libfuse2 or libfuse3 is required
* OpenSSH
* [masnagam/sshfs-rs]

## TODO

* A mechanism to launch worker containers on demand from a client container
* Security model
* Robustness
* Monitoring tools

## License

[MIT]

[Icecream]: https://github.com/icecc/icecream
[distcc]: https://distcc.github.io/
[Docker]: https://en.wikipedia.org/wiki/Docker_(software)
[SSHFS]: https://github.com/libfuse/sshfs
[masnagam/sshfs-rs]: https://github.com/masnagam/sshfs-rs
[MIT]: ./LICENSE
