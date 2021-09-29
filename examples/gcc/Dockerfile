FROM masnagam/concc-tools AS tools

FROM debian
COPY ./buildenv.sh /
RUN sh -eux /buildenv.sh
COPY --from=tools /opt/concc /opt/concc/
RUN sh -eux /opt/concc/setup.sh
EXPOSE 22/tcp
WORKDIR /workspace
ENV PATH="/opt/concc/bin:$PATH"
