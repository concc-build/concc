FROM ubuntu:focal
ARG CHROMIUM="93.0.4577.63"  # commit-sh
COPY ./buildenv.sh /buildenv.sh
RUN sh -eux /buildenv.sh $CHROMIUM
COPY ./docker/setup.sh /
RUN sh -eux /setup.sh
COPY ./docker/bin/* /usr/local/bin/
EXPOSE 22/tcp
WORKDIR /workspace
ENV PATH="$PATH:/opt/depot_tools"
