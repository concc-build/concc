FROM rust AS tools-build
WORKDIR /build
COPY ./tools .
RUN cargo build --release
RUN strip target/release/concc-scriptify
RUN strip target/release/concc-worker-pool
RUN cargo install --git=https://github.com/concc-build/sshfs-rs.git
RUN strip /usr/local/cargo/bin/sshfs

FROM scratch
LABEL maintainer="Contributors of concc-build"
COPY ./setup.sh /opt/concc/
COPY ./bin /opt/concc/bin/
COPY --from=tools-build /build/target/release/concc-scriptify /opt/concc/bin/
COPY --from=tools-build /build/target/release/concc-worker-pool /opt/concc/bin/
COPY --from=tools-build /usr/local/cargo/bin/sshfs /opt/concc/bin/
