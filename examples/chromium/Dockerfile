FROM ubuntu:focal
ARG CHROMIUM=main  # commit-sh
COPY ./buildenv.sh /buildenv.sh
RUN sh -eux /buildenv.sh $CHROMIUM
COPY --from=masnagam/concc-tools /opt/concc /opt/concc/
RUN sh -eux /opt/concc/setup.sh
EXPOSE 22/tcp
WORKDIR /workspace
ENV PATH="/opt/concc/bin:/opt/depot_tools:$PATH"
ENV CHROMIUM=$CHROMIUM
