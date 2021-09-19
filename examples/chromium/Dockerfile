FROM ubuntu:focal
ARG CHROMIUM=main  # commit-sh
COPY ./buildenv.sh /buildenv.sh
RUN sh -eux /buildenv.sh $CHROMIUM
COPY ./docker/setup.sh /
RUN sh -eux /setup.sh
COPY ./docker/bin/* /usr/local/bin/
EXPOSE 22/tcp
WORKDIR /workspace
ENV CHROMIUM=$CHROMIUM
ENV PATH="$PATH:/opt/depot_tools"
