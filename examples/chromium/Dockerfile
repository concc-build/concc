FROM ubuntu:bionic
ARG CHROMIUM="93.0.4577.63"  # commit-sh
COPY ./buildenv.sh /buildenv.sh
RUN sh -eux /buildenv.sh $CHROMIUM
COPY ./scripts /opt/concc/
RUN sh -eux /opt/concc/setup.sh
EXPOSE 22/tcp
ENV PATH="$PATH:/opt/depot_tools"
WORKDIR /proj
