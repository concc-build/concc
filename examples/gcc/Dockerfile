FROM debian
COPY ./buildenv.sh /
RUN sh -eux /buildenv.sh
COPY ./docker/setup.sh /
RUN sh -eux /setup.sh
COPY ./docker/bin/* /usr/local/bin/
EXPOSE 22/tcp
WORKDIR /workspace
