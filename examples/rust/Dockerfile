FROM rust
COPY --from=concc-poc/tools /opt/concc /opt/concc/
RUN sh -eux /opt/concc/setup.sh
EXPOSE 22/tcp
WORKDIR /workspace
ENV PATH="/opt/concc/bin:$PATH"
ENV CARGO_HOME=/workspace/.cargo
