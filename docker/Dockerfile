FROM rust AS tools-build
WORKDIR /build
COPY ./tools .
RUN cargo build --release
RUN strip target/release/concc-scriptify
RUN strip target/release/concc-worker-pool

FROM debian AS sshfs-build
WORKDIR /build
COPY ./build-sshfs.sh ./sshfs/* .
RUN sh -eux ./build-sshfs.sh

FROM scratch
LABEL maintainer="Contributors of concc"
COPY ./setup.sh /opt/concc/
COPY ./bin /opt/concc/bin/
COPY --from=tools-build /build/target/release/concc-scriptify /opt/concc/bin/
COPY --from=tools-build /build/target/release/concc-worker-pool /opt/concc/bin/
COPY --from=sshfs-build /build/sshfs /opt/concc/bin/
