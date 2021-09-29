FROM rust AS tools-build
WORKDIR /build
COPY ./tools /build/
RUN cargo build --release
RUN strip target/release/concc-scriptify
RUN strip target/release/concc-worker-pool

FROM scratch
LABEL maintainer="Contributors of concc"
COPY ./setup.sh /opt/concc/
COPY ./bin /opt/concc/bin/
COPY --from=tools-build /build/target/release/concc-scriptify /opt/concc/bin/
COPY --from=tools-build /build/target/release/concc-worker-pool /opt/concc/bin/
