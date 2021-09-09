FROM rust
COPY ./scripts /opt/concc/
RUN sh -eux /opt/concc/setup.sh
EXPOSE 22/tcp
WORKDIR /proj
