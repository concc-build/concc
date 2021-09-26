# concc

> A PoC implementation of a distributed build system using Docker containers

## About this project

This is an experimental project to study the feasibility of a distributed build system using
Docker containers.  A simple distributed build system is built for the proof of concept.

In this project, we also study necessary components which compose a distributed build system.

## Quick start with examples

The [examples](./examples) folder contains simple distributed build systems.  Each system is dedicated to
a particular project.  For example, the [examples/rust](./examples/rust) contains a simple
distributed build system for projects using Rust.

For simplicity, Docker containers used in example distributed build systems are executed on your
local machine.  However, it can be possible to execute worker containers on remote machines with
small changes to reproduction steps described in README.md contained in each folder.

## Motivation

Distributed build systems make it possible to increase software productivity by saving times
needed for building binaries from large source tree.  One of important metrics of these systems is
the scalability of compilation throughput for the size of cluster of build machines.  The
compilation throughput of an ideal system follows Amdahl's law.  And it's theoretically limited by
the percentage of non-parallelizable parts in the whole.

[Icecream] (formerly icecc) is a widely used distributed build system for C/C++ projects.
Icecream processes `#include` directives on the client machine and distribute remaining
preprocessing to remote machines in order to improve the compilation throughput.  However,
processing `#include` directives on the client machine cause high CPU usage when the client
performs a lot of build jobs in parallel.  As a result, the compilation throughput peaks out
before reaching the theoretical limit if the client machine does not equip a powerful CPU.

The issue regardin `#include` directives has been solved in [distcc] which is another famous
distributed build system.  distcc with the pump mode sends included header files to remote build
servers so that preprocessing can be distributed.  However, distcc is highly optimized for C,
C++ and Objective-C projects.  And it does not support other programming languages.

A [Docker] container seems be to be used initially for encapsulation of a single service like a web
server.  After a short time, someone started to use it as a build environment.  This method saves
time to prepare a build environment respectively, avoids problems caused by incorrect preparations,
and makes it possible to deliver the build environment as a Docker image.

Normally, a Docker image for a build environment includes all stuffs needed to build binaries
other than the source tree for the binaries.  This means that we can simply distribute
C/C++ preprocessing on remote machines if we can mount the source tree onto the remote machines.
And there are a lot of such software at this point.  [SSHFS] is one of them.

As described so far, we are possibly able to build a distributed build system using Docker
containers with smaller effort than before.

## Basic idea

As described in the previous section, the basic idea is very simple:

1. Create a Docker image containing all stuffs needed to build binaries
2. Create containers and mount the source tree of the target binaries
3. Distribute build jobs to the containers

The component diagram is show below:

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
   |          | Build command via SSH           |
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

## TODO

* A mechanism to launch worker containers on demand from a client container
* Security Model

## Dependencies

* Docker
* Python3
* SSH
* SSHFS

## License

Licensed under either of

* Apache License, Version 2.0
  ([LICENSE-APACHE] or http://www.apache.org/licenses/LICENSE-2.0)
* MIT License
  ([LICENSE-MIT] or http://opensource.org/licenses/MIT)

at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in this project by you, as defined in the Apache-2.0 license,
shall be dual licensed as above, without any additional terms or conditions.

[Icecream]: https://github.com/icecc/icecream
[distcc]: https://distcc.github.io/
[Docker]: https://en.wikipedia.org/wiki/Docker_(software)
[SSHFS]: https://github.com/libfuse/sshfs
[LICENSE-APACHE]: ./LICENSE-APACHE
[LICENSE-MIT]: ./LICENSE-MIT
